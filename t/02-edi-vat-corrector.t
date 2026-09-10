#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 4;
use Path::Tiny qw(path);

my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';
unshift @INC, $plugin_dir;

use_ok('Koha::Plugin::Com::OpenFifth::Oracle::EdiVatCorrector') || print "Bail out!\n";

# Fixture reproduces the shape of a real WSCC rejection: a vendor
# invoice LIN with two TAX/MOA segment pairs (part standard-rated, part
# zero-rated) alongside an ordinary single-rate LIN, using synthetic
# ISBNs/order numbers rather than real customer data.
my $fixture = path($plugin_dir)->child('t/fixtures/mixed-rate-invoice.edi')->slurp;

my $corrector = Koha::Plugin::Com::OpenFifth::Oracle::EdiVatCorrector->new;

subtest 'tax_by_ordernumber sums every TAX/MOA+124 pair on a LIN' => sub {
    plan tests => 2;

    my $tax = $corrector->tax_by_ordernumber($fixture);

    # Mixed-rate line: 20%-rated portion taxed at 2.95, 0%-rated
    # portion taxed at 0 -> vendor's real total tax for the line is
    # 2.95, not a flat-rate recompute over the whole line value.
    is( $tax->{90001}, 2.95, 'mixed-rate LIN: sums both TAX/MOA+124 pairs to the true total' );

    # Ordinary single-rate line: one TAX/MOA+124 pair, read as-is.
    is( $tax->{90002}, 6,    'single-rate LIN: reads the one TAX/MOA+124 amount' );
};

subtest 'a mixed-rate line disagrees with the naive rate x price calculation' => sub {
    plan tests => 1;

    my $tax = $corrector->tax_by_ordernumber($fixture);

    # This is the exact defect in Koha::EDI: it ignores the vendor's
    # TAX/MOA+124 figures entirely and instead computes
    # quantity * price_excl_tax * (first TAX segment's rate), which
    # taxes the whole line at 20% regardless of the zero-rated portion.
    my $quantity         = 6;
    my $price_excl_tax   = 56.46 / $quantity;
    my $naive_tax        = sprintf( '%.2f', $quantity * $price_excl_tax * 0.20 ) + 0;

    isnt( $tax->{90001}, $naive_tax,
        "vendor's true tax (£$tax->{90001}) differs from Koha's naive flat-rate figure (£$naive_tax)" );
};

subtest 'an unmatched ordernumber is absent, not zero' => sub {
    plan tests => 1;

    my $tax = $corrector->tax_by_ordernumber($fixture);
    ok( !exists $tax->{99999}, 'ordernumbers not present on the invoice are simply absent from the map' );
};
