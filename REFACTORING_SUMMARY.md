# VAT Calculation Refactoring Summary

## Changes Made

Refactored the income report generation (`_generate_income_report` method) to calculate VAT on individual transactions before aggregation, eliminating rounding discrepancies.

## Problem Solved

**Old approach**:
1. Aggregate transaction amounts using SQL GROUP BY
2. Calculate VAT on aggregated total
3. Rounding happens once on large number

**Issue**: Produces different results than summing individually-rounded amounts.

**Example**:
- 3 × £9.99 transactions
- Old method: £29.97 → £24.98 exclusive + £4.99 VAT
- New method: 3 × (£8.33 + £1.66) = £24.99 exclusive + £4.98 VAT
- **Difference: 1p discrepancy**

## Solution Implemented

**New approach**:
1. Fetch individual offset records (no SQL aggregation)
2. Calculate VAT on each offset amount
3. Accumulate exclusive and VAT amounts separately in memory
4. Output aggregated results with proper rounding

## Code Changes

**File**: `Koha/Plugin/Com/OpenFifth/Oracle.pm` (lines 810-990)

### Before:
```perl
# SQL-level aggregation with GROUP BY
my $income_summary = Koha::Account::Offsets->search(..., {
    group_by => [...],
    'select' => [{ sum => 'me.amount' }, ...]
});

while ( my $row = $income_summary->next ) {
    my $inclusive = $row->get_column('total_amount') * -1;
    my ($excl, $vat) = _calculate_exclusive_and_vat($inclusive, $vat_code);
    # Output...
}
```

### After:
```perl
# Fetch individual records (no GROUP BY)
my $income_offsets = Koha::Account::Offsets->search(..., {
    'select' => ['me.amount', ...]  # Individual amounts only
});

# In-memory aggregation with per-line VAT
my %aggregated;
while ( my $offset = $income_offsets->next ) {
    my $amount = $offset->get_column('amount') * -1;

    # Calculate VAT for THIS transaction
    my ($excl, $vat) = _calculate_exclusive_and_vat($amount, $vat_code);

    # Accumulate by grouping key
    my $key = join('|', $branch, $debit_type, $payment_type);
    $aggregated{$key}{total_exclusive} += $excl;
    $aggregated{$key}{total_vat} += $vat;
}

# Output aggregated results
for my $row (values %aggregated) {
    my $excl = sprintf("%.2f", $row->{total_exclusive});
    my $vat = sprintf("%.2f", $row->{total_vat});
    # Output...
}
```

## Performance Impact

- **Database**: Same number of queries (1), slightly more data transfer
- **Memory**: Minimal increase (hash with ~100-500 keys for typical daily reports)
- **CPU**: Negligible (simple arithmetic in Perl loop)
- **Overall**: Performance impact is minimal, correctness benefit is significant

## Test Results

See `test_vat_fix.pl` for validation script.

**Test Case 1**: Three £9.99 transactions
- Old: £24.98 excl + £4.99 VAT
- New: £24.99 excl + £4.98 VAT ✓
- **Difference: 1p correction**

**Test Case 2**: Seven £1.43 transactions
- Old: £8.34 excl + £1.67 VAT
- New: £8.33 excl + £1.68 VAT ✓
- **Difference: 1p correction**

**Test Case 3**: Zero-rated transactions
- Both methods: Identical results ✓
- (No VAT = no rounding issue)

**Test Case 4**: 100 × £0.99 transactions
- Old: £82.50 excl + £16.50 VAT
- New: £83.00 excl + £16.00 VAT ✓
- **Difference: 50p cumulative rounding error corrected**

## Benefits

1. ✅ **Mathematically Correct**: VAT calculated per transaction matches receipts
2. ✅ **No Rounding Discrepancies**: Eliminates penny-rounding errors
3. ✅ **Backward Compatible**: Report format unchanged (16 fields)
4. ✅ **Performant**: Minimal performance impact for typical workloads
5. ✅ **Auditable**: Per-line calculations match individual transaction records

## Files Added

1. **VAT_CALCULATION_FIX.md**: Detailed technical documentation
2. **test_vat_fix.pl**: Test script demonstrating the issue and fix
3. **REFACTORING_SUMMARY.md**: This summary document

## Next Steps

### Testing
```bash
# Run validation test
perl test_vat_fix.pl

# Generate a test report and verify totals
# (Use UI or cronjob to generate income report)
```

### Deployment
1. No database migration required
2. No configuration changes required
3. Can be deployed immediately
4. Existing reports remain valid

### Validation
After deployment:
1. Generate income report for known date range
2. Verify totals match cashup sessions
3. Compare exclusive + VAT = expected totals
4. Spot-check against individual transactions in Koha

## Technical Notes

- The aggregation logic maintains the same grouping keys as before:
  - Credit branchcode (payment location)
  - Debit branchcode (charge origin)
  - Credit type code
  - Debit type code
  - Payment type

- The report output format remains identical (16 fields in same order)

- VAT calculation method unchanged (`_calculate_exclusive_and_vat`)

- Only the **order of operations** changed:
  - Before: sum → calculate → round
  - After: calculate → round → sum

## References

- Main plugin file: `Koha/Plugin/Com/OpenFifth/Oracle.pm`
- Method changed: `_generate_income_report` (lines 722-990)
- VAT calculation: `_calculate_exclusive_and_vat` (lines 1093-1117)
