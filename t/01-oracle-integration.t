#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 9;
use Test::Exception;
use Path::Tiny qw(path);

my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';
unshift @INC, $plugin_dir;

use Mojo::JSON qw(encode_json);

use_ok('Koha::Plugin::Com::OpenFifth::Oracle') || print "Bail out!\n";

my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new();

# Seed mappings so accessor methods have data to read.
$plugin->store_data({
    fund_field_mappings => encode_json({
        WAFI => {
            costcenter  => 'RN05',
            objective   => 'CUL001',
            subjective  => '503000',
            subanalysis => '5460',
        },
    }),
    vendor_supplier_mappings => encode_json({ 1 => 'V12345' }),
    vendor_contract_mappings => encode_json({ 1 => 'C67890' }),
});

subtest 'Filename generation' => sub {
    plan tests => 4;

    my $invoice_filename = $plugin->_generate_filename('invoices');
    like(
        $invoice_filename,
        qr/^KOHA_SaaS_APInvoice_\d{14}\.csv$/,
        'invoices filename follows pattern',
    );

    my $income_filename = $plugin->_generate_filename('income');
    like(
        $income_filename,
        qr/^KOHA_SaaS_TaxableJournal_\d{14}\.csv$/,
        'income filename follows pattern',
    );

    isnt(
        $invoice_filename, $income_filename,
        'invoice and income filenames differ',
    );

    is(
        substr( $invoice_filename, -4 ), '.csv',
        'invoice filename has .csv extension',
    );
};

subtest 'Plugin metadata' => sub {
    plan tests => 6;

    my $metadata = $plugin->{metadata};
    ok( $metadata->{name},            'Plugin has name' );
    ok( $metadata->{author},          'Plugin has author' );
    ok( $metadata->{version},         'Plugin has version' );
    ok( $metadata->{description},     'Plugin has description' );
    ok( $metadata->{date_authored},   'Plugin has date_authored' );
    ok( $metadata->{minimum_version}, 'Plugin has minimum_version' );
};

subtest 'Required plugin methods' => sub {
    plan tests => 14;

    can_ok( $plugin, 'configure' );
    can_ok( $plugin, 'cronjob_nightly' );
    can_ok( $plugin, 'report' );
    can_ok( $plugin, 'report_step1' );
    can_ok( $plugin, 'report_step2' );
    can_ok( $plugin, '_generate_filename' );
    can_ok( $plugin, 'install' );
    can_ok( $plugin, 'uninstall' );
    can_ok( $plugin, 'upgrade' );
    can_ok( $plugin, 'manage_submissions' );
    can_ok( $plugin, '_get_submitted_invoice_numbers' );
    can_ok( $plugin, '_get_submitted_cashup_ids' );
    can_ok( $plugin, '_mark_invoices_submitted' );
    can_ok( $plugin, '_mark_cashups_submitted' );
};

subtest 'Configuration handling' => sub {
    plan tests => 2;

    lives_ok {
        $plugin->store_data({ test_key => 'test_value' });
    } 'Can store configuration data';

    is(
        $plugin->retrieve_data('test_key'), 'test_value',
        'Can retrieve stored configuration data',
    );
};

subtest 'Acquisitions field defaults fall through correctly' => sub {
    plan tests => 4;

    # When no fund mapping exists, the configured plugin defaults should win.
    $plugin->store_data({
        default_acquisitions_costcenter  => 'RN05',
        default_acquisitions_objective   => 'ZZZ999',
        default_acquisitions_subjective  => '503000',
        default_acquisitions_subanalysis => '5460',
    });

    is(
        $plugin->_get_acquisitions_costcenter('UNKNOWN_FUND'), 'RN05',
        'unmapped fund falls through to configured default cost centre',
    );
    is(
        $plugin->_get_acquisitions_objective('UNKNOWN_FUND'), 'ZZZ999',
        'unmapped fund falls through to configured default objective',
    );
    is(
        $plugin->_get_acquisitions_subjective('UNKNOWN_FUND'), '503000',
        'unmapped fund falls through to configured default subjective',
    );
    is(
        $plugin->_get_acquisitions_subanalysis('UNKNOWN_FUND'), '5460',
        'unmapped fund falls through to configured default subanalysis',
    );
};

subtest 'Vendor mappings resolve from stored data' => sub {
    plan tests => 2;

    is(
        $plugin->_get_vendor_supplier_number(1), 'V12345',
        'mapped vendor returns configured supplier number',
    );
    is(
        $plugin->_get_vendor_contract_number(1), 'C67890',
        'mapped vendor returns configured contract number',
    );
};

subtest 'Invoice tax code mapping' => sub {
    plan tests => 4;

    is( $plugin->_invoice_tax_code(20), 'STANDARD', '20% maps to STANDARD' );
    is( $plugin->_invoice_tax_code(0),  'ZERO',     '0% maps to ZERO' );
    is( $plugin->_invoice_tax_code(5),  '*UNMAPPED*',
        'reduced rate maps to *UNMAPPED* until Oracle code is agreed' );
    is( $plugin->_invoice_tax_code(17.5), '*UNMAPPED*',
        'historic rate maps to *UNMAPPED*' );
};

subtest 'INVOICE_TOTAL is the exact sum of emitted line+tax amounts' => sub {
    plan tests => 7;

    # Property: INVOICE_TOTAL must equal Sum(LINE_AMOUNT) + Sum(TAX_AMOUNT).
    # Locks in the contract that fixes the Bolinda 525275 / Askews 7281289
    # rejections, where header total drifted from the sum of line records
    # via per-line tax rounding aggregation.

    is( $plugin->_invoice_total_from_rows( [] ), 0,
        'empty invoice totals zero' );

    my $single = [ { line_amount => 49.34, tax_amount => 9.87 } ];
    is( $plugin->_invoice_total_from_rows($single), 59.21,
        'single row sums line + tax' );

    # Case 1 analogue: many rows at 20% VAT. Whatever per-line rounding
    # falls out, the header must match the sum.
    my @case1_rows = map {
        { line_amount => 49.34, tax_amount => 9.87 }
    } 1 .. 41;
    my $case1_total = 0;
    $case1_total += $_->{line_amount} + $_->{tax_amount} for @case1_rows;
    is(
        $plugin->_invoice_total_from_rows( \@case1_rows ),
        sprintf( "%.2f", $case1_total ) + 0,
        '41 rows at 20% VAT: header equals sum of emitted line + tax amounts',
    );

    # Case 2 analogue: mixed VAT rates in one invoice.
    my @case2_rows = (
        ( map { { line_amount => 5.33, tax_amount => 1.07 } } 1 .. 20 ),
        ( map { { line_amount => 5.78, tax_amount => 0 } }    1 .. 59 ),
    );
    my $case2_expected = 20 * ( 5.33 + 1.07 ) + 59 * ( 5.78 + 0 );
    is(
        $plugin->_invoice_total_from_rows( \@case2_rows ),
        sprintf( "%.2f", $case2_expected ) + 0,
        'mixed VAT invoice: header equals sum across rates',
    );

    # Defensive: missing keys must not blow up.
    my $partial = [ { line_amount => 10.00 }, { tax_amount => 2.00 } ];
    is( $plugin->_invoice_total_from_rows($partial), 12.00,
        'missing line_amount / tax_amount treated as zero' );

    # Float-noise resistance: 0.1 + 0.2 == 0.3, etc.
    my @noisy_rows = map {
        { line_amount => 0.10, tax_amount => 0.02 }
    } 1 .. 100;
    is(
        $plugin->_invoice_total_from_rows( \@noisy_rows ),
        12.00,
        'sum of 100 rows of 0.10+0.02 rounds cleanly to 12.00',
    );

    # An adjustment row contributes both line and tax to the total.
    my $with_adj = [
        { line_amount => 100.00, tax_amount => 20.00 },
        { line_amount => 5.00,   tax_amount => 1.00 },     # adjustment
    ];
    is( $plugin->_invoice_total_from_rows($with_adj), 126.00,
        'adjustment rows contribute to invoice total' );
};

done_testing();
