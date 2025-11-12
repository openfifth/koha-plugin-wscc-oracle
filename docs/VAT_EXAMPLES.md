# VAT Calculation Examples

## Overview

This document shows example calculations for the updated VAT handling in the income report.

## VAT Calculation Formula

For a 20% VAT rate (STANDARD):
```
VAT Amount = Inclusive Amount ÷ 6
Exclusive Amount = Inclusive Amount - VAT Amount
```

The VAT amount is **always rounded UP** to the nearest penny using `POSIX::ceil`.

## Test Results

All test cases pass in the Koha Testing Docker environment:

```
Testing VAT calculations (STANDARD rate with Oracle round-up)
======================================================================
✓ PASS: Clean 120.00 inclusive
  Inclusive: £120 => VAT: £20.00, Exclusive: £100.00

✓ PASS: Clean 60.00 inclusive
  Inclusive: £60 => VAT: £10.00, Exclusive: £50.00

✓ PASS: Clean 6.00 inclusive
  Inclusive: £6 => VAT: £1.00, Exclusive: £5.00

✓ PASS: 1.00 inclusive (rounds up from 0.166...)
  Inclusive: £1 => VAT: £0.17, Exclusive: £0.83

✓ PASS: 0.10 inclusive (rounds up from 0.0166...)
  Inclusive: £0.1 => VAT: £0.02, Exclusive: £0.08

✓ PASS: 10.01 inclusive (rounds up from 1.668...)
  Inclusive: £10.01 => VAT: £1.67, Exclusive: £8.34

✓ PASS: 5.55 inclusive (rounds up from 0.925)
  Inclusive: £5.55 => VAT: £0.93, Exclusive: £4.62

✓ PASS: 12.34 inclusive (rounds up from 2.056...)
  Inclusive: £12.34 => VAT: £2.06, Exclusive: £10.28

✓ PASS: Minimum 0.01 inclusive
  Inclusive: £0.01 => VAT: £0.01, Exclusive: £0.00

✓ PASS: Large amount 999.99
  Inclusive: £999.99 => VAT: £166.67, Exclusive: £833.32

======================================================================
Results: 10 passed, 0 failed
```

## Detailed Examples

### Example 1: Clean Division (£120.00)
```
Inclusive Amount: £120.00
VAT Calculation: £120.00 ÷ 6 = £20.00
VAT Amount: £20.00 (no rounding needed)
Exclusive Amount: £120.00 - £20.00 = £100.00
```

### Example 2: Rounding Up (£1.00)
```
Inclusive Amount: £1.00
VAT Calculation: £1.00 ÷ 6 = £0.16666...
VAT Amount: £0.17 (rounded UP from £0.16666...)
Exclusive Amount: £1.00 - £0.17 = £0.83
```

### Example 3: Rounding Up (£10.01)
```
Inclusive Amount: £10.01
VAT Calculation: £10.01 ÷ 6 = £1.66833...
VAT Amount: £1.67 (rounded UP from £1.66833...)
Exclusive Amount: £10.01 - £1.67 = £8.34
```

### Example 4: Edge Case - Half Penny (£5.55)
```
Inclusive Amount: £5.55
VAT Calculation: £5.55 ÷ 6 = £0.925
VAT Amount: £0.93 (rounded UP from £0.925)
Exclusive Amount: £5.55 - £0.93 = £4.62
```

## CSV Output Format

The income report CSV will contain these fields (relevant ones shown):

| Field | Name | Example Value | Description |
|-------|------|---------------|-------------|
| 5 | D_Line Amount | 100.00 | **Tax exclusive amount** |
| 15 | D_VAT Code | STANDARD | VAT classification |
| 16 | D_VAT Amount | 20.00 | VAT amount (rounded up) |

Oracle will add Field 5 + Field 16 to get the total inclusive amount.

## VAT Code Behavior

| VAT Code | Rate | VAT Calculation | Example |
|----------|------|-----------------|---------|
| STANDARD | 20% | Calculated with round-up | £120 → VAT £20 + Ex £100 |
| ZERO | 0% | Always £0.00 | £120 → VAT £0 + Ex £120 |
| EXEMPT | 0% | Always £0.00 | £120 → VAT £0 + Ex £120 |
| OUT OF SCOPE | 0% | Always £0.00 | £120 → VAT £0 + Ex £120 |

## Running Tests

To verify the calculations:

```bash
# Outside container
perl t/vat-calc-simple.pl

# Inside Koha Testing Docker
docker exec kohadev-koha-1 perl /kohadevbox/plugins/koha-plugin-wscc-oracle/t/vat-calc-simple.pl

# Run all tests
docker exec kohadev-koha-1 bash -c "cd /kohadevbox/plugins/koha-plugin-wscc-oracle && prove t/"
```

## Oracle Reconciliation

With these changes:
1. Koha records the tax-inclusive amount in the database
2. Plugin calculates VAT using Oracle's round-up rules
3. Plugin sends tax-exclusive amount and VAT to Oracle
4. Oracle adds exclusive + VAT to get the inclusive total
5. Oracle's calculated VAT matches our calculated VAT exactly

This ensures perfect reconciliation between Koha and Oracle Finance.
