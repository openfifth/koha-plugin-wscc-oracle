package Koha::Plugin::Com::OpenFifth::Oracle;

use Modern::Perl;

use base            qw{ Koha::Plugins::Base };
use Koha::DateUtils qw(dt_from_string);
use Koha::File::Transports;
use Koha::Number::Price;
use Koha::Account::Lines;
use Koha::Account::Offsets;
use Koha::AdditionalFields;
use Koha::AdditionalFieldValues;
use Koha::Acquisition::Funds;
use Koha::Acquisition::Booksellers;
use Koha::Cash::Register::Cashups;

use File::Spec;
use List::Util qw(min max);
use Mojo::JSON qw{ decode_json encode_json };
use Text::CSV  qw( csv );
use C4::Context;

our $VERSION = '0.2.15';

our $metadata = {
    name => 'Oracle Finance Integration',

    author          => 'Open Fifth',
    date_authored   => '2025-04-24',
    date_updated    => '2026-02-09',
    minimum_version => '24.11.00.000',
    maximum_version => '25.05.00.000',
    version         => $VERSION,
    description     =>
      'A plugin to manage finance integration for WSCC with Oracle',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);
    $self->{cgi} = CGI->new();

    # Initialize caches for additional fields
    $self->{debit_type_fields_cache} = {};
    $self->{branch_fields_cache}     = {};

    return $self;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        ## Grab the values we already have for our settings, if any exist
        my $available_transports = Koha::File::Transports->search();
        my @days_of_week =
          qw(sunday monday tuesday wednesday thursday friday saturday);
        my $transport_days_data = $self->retrieve_data('transport_days') || '';
        my $transport_days      = {
            map  { $days_of_week[$_] => 1 }
            grep { defined $days_of_week[$_] }
              split( ',', $transport_days_data )
        };

        # Get all acquisition funds for the mapping table
        my $funds = Koha::Acquisition::Funds->search(
            {},
            {
                order_by => 'budget_code'
            }
        );

        # Get all vendors for the mapping table
        my $vendors = Koha::Acquisition::Booksellers->search(
            {},
            {
                order_by => 'name'
            }
        );

        # Get existing fund mappings
        my $fund_mappings_data =
          $self->retrieve_data('fund_field_mappings') || '{}';
        my $fund_mappings = eval { decode_json($fund_mappings_data) } || {};

        # Get existing vendor mappings
        my $vendor_supplier_data =
          $self->retrieve_data('vendor_supplier_mappings') || '{}';
        my $vendor_supplier_mappings =
          eval { decode_json($vendor_supplier_data) } || {};

        my $vendor_contract_data =
          $self->retrieve_data('vendor_contract_mappings') || '{}';
        my $vendor_contract_mappings =
          eval { decode_json($vendor_contract_data) } || {};
        $template->param(
            transport_server     => $self->retrieve_data('transport_server'),
            transport_days       => $transport_days,
            output               => $self->retrieve_data('output'),
            available_transports => $available_transports,
            upload_dir_income    => $self->retrieve_data('upload_dir_income'),
            upload_dir_invoices  => $self->retrieve_data('upload_dir_invoices'),
            default_acquisitions_costcenter =>
              $self->retrieve_data('default_acquisitions_costcenter'),
            default_acquisitions_objective =>
              $self->retrieve_data('default_acquisitions_objective'),
            default_acquisitions_subjective =>
              $self->retrieve_data('default_acquisitions_subjective'),
            default_acquisitions_subanalysis =>
              $self->retrieve_data('default_acquisitions_subanalysis'),
            default_income_costcentre =>
              $self->retrieve_data('default_income_costcentre'),
            default_branch_objective =>
              $self->retrieve_data('default_branch_objective'),
            default_vat_code    => $self->retrieve_data('default_vat_code'),
            default_subjective  => $self->retrieve_data('default_subjective'),
            default_subanalysis => $self->retrieve_data('default_subanalysis'),
            default_income_costcentre_offset =>
              $self->retrieve_data('default_income_costcentre_offset'),
            default_income_subjective_offset =>
              $self->retrieve_data('default_income_subjective_offset'),
            default_income_subanalysis_offset =>
              $self->retrieve_data('default_income_subanalysis_offset'),
            funds => $funds,
            fund_mappings            => $fund_mappings,
            vendors                  => $vendors,
            vendor_supplier_mappings => $vendor_supplier_mappings,
            vendor_contract_mappings => $vendor_contract_mappings
        );

        $self->output_html( $template->output() );
    }
    else {
        # Get selected days (returns an array from multiple checkboxes)
        my @selected_days = $cgi->multi_param('days');
        my $days_str      = join( ',', sort { $a <=> $b } @selected_days );

        # Process fund mapping data
        my %fund_mappings;
        my %vendor_supplier_mappings;
        my %vendor_contract_mappings;
        my @param_names = $cgi->param();
        for my $param_name (@param_names) {
            if ( $param_name =~
                /^fund_(costcenter|objective|subjective|subanalysis)_(.+)$/ )
            {
                my $field_type = $1;
                my $fund_code  = $2;
                my $value      = $cgi->param($param_name);
                if ( $value && $value =~ /\S/ ) {
                    $fund_mappings{$fund_code} ||= {};
                    $fund_mappings{$fund_code}{$field_type} = $value;
                }
            }
            elsif ( $param_name =~ /^vendor_supplier_(.+)$/ ) {
                my $vendor_id       = $1;
                my $supplier_number = $cgi->param($param_name);
                if ( $supplier_number && $supplier_number =~ /\S/ ) {
                    $vendor_supplier_mappings{$vendor_id} = $supplier_number;
                }
            }
            elsif ( $param_name =~ /^vendor_contract_(.+)$/ ) {
                my $vendor_id       = $1;
                my $contract_number = $cgi->param($param_name);
                if ( $contract_number && $contract_number =~ /\S/ ) {
                    $vendor_contract_mappings{$vendor_id} = $contract_number;
                }
            }
        }

        $self->store_data(
            {
                transport_server    => scalar $cgi->param('transport_server'),
                transport_days      => $days_str,
                output              => scalar $cgi->param('output'),
                upload_dir_income   => scalar $cgi->param('upload_dir_income'),
                upload_dir_invoices =>
                  scalar $cgi->param('upload_dir_invoices'),
                default_acquisitions_costcenter =>
                  scalar $cgi->param('default_acquisitions_costcenter'),
                default_acquisitions_objective =>
                  scalar $cgi->param('default_acquisitions_objective'),
                default_acquisitions_subjective =>
                  scalar $cgi->param('default_acquisitions_subjective'),
                default_acquisitions_subanalysis =>
                  scalar $cgi->param('default_acquisitions_subanalysis'),
                default_income_costcentre =>
                  scalar $cgi->param('default_income_costcentre'),
                default_branch_objective =>
                  scalar $cgi->param('default_branch_objective'),
                default_vat_code    => scalar $cgi->param('default_vat_code'),
                default_subjective  => scalar $cgi->param('default_subjective'),
                default_subanalysis =>
                  scalar $cgi->param('default_subanalysis'),
                default_income_costcentre_offset =>
                  scalar $cgi->param('default_income_costcentre_offset'),
                default_income_subjective_offset =>
                  scalar $cgi->param('default_income_subjective_offset'),
                default_income_subanalysis_offset =>
                  scalar $cgi->param('default_income_subanalysis_offset'),
                fund_field_mappings => encode_json( \%fund_mappings ),
                vendor_supplier_mappings =>
                  encode_json( \%vendor_supplier_mappings ),
                vendor_contract_mappings =>
                  encode_json( \%vendor_contract_mappings )
            }
        );
        $self->go_home();
    }
}

sub cronjob_nightly {
    my ($self) = @_;

    my $transport_days = $self->retrieve_data('transport_days');
    return unless $transport_days;

    my @selected_days = sort { $a <=> $b } split( /,/, $transport_days );
    my %selected_days = map  { $_ => 1 } @selected_days;

    # Get current day of the week (0=Sunday, ..., 6=Saturday)
    my $today = dt_from_string()->day_of_week % 7;
    return unless $selected_days{$today};

    my $output = $self->retrieve_data('output');
    my $transport;
    if ( $output eq 'upload' ) {
        $transport = Koha::File::Transports->find(
            $self->retrieve_data('transport_server') );
        return unless $transport;
    }

    # Find start date (previous selected day) and end date (today)
    my $previous_day =
      max( grep { $_ < $today } @selected_days );   # Last selected before today
    $previous_day //=
      $selected_days[-1];    # Wrap around to last one from previous week

    # Calculate the start date (previous selected day) and end date (today)
    my $now = DateTime->now;
    my $start_date =
      $now->clone->subtract( days => ( $today - $previous_day ) % 7 );
    my $end_date = $now;

    # Generate both income and invoices reports
    my @report_types = ( 'income', 'invoices' );
    my $all_success  = 1;

    for my $type (@report_types) {
        my $filename = $self->_generate_filename($type);
        my $report =
          $self->_generate_report( $start_date, $end_date, $type, $filename );

        next unless $report;

        if ( $output eq 'upload' ) {

            # Get configured upload directory for this report type
            my $upload_dir =
                $type eq 'income'
              ? $self->retrieve_data('upload_dir_income')
              : $self->retrieve_data('upload_dir_invoices');

            # Construct upload path (directory + filename)
            my $upload_path = $filename;
            if ( $upload_dir && $upload_dir =~ /\S/ ) {

                # Remove leading/trailing slashes and ensure proper format
                $upload_dir =~ s{^/+}{};
                $upload_dir =~ s{/+$}{};
                $upload_path =
                  $upload_dir ? "$upload_dir/$filename" : $filename;
            }

            $transport->connect;
            open my $fh, '<', \$report;
            if ( $transport->upload_file( $fh, $upload_path ) ) {
                close $fh;
            }
            else {
                # Upload failed for this report type
                close $fh;
                $all_success = 0;
            }
        }
        else {
            my $file_path =
              File::Spec->catfile( $self->bundle_path, 'output', $filename );
            open( my $fh, '>', $file_path )
              or die "Unable to open $file_path: $!";
            print $fh $report;
            close($fh);
        }
    }

    return $all_success;
}

sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('output') ) {
        $self->report_step1();
    }
    else {
        $self->report_step2();
    }
}

sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $startdate =
      $cgi->param('startdate')
      ? dt_from_string( $cgi->param('startdate') )
      : undef;
    my $enddate =
      $cgi->param('enddate') ? dt_from_string( $cgi->param('enddate') ) : undef;

    my $template = $self->get_template( { file => 'report-step1.tt' } );
    $template->param(
        startdate => $startdate,
        enddate   => $enddate,
    );

    $self->output_html( $template->output() );
}

sub report_step2 {
    my ( $self, $args ) = @_;

    my $cgi       = $self->{'cgi'};
    my $startdate = $cgi->param('from');
    my $enddate   = $cgi->param('to');
    my $type      = $cgi->param('type');
    my $output    = $cgi->param('output');

    if ($startdate) {
        $startdate =~ s/^\s+//;
        $startdate =~ s/\s+$//;
        $startdate = eval { dt_from_string($startdate) };
    }

    if ($enddate) {
        $enddate =~ s/^\s+//;
        $enddate =~ s/\s+$//;
        $enddate = eval { dt_from_string($enddate) };
    }

    my $filename = $self->_generate_filename($type);
    my $results =
      $self->_generate_report( $startdate, $enddate, $type, $filename );

    my $templatefile;

    if ( $output eq "txt" ) {
        print $cgi->header( -attachment => "$filename" );
        $templatefile = 'report-step2-txt.tt';
    }
    else {
        print $cgi->header();
        $templatefile = 'report-step2-html.tt';
    }

    my $template = $self->get_template( { file => $templatefile } );

    $template->param(
        date_ran  => dt_from_string(),
        startdate => dt_from_string($startdate),
        enddate   => dt_from_string($enddate),
        results   => $results,
        type      => $type,
        filename  => $filename,
        CLASS     => ref($self),
    );

    print $template->output();
}

sub api_namespace {
    my ($self) = @_;

    return 'oracle';
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub _generate_report {
    my ( $self, $startdate, $enddate, $type, $filename ) = @_;
    if ( $type eq 'income' ) {
        return $self->_generate_income_report( $startdate, $enddate,
            $filename );
    }
    elsif ( $type eq 'invoices' ) {
        return $self->_generate_invoices_report( $startdate, $enddate,
            $filename );
    }
}

sub _generate_invoices_report {
    my ( $self, $startdate, $enddate, $filename ) = @_;

    my $csv = Text::CSV->new(
        {
            binary       => 1,
            eol          => "\015\012",
            sep_char     => "|",
            quote_char   => '"',
            always_quote => 1
        }
    );

    ( my $filename_no_ext = $filename ) =~ s/\.csv$//;

    my $where         = {};
    my $dtf           = Koha::Database->new->schema->storage->datetime_parser;
    my $startdate_iso = $dtf->format_date($startdate);
    my $enddate_iso   = $dtf->format_date($enddate);
    if ( $startdate_iso && $enddate_iso ) {
        $where->{'me.closedate'} =
          [ -and => { '>=', $startdate_iso }, { '<=', $enddate_iso } ];
    }
    elsif ($startdate_iso) {
        $where->{'me.closedate'} = { '>=', $startdate_iso };
    }
    elsif ($enddate_iso) {
        $where->{'me.closedate'} = { '<=', $enddate_iso };
    }

    my $invoices = Koha::Acquisition::Invoices->search( $where,
        { prefetch => [ 'booksellerid', 'aqorders' ] } );

    my $results;
    my $invoice_count = 0;

    if ( $invoices->count ) {
        $results = "";
        open my $fh, '>', \$results or die "Could not open scalar ref: $!";

        # Start with header line matching new client requirements
        my @header_line =
          qw(INVOICE_NUMBER INVOICE_TOTAL INVOICE_DATE SUPPLIER_NUMBER CONTRACT_NUMBER SHIPMENT_DATE LINE_AMOUNT TAX_AMOUNT TAX_CODE DESCRIPTION COST_CENTRE OBJECTIVE SUBJECTIVE SUBANALYSIS LIN_NUM);
        my $worked = $csv->print( $fh, \@header_line );

        while ( my $invoice = $invoices->next ) {
            $invoice_count++;
            my $invoice_total = 0;
            my $orders        = $invoice->_result->aqorders;

            # Calculate invoice total first
            my @orderlines;
            my $line_count = 0;
            while ( my $line = $orders->next ) {
                $line_count++;

                # Unit price - keep as numeric for calculation
                my $unitprice = Koha::Number::Price->new( $line->unitprice )->round;
                my $quantity = $line->quantity || 1;

                # Tax - keep as numeric for calculation
                my $tax_value_on_receiving = Koha::Number::Price->new( $line->tax_value_on_receiving )->round;

                # Invoice total includes both line amount and tax
                $invoice_total += ( $unitprice * $quantity ) + ( $tax_value_on_receiving * $quantity );
                my $tax_rate_on_receiving = $line->tax_rate_on_receiving * 100;
                my $tax_code =
                    $tax_rate_on_receiving == 20 ? 'STANDARD'
                  : $tax_rate_on_receiving == 0  ? 'ZERO'
                  :                                '*UNMAPPED*';

                # Get budget code for mappings
                my $budget_code = $line->budget->budget_code;

                # Get item description (fallback to generic if not available)
                my $description = "Library Materials";
                if ( my $biblio = $line->biblio ) {
                    $description = $biblio->title || $description;
                }

                # Line record: INVOICE_NUMBER, then empty fields for header
                # data, then line-specific data
                # Line amounts are positive (matching header convention)
                for my $qty_unit ( 1 .. $quantity ) {
                    push @orderlines, [
                        $invoice->invoicenumber,    # INVOICE_NUMBER
                        "",            # INVOICE_TOTAL (empty for line)
                        "",            # INVOICE_DATE (empty for line)
                        "",            # SUPPLIER_NUMBER (empty for line)
                        "",            # CONTRACT_NUMBER (empty for line)
                        "",            # SHIPMENT_DATE (empty for line)
                        sprintf( "%.2f", $unitprice ),    # LINE_AMOUNT (positive)
                        sprintf( "%.2f", $tax_value_on_receiving ),    # TAX_AMOUNT (positive)
                        $tax_code,                  # TAX_CODE
                        $description,               # DESCRIPTION
                        $self->_get_acquisitions_costcenter($budget_code)
                        ,                           # COST_CENTRE
                        $self->_get_acquisitions_objective($budget_code)
                        ,                           # OBJECTIVE
                        $self->_get_acquisitions_subjective($budget_code)
                        ,                           # SUBJECTIVE
                        $self->_get_acquisitions_subanalysis($budget_code)
                        ,                           # SUBANALYSIS
                        $line_count++               # LIN_NUM
                    ];
                }
            }

            # Get supplier number and contract number from vendor mappings
            my $vendor_id = $invoice->booksellerid;
            my $supplier_number =
              $self->_get_vendor_supplier_number($vendor_id);
            my $contract_number =
              $self->_get_vendor_contract_number($vendor_id);

            # Format invoice total as positive for header record
            $invoice_total = sprintf( "%.2f", $invoice_total );

            # Build header record with new format (15 fields)
            # Header record: INVOICE_NUMBER, INVOICE_TOTAL,
            # INVOICE_DATE, SUPPLIER_NUMBER,
            # CONTRACT_NUMBER, SHIPMENT_DATE, then empty fields
            $csv->print(
                $fh,
                [
                    $invoice->invoicenumber,    # INVOICE_NUMBER
                    $invoice_total,             # INVOICE_TOTAL
                    $self->_format_oracle_date( $invoice->closedate )
                    ,                           # INVOICE_DATE
                    $supplier_number,           # SUPPLIER_NUMBER
                    $contract_number,           # CONTRACT_NUMBER
                    $self->_format_oracle_date( $invoice->shipmentdate )
                    ,                           # SHIPMENT_DATE
                    "",                         # LINE_AMOUNT (empty for header)
                    "",                         # TAX_AMOUNT (empty for header)
                    "",                         # TAX_CODE (empty for header)
                    "",                         # DESCRIPTION (empty for header)
                    "",                         # COST_CENTRE (empty for header)
                    "",                         # OBJECTIVE (empty for header)
                    "",                         # SUBJECTIVE (empty for header)
                    "",                         # SUBANALYSIS (empty for header)
                    ""                          # LIN_NUM (empty for header)
                ]
            );

            # Print all line records for this invoice
            for my $line (@orderlines) {
                $csv->print( $fh, $line );
            }
        }

        close $fh;
    }

    return $results;
}

sub _get_acquisitions_costcenter {
    my ( $self, $fund_code ) = @_;

    # Get configured fund mappings
    my $fund_mappings_data =
      $self->retrieve_data('fund_field_mappings') || '{}';
    my $fund_mappings = eval { decode_json($fund_mappings_data) } || {};

    # Check if we have a specific mapping for this fund
    if (   $fund_mappings->{$fund_code}
        && $fund_mappings->{$fund_code}{costcenter} )
    {
        return $fund_mappings->{$fund_code}{costcenter};
    }

    # Fall back to configured default
    return $self->retrieve_data('default_acquisitions_costcenter');
}

sub _get_acquisitions_objective {
    my ( $self, $fund_code ) = @_;

    # Get configured fund mappings
    my $fund_mappings_data =
      $self->retrieve_data('fund_field_mappings') || '{}';
    my $fund_mappings = eval { decode_json($fund_mappings_data) } || {};

    # Check if we have a specific mapping for this fund
    if (   $fund_mappings->{$fund_code}
        && $fund_mappings->{$fund_code}{objective} )
    {
        return $fund_mappings->{$fund_code}{objective};
    }

    # Fall back to configured default
    return $self->retrieve_data('default_acquisitions_objective');
}

sub _get_acquisitions_subjective {
    my ( $self, $fund_code ) = @_;

    # Get configured fund mappings
    my $fund_mappings_data =
      $self->retrieve_data('fund_field_mappings') || '{}';
    my $fund_mappings = eval { decode_json($fund_mappings_data) } || {};

    # Check if we have a specific mapping for this fund
    if (   $fund_mappings->{$fund_code}
        && $fund_mappings->{$fund_code}{subjective} )
    {
        return $fund_mappings->{$fund_code}{subjective};
    }

    # Fall back to configured default
    return $self->retrieve_data('default_acquisitions_subjective');
}

sub _get_acquisitions_subanalysis {
    my ( $self, $fund_code ) = @_;

    # Get configured fund mappings
    my $fund_mappings_data =
      $self->retrieve_data('fund_field_mappings') || '{}';
    my $fund_mappings = eval { decode_json($fund_mappings_data) } || {};

    # Check if we have a specific mapping for this fund
    if (   $fund_mappings->{$fund_code}
        && $fund_mappings->{$fund_code}{subanalysis} )
    {
        return $fund_mappings->{$fund_code}{subanalysis};
    }

    # Fall back to configured default
    return $self->retrieve_data('default_acquisitions_subanalysis');
}

sub _get_vendor_supplier_number {
    my ( $self, $vendor_id ) = @_;

    # Get vendor to supplier number mappings from configuration
    my $vendor_supplier_data =
      $self->retrieve_data('vendor_supplier_mappings') || '{}';
    my $vendor_mappings = eval { decode_json($vendor_supplier_data) } || {};

    # Return mapping for this vendor (no default - must be configured)
    return $vendor_mappings->{$vendor_id};
}

sub _get_vendor_contract_number {
    my ( $self, $vendor_id ) = @_;

    # Get vendor to contract number mappings from configuration
    my $vendor_contract_data =
      $self->retrieve_data('vendor_contract_mappings') || '{}';
    my $vendor_mappings = eval { decode_json($vendor_contract_data) } || {};

    # Return mapping for this vendor (no default - must be configured)
    return $vendor_mappings->{$vendor_id};
}

sub _get_acquisitions_distribution {
    my ( $self, $fund_code ) = @_;
    my $company     = "1000";    # Default company code
    my $costcenter  = $self->_get_acquisitions_costcenter($fund_code);
    my $objective   = $self->_get_acquisitions_objective($fund_code);
    my $subjective  = $self->_get_acquisitions_subjective($fund_code);
    my $subanalysis = $self->_get_acquisitions_subanalysis($fund_code);
    my $spare1      = "000000";
    my $spare2      = "000000";

    return
"$company-$costcenter-$objective-$subjective-$subanalysis-$spare1-$spare2";
}

# Apply temporary data fixes for upstream bugs not yet backported
# These fixes correct missing branchcodes on various transaction types
sub _apply_temporary_data_fixes {
    my ($self) = @_;

    my $dbh = C4::Context->dbh;

    # FIX 1: SIP payments missing branchcode
    # Bug: SIP type payments are not recording branch during processing
    # Fix: Set branchcode from the manager (staff member) who processed the payment
    my $sip_fix = $dbh->do(q{
        UPDATE accountlines al
        JOIN borrowers b ON al.manager_id = b.borrowernumber
        SET al.branchcode = b.branchcode
        WHERE al.branchcode IS NULL
        AND al.payment_type LIKE 'SIP%'
    });

    # FIX 2: Various debit types missing branchcode
    # Bug: OVERDUE, RESERVE, and other debit types not recording branch
    # Fix: Set debit branchcode to match the corresponding payment's branchcode
    # (Uses offsets table to find the related payment transaction)
    my $debit_fix = $dbh->do(q{
        UPDATE accountlines debit
        JOIN account_offsets o ON o.debit_id = debit.accountlines_id
        JOIN accountlines credit ON o.credit_id = credit.accountlines_id
        SET debit.branchcode = credit.branchcode
        WHERE debit.branchcode IS NULL
        AND debit.debit_type_code IS NOT NULL
        AND credit.branchcode IS NOT NULL
    });

    return 1;
}

sub _generate_income_report {
    my ( $self, $startdate, $enddate, $filename ) = @_;

    # TEMPORARY DATA FIXES - Apply before report generation
    # These fixes address core Koha bugs that haven't been backported yet
    $self->_apply_temporary_data_fixes();

    # Use pipe delimiter for income reports as specified
    my $csv = Text::CSV->new(
        {
            binary       => 1,
            eol          => "\015\012",
            sep_char     => "|",
            quote_char   => '"',
            always_quote => 1
        }
    );

    ( my $filename_no_ext = $filename ) =~ s/\.csv$//;

    # Build date filtering conditions for cashup query
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $cashup_conditions = {};

    if ( $startdate && $enddate ) {
        my $start_dt =
          $startdate->clone->set( hour => 0, minute => 0, second => 0 );
        my $end_dt =
          $enddate->clone->set( hour => 23, minute => 59, second => 59 );
        $cashup_conditions->{timestamp} = {
            '-between' => [
                $dtf->format_datetime($start_dt),
                $dtf->format_datetime($end_dt)
            ]
        };
    }
    elsif ($startdate) {
        my $start_dt =
          $startdate->clone->set( hour => 0, minute => 0, second => 0 );
        $cashup_conditions->{timestamp} =
          { '>=', $dtf->format_datetime($start_dt) };
    }
    elsif ($enddate) {
        my $end_dt =
          $enddate->clone->set( hour => 23, minute => 59, second => 59 );
        $cashup_conditions->{timestamp} =
          { '<=', $dtf->format_datetime($end_dt) };
    }

    # Query all cashups within date range (across all registers)
    my $cashups = Koha::Cash::Register::Cashups->search( $cashup_conditions,
        { order_by => { '-asc' => [ 'timestamp', 'id' ] } } );

    # Early return if no cashups found
    return undef unless $cashups->count;

    my $results     = "";
    my $line_number = 1;

    open my $fh, '>', \$results or die "Could not open scalar ref: $!";

    # Process each cashup session
    while ( my $cashup = $cashups->next ) {

        # Get accountlines for this cashup session
        my $session_accountlines = $cashup->accountlines();

       # Filter for income transactions (credits only, excluding reconciliation)
        my $income_transactions = $session_accountlines->search(
            {
                debit_type_code  => undef,                        # Only credits
                credit_type_code => { '!=' => 'CASHUP_SURPLUS' }
                ,    # Exclude reconciliation
                amount      => { '<', 0 },    # Negative amounts (credits)
                # BUG FIX: PURCHASE credits have NULL descriptions and were being excluded
                # by 'NOT LIKE' filter (NULL comparisons return NULL, not TRUE in SQL)
                -or => [
                    description => undef,                         # Include NULL descriptions
                    description => { 'NOT LIKE' => '%Pay360%' }   # Exclude Pay360
                ]
            }
        );

        # Skip if no income transactions in this session
        next unless $income_transactions->count;

     # Aggregate using offsets (same logic as before, but without DATE grouping)
        my $income_summary = Koha::Account::Offsets->search(
            {
                'me.credit_id' => {
                    '-in' => $income_transactions->_resultset->get_column(
                        'accountlines_id')->as_query
                },
                'me.debit_id' => { '!=' => undef }
            },
            {
                join => [
                    { 'credit' => 'credit_type_code' },
                    { 'debit'  => 'debit_type_code' }
                ],
                group_by => [
                    'credit.branchcode',       'debit.branchcode',
                    'credit.credit_type_code', 'credit_type_code.description',
                    'debit.debit_type_code',   'debit_type_code.description',
                    'credit.payment_type'
                ],
                'select' => [
                    { sum => 'me.amount' },         'credit.branchcode',
                    'debit.branchcode',             'credit.credit_type_code',
                    'credit_type_code.description', 'debit.debit_type_code',
                    'debit_type_code.description',  'credit.payment_type'
                ],
                'as' => [
                    'total_amount',       'credit_branchcode',
                    'debit_branchcode',   'credit_type_code',
                    'credit_description', 'debit_type_code',
                    'debit_description',  'payment_type'
                ]
            }
        );

        # Get cashup metadata for document reference and description
        my $register         = $cashup->register;
        my $register_id      = $register->id;
        my $cashup_id        = $cashup->id;
        my $cashup_timestamp = dt_from_string( $cashup->timestamp );

        # Process aggregated results for this cashup session
        while ( my $row = $income_summary->next ) {
            my $inclusive_amount =
              $row->get_column('total_amount') * -1;   # Reverse sign for income

            next if $inclusive_amount <= 0;    # Skip zero or negative amounts

            my $credit_branch =
              $row->get_column('credit_branchcode') || 'UNKNOWN';
            my $debit_branch =
              $row->get_column('debit_branchcode') || 'UNKNOWN';
            my $credit_type  = $row->get_column('credit_type_code');
            my $debit_type   = $row->get_column('debit_type_code');
            my $payment_type = $row->get_column('payment_type') || 'UNKNOWN';

            # Generate document reference (sequential across all cashups)
            my $doc_reference = "AGG" . sprintf( "%06d", $line_number );

            # Generate document description with cashup visibility
            # Format: MonDD/YY/RegisterID(CashupID)-BranchCode-LIB-Income
            my $doc_description = sprintf(
                "%s:%s(%d)-%s-LIB-Income",
                $cashup_timestamp->strftime('%b%d/%y'),    # MonDD/YY
                $register_id,
                $cashup_id,
                $credit_branch
            );

            # Use cashup timestamp as accounting date (Oracle format YYYY/MM/DD)
            my $accounting_date =
              $self->_format_oracle_date( $cashup->timestamp );

           # Get GL code mappings from branches and debit type additional fields
           # Credit branch = where payment was taken (for main fields)
           # Debit branch = where charge originated (for offset fields)
            my $credit_branch_fields =
              $self->_get_branch_additional_fields($credit_branch);
            my $debit_branch_fields =
              $self->_get_branch_additional_fields($debit_branch);
            my $debit_fields =
              $self->_get_debit_type_additional_fields($debit_type);

        # Use debit type cost centre if available, otherwise fall back to branch
            my $cost_centre = $debit_fields->{'Cost Centre'}
              || $credit_branch_fields->{'Income Cost Centre'};

          # Use debit type objective if available, otherwise fall back to branch
            my $objective = $debit_fields->{'Objective'}
              || $credit_branch_fields->{'Income Objective'};
            my $subjective  = $debit_fields->{'Subjective'};
            my $subanalysis = $debit_fields->{'Subanalysis'};

            # Get offset fields
            my $cost_centre_offset =
              $self->retrieve_data('default_income_costcentre_offset');
            my $objective_offset =
              $debit_branch_fields->{'Income Objective'};    # From debit branch
            my $subjective_offset =
              $self->retrieve_data('default_income_subjective_offset');
            my $subanalysis_offset =
              $self->retrieve_data('default_income_subanalysis_offset');

            # Get VAT information and calculate exclusive/VAT split
            my $vat_code = $self->_get_debit_type_vat_code($debit_type);
            my ( $exclusive_amount, $vat_amount ) =
              $self->_calculate_exclusive_and_vat( $inclusive_amount,
                $vat_code );

            # Create line description in format: "[Payment Type] [Item Type]"
            my $line_description = $payment_type . " " . $debit_type;
            $line_description =~ s/[|"]//g;   # Remove pipe and quote characters

            # Build record according to 16-field specification
            $csv->print(
                $fh,
                [
                    $doc_reference,         # 1. D_Document Document Number
                    $doc_description,       # 2. D_Document Description
                    $accounting_date,       # 3. D_Document Date
                    1,                      # 4. D_Line Number
                    $exclusive_amount
                    ,    # 5. D_Line Amount (TAX EXCLUSIVE, in pounds.pence)
                    $cost_centre,           # 6. D_Cost Centre
                    $objective,             # 7. D_Objective
                    $subjective,            # 8. D_Subjective
                    $subanalysis,           # 9. D_Subanalysis
                    $cost_centre_offset,    # 10. D_Cost Centre Offset
                    $objective_offset,      # 11. D_Objective Offset
                    $subjective_offset,     # 12. D_Subjective Offset
                    $subanalysis_offset,    # 13. D_Subanalysis Offset
                    $line_description,      # 14. D_Line Description
                    $vat_code,              # 15. D_VAT Code
                    $vat_amount    # 16. D_VAT Amount (Oracle trusts this value)
                ]
            );

            $line_number++;
        }
    }

    close $fh;

    return $results;
}

sub _generate_filename {
    my ( $self, $type ) = @_;
    my $filename;
    my $extension = '.csv';

    if ( $type eq 'invoices' ) {
        $filename =
          "KOHA_SaaS_APInvoice_" . dt_from_string()->strftime('%d%m%Y%H%M%S');
    }
    elsif ( $type eq 'income' ) {
        $filename = "KOHA_SaaS_TaxableJournal_"
          . dt_from_string()->strftime('%Y%m%d%H%M%S');
    }

    return $filename . $extension;
}

sub _format_oracle_date {
    my ( $self, $date ) = @_;
    return "" unless $date;

    # Convert from YYYY-MM-DD to YYYY/MM/DD format (updated requirement)
    if ( $date =~ /^(\d{4})-(\d{2})-(\d{2})/ ) {
        return "$1/$2/$3";
    }
    return $date;
}

# Get branch additional field values with caching
sub _get_branch_additional_fields {
    my ( $self, $branch_code ) = @_;

    # Return cached result if available
    return $self->{branch_fields_cache}->{$branch_code}
      if exists $self->{branch_fields_cache}->{$branch_code};

    # Get additional fields for branches
    my $additional_fields = Koha::AdditionalFields->search(
        {
            tablename => 'branches',
            name      => [ 'Income Objective', 'Income Cost Centre' ]
        }
    );

    my $fields = {};

    # Get field values for this branch
    while ( my $field = $additional_fields->next ) {
        my $field_value = Koha::AdditionalFieldValues->search(
            {
                field_id  => $field->id,
                record_id => $branch_code
            }
        )->next;

        if ($field_value) {
            $fields->{ $field->name } = $field_value->value;
        }
    }

    # Set defaults if not found in database (from plugin configuration)
    $fields->{'Income Objective'} //=
      $self->retrieve_data('default_branch_objective');
    $fields->{'Income Cost Centre'} //=
      $self->retrieve_data('default_income_costcentre');

    # Cache the result
    $self->{branch_fields_cache}->{$branch_code} = $fields;

    return $fields;
}

# Get additional field values for a debit type with caching
sub _get_debit_type_additional_fields {
    my ( $self, $debit_type_code ) = @_;

    # Return cached result if available
    return $self->{debit_type_fields_cache}->{$debit_type_code}
      if exists $self->{debit_type_fields_cache}->{$debit_type_code};

    # Get additional fields for account_debit_types
    my $additional_fields = Koha::AdditionalFields->search(
        {
            tablename => 'account_debit_types',
            name => [ 'VAT Code', 'Subjective', 'Subanalysis', 'Cost Centre', 'Objective' ]
        }
    );

    my $fields = {};

    # Get field values for this debit type
    while ( my $field = $additional_fields->next ) {
        my $field_value = Koha::AdditionalFieldValues->search(
            {
                field_id  => $field->id,
                record_id => $debit_type_code
            }
        )->next;

        if ($field_value) {
            $fields->{ $field->name } = $field_value->value;
        }
    }

    # Set defaults if not found in database (from plugin configuration)
    $fields->{'VAT Code'}    //= $self->retrieve_data('default_vat_code');
    $fields->{'Subjective'}  //= $self->retrieve_data('default_subjective');
    $fields->{'Subanalysis'} //= $self->retrieve_data('default_subanalysis');

    # Cache the result
    $self->{debit_type_fields_cache}->{$debit_type_code} = $fields;

    return $fields;
}

# Map debit type VAT Code to Oracle VAT String
sub _get_debit_type_vat_code {
    my ( $self, $debit_type ) = @_;

    # Get VAT code from additional fields
    my $fields   = $self->_get_debit_type_additional_fields($debit_type);
    my $vat_code = $fields->{'VAT Code'} || 'O';

    # Map database VAT codes to Oracle format
    my $vat_map = {
        'S' => 'STANDARD',
        'Z' => 'ZERO',
        'E' => 'EXEMPT',
        'O' => 'OUT OF SCOPE',
    };

    return $vat_map->{$vat_code} || 'OUT OF SCOPE';
}

# Given a VAT inclusive amount and a VAT Code
# Return both the exclusive amount and VAT amount
# Oracle will trust the VAT amount we provide (Field 16)
sub _calculate_exclusive_and_vat {
    my ( $self, $inclusive_amount, $vat_code ) = @_;

    # For non-STANDARD rates, return full amount as exclusive with zero VAT
    unless ( $vat_code eq 'STANDARD' ) {
        return (
            sprintf( "%.2f", $inclusive_amount ),    # Exclusive
            sprintf( "%.2f", 0 )                     # VAT
        );
    }

    # Standard VAT rate is 20%
    # Calculate exclusive amount: inclusive / 1.20
    my $exclusive_amount = $inclusive_amount / 1.20;

    # Round exclusive to nearest penny (standard rounding)
    $exclusive_amount = sprintf( "%.2f", $exclusive_amount );

    # Calculate VAT as the difference to ensure exact total
    # This guarantees: exclusive + VAT = inclusive (exactly)
    my $vat_amount = $inclusive_amount - $exclusive_amount;
    $vat_amount = sprintf( "%.2f", $vat_amount );

    return ( $exclusive_amount, $vat_amount );
}

1;
