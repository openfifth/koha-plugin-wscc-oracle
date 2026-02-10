#!/usr/bin/perl

# Test script to validate per-line VAT calculation fix
# Demonstrates the difference between aggregate-first vs per-line calculation

use Modern::Perl;
use Test::More;

# Simulate the VAT calculation function from the plugin
sub calculate_exclusive_and_vat {
    my ( $inclusive_amount, $vat_code ) = @_;

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
    my $vat_amount = $inclusive_amount - $exclusive_amount;
    $vat_amount = sprintf( "%.2f", $vat_amount );

    return ( $exclusive_amount, $vat_amount );
}

# Test Case 1: Classic rounding discrepancy
sub test_classic_discrepancy {
    my @transactions = ( 9.99, 9.99, 9.99 );
    my $vat_code = 'STANDARD';

    # OLD METHOD: Aggregate first
    my $aggregate_total = 0;
    $aggregate_total += $_ for @transactions;
    my ( $old_exclusive, $old_vat ) =
      calculate_exclusive_and_vat( $aggregate_total, $vat_code );

    # NEW METHOD: Calculate per-line
    my $new_exclusive_total = 0;
    my $new_vat_total       = 0;
    for my $amount (@transactions) {
        my ( $excl, $vat ) = calculate_exclusive_and_vat( $amount, $vat_code );
        $new_exclusive_total += $excl;
        $new_vat_total       += $vat;
    }
    $new_exclusive_total = sprintf( "%.2f", $new_exclusive_total );
    $new_vat_total       = sprintf( "%.2f", $new_vat_total );

    diag("\n=== Test Case 1: Three £9.99 transactions ===");
    diag("Aggregate total: £$aggregate_total");
    diag("\nOLD METHOD (aggregate first):");
    diag("  Exclusive: £$old_exclusive");
    diag("  VAT:       £$old_vat");
    diag("  Total:     £" . ( $old_exclusive + $old_vat ));
    diag("\nNEW METHOD (per-line):");
    diag("  Exclusive: £$new_exclusive_total");
    diag("  VAT:       £$new_vat_total");
    diag("  Total:     £" . ( $new_exclusive_total + $new_vat_total ));

    # The new method should give different (more accurate) results
    isnt( $old_exclusive, $new_exclusive_total,
        "Exclusive amounts differ between methods" );
    isnt( $old_vat, $new_vat_total, "VAT amounts differ between methods" );

    # Both should sum to the same total
    is( sprintf( "%.2f", $old_exclusive + $old_vat ),
        sprintf( "%.2f", $new_exclusive_total + $new_vat_total ),
        "Both methods produce correct total" );
}

# Test Case 2: Maximum rounding edge case
sub test_maximum_rounding {
    my @transactions = ( 1.43, 1.43, 1.43, 1.43, 1.43, 1.43, 1.43 );
    my $vat_code = 'STANDARD';

    # OLD METHOD
    my $aggregate_total = 0;
    $aggregate_total += $_ for @transactions;
    my ( $old_exclusive, $old_vat ) =
      calculate_exclusive_and_vat( $aggregate_total, $vat_code );

    # NEW METHOD
    my $new_exclusive_total = 0;
    my $new_vat_total       = 0;
    for my $amount (@transactions) {
        my ( $excl, $vat ) = calculate_exclusive_and_vat( $amount, $vat_code );
        $new_exclusive_total += $excl;
        $new_vat_total       += $vat;
    }
    $new_exclusive_total = sprintf( "%.2f", $new_exclusive_total );
    $new_vat_total       = sprintf( "%.2f", $new_vat_total );

    diag("\n=== Test Case 2: Seven £1.43 transactions (edge case) ===");
    diag("Aggregate total: £$aggregate_total");
    diag("\nOLD METHOD:");
    diag("  Exclusive: £$old_exclusive");
    diag("  VAT:       £$old_vat");
    diag("\nNEW METHOD:");
    diag("  Exclusive: £$new_exclusive_total");
    diag("  VAT:       £$new_vat_total");

    isnt( $old_exclusive, $new_exclusive_total,
        "Rounding difference detected" );
}

# Test Case 3: Zero-rated transactions (no difference expected)
sub test_zero_rated {
    my @transactions = ( 10.00, 15.50, 20.00 );
    my $vat_code = 'ZERO';

    # OLD METHOD
    my $aggregate_total = 0;
    $aggregate_total += $_ for @transactions;
    my ( $old_exclusive, $old_vat ) =
      calculate_exclusive_and_vat( $aggregate_total, $vat_code );

    # NEW METHOD
    my $new_exclusive_total = 0;
    my $new_vat_total       = 0;
    for my $amount (@transactions) {
        my ( $excl, $vat ) = calculate_exclusive_and_vat( $amount, $vat_code );
        $new_exclusive_total += $excl;
        $new_vat_total       += $vat;
    }
    $new_exclusive_total = sprintf( "%.2f", $new_exclusive_total );
    $new_vat_total       = sprintf( "%.2f", $new_vat_total );

    diag("\n=== Test Case 3: Zero-rated transactions ===");
    diag("Aggregate total: £$aggregate_total");
    diag("\nOLD METHOD:");
    diag("  Exclusive: £$old_exclusive");
    diag("  VAT:       £$old_vat");
    diag("\nNEW METHOD:");
    diag("  Exclusive: £$new_exclusive_total");
    diag("  VAT:       £$new_vat_total");

    # For zero-rated, both methods should match
    is( $old_exclusive, $new_exclusive_total,
        "Zero-rated: exclusive amounts match" );
    is( $old_vat, $new_vat_total, "Zero-rated: VAT is zero" );
}

# Test Case 4: Large number of small transactions
sub test_many_small_transactions {
    my @transactions = (0.99) x 100;    # 100 transactions of £0.99
    my $vat_code = 'STANDARD';

    # OLD METHOD
    my $aggregate_total = 0;
    $aggregate_total += $_ for @transactions;
    my ( $old_exclusive, $old_vat ) =
      calculate_exclusive_and_vat( $aggregate_total, $vat_code );

    # NEW METHOD
    my $new_exclusive_total = 0;
    my $new_vat_total       = 0;
    for my $amount (@transactions) {
        my ( $excl, $vat ) = calculate_exclusive_and_vat( $amount, $vat_code );
        $new_exclusive_total += $excl;
        $new_vat_total       += $vat;
    }
    $new_exclusive_total = sprintf( "%.2f", $new_exclusive_total );
    $new_vat_total       = sprintf( "%.2f", $new_vat_total );

    diag("\n=== Test Case 4: 100 × £0.99 transactions ===");
    diag("Aggregate total: £$aggregate_total");
    diag("\nOLD METHOD:");
    diag("  Exclusive: £$old_exclusive");
    diag("  VAT:       £$old_vat");
    diag("  Difference: £"
          . sprintf( "%.2f", $aggregate_total - $old_exclusive - $old_vat ) );
    diag("\nNEW METHOD:");
    diag("  Exclusive: £$new_exclusive_total");
    diag("  VAT:       £$new_vat_total");
    diag("  Difference: £"
          . sprintf( "%.2f",
            $aggregate_total - $new_exclusive_total - $new_vat_total )
    );

    # Demonstrate cumulative rounding effect
    my $difference = abs( $old_exclusive - $new_exclusive_total );
    cmp_ok( $difference, '>=', 0.01,
        "Cumulative rounding difference of at least 1p detected" );
}

# Run all tests
test_classic_discrepancy();
test_maximum_rounding();
test_zero_rated();
test_many_small_transactions();

done_testing();
