# VAT Calculation Changes - FINAL

## Summary

The income report VAT handling has been updated to send **tax exclusive amounts** instead of tax inclusive amounts. Oracle will **trust the VAT amount we provide** in Field 16.

## The Problem

Koha stores tax-inclusive amounts (what the patron actually paid). Oracle expects:
- Field 5: Tax exclusive amount
- Field 15: VAT Code (STANDARD, ZERO, EXEMPT, OUT OF SCOPE)
- Field 16: VAT Amount

The challenge: for any inclusive amount, we need to split it into exclusive + VAT such that they sum exactly to the original amount.

## The Solution

### Algorithm

Given an inclusive amount from Koha:

```perl
# 1. Calculate exclusive amount
$exclusive = $inclusive / 1.20;  # For 20% VAT rate

# 2. Round exclusive to nearest penny (standard rounding)
$exclusive = sprintf("%.2f", $exclusive);

# 3. Calculate VAT as the difference
$vat = $inclusive - $exclusive;
$vat = sprintf("%.2f", $vat);
```

This guarantees: **exclusive + VAT = inclusive** (exactly to the penny)

### Why This Works

- Oracle receives both the exclusive amount AND the VAT amount
- Oracle **trusts our VAT amount** (doesn't recalculate)
- Oracle calculates: Total = Exclusive (Field 5) + VAT (Field 16)
- Result: Oracle's total matches Koha's inclusive amount perfectly

## Implementation

### New Method: `_calculate_exclusive_and_vat`

**Located in**: `Koha/Plugin/Com/OpenFifth/Oracle.pm:1026-1050`

```perl
sub _calculate_exclusive_and_vat {
    my ( $self, $inclusive_amount, $vat_code ) = @_;

    # For non-STANDARD rates, return full amount as exclusive with zero VAT
    unless ( $vat_code eq 'STANDARD' ) {
        return (
            sprintf( "%.2f", $inclusive_amount ),    # Exclusive
            sprintf( "%.2f", 0 )                     # VAT
        );
    }

    # Standard VAT rate is 20%
    my $exclusive_amount = $inclusive_amount / 1.20;
    $exclusive_amount = sprintf( "%.2f", $exclusive_amount );

    # Calculate VAT as difference to ensure exact total
    my $vat_amount = $inclusive_amount - $exclusive_amount;
    $vat_amount = sprintf( "%.2f", $vat_amount );

    return ( $exclusive_amount, $vat_amount );
}
```

### Updated Income Report Generation

**Located in**: `Koha/Plugin/Com/OpenFifth/Oracle.pm:846-848`

```perl
# Get VAT information and calculate exclusive/VAT split
my $vat_code = $self->_get_debit_type_vat_code($debit_type);
my ( $exclusive_amount, $vat_amount ) =
  $self->_calculate_exclusive_and_vat( $inclusive_amount, $vat_code );
```

The CSV output sends:
- Field 5: `$exclusive_amount` (tax exclusive)
- Field 16: `$vat_amount` (Oracle trusts this value)

## Example Calculations

| Koha Inclusive | Exclusive | VAT | VAT Rate | Notes |
|----------------|-----------|-----|----------|-------|
| £120.00 | £100.00 | £20.00 | 20.0% | Clean division |
| £60.00 | £50.00 | £10.00 | 20.0% | Clean division |
| £1.00 | £0.83 | £0.17 | 20.5% | Rounding adjustment |
| £11.11 | £9.26 | £1.85 | 20.0% | Previously problematic! |
| £0.06 | £0.05 | £0.01 | 20.0% | Small amount |
| £0.01 | £0.01 | £0.00 | 0.0% | Edge case |

**Note**: The effective VAT rate may vary slightly from 20% due to rounding, but the total is always exact.

## VAT Code Handling

| VAT Code | Rate | Behavior |
|----------|------|----------|
| STANDARD | 20% | Calculates exclusive = inclusive ÷ 1.20 |
| ZERO | 0% | Exclusive = inclusive, VAT = 0 |
| EXEMPT | 0% | Exclusive = inclusive, VAT = 0 |
| OUT OF SCOPE | 0% | Exclusive = inclusive, VAT = 0 |

## Testing

### Comprehensive Test Suite

All tests pass:

```bash
docker exec kohadev-koha-1 bash -c "cd /kohadevbox/plugins/koha-plugin-wscc-oracle && \
  KOHA_PLUGIN_DIR=/kohadevbox/plugins/koha-plugin-wscc-oracle perl t/verify-implementation.pl"
```

**Results**: 38/38 tests pass including:
- Clean divisions (£120, £60, £6)
- Rounding cases (£1.00, £11.11)
- Edge cases (£0.01, £0.06)
- All VAT codes (STANDARD, ZERO, EXEMPT, OUT OF SCOPE)

### Standalone Test

```bash
perl t/test-final-algorithm.pl
```

## Mathematical Note

**Important**: For approximately 16.67% of possible amounts, it's mathematically impossible to split them such that:
1. `exclusive + ceil(exclusive × 20%) = inclusive`
2. Both exclusive and VAT are rounded to 2 decimal places

**Our solution**: Oracle trusts the VAT amount we provide, so we can always achieve exact totals by calculating VAT as the difference.

## Oracle Integration

### What Oracle Receives (CSV Fields)

| Field | Name | Example | Description |
|-------|------|---------|-------------|
| 5 | D_Line Amount | 100.00 | Tax exclusive amount |
| 15 | D_VAT Code | STANDARD | VAT classification |
| 16 | D_VAT Amount | 20.00 | **Oracle trusts this value** |

### Oracle's Processing

```
Oracle receives: Exclusive=£100.00, VAT=£20.00
Oracle calculates: Total = £100.00 + £20.00 = £120.00
Koha's original: £120.00
Result: ✅ Perfect match!
```

## Benefits

1. **Always exact**: Totals match Koha's inclusive amounts to the penny
2. **Simple algorithm**: Division + subtraction, no complex rounding
3. **Handles edge cases**: Works for all amounts including £0.01
4. **Oracle compatible**: Oracle trusts our VAT calculations
5. **No reconciliation issues**: Perfect match between systems

## Migration Notes

- Previous implementation used `ceil` rounding which is no longer needed
- Removed `use POSIX qw(ceil);` import
- Method renamed from `_calculate_vat_amount` to `_calculate_exclusive_and_vat`
- Returns both values as a tuple instead of just VAT

## Support

If Oracle rejects reports due to VAT validation, this may indicate Oracle is recalculating VAT instead of trusting Field 16. In that case, contact the Oracle integration team to confirm the expected behavior.
