package Koha::Plugin::Com::OpenFifth::Oracle::UploadController;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Koha::DateUtils qw( dt_from_string );
use Koha::File::Transports;
use File::Spec;

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
                status => 400,
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
                status => 400,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "Failed to generate report"
                }
            );
        }

        # Upload to SFTP
        eval {
            $transport->connect;
            open my $fh, '<', \$report;
            my $upload_result = $transport->upload_file( $fh, $filename );
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
                return $c->render(
                    status => 400,
                    openapi => {
                        success => Mojo::JSON->false,
                        message => "Failed to upload file to SFTP server"
                    }
                );
            }
        };

        if ($@) {
            return $c->render(
                status => 400,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "SFTP upload error: $@"
                }
            );
        }
    } else {
        # Save to local file
        my $filename = $plugin->_generate_filename($type);
        my $report = $plugin->_generate_report( $startdate, $enddate, $type, $filename );

        unless ($report) {
            return $c->render(
                status => 400,
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
                status => 400,
                openapi => {
                    success => Mojo::JSON->false,
                    message => "Error saving file: $@"
                }
            );
        }
    }
}

1;
