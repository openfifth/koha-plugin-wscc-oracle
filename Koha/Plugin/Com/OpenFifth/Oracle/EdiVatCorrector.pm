package Koha::Plugin::Com::OpenFifth::Oracle::EdiVatCorrector;

# Corrects invoice-level VAT drift caused by Koha::EDI collapsing a
# multi-rate EDIFACT invoice line to a single flat
# tax_rate_on_receiving x price calculation.
#
# Some vendor invoice lines are genuinely mixed-rate (part of the
# line's value is standard-rated, part zero-rated) and carry more than
# one TAX/MOA segment pair to say so. Koha::Edifact::Line::tax_rate
# only reads the first TAX segment on a LIN, and Koha::EDI never reads
# the vendor's actual invoiced tax amount (MOA+124) at all - it always
# recomputes tax as quantity * price_excl_tax * that one rate, so a
# mixed-rate line is overtaxed by the zero-rated portion's share.
#
# This does NOT rewrite aqorders. C4::Acquisition::ModReceiveOrder
# recomputes tax_value_on_receiving from tax_rate_on_receiving (a
# single scalar column - it cannot represent a split rate) on every
# subsequent receive/edit of an order line, so a direct data fix would
# be silently reverted the next time anyone touches that line through
# the normal acquisitions UI. Instead this raises a
# Koha::Acquisition::Invoice::Adjustment for the delta between the
# vendor's actual invoiced tax and what Koha stored. Koha's own invoice
# screen already folds adjustments into its "Total + adjustments +
# shipment cost" figure, and the Oracle export already understands
# aqinvoice_adjustments (see Oracle.pm), so both agree with the
# vendor's real total without core Koha needing to change.
#
# See Koha core Bug 43510 for the underlying ingest defect - filed for
# visibility/record rather than as something to patch directly, for
# the reasons above.
#
# Runs from the after_edi_cron plugin hook.

use Modern::Perl;

use Koha::Edifact;
use Koha::Number::Price;
use Koha::Database;
use Koha::Acquisition::Invoices;
use Koha::Acquisition::Invoice::Adjustments;
use Koha::Logger;

our $ADJUSTMENT_MARKER = 'EDI VAT correction';

sub new {
    my ( $class, %params ) = @_;
    return bless {
        logger => $params{logger}
            // Koha::Logger->get( { category => 'Koha.Plugin.Com.OpenFifth.Oracle.EdiVatCorrector' } ),
        dry_run => $params{dry_run} // 0,
    }, $class;
}

=head3 tax_by_ordernumber

my $tax_by_ordernumber = $corrector->tax_by_ordernumber( $raw_msg );

Parse a raw EDIFACT INVOIC transmission and return a hashref of
ordernumber => vendor-declared total tax for that line (the sum of
every MOA+124 amount on that LIN, however many TAX segments it has).
Pure parsing, no database access - a line with no ordernumber (RFF+LI
missing or unresolved) is skipped.

=cut

sub tax_by_ordernumber {
    my ( $self, $raw_msg ) = @_;

    my %tax_by_ordernumber;
    return \%tax_by_ordernumber unless $raw_msg;

    my $edi = Koha::Edifact->new( { transmission => $raw_msg } );
    for my $msg ( @{ $edi->message_array // [] } ) {
        next unless $msg->message_type eq 'INVOIC';
        for my $line ( @{ $msg->lineitems // [] } ) {
            my $ordernumber = $line->ordernumber or next;
            $tax_by_ordernumber{$ordernumber} = $self->_round( $line->amt_taxoncharge // 0 );
        }
    }

    return \%tax_by_ordernumber;
}

=head3 run_for_invoice

my $result = $corrector->run_for_invoice( $invoice );

Compare each of $invoice's orderlines against the vendor's actual
invoiced tax (read from the EDI message the invoice was created from,
via aqinvoices.message_id) and raise an adjustment for any that drift
beyond a rounding penny. Returns { checked => N, corrected => N }.

=cut

sub run_for_invoice {
    my ( $self, $invoice ) = @_;

    my $result = { checked => 0, corrected => 0 };

    my $message_id = $invoice->message_id;
    return $result unless $message_id;

    my $message = Koha::Database->new->schema->resultset('EdifactMessage')->find($message_id);
    return $result unless $message && $message->raw_msg;

    my $tax_by_ordernumber = $self->tax_by_ordernumber( $message->raw_msg );
    return $result unless %$tax_by_ordernumber;

    my $orders = $invoice->_result->aqorders;
    while ( my $order = $orders->next ) {
        my $ordernumber = $order->ordernumber;
        next unless exists $tax_by_ordernumber->{$ordernumber};
        $result->{checked}++;

        my $correct_tax = $tax_by_ordernumber->{$ordernumber};
        my $stored_tax   = $self->_round( $order->tax_value_on_receiving // 0 );
        my $delta        = $self->_round( $correct_tax - $stored_tax );

        next if $delta == 0;
        next if $self->_adjustment_exists( $invoice, $ordernumber );

        $self->{logger}->info(
            sprintf(
                'Invoice %s order #%s: vendor VAT GBP%.2f vs recorded GBP%.2f (delta GBP%.2f)%s',
                $invoice->invoicenumber, $ordernumber, $correct_tax, $stored_tax, $delta,
                $self->{dry_run} ? ' [dry run]' : q{},
            )
        );

        unless ( $self->{dry_run} ) {
            Koha::Acquisition::Invoice::Adjustment->new(
                {
                    invoiceid  => $invoice->invoiceid,
                    adjustment => $delta,
                    note       => $self->_adjustment_note( $ordernumber, $correct_tax, $stored_tax ),
                }
            )->store;
        }
        $result->{corrected}++;
    }

    return $result;
}

=head3 run_for_message_ids

my $result = $corrector->run_for_message_ids( \@edifact_message_ids );

Run L</run_for_invoice> for every invoice created from the given
edifact_messages ids (matched via aqinvoices.message_id). This is what
the after_edi_cron hook hands us: message ids, not invoice ids.

=cut

sub run_for_message_ids {
    my ( $self, $message_ids ) = @_;

    my $totals = { checked => 0, corrected => 0 };
    return $totals unless $message_ids && @$message_ids;

    my $invoices = Koha::Acquisition::Invoices->search( { message_id => { -in => $message_ids } } );
    while ( my $invoice = $invoices->next ) {
        my $r = $self->run_for_invoice($invoice);
        $totals->{$_} += $r->{$_} for qw(checked corrected);
    }
    return $totals;
}

sub _adjustment_note {
    my ( $self, $ordernumber, $correct_tax, $stored_tax ) = @_;
    return sprintf(
        '%s: Order #%s (vendor VAT %.2f vs recorded %.2f) [Tax Correction]',
        $ADJUSTMENT_MARKER, $ordernumber, $correct_tax, $stored_tax
    );
}

sub _adjustment_exists {
    my ( $self, $invoice, $ordernumber ) = @_;
    return Koha::Acquisition::Invoice::Adjustments->search(
        {
            invoiceid => $invoice->invoiceid,
            note      => { like => "$ADJUSTMENT_MARKER: Order \#$ordernumber %" },
        }
    )->count ? 1 : 0;
}

sub _round {
    my ( $self, $n ) = @_;
    return Koha::Number::Price->new($n)->round + 0;
}

1;
