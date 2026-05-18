#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 7;
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

done_testing();
