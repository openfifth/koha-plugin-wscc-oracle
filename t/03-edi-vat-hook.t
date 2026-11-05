#!/usr/bin/perl

# after_edi_cron receives edifact_messages ids (not aqinvoices ids). Check
# the corrector raises the adjustment on the invoice created from the
# message, and does not touch an unrelated invoice whose invoiceid happens
# to equal that message id.

use Modern::Perl;
use Test::More tests => 5;
use Path::Tiny qw(path);

my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';
unshift @INC, $plugin_dir;

use t::lib::TestBuilder;
use Koha::Database;
use Koha::Acquisition::Invoice::Adjustments;

use_ok('Koha::Plugin::Com::OpenFifth::Oracle::EdiVatCorrector') || print "Bail out!\n";

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
$schema->storage->txn_begin;

my $fixture = path($plugin_dir)->child('t/fixtures/mixed-rate-invoice.edi')->slurp;

# Make invoice ids and message ids diverge so a confusion between them shows.
$builder->build_object( { class => 'Koha::Acquisition::Invoices' } ) for 1 .. 3;
my $vendor  = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices' } );
my $order   = $builder->build_object(
    {
        class => 'Koha::Acquisition::Orders',
        value => { invoiceid => $invoice->id, tax_value_on_receiving => 11.29 },
    }
);

# Point the fixture's mixed-rate LIN (RFF+LI:90001) at our real order.
( my $raw = $fixture ) =~ s/RFF\+LI:90001/RFF+LI:@{[ $order->ordernumber ]}/;

my $message = $schema->resultset('EdifactMessage')->create(
    {
        message_type  => 'INVOICE',
        transfer_date => '2026-01-01',
        status        => 'processed',
        raw_msg       => $raw,
        filename      => 'test.inv',
        vendor_id     => $vendor->id,
    }
);
$invoice->message_id( $message->id )->store;
isnt( $invoice->id, $message->id, 'message id and invoice id differ (precondition)' );

my $corrector = Koha::Plugin::Com::OpenFifth::Oracle::EdiVatCorrector->new;
my $result    = $corrector->run_for_message_ids( [ $message->id ] );

is( $result->{corrected}, 1, 'one line corrected' );
my $adj = Koha::Acquisition::Invoice::Adjustments->search( { invoiceid => $invoice->id } );
is( $adj->count, 1, 'adjustment raised on the invoice created from the message' );
is( $adj->next->adjustment + 0, -8.34, 'adjustment = vendor VAT 2.95 - recorded 11.29' );

$schema->storage->txn_rollback;
