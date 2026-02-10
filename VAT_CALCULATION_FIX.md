# VAT Calculation Fix - Per-Line Calculation

## Problem

The previous implementation calculated VAT on **aggregated amounts**, leading to rounding discrepancies:

### Example of the Issue:
```
3 transactions of £9.99 each (inclusive of 20% VAT)

OLD METHOD (Aggregate first, then calculate):
1. Sum amounts: £9.99 + £9.99 + £9.99 = £29.97
2. Calculate: £29.97 ÷ 1.20 = £24.975 → rounds to £24.98 (exclusive)
3. VAT: £29.97 - £24.98 = £4.99
Result: £24.98 exclusive + £4.99 VAT = £29.97 ✓

NEW METHOD (Calculate per-line, then aggregate):
1. Transaction 1: £9.99 ÷ 1.20 = £8.325 → £8.33 exclusive, £1.66 VAT
2. Transaction 2: £9.99 ÷ 1.20 = £8.325 → £8.33 exclusive, £1.66 VAT
3. Transaction 3: £9.99 ÷ 1.20 = £8.325 → £8.33 exclusive, £1.66 VAT
4. Sum: £24.99 exclusive + £4.98 VAT = £29.97 ✓
```

**Difference: 1p in exclusive amount (£24.98 vs £24.99) and 1p in VAT (£4.99 vs £4.98)**

## Solution

Changed from SQL-level aggregation to per-line calculation with in-memory aggregation:

### Before:
```perl
# SQL aggregates with GROUP BY
my $income_summary = Koha::Account::Offsets->search(..., {
    group_by => [...],
    'select' => [{ sum => 'me.amount' }, ...]
});

while ( my $row = $income_summary->next ) {
    my $inclusive_amount = $row->get_column('total_amount') * -1;
    my ($exclusive, $vat) = _calculate_exclusive_and_vat($inclusive_amount, $vat_code);
    # Output CSV line
}
```

### After:
```perl
# Fetch individual offsets (no GROUP BY)
my $income_offsets = Koha::Account::Offsets->search(..., {
    'select' => ['me.amount', ...]  # Individual amounts
});

# Aggregate in memory with per-line VAT calculation
my %aggregated;
while ( my $offset = $income_offsets->next ) {
    my $offset_amount = $offset->get_column('amount') * -1;

    # Calculate VAT for THIS offset
    my ($exclusive, $vat) = _calculate_exclusive_and_vat($offset_amount, $vat_code);

    # Accumulate by grouping key
    my $key = join('|', $credit_branch, $debit_branch, ...);
    $aggregated{$key}{total_exclusive} += $exclusive;
    $aggregated{$key}{total_vat} += $vat;
}

# Output aggregated results
for my $row (values %aggregated) {
    # Round aggregated totals
    my $exclusive_amount = sprintf("%.2f", $row->{total_exclusive});
    my $vat_amount = sprintf("%.2f", $row->{total_vat});
    # Output CSV line
}
```

## Benefits

1. **Mathematical Correctness**: VAT calculated on individual transactions matches real-world receipts
2. **No Rounding Errors**: Sum of rounded amounts = correct total
3. **Same Report Format**: Output structure unchanged, backward compatible
4. **Performance**: In-memory aggregation is fast, minimal impact

## Performance Considerations

- **Old approach**: One SQL query with GROUP BY (faster query, wrong math)
- **New approach**: One SQL query returning more rows, Perl aggregation (slightly more memory, correct math)

For typical daily reports (thousands of transactions):
- Memory usage: Negligible (hash with ~100-500 keys)
- CPU impact: Minimal (simple arithmetic operations)
- Database impact: Same number of queries (1), slightly more data transfer

## Testing Scenarios

### Test Case 1: Standard VAT (20%)
```
Input: 3 transactions of £9.99 each
Expected Output:
- Exclusive: £24.99
- VAT: £4.98
- Total: £29.97
```

### Test Case 2: Zero-Rated VAT
```
Input: 5 transactions of £10.00 each (VAT Code: ZERO)
Expected Output:
- Exclusive: £50.00
- VAT: £0.00
- Total: £50.00
```

### Test Case 3: Mixed VAT Codes
```
Input:
- 2 × £9.99 (STANDARD VAT)
- 3 × £15.00 (OUT OF SCOPE)
Expected Output (separate lines):
Line 1: £16.66 exclusive + £3.32 VAT = £19.98
Line 2: £45.00 exclusive + £0.00 VAT = £45.00
```

### Test Case 4: Penny Rounding Edge Case
```
Input: 7 transactions of £1.43 each (creates maximum rounding)
£1.43 ÷ 1.20 = £1.191666... → £1.19 exclusive, £0.24 VAT

Old method: £10.01 aggregate → £8.34 exclusive, £1.67 VAT
New method: 7 × (£1.19 + £0.24) = £8.33 exclusive, £1.68 VAT
```

## Validation

To verify the fix is working:

1. Generate an income report for a known date range
2. For each line in the report:
   - Verify: `exclusive_amount + vat_amount = expected_total`
   - Compare against individual transaction records in Koha
3. Sum all exclusive amounts and VAT amounts
4. Verify totals match sum of individual cashup sessions

## Migration Notes

- No database schema changes required
- No configuration changes required
- Existing reports remain valid
- Report format unchanged (same 16 fields)
- Can be deployed without data migration

## Code Changes

**File**: `Koha/Plugin/Com/OpenFifth/Oracle.pm`

**Method**: `_generate_income_report` (lines 722-954)

**Changes**:
1. Removed SQL `GROUP BY` aggregation (line 811-837)
2. Added per-line VAT calculation loop (line 843-877)
3. Changed output loop from ResultSet iterator to array (line 889-990)
4. Removed redundant VAT calculation in output loop (already done in aggregation)

## Backward Compatibility

- ✅ Report format unchanged (16 fields)
- ✅ Field meanings unchanged
- ✅ Oracle import process unchanged
- ✅ Configuration unchanged
- ✅ No breaking changes

## Future Enhancements

Consider adding:
1. Debug logging to compare old vs new calculations
2. Report validation tool to check VAT math
3. Unit tests for VAT calculation edge cases
