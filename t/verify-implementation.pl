#!/usr/bin/env perl
use Modern::Perl;
use Test::More;
use Path::Tiny qw(path);
use JSON::MaybeXS qw(decode_json);

# Get the plugin directory path
my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';

# Add plugin directory to @INC
unshift @INC, $plugin_dir;

# Read package.json to get plugin module name
my $package_json_path = path($plugin_dir)->child('package.json');
my $package_json = decode_json($package_json_path->slurp);
my $plugin_module = $package_json->{plugin}->{module};

# Load the plugin
use_ok($plugin_module);

# Create plugin instance
my $plugin = $plugin_module->new();
ok($plugin, 'Plugin instantiated');

# Test the new _calculate_exclusive_and_vat method
my @test_cases = (
    # [inclusive, expected_exclusive, expected_vat, vat_code, description]
    [120.00, 100.00, 20.00, 'STANDARD', 'Clean £120.00'],
    [60.00,  50.00,  10.00, 'STANDARD', 'Clean £60.00'],
    [1.00,   0.83,   0.17,  'STANDARD', '£1.00 with rounding'],
    [11.11,  9.26,   1.85,  'STANDARD', 'Previously problematic £11.11'],
    [0.01,   0.01,   0.00,  'STANDARD', 'Edge case £0.01'],
    [0.06,   0.05,   0.01,  'STANDARD', 'Edge case £0.06'],

    # Non-STANDARD VAT codes
    [100.00, 100.00, 0.00,  'ZERO',          'ZERO rate'],
    [100.00, 100.00, 0.00,  'EXEMPT',        'EXEMPT'],
    [100.00, 100.00, 0.00,  'OUT OF SCOPE',  'OUT OF SCOPE'],
);

plan tests => 2 + (scalar @test_cases * 4);

for my $case (@test_cases) {
    my ($inclusive, $expected_ex, $expected_vat, $vat_code, $desc) = @$case;

    my ($exclusive, $vat) = $plugin->_calculate_exclusive_and_vat($inclusive, $vat_code);

    is($exclusive, sprintf("%.2f", $expected_ex), "$desc: exclusive amount");
    is($vat, sprintf("%.2f", $expected_vat), "$desc: VAT amount");

    # Verify the math: exclusive + VAT should equal inclusive
    my $total = $exclusive + $vat;
    is(sprintf("%.2f", $total), sprintf("%.2f", $inclusive), "$desc: total matches");

    # Verify Oracle will get the right total
    my $oracle_total = sprintf("%.2f", $exclusive + $vat);
    is($oracle_total, sprintf("%.2f", $inclusive), "$desc: Oracle will calculate correct total");
}

done_testing();
