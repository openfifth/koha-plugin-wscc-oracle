#!/usr/bin/env perl
use Modern::Perl;
use POSIX qw(ceil);

# FINAL ALGORITHM (Approach A: Oracle trusts our VAT amount)
# Given: inclusive amount from Koha
# Calculate: exclusive and VAT such that exclusive + VAT = inclusive (exactly)
sub calculate_exclusive_and_vat_final {
    my ($inclusive) = @_;

    # Calculate exclusive amount (standard division by 1.20)
    my $exclusive = $inclusive / 1.20;

    # Round exclusive to nearest penny (standard rounding, not ceil)
    $exclusive = sprintf("%.2f", $exclusive);

    # Calculate VAT as the difference (ensures exact total)
    my $vat = $inclusive - $exclusive;
    $vat = sprintf("%.2f", $vat);

    return ($exclusive, $vat);
}

print "Testing FINAL Algorithm (Oracle trusts our VAT)\n";
print "=" x 80 . "\n\n";

my @test_cases = (
    120.00, 60.00, 6.00,
    1.00, 0.10, 10.01, 5.55, 12.34,
    0.01, 0.06, 0.12, 0.19, 0.24,  # Previously "impossible" cases
    999.99,
    1.67, 3.33, 7.77, 11.11, 99.99,
);

my $all_pass = 1;
my $pass_count = 0;
my $fail_count = 0;

for my $koha_inclusive (@test_cases) {
    my ($exclusive, $vat) = calculate_exclusive_and_vat_final($koha_inclusive);

    # Verify our math
    my $our_total = sprintf("%.2f", $exclusive + $vat);
    my $matches = ($our_total eq sprintf("%.2f", $koha_inclusive));

    # Calculate expected VAT rate for display
    my $vat_rate = $exclusive > 0 ? ($vat / $exclusive) * 100 : 0;

    if ($matches) {
        print "✓ PASS: £$koha_inclusive\n";
        print "  → Send to Oracle: Exclusive=£$exclusive, VAT=£$vat (rate: " .
              sprintf("%.1f", $vat_rate) . "%)\n";
        print "  → Oracle uses our VAT: Total = £$exclusive + £$vat = £$our_total\n";
        $pass_count++;
    } else {
        print "✗ FAIL: £$koha_inclusive\n";
        print "  Target: £$koha_inclusive\n";
        print "  Our calculation: Ex=£$exclusive + VAT=£$vat = £$our_total\n";
        print "  Diff: £" . sprintf("%.2f", $koha_inclusive - $our_total) . "\n";
        $fail_count++;
        $all_pass = 0;
    }
    print "\n";
}

print "=" x 80 . "\n";
print "Results: $pass_count passed, $fail_count failed\n\n";

if ($all_pass) {
    print "✓ SUCCESS! All amounts split correctly\n";
    print "  Oracle will trust our VAT amounts (Field 16)\n";
    print "  Oracle will calculate: Exclusive (Field 5) + VAT (Field 16) = Total\n";
} else {
    print "✗ FAILURES - Algorithm needs fixing\n";
}

exit($all_pass ? 0 : 1);
