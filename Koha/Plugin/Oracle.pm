package Koha::Plugin::Oracle;

use Modern::Perl;

use base            qw{ Koha::Plugins::Base };
use Koha::DateUtils qw(dt_from_string);
use Koha::File::Transports;
use Koha::Number::Price;
use Koha::Account::Lines;
use Koha::Account::Offsets;

use File::Spec;
use List::Util qw(min max);
use Mojo::JSON qw{ decode_json };
use Text::CSV  qw( csv );
use C4::Context;

our $VERSION = '0.0.01';

our $metadata = {
    name => 'Oracle Finance Integration',

    author          => 'Open Fifth',
    date_authored   => '2025-04-24',
    date_updated    => '2025-04-24',
    minimum_version => '24.11.00.000',
    maximum_version => '24.11',
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
        my $transport_days = {
            map  { $days_of_week[$_] => 1 }
            grep { defined $days_of_week[$_] }
              split( ',', $self->retrieve_data('transport_days') )
        };
        $template->param(
            transport_server     => $self->retrieve_data('transport_server'),
            transport_days       => $transport_days,
            output               => $self->retrieve_data('output'),
            available_transports => $available_transports
        );

        $self->output_html( $template->output() );
    }
    else {
        # Get selected days (returns an array from multiple checkboxes)
        my @selected_days = $cgi->multi_param('days');
        my $days_str      = join( ',', sort { $a <=> $b } @selected_days );
        $self->store_data(
            {
                transport_server => scalar $cgi->param('transport_server'),
                transport_days   => $days_str,
                output           => scalar $cgi->param('output')
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

    my $filename = $self->_generate_filename();
    my $report   = $self->_generate_report( $start_date, $end_date, $filename );
    if ($report) {

        if ( $output eq 'upload' ) {
            $transport->connect;
            open my $fh, '<', \$report;
            if ( $transport->file_upload( $fh, $filename ) ) {
                close $fh;
                return 1;
            }
            else {
                # Deal with transport errors?
                close $fh;
                return 0;
            }
        }
        else {
            my $file_path =
              File::Spec->catfile( $self->bundle_path, 'output', $filename );
            open( my $fh, '>', $file_path )
              or die "Unable to open $file_path: $!";
            print $fh $report;
            close($fh);
            return 1;
        }
    }

    return 1;
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
          qw(INVOICE_NUMBER INVOICE_TOTAL INVOICE_DATE SUPPLIER_NUMBER_PROPERTY_KEY CONTRACT_NUMBER SHIPMENT_DATE LINE_AMOUNT TAX_AMOUNT TAX_CODE DESCRIPTION COST_CENTRE_PROPERTY_KEY OBJECTIVE SUBJECTIVE SUBANALYSIS LIN_NUM);
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

                # Unit price
                my $unitprice =
                  Koha::Number::Price->new( $line->unitprice )->round * 100;
                my $quantity = $line->quantity || 1;
                $invoice_total += ( $unitprice * $quantity );

                # Tax
                my $tax_value_on_receiving =
                  Koha::Number::Price->new( $line->tax_value_on_receiving )
                  ->round * 100;
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

                # Build line records with new format (15 fields)
                # Line record: INVOICE_NUMBER, then empty fields for header data, then line-specific data
                for my $qty_unit ( 1 .. $quantity ) {
                    push @orderlines, [
                        $invoice->invoicenumber,              # INVOICE_NUMBER
                        "",                                   # INVOICE_TOTAL (empty for line)
                        "",                                   # INVOICE_DATE (empty for line)
                        "",                                   # SUPPLIER_NUMBER_PROPERTY_KEY (empty for line)
                        "",                                   # CONTRACT_NUMBER (empty for line)
                        "",                                   # SHIPMENT_DATE (empty for line)
                        $unitprice,                           # LINE_AMOUNT
                        $tax_value_on_receiving,              # TAX_AMOUNT
                        $tax_code,                            # TAX_CODE
                        $description,                         # DESCRIPTION
                        $self->_get_acquisitions_costcenter(), # COST_CENTRE_PROPERTY_KEY
                        $self->_get_acquisitions_objective(),  # OBJECTIVE
                        $self->_get_acquisitions_subjective(), # SUBJECTIVE
                        $self->_get_acquisitions_subanalysis($budget_code), # SUBANALYSIS
                        $line_count                           # LIN_NUM
                    ];
                }
            }

# Get supplier number for first order (assuming all orders in invoice have same supplier)
            my $first_order     = $invoice->_result->aqorders->first;
            my $supplier_number = "";
            if ($first_order) {
                $supplier_number = $self->_map_fund_to_suppliernumber(
                    $first_order->budget->budget_code );
            }

            # Make invoice total negative for AP
            $invoice_total *= -1;

            # Build header record with new format (15 fields)
            # Header record: INVOICE_NUMBER, INVOICE_TOTAL, INVOICE_DATE, SUPPLIER_NUMBER_PROPERTY_KEY, CONTRACT_NUMBER, SHIPMENT_DATE, then empty fields
            $csv->print(
                $fh,
                [
                    $invoice->invoicenumber,              # INVOICE_NUMBER
                    $invoice_total,                       # INVOICE_TOTAL
                    $self->_format_oracle_date( $invoice->closedate ), # INVOICE_DATE
                    $supplier_number,                     # SUPPLIER_NUMBER_PROPERTY_KEY
                    "C50335",                            # CONTRACT_NUMBER
                    $self->_format_oracle_date( $invoice->shipmentdate ), # SHIPMENT_DATE
                    "",                                   # LINE_AMOUNT (empty for header)
                    "",                                   # TAX_AMOUNT (empty for header)
                    "",                                   # TAX_CODE (empty for header)
                    "",                                   # DESCRIPTION (empty for header)
                    "",                                   # COST_CENTRE_PROPERTY_KEY (empty for header)
                    "",                                   # OBJECTIVE (empty for header)
                    "",                                   # SUBJECTIVE (empty for header)
                    "",                                   # SUBANALYSIS (empty for header)
                    ""                                    # LIN_NUM (empty for header)
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
    my ($self) = @_;

    # Cost Center = RN05 for all acquisitions
    return "RN05";
}

sub _get_acquisitions_objective {
    my ($self) = @_;

    # Default objective for all funds
    return "ZZZ999";
}

sub _get_acquisitions_subjective {
    my ($self) = @_;

    # Default subjective for all funds
    return "503000";
}

# FIXME: Need a mapping for where subanalysis will come from in Koha, this is just a placehold stub
sub _get_acquisitions_subanalysis {
    my ( $self, $fund ) = @_;
    my $map = {
        KAFI   => "5460",    # Fiction
        KANF   => "5461",    # Non-Fiction
        KARC   => "5462",    # Archive
        KBAS   => "5463",    # Basic
        KCFI   => "5464",    # Children Fiction
        KCHG   => "5465",    # Children General
        KCNF   => "5466",    # Children Non-Fiction
        KCOM   => "5467",    # Computing
        KEBE   => "5468",    # E-Books
        KELE   => "5469",    # Electronic
        KERE   => "5470",    # Reference
        KFSO   => "5471",    # Fiction Standing Order
        KHLS   => "5472",    # Health
        KLPR   => "5473",    # Large Print
        KNHC   => "5474",    # National Heritage Collection
        KNSO   => "5475",    # Non-Fiction Standing Order
        KPER   => "5476",    # Periodicals
        KRCHI  => "5477",    # Reference Children
        KREF   => "5478",    # Reference
        KREFSO => "5479",    # Reference Standing Order
        KREP   => "5480",    # Replacement
        KREQ   => "5481",    # Request
        KRFI   => "5482",    # Reference Fiction
        KRNF   => "5483",    # Reference Non-Fiction
        KSPO   => "5484",    # Sport
        KSSS   => "5485",    # Stock Selection Service
        KVAT   => "5486",    # VAT
        KYAD   => "5487",    # Young Adult
    };
    my $return = defined( $map->{$fund} ) ? $map->{$fund} : '5999';
    return $return;
}

sub _get_acquisitions_distribution {
    my ( $self, $fund ) = @_;
    my $company     = "1000";    # Default company code
    my $costcenter  = $self->_get_acquisitions_costcenter();
    my $objective   = $self->_get_acquisitions_objective();
    my $subjective  = $self->_get_acquisitions_subjective();
    my $subanalysis = $self->_get_acquisitions_subanalysis($fund);
    my $spare1      = "000000";
    my $spare2      = "000000";

    return
"$company-$costcenter-$objective-$subjective-$subanalysis-$spare1-$spare2";
}

sub _generate_income_report {
    my ( $self, $startdate, $enddate, $filename ) = @_;

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

    # Build date filtering conditions for cashup-style approach
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $date_conditions = {};
    
    if ( $startdate && $enddate ) {
        my $start_dt = $startdate->clone->set( hour => 0, minute => 0, second => 0 );
        my $end_dt = $enddate->clone->set( hour => 23, minute => 59, second => 59 );
        $date_conditions->{'date'} = {
            '-between' => [ $dtf->format_datetime($start_dt), $dtf->format_datetime($end_dt) ]
        };
    }
    elsif ($startdate) {
        my $start_dt = $startdate->clone->set( hour => 0, minute => 0, second => 0 );
        $date_conditions->{'date'} = { '>=', $dtf->format_datetime($start_dt) };
    }
    elsif ($enddate) {
        my $end_dt = $enddate->clone->set( hour => 23, minute => 59, second => 59 );
        $date_conditions->{'date'} = { '<=', $dtf->format_datetime($end_dt) };
    }

    # Find income transactions using cashup methodology
    # Get credits (money received) excluding Pay360 payments
    my $income_transactions = Koha::Account::Lines->search(
        {
            %{$date_conditions},
            debit_type_code => undef,  # Only credits
            amount => { '<', 0 },       # Negative amounts (credits)
            description => { 'NOT LIKE' => '%Pay360%' }  # FIXME: Exclude Pay360 payments
        }
    );

    # Use offsets to get the breakdown like cashup does
    my $income_summary = Koha::Account::Offsets->search(
        {
            'me.credit_id' => {
                '-in' => $income_transactions->_resultset->get_column('accountlines_id')->as_query
            },
            'me.debit_id' => { '!=' => undef }
        },
        {
            join => [ 
                { 'credit' => 'credit_type_code' },
                { 'debit' => 'debit_type_code' }
            ],
            group_by => [
                'credit.branchcode',
                'credit.credit_type_code', 
                'credit_type_code.description',
                'debit.debit_type_code',
                'debit_type_code.description',
                'credit.payment_type',
                { 'DATE' => 'credit.date' }
            ],
            'select' => [
                { sum => 'me.amount' },
                'credit.branchcode',
                'credit.credit_type_code',
                'credit_type_code.description',
                'debit.debit_type_code', 
                'debit_type_code.description',
                'credit.payment_type',
                { 'DATE' => 'credit.date' }
            ],
            'as' => [
                'total_amount',
                'branchcode',
                'credit_type_code',
                'credit_description',
                'debit_type_code',
                'debit_description', 
                'payment_type',
                'transaction_date'
            ],
            order_by => [
                { '-desc' => 'credit.date' },
                'credit.branchcode',
                'credit.credit_type_code',
                'debit.debit_type_code'
            ]
        }
    );

    my $results;
    my $line_number = 1;

    if ( $income_summary->count ) {
        $results = "";
        open my $fh, '>', \$results or die "Could not open scalar ref: $!";

        # Process the offset-based aggregated data
        while ( my $row = $income_summary->next ) {
            my $amount = $row->get_column('total_amount') * -1;  # Reverse sign for income
            my $amount_pence = int( $amount * 100 );            # Convert to pence
            
            next if $amount_pence <= 0;  # Skip zero or negative amounts

            my $library = $row->get_column('branchcode') || 'UNKNOWN';
            my $credit_type = $row->get_column('credit_type_code');
            my $debit_type = $row->get_column('debit_type_code');
            my $payment_type = $row->get_column('payment_type') || 'UNKNOWN';
            my $date = $row->get_column('transaction_date');

            # Generate document reference based on aggregation
            my $doc_reference = "AGG" . sprintf( "%06d", $line_number );

            # Generate document description using new format
            my $doc_description = 
                dt_from_string( $date )->strftime('%b%d/%y') . "/"
              . $library
              . "-LIB-Income";

            # Get accounting date in Oracle format
            my $accounting_date = $self->_format_oracle_date( $date );

            # Get GL code mappings
            my $cost_centre = "RN03";    # Always RN03 for libraries
            my $objective   = $self->_get_income_objective( $library );
            my $subjective  = $self->_get_income_subjective( $debit_type );
            my $subanalysis = $self->_get_income_subanalysis( $debit_type );

            # Get offset fields
            my $cost_centre_offset = $self->_get_income_costcenter( $debit_type );
            my $objective_offset   = $self->_get_objective_offset( $debit_type );
            my $subjective_offset  = $self->_get_subjective_offset( $debit_type );
            my $subanalysis_offset = $self->_get_subanalysis_offset( $debit_type );

            # Get VAT information using new codes
            my $vat_code = $self->_get_debit_type_vat_code( $debit_type );
            my $vat_amount = $self->_calculate_vat_amount_new( $amount, $vat_code );

            # Map payment type to standard format
            my $mapped_payment_type = $self->_map_credit_type_to_payment_type($credit_type);

            # Create line description in format: "[Payment Type] [Item Type]"
            my $line_description = $mapped_payment_type . " " . $debit_type;
            $line_description =~ s/[|"]//g;   # Remove pipe and quote characters

            # Build record according to new 19-field cash management spec
            $csv->print(
                $fh,
                [
                    $doc_reference,      # 1. D_Document Document Number
                    $doc_description,    # 2. D_Document Description
                    $accounting_date,    # 3. D_Document Date
                    $line_number,        # 4. D_Line Number
                    $amount_pence,       # 5. D_Line Amount (positive, in pence)
                    $cost_centre,        # 6. D_Cost Centre
                    $objective,          # 7. D_Objective
                    $subjective,         # 8. D_Subjective
                    $subanalysis,        # 9. D_Subanalysis
                    $cost_centre_offset, # 10. D_Cost Centre Offset
                    $objective_offset,   # 11. D_Objective Offset
                    $subjective_offset,  # 12. D_Subjective Offset
                    $subanalysis_offset, # 13. D_Subanalysis Offset
                    $line_description,   # 14. D_Line Description
                    $vat_code,           # 15. D_VAT Code
                    $vat_amount          # 16. D_VAT Amount
                ]
            );

            $line_number++;
        }

        close $fh;
    }

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

sub _map_income_type_to_cost_centre {
    my ( $self, $credit_type, $branch ) = @_;

    # Map library branches to cost centres
    my $branch_map = {
        'Angmering'      => "RG02",
        'Arundel'        => "RG03",
        'Billingshurst'  => "RE01",
        'Bognor Regis'   => "RH00",
        'Broadfield'     => "RA01",
        'Broadwater'     => "RK01",
        'Burgess Hill'   => "RD00",
        'Chichester'     => "RJ00",
        'Crawley'        => "RA00",
        'Durrington'     => "RK02",
        'East Grinstead' => "RB00",
        'East Preston'   => "RG04",
        'Ferring'        => "RG05",
        'Findon Valley'  => "RK03",
        'Goring'         => "RK04",
        'Hassocks'       => "RD03",
        'Haywards Heath' => "RD01",
        'Henfield'       => "RD02",
        'Horsham'        => "RC00",
        'Hurstpierpoint' => "RD04",
        'Lancing'        => "RF01",
        'Littlehampton'  => "RG00",
        'Midhurst'       => "RE02",
        'Petworth'       => "RE03",
        'Pulborough'     => "RE04",
        'Rustington'     => "RG01",
        'Selsey'         => "RJ01",
        'Shoreham'       => "RF00",
        'Southbourne'    => "RJ02",
        'Southwater'     => "RC01",
        'Southwick'      => "RF02",
        'Steyning'       => "RF03",
        'Storrington'    => "RE00",
        'Willowhale'     => "RH01",
        'Witterings'     => "RJ03",
        'Worthing'       => "RK00"
    };

    return $branch_map->{$branch} || 'E26315';
}

sub _map_income_type_to_objective {
    my ( $self, $credit_type, $branch ) = @_;

    # Map library branches to objectives
    my $branch_map = {
        'CPL' => 'CUL001',    # Centerville
        'FFL' => 'CUL002',    # Fairfield
        'FPL' => 'CUL003',    # Fairview
        'FRL' => 'CUL004',    # Franklin
        'IPT' => 'CUL005',    # Institut Protestant
                              # Add other branches as needed
    };

    return $branch_map->{$branch} || 'CUL074';    # Default to Central Admin
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

sub _map_fund_to_suppliernumber {
    my ( $self, $fund ) = @_;
    my $map = {
        KAFI   => 4539,
        KANF   => 4539,
        KARC   => 4539,
        KBAS   => 4539,
        KCFI   => 4539,
        KCHG   => 4539,
        KCNF   => 4539,
        KCOM   => 4539,
        KEBE   => 4539,
        KELE   => 4539,
        KERE   => 5190,
        KFSO   => 4539,
        KHLS   => 4539,
        KLPR   => 4539,
        KNHC   => 4539,
        KNSO   => 4539,
        KPER   => 4625,
        KRCHI  => 4539,
        KREF   => 4539,
        KREFSO => 4539,
        KREP   => 4539,
        KREQ   => 4539,
        KRFI   => 4539,
        KRNF   => 4539,
        KSPO   => 4539,
        KSSS   => 4539,
        KVAT   => 4539,
        KYAD   => 4539,
    };
    my $return = defined( $map->{$fund} ) ? $map->{$fund} : '4539';
    return $return;
}

# New income report helper functions for updated requirements

sub _get_debit_type_from_debit_type {
    my ( $self, $credit_type ) = @_;

    # Map credit types to item types based on our loaded debit types
    # This should eventually use the additional fields from account_debit_types
    my $map = {
        'PAYMENT'      => 'Fines',
        'PURCHASE'     => 'Book Sale',
        'CREDIT'       => 'Credit',
        'REFUND'       => 'Refund',
        'CANCELLATION' => 'Cancellation',
        'OVERPAYMENT'  => 'Overpayment',
    };

    return $map->{$credit_type} || 'Unknown';
}

sub _map_credit_type_to_payment_type {
    my ( $self, $credit_type ) = @_;

    # Map credit types to payment types (CASH, CARD KIOSK, CARD TERMINAL)
    # This is a simplified mapping - in reality this would need more logic
    # to determine actual payment method used
    my $map = {
        'PAYMENT'      => 'CASH',
        'PURCHASE'     => 'CASH',
        'CREDIT'       => 'CASH',
        'REFUND'       => 'CASH',
        'CANCELLATION' => 'CASH',
        'OVERPAYMENT'  => 'CASH',
    };

    return $map->{$credit_type} || 'CASH';
}

sub _get_income_objective {
    my ( $self, $library_code ) = @_;

    # Map library codes to objectives based on requirements
    # FIXME: This should use additional fields attached to the branches table instead of being hard coded.
    my $map = {
        'CRAWLEY'       => 'CUL001',
        'BROADFIELD'    => 'CUL002',
        'EASTGRINSTEAD' => 'CUL003',
        'HORSHAM'       => 'CUL004',
        'SOUTHWATER'    => 'CUL005',
        'BURGESSHILL'   => 'CUL006',
        'HAYWARDSHE'    => 'CUL007',
        'HENFIELD'      => 'CUL008',
        'HASSOCKS'      => 'CUL009',
        'HURSTPIERP'    => 'CUL010',
        'STORRINGTON'   => 'CUL011',
        'BILLINGSH'     => 'CUL012',
        'MIDHURST'      => 'CUL013',
        'PETWORTH'      => 'CUL014',
        'PULBOROUGH'    => 'CUL015',
        'SHOREHAM'      => 'CUL016',
        'LANCING'       => 'CUL017',
        'SOUTHWICK'     => 'CUL018',
        'STEYNING'      => 'CUL019',
        'LITTLEHAMP'    => 'CUL020',
        'RUSTINGTON'    => 'CUL021',
        'ANGMERING'     => 'CUL022',
        'ARUNDEL'       => 'CUL023',
        'EASTPRESTON'   => 'CUL024',
        'FERRING'       => 'CUL025',
        'BOGNORREGIS'   => 'CUL026',
        'WILLOWHALE'    => 'CUL027',
        'BOGNORMOB'     => 'CUL028',
        'CHICHESTER'    => 'CUL029',
        'SELSEY'        => 'CUL030',
        'SOUTHBOURNE'   => 'CUL031',
        'WITTERINGS'    => 'CUL032',
        'WORTHING'      => 'CUL033',
        'BROADWATER'    => 'CUL034',
        'DURRINGTON'    => 'CUL035',
        'FINDON'        => 'CUL036',
        'GORING'        => 'CUL037',
        'CENTRAL'       => 'CUL074',
    };

    return $map->{$library_code} || 'CUL074';    # Default to Central Admin
}

sub _get_income_subjective {
    my ( $self, $debit_type ) = @_;

    # Map item types to subjective codes based on requirements
    my $map = {
        'Fines'        => '841800',
        'Book Sale'    => '841850',
        'Credit'       => '841800',
        'Refund'       => '841800',
        'Cancellation' => '841800',
        'Overpayment'  => '841800',
    };

    return $map->{$debit_type} || '841800';
}

sub _get_income_subanalysis {
    my ( $self, $debit_type ) = @_;

    # Map item types to subanalysis codes based on requirements
    my $map = {
        'Fines'        => '5435',
        'Book Sale'    => '5436',
        'Credit'       => '5437',
        'Refund'       => '5438',
        'Cancellation' => '5439',
        'Overpayment'  => '5440',
    };

    return $map->{$debit_type} || '5435';
}

sub _get_income_costcenter {
    my ( $self, $debit_type ) = @_;

    # Map item types to cost centre offset codes
    # Using sample data from requirements
    my $map = {
        'Fines'        => 'DM87',
        'Book Sale'    => 'DM87',
        'Credit'       => 'DM87',
        'Refund'       => 'DM87',
        'Cancellation' => 'DM87',
        'Overpayment'  => 'DM87',
    };

    return $map->{$debit_type} || 'DM87';
}

sub _get_objective_offset {
    my ( $self, $debit_type ) = @_;

    # Map item types to objective offset codes
    # Using sample data from requirements
    my $map = {
        'Fines'        => 'SRT003',
        'Book Sale'    => 'SRT003',
        'Credit'       => 'SRT003',
        'Refund'       => 'SRT003',
        'Cancellation' => 'SRT003',
        'Overpayment'  => 'SRT003',
    };

    return $map->{$debit_type} || 'SRT003';
}

sub _get_subjective_offset {
    my ( $self, $debit_type ) = @_;

    # Map item types to subjective offset codes
    # Using sample data from requirements
    my $map = {
        'Fines'        => '276001',
        'Book Sale'    => '276001',
        'Credit'       => '276001',
        'Refund'       => '276001',
        'Cancellation' => '276001',
        'Overpayment'  => '276001',
    };

    return $map->{$debit_type} || '276001';
}

sub _get_subanalysis_offset {
    my ( $self, $debit_type ) = @_;

    # Map item types to subanalysis offset codes
    # Using sample data from requirements
    my $map = {
        'Fines'        => '5435',
        'Book Sale'    => '5435',
        'Credit'       => '5435',
        'Refund'       => '5435',
        'Cancellation' => '5435',
        'Overpayment'  => '5435',
    };

    return $map->{$debit_type} || '5435';
}

sub _get_debit_type_vat_code {
    my ( $self, $debit_type ) = @_;

    # Map item types to VAT codes (STANDARD, ZERO, OUT OF SCOPE)
    my $map = {
        'Fines'        => 'OUT OF SCOPE',
        'Book Sale'    => 'ZERO',
        'Credit'       => 'OUT OF SCOPE',
        'Refund'       => 'OUT OF SCOPE',
        'Cancellation' => 'OUT OF SCOPE',
        'Overpayment'  => 'OUT OF SCOPE',
    };

    return $map->{$debit_type} || 'OUT OF SCOPE';
}

sub _calculate_vat_amount_new {
    my ( $self, $amount, $vat_code ) = @_;

    return 0 unless $vat_code eq 'STANDARD';

    # Standard VAT rate is 20%
    my $vat_amount = $amount * 0.20;
    return int( $vat_amount * 100 );    # Convert to pence
}

1;
