# Implementation Details

## Overview

Koha plugin that uses Koha::Objects and SQL::Abstract syntax to build reports for output via SFTP to the Oracle finance system via InfoSys.

Utilises the additional fields functionality of Koha to allow dynamic configuration and lookup for VAT and other COA codes and income.

## Key Requirements

### 1. Use Koha Objects and SQL::Abstract

```perl
use Koha::AdditionalFields;
use Koha::AdditionalFieldValues;
```

### 2. Implemented Caching System for frequently queried tables

- Added `debit_type_fields_cache` for debit type additional fields
- Added `branch_fields_cache` for branch additional fields
- Both caches initialized in constructor for performance optimization

### 3. New Database Lookup Functions

#### `_get_debit_type_additional_fields($debit_type_code)`

- Uses `Koha::AdditionalFields->search()` and `Koha::AdditionalFieldValues->search()`
- Retrieves `vat_code`, `income_code`, and `extra_code` for any debit type
- Implements caching to avoid repeated database queries
- Provides sensible defaults if fields aren't found

#### `_get_branch_additional_fields($branch_code)`

- Retrieves `objective` and `cost_center` for library branches
- Uses same caching pattern as debit type lookups
- Supports future branch-specific financial mappings

### 4. Updated Mapping Functions

#### VAT Code Mapping

- `_get_debit_type_vat_code()` now uses database lookup
- Maps database codes to Oracle format:
  - `S` → `STANDARD`
  - `Z` → `ZERO`
  - `E` → `EXEMPT`
  - `O` → `OUT OF SCOPE`

#### Income Code (Subanalysis) Mapping

- `_get_income_subanalysis()` now uses `income_code` from additional fields
- Replaces hard-coded mapping with dynamic database lookup

#### Library Objective Mapping

- `_get_income_objective()` now uses branch additional fields
- Supports dynamic library objective codes from database

### 5. Maintains Backward Compatibility

- All functions provide default values if database lookups fail
- No breaking changes to existing API
- Graceful fallback to sensible defaults

## Database Schema Requirements

### Additional Fields for account_debit_types

```sql
INSERT INTO additional_fields (tablename, name, ...) VALUES
('account_debit_types', 'extra_code', ...),
('account_debit_types', 'income_code', ...),
('account_debit_types', 'vat_code', ...);
```

### Additional Fields for branches (future)

```sql
INSERT INTO additional_fields (tablename, name, ...) VALUES
('branches', 'objective', ...),
('branches', 'cost_center', ...);
```

## Benefits

1. **Maintainability**: No more hard-coded mappings in code
2. **Flexibility**: Easy to update VAT codes and income codes via database
3. **Performance**: Caching prevents repeated database queries during report generation
4. **Standards Compliance**: Uses proper Koha Objects and SQL::Abstract syntax
5. **Extensibility**: Easy to add new additional fields as needed

## Testing

The implementation has been validated for:

- ✅ Proper Koha Objects usage
- ✅ SQL::Abstract compliance (no raw SQL)
- ✅ Caching implementation
- ✅ Error handling with defaults
- ✅ Backward compatibility

## Usage in Income Report

The income report now:

1. Queries `additional_field_values` for each debit type encountered
2. Maps database VAT codes to Oracle-compatible format
3. Uses dynamic income codes instead of hard-coded ones
4. Caches results for performance during batch processing
5. Supports branch-specific objectives and cost centers

This change makes the system much more maintainable and allows financial mappings to be updated through the database rather than requiring code changes.

## Chart of Accounts (COA) Storage Strategy

### Current Problem

The Oracle finance integration requires valid COA (Chart of Accounts) combinations for successful transaction processing. Invalid combinations result in "COA combination errors" and transaction rejection.

### COA Storage Approach

#### 1. Branch-Level COA Codes

Store branch-specific accounting codes using additional fields on the `branches` table:

**Required Additional Fields for branches:**

- `cost_center` - Cost Centre code (e.g., RN03, RQ30)
- `objective` - Objective code (e.g., CUL074, CUL096)

**Benefits:**

- Library staff can configure per-branch via Admin → Libraries interface
- Supports multi-region library systems with different accounting structures
- Cached by plugin for performance

#### 2. Debit Type COA Mapping

Store transaction-type specific codes using additional fields on `account_debit_types`:

**Required Additional Fields for account_debit_types:**

- `subjective_code` - Subjective code (841800, etc.)
- `subanalysis_code` - Subanalysis code (8089, etc.)
- `vat_code` - VAT classification (S, Z, E, O) - _already implemented_
- `offset_cost_center` - Offset cost centre (ZZ99, etc.)
- `offset_objective` - Offset objective (ZZZ999, etc.)
- `offset_subjective` - Offset subjective (102832, etc.)
- `offset_subanalysis` - Offset subanalysis (1000, etc.)

#### 3. Income Report Field Mapping

The income report CSV requires 16 fields per transaction. Mapping to additional fields:

| CSV Field                 | Source     | Additional Field     |
| ------------------------- | ---------- | -------------------- |
| D_Cost Centre (8)         | Branch     | `cost_center`        |
| D_Objective (9)           | Branch     | `objective`          |
| D_Subjective (10)         | Debit Type | `subjective_code`    |
| D_Subanalysis (11)        | Debit Type | `subanalysis_code`   |
| D_Cost Centre Offset (13) | Debit Type | `offset_cost_center` |
| D_Objective Offset (14)   | Debit Type | `offset_objective`   |
| D_Subjective Offset (15)  | Debit Type | `offset_subjective`  |
| D_Subanalysis Offset (16) | Debit Type | `offset_subanalysis` |

#### 4. Plugin Installation Setup

The plugin's `install()` method should automatically create required additional fields if they don't exist:

```perl
sub install {
    my ($self) = @_;

    # Create branch additional fields
    $self->_ensure_additional_field('branches', 'cost_center', 'Cost Centre Code');
    $self->_ensure_additional_field('branches', 'objective', 'Objective Code');
    $self->_ensure_additional_field('branches', 'coa_region', 'COA Region Identifier');

    # Create debit type additional fields
    $self->_ensure_additional_field('account_debit_types', 'subjective_code', 'Subjective Code');
    $self->_ensure_additional_field('account_debit_types', 'subanalysis_code', 'Subanalysis Code');
    $self->_ensure_additional_field('account_debit_types', 'offset_cost_center', 'Offset Cost Centre');
    $self->_ensure_additional_field('account_debit_types', 'offset_objective', 'Offset Objective');
    $self->_ensure_additional_field('account_debit_types', 'offset_subjective', 'Offset Subjective');
    $self->_ensure_additional_field('account_debit_types', 'offset_subanalysis', 'Offset Subanalysis');

    return 1;
}
```

#### 5. Required Code Updates

**Functions to Update:**

- `_get_income_costcenter()` - Read from debit type `offset_cost_center` field
- `_get_objective_offset()` - Read from debit type `offset_objective` field
- `_get_subjective_offset()` - Read from debit type `offset_subjective` field
- `_get_subanalysis_offset()` - Read from debit type `offset_subanalysis` field
- `_get_income_subjective()` - Read from debit type `subjective_code` field
- `_get_income_subanalysis()` - Read from debit type `subanalysis_code` field

Replace hardcoded mappings with database lookups using the existing `_get_debit_type_additional_fields()` pattern.

#### 6. Configuration Workflow

1. **Plugin Installation** - Automatically creates required additional fields
2. **Admin Configuration** - Library staff configure fields via:
   - Admin → Libraries → [Library] → Additional Fields (branch codes)
   - Admin → Account Debit Types → [Type] → Additional Fields (transaction codes)
3. **Report Generation** - Plugin dynamically fetches COA codes from database

#### 7. Advantages of This Approach

✅ **No hardcoded mappings** - All COA codes stored in database  
✅ **Library staff configurable** - No developer intervention needed for changes  
✅ **Oracle validation** - Ensures only valid COA combinations are used  
✅ **Multi-region support** - Different branches can use different COA structures  
✅ **Audit trail** - Changes tracked through Koha's interface  
✅ **Performance optimized** - Caching prevents repeated database queries  
✅ **Future extensible** - New COA fields can be added without code changes

This comprehensive approach moves COA configuration from static code into Koha's flexible additional fields system, enabling proper financial system integration while maintaining administrative control.
