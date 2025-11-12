package Koha::Plugin::Com::OpenFifth::Oracle::UploadController;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Koha::DateUtils qw( dt_from_string );
use Koha::File::Transports;
use File::Spec;
use JSON qw( decode_json );

=head1 API

=head2 Class Methods

=head3 upload

Handle upload/save operations for Oracle reports

=cut

sub upload {
    my $c = shift->openapi->valid_input or return;

    # Get the plugin instance
    my $plugin_class = "Koha::Plugin::Com::OpenFifth::Oracle";
    my $plugin = $plugin_class->new();

    # Get parameters
    my $from = $c->validation->param('from');
    my $to = $c->validation->param('to');
    my $type = $c->validation->param('type');

    # Parse dates
    my $startdate = eval { dt_from_string($from) };
    my $enddate = eval { dt_from_string($to) };

    unless ($startdate && $enddate) {
        return $c->render(
            status => 400,
            openapi => {
                success => Mojo::JSON->false,
                message => "Invalid date parameters"
            }
        );
    }

    # Validate type
    unless ($type && ($type eq 'income' || $type eq 'invoices')) {
        return $c->render(
            status => 400,
            openapi => {
                success => Mojo::JSON->false,
                message => "Invalid report type. Must be 'income' or 'invoices'"
            }
        );
    }

    # Check output configuration
    my $output = $plugin->retrieve_data('output');

    if ($output eq 'upload') {
        # Get transport configuration
        my $transport = Koha::File::Transports->find( $plugin->retrieve_data('transport_server') );
        unless ($transport) {
            return $c->render(
                status => 503,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "No SFTP transport configured"
                }
            );
        }

        # Generate report
        my $filename = $plugin->_generate_filename($type);
        my $report = $plugin->_generate_report( $startdate, $enddate, $type, $filename );

        unless ($report) {
            return $c->render(
                status => 500,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "Failed to generate report"
                }
            );
        }

        # Get configured upload directory for this report type
        my $upload_dir = $type eq 'income'
            ? $plugin->retrieve_data('upload_dir_income')
            : $plugin->retrieve_data('upload_dir_invoices');

        # Construct upload path (directory + filename)
        my $upload_path = $filename;
        if ($upload_dir && $upload_dir =~ /\S/) {
            # Remove leading/trailing slashes and ensure single trailing slash
            $upload_dir =~ s{^/+}{};
            $upload_dir =~ s{/+$}{};
            $upload_path = $upload_dir ? "$upload_dir/$filename" : $filename;
        }

        # Upload to SFTP
        eval {
            my $connect_result = $transport->connect;
            unless ($connect_result) {
                my $error_detail = $c->_extract_transport_error($transport, 'connection');
                return $c->render(
                    status => 502,
                    openapi => {
                        success => Mojo::JSON->false,
                        message => "SFTP connection failed: " . $error_detail->{message},
                        error_detail => $error_detail
                    }
                );
            }

            open my $fh, '<', \$report;
            my $upload_result = $transport->upload_file( $fh, $upload_path );
            close $fh;

            if ($upload_result) {
                return $c->render(
                    status => 200,
                    openapi => {
                        success => Mojo::JSON->true,
                        message => "File uploaded successfully to SFTP server",
                        filename => $filename
                    }
                );
            } else {
                my $error_detail = $c->_extract_transport_error($transport, 'upload');
                return $c->render(
                    status => 502,
                    openapi => {
                        success => Mojo::JSON->false,
                        message => "SFTP upload failed: " . $error_detail->{message},
                        error_detail => $error_detail
                    }
                );
            }
        };

        if ($@) {
            return $c->render(
                status => 502,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "SFTP upload exception: $@"
                }
            );
        }
    } else {
        # Save to local file
        my $filename = $plugin->_generate_filename($type);
        my $report = $plugin->_generate_report( $startdate, $enddate, $type, $filename );

        unless ($report) {
            return $c->render(
                status => 500,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "Failed to generate report"
                }
            );
        }

        my $file_path = File::Spec->catfile( $plugin->bundle_path, 'output', $filename );

        eval {
            open( my $fh, '>', $file_path ) or die "Unable to open $file_path: $!";
            print $fh $report;
            close($fh);

            return $c->render(
                status => 200,
                openapi => {
                    success => Mojo::JSON->true,
                    message => "File saved successfully to server",
                    filename => $filename
                }
            );
        };

        if ($@) {
            return $c->render(
                status => 500,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "Error saving file: $@"
                }
            );
        }
    }
}

=head3 _extract_transport_error

Helper method to extract detailed error information from a transport object

=cut

sub _extract_transport_error {
    my ( $self, $transport, $operation ) = @_;

    my $error_detail = {
        operation => $operation,
        message   => 'Unknown error'
    };

    # Extract error from transport status field
    if ( my $status_json = $transport->status ) {
        eval {
            my $status = decode_json($status_json);
            if ( $status->{operations} && ref $status->{operations} eq 'ARRAY' ) {
                # Find the most recent error operation
                for my $op ( reverse @{ $status->{operations} } ) {
                    if ( $op->{status} eq 'error' && $op->{detail} ) {
                        $error_detail->{message}     = $op->{detail}->{error} || 'Unknown error';
                        $error_detail->{status_code} = $op->{detail}->{status};
                        $error_detail->{path}        = $op->{detail}->{path};
                        $error_detail->{error_raw}   = $op->{detail}->{error_raw};
                        $error_detail->{operation}   = $op->{code} if $op->{code};
                        last;
                    }
                }
            }
        };
    }

    # Extract error from object messages (in-memory, more immediate)
    if ( my $messages = $transport->object_messages ) {
        for my $msg ( reverse @{$messages} ) {
            if ( $msg->type eq 'error' ) {
                my $payload = $msg->payload;
                if ($payload) {
                    $error_detail->{message}     = $payload->{error} || $error_detail->{message};
                    $error_detail->{status_code} = $payload->{status};
                    $error_detail->{path}        = $payload->{path};
                    $error_detail->{error_raw}   = $payload->{error_raw};
                }
                $error_detail->{operation} = $msg->message if $msg->message;
                last;
            }
        }
    }

    return $error_detail;
}

1;
