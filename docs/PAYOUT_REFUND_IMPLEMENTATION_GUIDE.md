# Payout/Refund Implementation Guide

**Context:** This guide describes how to modify the Oracle income report to include PAYOUT transactions (refunds), showing money leaving the register to allow for complete cashup balancing.

**Status:** Pending decision after meeting (2026-02-11)

**Current Behavior:** The income report excludes refunds entirely, showing only positive income amounts as per Oracle spec Field 5: "Positive Amount (No Refunds)".

---

## Table of Contents

1. [Current State](#current-state)
2. [Design Considerations](#design-considerations)
3. [Implementation Approach](#implementation-approach)
4. [Code Changes](#code-changes)
5. [Testing Strategy](#testing-strategy)
6. [Recommendations](#recommendations)

---

## Current State

### How Refunds Work in Koha

When a refund is processed in Koha:

1. **REFUND credit** is created (credit_type_code = 'REFUND') - reverses the original charge
2. **PAYOUT debit** is created at the register where refund occurs - represents cash leaving the till
3. These are linked via account offsets to track the relationship

**Cross-Register Refunds:**
- Payment made at Register A: +£10 (appears in Register A's cashup)
- Refund issued at Register B: -£10 (appears in Register B's cashup via PAYOUT debit)
- This maintains accurate per-register cash accounting

### Why Current Report Excludes Refunds

The `_generate_income_report` method filters out refunds at multiple levels:

1. **Documentation requirement** (docs/income/income_report.md:34):
   - Field 5: "Positive Amount (No Refunds)"

2. **Credits-only query** (Oracle.pm:801):
   ```perl
   debit_type_code => undef,  # Only credits (payments IN)
   ```
   - PAYOUTs are debits, so automatically excluded

3. **Amount filters** (Oracle.pm:855, 911):
   ```perl
   next if $offset_amount <= 0;      # Skip zero or negative
   next if $exclusive_amount <= 0;   # Skip zero or negative
   ```

---

## Design Considerations

### Critical Questions for Oracle Team

Before implementing, you MUST clarify with Oracle:

1. **Can Field 5 (D_Line Amount) accept negative values?**
   - If NO: Need to use offset accounts or separate report
   - If YES: Can show income as positive, payouts as negative

2. **Should payouts use the same COA codes as income or different ones?**
   - Same codes: Simpler implementation
   - Different codes: Need new configuration fields for payout mappings

3. **Should they be in the same file or separate files?**
   - Same file: Single reconciliation point
   - Separate files: Cleaner GL account separation

4. **How should VAT be handled for refunds?**
   - Should be negative VAT (reversing the original transaction)
   - Confirm Oracle can process negative VAT amounts

### Implementation Options

#### Option A: Negative Amounts in Same Report (Recommended)
- **Pros:** Single file, easy reconciliation, shows true cashup balance
- **Cons:** Requires Oracle spec change, mixed positive/negative amounts
- **Best for:** Complete cashup reconciliation

#### Option B: Net Amounts (Income - Payouts per Type)
- **Pros:** Only positive amounts, simple aggregation
- **Cons:** Loses visibility into individual transactions, harder to audit
- **Best for:** Simplified reporting when detail not needed

#### Option C: Separate Payout Report
- **Pros:** No spec change, clear separation, different GL accounts possible
- **Cons:** Two files to manage, more complex reconciliation
- **Best for:** When Oracle has separate GL accounts for refunds

**This guide covers Option A (most requested for cashup balancing).**

---

## Implementation Approach

### High-Level Changes

1. Add method to query PAYOUT transactions from cashup sessions
2. Query payout offsets (debit = PAYOUT, credit = REFUND)
3. Process payouts with negative amounts
4. Integrate into existing aggregation structure
5. Remove positive-only filters
6. Add payout indicators to document descriptions
7. Handle COA field mappings for payouts (may need separate defaults)

### Data Flow

```
Cashup Session
    ├─ Income Transactions (Credits: PAYMENT, PURCHASE, etc.)
    │   └─ Offsets → Link to Debits (OVERDUE, LOST, etc.)
    │       └─ Aggregate by: branch|debit_type|payment_type
    │           └─ Output: Positive amounts (£10.00)
    │
    └─ Payout Transactions (Debits: PAYOUT)
        └─ Offsets → Link to Credits (REFUND)
            └─ Lookup Original Debit Type (what was refunded)
                └─ Aggregate by: branch|original_debit_type|payment_type
                    └─ Output: Negative amounts (-£10.00)
```

---

## Code Changes

### Step 1: Add Payout Query Method

Add this method after `_generate_income_report` (around line 1006):

```perl
sub _get_payout_transactions {
    my ( $self, $session_accountlines ) = @_;

    # Query for PAYOUT debits (refunds) from this cashup session
    my $payout_transactions = $session_accountlines->search(
        {
            debit_type_code => 'PAYOUT',          # Only PAYOUT debits
            credit_type_code => undef,            # Debits have NULL credit_type
            amount => { '>', 0 },                 # Positive amounts (debits in Koha)
        }
    );

    return $payout_transactions;
}
```

### Step 2: Query Both Income and Payouts

Modify around line 798-817:

```perl
# EXISTING: Get income transactions
my $income_transactions = $session_accountlines->search({
    debit_type_code  => undef,                        # Only credits
    credit_type_code => { '!=' => 'CASHUP_SURPLUS' },
    payment_type => { '!=' => undef },
    amount => { '<', 0 },
    -or => [
        description => undef,
        description => { 'NOT LIKE' => '%Pay360%' }
    ]
});

# NEW: Also get payout transactions
my $payout_transactions = $self->_get_payout_transactions($session_accountlines);

# Skip if no transactions at all in this session
next unless ($income_transactions->count || $payout_transactions->count);
```

### Step 3: Query Payout Offsets

Add after line 846 (existing income_offsets query):

```perl
# NEW: Fetch payout offsets
# For payouts: debit = PAYOUT, credit = REFUND
# Need to link back to find original debit type that was refunded
my $payout_offsets = Koha::Account::Offsets->search(
    {
        'me.debit_id' => {
            '-in' => $payout_transactions->_resultset->get_column(
                'accountlines_id')->as_query
        },
        'me.credit_id' => { '!=' => undef }  # Must have linked REFUND credit
    },
    {
        join => [
            { 'debit'  => 'debit_type_code' },   # PAYOUT debit
            { 'credit' => 'credit_type_code' }    # REFUND credit
        ],
        'select' => [
            'me.amount',                    # Offset amount (positive)
            'debit.branchcode',             # Where payout occurred
            'credit.branchcode',            # Where original payment was
            'debit.debit_type_code',        # Should be 'PAYOUT'
            'debit_type_code.description',
            'credit.credit_type_code',      # Should be 'REFUND'
            'credit_type_code.description',
            'debit.payment_type',           # Payment method (CASH, CARD, etc)
            'credit.accountlines_id'        # For looking up original debit
        ],
        'as' => [
            'amount',
            'payout_branchcode',    # Register where refund was issued
            'original_branchcode',  # Register where payment was made
            'debit_type_code',
            'debit_description',
            'credit_type_code',
            'credit_description',
            'payment_type',
            'refund_credit_id'
        ]
    }
);
```

### Step 4: Helper Method to Find Original Debit Type

Add this method to look up what was originally refunded:

```perl
sub _get_original_debit_type_from_refund {
    my ( $self, $refund_credit_id ) = @_;

    # Find the offset where this REFUND credit paid off an original debit
    my $original_offset = Koha::Account::Offsets->search(
        {
            'me.credit_id' => $refund_credit_id,
            'me.debit_id'  => { '!=' => undef }
        },
        {
            join => { 'debit' => 'debit_type_code' },
            'select' => [
                'debit.debit_type_code',
                'debit_type_code.description'
            ],
            'as' => [
                'original_debit_type',
                'original_debit_description'
            ]
        }
    )->first;

    return $original_offset
        ? $original_offset->get_column('original_debit_type')
        : 'UNKNOWN';
}
```

### Step 5: Aggregate Payouts with Negative Amounts

Modify aggregation loop (around line 850-889):

```perl
# Aggregate in memory with per-line VAT calculation
# Key: branch|original_branch|credit_type|debit_type|payment_type|direction
my %aggregated;

# EXISTING: Process INCOME offsets (keep as-is)
while ( my $offset = $income_offsets->next ) {
    my $offset_amount = $offset->get_column('amount') * -1;  # Reverse sign
    next if $offset_amount <= 0;  # Skip zero or negative

    my $credit_branch = $offset->get_column('credit_branchcode') || 'UNKNOWN';
    my $debit_branch  = $offset->get_column('debit_branchcode') || 'UNKNOWN';
    my $credit_type   = $offset->get_column('credit_type_code');
    my $debit_type    = $offset->get_column('debit_type_code');
    my $payment_type  = $offset->get_column('payment_type') || 'UNKNOWN';

    # Create aggregation key with direction flag
    my $key = join('|',
        $credit_branch, $debit_branch, $credit_type,
        $debit_type, $payment_type, 'INCOME'
    );

    # Calculate VAT
    my $vat_code = $self->_get_debit_type_vat_code($debit_type);
    my ($exclusive, $vat) = $self->_calculate_exclusive_and_vat($offset_amount, $vat_code);

    # Initialize aggregation structure
    $aggregated{$key} //= {
        credit_branchcode => $credit_branch,
        debit_branchcode  => $debit_branch,
        credit_type_code  => $credit_type,
        debit_type_code   => $debit_type,
        payment_type      => $payment_type,
        direction         => 'INCOME',
        total_exclusive   => 0,
        total_vat         => 0,
    };

    # Accumulate positive amounts
    $aggregated{$key}{total_exclusive} += $exclusive;
    $aggregated{$key}{total_vat}       += $vat;
}

# NEW: Process PAYOUT offsets with NEGATIVE amounts
while ( my $offset = $payout_offsets->next ) {
    my $offset_amount = $offset->get_column('amount');  # Keep positive initially
    next if $offset_amount <= 0;  # Skip zero or negative

    my $payout_branch   = $offset->get_column('payout_branchcode') || 'UNKNOWN';
    my $original_branch = $offset->get_column('original_branchcode') || 'UNKNOWN';
    my $payment_type    = $offset->get_column('payment_type') || 'UNKNOWN';
    my $refund_credit_id = $offset->get_column('refund_credit_id');

    # Look up the original debit type that was refunded
    my $original_debit_type = $self->_get_original_debit_type_from_refund($refund_credit_id);

    # Create aggregation key (using payout_branch as main, original debit type)
    my $key = join('|',
        $payout_branch,      # Where refund occurred (main branch)
        $original_branch,    # Where original payment was (for offset fields)
        'REFUND',           # Credit type
        $original_debit_type, # What was refunded (OVERDUE, LOST, etc.)
        $payment_type,
        'PAYOUT'            # Direction flag
    );

    # Calculate VAT using original debit type's VAT code
    my $vat_code = $self->_get_debit_type_vat_code($original_debit_type);
    my ($exclusive, $vat) = $self->_calculate_exclusive_and_vat($offset_amount, $vat_code);

    # Make amounts NEGATIVE (money leaving register)
    $exclusive = $exclusive * -1;
    $vat = $vat * -1;

    # Initialize aggregation structure
    $aggregated{$key} //= {
        credit_branchcode => $payout_branch,    # Where payout occurred
        debit_branchcode  => $original_branch,  # Where original charge was
        credit_type_code  => 'REFUND',
        debit_type_code   => $original_debit_type,
        payment_type      => $payment_type,
        direction         => 'PAYOUT',
        total_exclusive   => 0,
        total_vat         => 0,
    };

    # Accumulate negative amounts
    $aggregated{$key}{total_exclusive} += $exclusive;
    $aggregated{$key}{total_vat}       += $vat;
}
```

### Step 6: Remove Positive-Only Filter

Around line 911, change:

```perl
# OLD CODE:
next if $exclusive_amount <= 0;    # Skip zero or negative amounts

# NEW CODE:
next if $exclusive_amount == 0;    # Only skip zero amounts (allow negative)
```

### Step 7: Update Document Description

Around line 920-930, distinguish payouts:

```perl
# Generate document description with direction indicator
my $direction_indicator = $row->{direction} eq 'PAYOUT' ? 'REFUND' : 'Income';
my $doc_description = sprintf(
    "%s:%s(%d)-%s-LIB-%s",
    $cashup_timestamp->strftime('%b%d/%y'),
    $register_id,
    $cashup_id,
    $credit_branch,
    $direction_indicator  # Shows 'Income' or 'REFUND'
);
```

### Step 8: Update Line Description

Around line 972, show refund indicator:

```perl
# Create line description
my $line_description;
if ($row->{direction} eq 'PAYOUT') {
    $line_description = "REFUND " . $payment_type . " " . $debit_type;
} else {
    $line_description = $payment_type . " " . $debit_type;
}
$line_description =~ s/[|"]//g;  # Remove pipe and quote characters
```

### Step 9: Optional - Add Payout-Specific COA Defaults

If Oracle requires different GL accounts for payouts, add configuration:

```perl
# In configure() method, add storage for payout defaults:
default_payout_costcentre => scalar $cgi->param('default_payout_costcentre'),
default_payout_subjective => scalar $cgi->param('default_payout_subjective'),
default_payout_subanalysis => scalar $cgi->param('default_payout_subanalysis'),

# In report generation, use conditional logic:
my $cost_centre;
my $subjective;
my $subanalysis;

if ($row->{direction} eq 'PAYOUT') {
    # Use payout-specific mappings (if configured)
    $cost_centre = $self->retrieve_data('default_payout_costcentre')
                   || $credit_branch_fields->{'Income Cost Centre'};
    $subjective = $self->retrieve_data('default_payout_subjective')
                  || $debit_fields->{'Subjective'};
    $subanalysis = $self->retrieve_data('default_payout_subanalysis')
                   || $debit_fields->{'Subanalysis'};
} else {
    # Existing income logic
    $cost_centre = $debit_fields->{'Cost Centre'}
                   || $credit_branch_fields->{'Income Cost Centre'};
    $subjective = $debit_fields->{'Subjective'};
    $subanalysis = $debit_fields->{'Subanalysis'};
}
```

### Step 10: Add Validation

At end of cashup processing, validate totals:

```perl
# After processing all transactions for a cashup, validate
my $report_total = 0;
for my $row (@income_summary) {
    $report_total += ($row->{total_exclusive} + $row->{total_vat});
}

# Compare to Koha's cashup summary
my $cashup_summary = $cashup->summary;
my $expected_total = 0;
for my $payment_type (keys %{$cashup_summary->{income}}) {
    $expected_total += $cashup_summary->{income}{$payment_type};
}
for my $payment_type (keys %{$cashup_summary->{payout}}) {
    $expected_total -= $cashup_summary->{payout}{$payment_type};
}

# Warn if mismatch (allow 1p rounding difference)
if (abs($report_total - $expected_total) > 0.01) {
    warn sprintf(
        "Cashup %d: Report total (%.2f) != Expected total (%.2f)",
        $cashup->id, $report_total, $expected_total
    );
}
```

---

## Testing Strategy

### Unit Tests

Create test file: `t/payout_report.t`

```perl
#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 5;
use t::lib::TestBuilder;
use Koha::Database;

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Income only (existing behavior)' => sub {
    plan tests => 2;
    $schema->storage->txn_begin;

    # Create cashup with only income
    my $register = $builder->build_object({ class => 'Koha::Cash::Registers' });
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });

    # Add PAYMENT credit
    my $payment = $patron->account->add_credit({
        amount => 10.00,
        type => 'PAYMENT',
        payment_type => 'CASH',
        interface => 'intranet',
        register_id => $register->id
    });

    # Create cashup
    my $cashup = $register->add_cashup({
        manager_id => $patron->id,
        amount => 10.00
    });

    # Generate report
    my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new;
    my $report = $plugin->_generate_income_report(
        dt_from_string()->subtract(days => 1),
        dt_from_string(),
        'test.csv'
    );

    ok($report, 'Report generated');
    like($report, qr/10\.00/, 'Contains positive amount');

    $schema->storage->txn_rollback;
};

subtest 'Payout only' => sub {
    plan tests => 3;
    $schema->storage->txn_begin;

    # Create cashup with payout
    my $register = $builder->build_object({ class => 'Koha::Cash::Registers' });
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });

    # Add REFUND credit and PAYOUT debit
    my $refund = $patron->account->add_credit({
        amount => 10.00,
        type => 'REFUND',
        interface => 'intranet'
    });

    my $payout = Koha::Account::Line->new({
        borrowernumber => $patron->id,
        amount => 10.00,
        debit_type_code => 'PAYOUT',
        payment_type => 'CASH',
        interface => 'intranet',
        register_id => $register->id
    })->store;

    # Link them via offset
    Koha::Account::Offset->new({
        credit_id => $refund->id,
        debit_id => $payout->id,
        type => 'REFUND',
        amount => 10.00
    })->store;

    # Create cashup
    my $cashup = $register->add_cashup({
        manager_id => $patron->id,
        amount => -10.00  # Negative (cash leaving)
    });

    # Generate report
    my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new;
    my $report = $plugin->_generate_income_report(
        dt_from_string()->subtract(days => 1),
        dt_from_string(),
        'test.csv'
    );

    ok($report, 'Report generated');
    like($report, qr/-10\.00/, 'Contains negative amount');
    like($report, qr/REFUND/, 'Contains REFUND indicator');

    $schema->storage->txn_rollback;
};

subtest 'Mixed income and payouts' => sub {
    plan tests => 4;
    $schema->storage->txn_begin;

    # Create cashup with both income and payout
    my $register = $builder->build_object({ class => 'Koha::Cash::Registers' });
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });

    # Income: £20
    my $payment = $patron->account->add_credit({
        amount => 20.00,
        type => 'PAYMENT',
        payment_type => 'CASH',
        interface => 'intranet',
        register_id => $register->id
    });

    # Payout: £10
    my $refund = $patron->account->add_credit({
        amount => 10.00,
        type => 'REFUND',
        interface => 'intranet'
    });

    my $payout = Koha::Account::Line->new({
        borrowernumber => $patron->id,
        amount => 10.00,
        debit_type_code => 'PAYOUT',
        payment_type => 'CASH',
        interface => 'intranet',
        register_id => $register->id
    })->store;

    Koha::Account::Offset->new({
        credit_id => $refund->id,
        debit_id => $payout->id,
        type => 'REFUND',
        amount => 10.00
    })->store;

    # Net cashup: £10
    my $cashup = $register->add_cashup({
        manager_id => $patron->id,
        amount => 10.00
    });

    # Generate report
    my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new;
    my $report = $plugin->_generate_income_report(
        dt_from_string()->subtract(days => 1),
        dt_from_string(),
        'test.csv'
    );

    ok($report, 'Report generated');
    like($report, qr/20\.00/, 'Contains positive income');
    like($report, qr/-10\.00/, 'Contains negative payout');

    # Verify net matches cashup
    my @lines = split /\n/, $report;
    is(scalar @lines, 2, 'Two lines (income + payout)');

    $schema->storage->txn_rollback;
};

subtest 'Cross-register refund' => sub {
    plan tests => 4;
    $schema->storage->txn_begin;

    # Payment at Register A
    my $register_a = $builder->build_object({ class => 'Koha::Cash::Registers' });
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });

    my $payment = $patron->account->add_credit({
        amount => 10.00,
        type => 'PAYMENT',
        payment_type => 'CASH',
        interface => 'intranet',
        register_id => $register_a->id
    });

    my $cashup_a = $register_a->add_cashup({
        manager_id => $patron->id,
        amount => 10.00
    });

    # Refund at Register B
    my $register_b = $builder->build_object({ class => 'Koha::Cash::Registers' });

    my $refund = $patron->account->add_credit({
        amount => 10.00,
        type => 'REFUND',
        interface => 'intranet'
    });

    my $payout = Koha::Account::Line->new({
        borrowernumber => $patron->id,
        amount => 10.00,
        debit_type_code => 'PAYOUT',
        payment_type => 'CASH',
        interface => 'intranet',
        register_id => $register_b->id  # Different register!
    })->store;

    Koha::Account::Offset->new({
        credit_id => $refund->id,
        debit_id => $payout->id,
        type => 'REFUND',
        amount => 10.00
    })->store;

    my $cashup_b = $register_b->add_cashup({
        manager_id => $patron->id,
        amount => -10.00
    });

    # Generate report
    my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new;
    my $report = $plugin->_generate_income_report(
        dt_from_string()->subtract(days => 1),
        dt_from_string(),
        'test.csv'
    );

    ok($report, 'Report generated');

    # Should show both cashups
    like($report, qr/10\.00.*Income/, 'Register A shows income');
    like($report, qr/-10\.00.*REFUND/, 'Register B shows refund');

    # Net should be zero
    my @lines = split /\n/, $report;
    is(scalar @lines, 2, 'Two lines (one per register)');

    $schema->storage->txn_rollback;
};

subtest 'VAT calculation on payouts' => sub {
    plan tests => 3;
    $schema->storage->txn_begin;

    # Create payout with VAT
    my $register = $builder->build_object({ class => 'Koha::Cash::Registers' });
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });

    # £12.00 including 20% VAT = £10.00 + £2.00 VAT
    my $refund = $patron->account->add_credit({
        amount => 12.00,
        type => 'REFUND',
        interface => 'intranet'
    });

    my $payout = Koha::Account::Line->new({
        borrowernumber => $patron->id,
        amount => 12.00,
        debit_type_code => 'PAYOUT',
        payment_type => 'CASH',
        interface => 'intranet',
        register_id => $register->id
    })->store;

    Koha::Account::Offset->new({
        credit_id => $refund->id,
        debit_id => $payout->id,
        type => 'REFUND',
        amount => 12.00
    })->store;

    # Generate report
    my $plugin = Koha::Plugin::Com::OpenFifth::Oracle->new;
    my $report = $plugin->_generate_income_report(
        dt_from_string()->subtract(days => 1),
        dt_from_string(),
        'test.csv'
    );

    ok($report, 'Report generated');

    # Should show negative exclusive and negative VAT
    like($report, qr/-10\.00/, 'Negative exclusive amount (£10)');
    like($report, qr/-2\.00/, 'Negative VAT amount (£2)');

    $schema->storage->txn_rollback;
};
```

### Manual Testing Scenarios

1. **Simple refund same-day:**
   - Make £10 payment at Register A
   - Issue £10 refund at Register A
   - Close cashup
   - Verify report shows both lines, net £0

2. **Cross-register refund:**
   - Make £10 payment at Register A, close cashup
   - Next day: Issue £10 refund at Register B, close cashup
   - Verify: Register A report shows +£10, Register B report shows -£10

3. **Partial refund:**
   - Make £20 payment
   - Issue £5 refund
   - Verify: +£20 and -£5 both appear

4. **VAT verification:**
   - Make £12 payment (£10 + £2 VAT, STANDARD rate)
   - Issue £12 refund
   - Verify: -£10 exclusive, -£2 VAT in report

5. **Multiple transaction types:**
   - CASH payment £10, CARD payment £20
   - CASH refund £5, CARD refund £10
   - Verify: All 4 lines appear with correct signs and payment types

### Oracle Integration Testing

1. **Import test file:**
   - Generate report with mixed income/payouts
   - Attempt Oracle import
   - Verify GL postings are correct

2. **COA validation:**
   - Confirm payout COA codes are valid
   - Check if debits/credits balance correctly

3. **Negative amount handling:**
   - Verify Oracle accepts negative values in Amount and VAT fields
   - Confirm no parsing errors

---

## Recommendations

### Before Meeting Tomorrow

**Questions to ask Oracle team:**

1. ✅ Can Field 5 (D_Line Amount) be negative?
2. ✅ Can Field 16 (D_VAT Amount) be negative?
3. ✅ Should payouts use the same COA codes as income?
4. ✅ Same file or separate payout report?
5. ✅ Should payouts show original transaction type (OVERDUE, LOST) or just "PAYOUT"?
6. ✅ Any GL account setup changes needed?

### Implementation Priority

**If approved, implement in this order:**

1. **Phase 1 (Day 1-2):** Basic payout query and negative amounts
   - Steps 1-6 from code changes
   - Test with simple same-register refunds

2. **Phase 2 (Day 3-4):** Cross-register and original type lookup
   - Steps 7-8 from code changes
   - Test cross-register scenarios

3. **Phase 3 (Day 5):** COA configuration and validation
   - Step 9 from code changes (if needed)
   - Step 10 validation
   - Full integration testing

4. **Phase 4 (Day 6-7):** Oracle integration and production prep
   - Oracle import testing
   - Documentation updates
   - Training materials

### Risk Mitigation

**Rollback plan:**
- Keep existing `_generate_income_report` as `_generate_income_report_legacy`
- Add feature flag: `$self->retrieve_data('include_payouts')`
- If issues arise, disable flag to revert to income-only

**Gradual rollout:**
- Test in UAT with known data
- Run parallel reports (with/without payouts) for 1 week
- Compare totals before going live

### Alternative: Separate Payout Report

**If Oracle prefers separation:**

Add new report type in `_generate_report`:

```perl
sub _generate_report {
    my ( $self, $startdate, $enddate, $type, $filename ) = @_;

    if ( $type eq 'income' ) {
        return $self->_generate_income_report( $startdate, $enddate, $filename );
    }
    elsif ( $type eq 'payouts' ) {
        return $self->_generate_payout_report( $startdate, $enddate, $filename );
    }
    elsif ( $type eq 'invoices' ) {
        return $self->_generate_invoices_report( $startdate, $enddate, $filename );
    }
}

sub _generate_payout_report {
    my ( $self, $startdate, $enddate, $filename ) = @_;

    # Similar structure to income report but:
    # - Only query payout transactions
    # - All amounts positive (Oracle treats as separate GL account)
    # - Different COA codes (configured separately)
    # - Filename: KOHA_SaaS_Payouts_YYYYMMDDHHMMSS.csv
}
```

**Pros:** Cleaner separation, different GL accounts, easier Oracle setup
**Cons:** Two files to manage, more complex reconciliation

---

## Summary

**Current state:** Income report excludes refunds (as per spec)

**Proposed change:** Include PAYOUT transactions as negative amounts for complete cashup balancing

**Key implementation points:**
- Query both credits (income) and debits (payouts) from cashup sessions
- Process payouts with negative amounts and VAT
- Look up original transaction type that was refunded
- Remove positive-only filters
- Add refund indicators to descriptions
- Validate totals match cashup summary

**Decision needed:** Oracle team approval on negative amounts and COA codes

**Effort estimate:** 5-7 days (including testing and Oracle integration)

**Risk level:** Medium (requires spec change, testing critical)

---

## References

- Bug report: `/home/martin/Projects/koha/bug_cross_register_refund.txt`
- Cashup tests: `/home/martin/Projects/koha/t/db_dependent/Koha/Cash/Register/Cashup.t`
- Current implementation: `Koha/Plugin/Com/OpenFifth/Oracle.pm` lines 731-1006
- Income spec: `docs/income/income_report.md`
