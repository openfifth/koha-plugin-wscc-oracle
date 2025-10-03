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

### 3. Database Lookup Functions

#### `_get_debit_type_additional_fields($debit_type_code)`

- Uses `Koha::AdditionalFields->search()` and `Koha::AdditionalFieldValues->search()`
- Retrieves Title Case field names: `VAT Code`, `Subjective`, `Subanalysis`, `Extra Code`
- Implements caching to avoid repeated database queries
- Returns defaults from plugin configuration or hardcoded fallbacks

#### `_get_branch_additional_fields($branch_code)`

- Retrieves Title Case field names: `Objective`, `Income Cost Centre`, `Acquisitions Cost Centre`
- Uses same caching pattern as debit type lookups
- Returns defaults from plugin configuration or hardcoded fallbacks

### 4. Updated Mapping Functions

#### VAT Code Mapping

- `_get_debit_type_vat_code()` now uses database lookup
- Maps database codes to Oracle format:
  - `S` → `STANDARD`
  - `Z` → `ZERO`
  - `E` → `EXEMPT`
  - `O` → `OUT OF SCOPE`

#### Income Field Mapping

Income report fields are now directly accessed from cached additional fields:
- Subjective: Retrieved from `$debit_fields->{'Subjective'}`
- Subanalysis: Retrieved from `$debit_fields->{'Subanalysis'}`
- Objective: Retrieved from `$branch_fields->{'Objective'}`
- Cost Centre: Retrieved from `$branch_fields->{'Income Cost Centre'}`

#### Income Offset Fields (Fixed Values)

Income offset fields use fixed values for all transactions:
- **Objective Offset**: Matches the Objective value
- **Subjective Offset**: Fixed value '810400'
- **Subanalysis Offset**: Fixed value '8201'
- **Cost Centre Offset**: Uses debit type mapping (default: DM87)

### 5. Maintains Backward Compatibility

- All functions provide default values if database lookups fail
- No breaking changes to existing API
- Graceful fallback to sensible defaults

## Database Schema Requirements

**Note**: Field names use Title Case for better display in Koha's admin interface.

### Additional Fields for account_debit_types

```sql
INSERT INTO additional_fields (tablename, name, ...) VALUES
('account_debit_types', 'VAT Code', ...),
('account_debit_types', 'Subjective', ...),
('account_debit_types', 'Subanalysis', ...),
('account_debit_types', 'Extra Code', ...);
```

### Additional Fields for branches

```sql
INSERT INTO additional_fields (tablename, name, ...) VALUES
('branches', 'Objective', ...),
('branches', 'Income Cost Centre', ...),
('branches', 'Acquisitions Cost Centre', ...);
```

### Setup Scripts

SQL scripts are provided in the `scripts/` directory:
- `setup_additional_fields.sql`: Creates field definitions
- `populate_branch_costcenters.sql`: Sets default cost centres
- `populate_branch_objectives.sql`: Sets default objectives
- `migrate_income_code_to_subanalysis.sql`: Migration from legacy field names

## Benefits

1. **Maintainability**: Minimal hard-coded mappings - most values from database
2. **Flexibility**: Easy to update COA codes via database or plugin configuration
3. **Performance**: Caching prevents repeated database queries during report generation
4. **Standards Compliance**: Uses proper Koha Objects and SQL::Abstract syntax
5. **Extensibility**: Easy to add new additional fields as needed
6. **Configurable Defaults**: All default values configurable through plugin interface

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

### Current Implementation

The Oracle finance integration requires valid COA (Chart of Accounts) combinations for successful transaction processing. Invalid combinations result in "COA combination errors" and transaction rejection.

### COA Storage Approach

#### 1. Branch-Level COA Codes

Store branch-specific accounting codes using additional fields on the `branches` table:

**Implemented Additional Fields for branches:**

- `Income Cost Centre` - Cost Centre code for income transactions (e.g., RN03, RQ30)
- `Acquisitions Cost Centre` - Cost Centre code for acquisitions transactions (e.g., RN05)
- `Objective` - Objective code (e.g., CUL074, CUL096)

**Benefits:**

- Library staff can configure per-branch via Admin → Libraries interface
- Supports multi-region library systems with different accounting structures
- Cached by plugin for performance

#### 2. Debit Type COA Mapping

Store transaction-type specific codes using additional fields on `account_debit_types`:

**Implemented Additional Fields for account_debit_types:**

- `VAT Code` - VAT classification (S, Z, E, O)
- `Subjective` - Subjective code (841800, etc.)
- `Subanalysis` - Subanalysis code (8089, etc.)
- `Extra Code` - Additional codes for future requirements

#### 3. Income Report Field Mapping

The income report CSV requires 16 fields per transaction. Current field mapping:

| CSV Field                 | Source             | Implementation                              |
| ------------------------- | ------------------ | ------------------------------------------- |
| D_Cost Centre (8)         | Branch             | `Income Cost Centre` additional field       |
| D_Objective (9)           | Branch             | `Objective` additional field                |
| D_Subjective (10)         | Debit Type         | `Subjective` additional field               |
| D_Subanalysis (11)        | Debit Type         | `Subanalysis` additional field              |
| D_Cost Centre Offset (13) | Debit Type Mapping | `_get_income_costcenter()` method           |
| D_Objective Offset (14)   | Branch             | Matches Objective value                     |
| D_Subjective Offset (15)  | Fixed              | Always '810400'                             |
| D_Subanalysis Offset (16) | Fixed              | Always '8201'                               |

**Note:** Offset fields for income have been simplified based on business requirements - Objective Offset always matches Objective, while Subjective and Subanalysis Offsets use fixed values.

#### 4. Configurable Defaults System

The plugin implements a three-tier default value precedence system:

1. **Database** - Values from additional_field_values (highest priority)
2. **Configuration** - Plugin configuration defaults
3. **Hardcoded** - Fallback values in code (lowest priority)

**Configurable defaults available:**

- Default Income Cost Centre (fallback: RN03)
- Default Branch Objective (fallback: CUL074)
- Default Acquisitions Cost Centre (fallback: RN05)
- Default VAT Code (fallback: O - Out of Scope)
- Default Subjective (fallback: 841800)
- Default Subanalysis (fallback: 8089)

#### 5. Setup and Installation

**SQL Scripts Provided:**

- `scripts/setup_additional_fields.sql` - Creates field definitions
- `scripts/populate_branch_costcenters.sql` - Sets default cost centres
- `scripts/populate_branch_objectives.sql` - Sets default objectives
- `scripts/migrate_income_code_to_subanalysis.sql` - Migration from legacy field names
- `scripts/load_debit_types.sql` - Loads debit types with additional field values

**Installation Workflow:**

1. Run `setup_additional_fields.sql` to create field definitions
2. Run population scripts to set default values for existing branches
3. Configure plugin defaults via Admin → Plugins → Oracle → Configuration
4. Configure per-branch and per-debit-type values via Admin interface

#### 6. Configuration Workflow

1. **Field Setup** - SQL scripts create additional field definitions
2. **Default Population** - Scripts set sensible defaults for all branches
3. **Plugin Configuration** - Admin configures fallback defaults
4. **Per-Entity Configuration** - Library staff configure specific values via:
   - Admin → Libraries → [Library] → Additional Fields (branch codes)
   - Admin → Account Debit Types → [Type] → Additional Fields (transaction codes)
5. **Report Generation** - Plugin dynamically fetches COA codes from database with caching

#### 7. Advantages of This Approach

✅ **Minimal hardcoded mappings** - Most values from database or configuration
✅ **Library staff configurable** - No developer intervention needed for changes
✅ **Three-tier defaults** - Graceful fallback when values not set
✅ **Oracle validation** - Ensures only valid COA combinations are used
✅ **Multi-region support** - Different branches can use different COA structures
✅ **Audit trail** - Changes tracked through Koha's interface
✅ **Performance optimized** - Caching prevents repeated database queries
✅ **Simple offset logic** - Fixed values for income offsets reduce complexity

This comprehensive approach moves COA configuration from static code into Koha's flexible additional fields system, enabling proper financial system integration while maintaining administrative control through both database and plugin configuration.
