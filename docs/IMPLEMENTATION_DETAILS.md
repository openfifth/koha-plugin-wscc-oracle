# Implementation Details

## Overview

Koha plugin that uses Koha::Objects and SQL::Abstract syntax to build reports for output via SFTP to the Oracle finance system via InfoSys.

Utilises the additional fields functionality of Koha where possible to allow dynamic configuration and lookup for VAT and other COA codes and income. Where additional fields support has not yet been added for a particular table, add a mappings table utilising the plugin configuration page and plugin storage.

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

- Retrieves Title Case field names: `Income Objective`, `Income Cost Centre`
- Uses same caching pattern as debit type lookups
- Returns defaults from plugin configuration or hardcoded fallbacks

#### Acquisitions Field Accessor Methods

Since Koha does not support additional fields for the `aqbudgets` table, acquisitions COA mappings are configured at the budget/fund level via plugin configuration:

- `_get_acquisitions_costcenter($fund_code)` - Returns cost center for a fund
- `_get_acquisitions_objective($fund_code)` - Returns objective for a fund
- `_get_acquisitions_subjective($fund_code)` - Returns subjective for a fund
- `_get_acquisitions_subanalysis($fund_code)` - Returns subanalysis for a fund

These methods query the plugin's `fund_field_mappings` configuration and fall back to configurable defaults.

### 4. Updated Mapping Functions

#### VAT Code Mapping

- `_get_debit_type_vat_code()` now uses database lookup
- Maps database codes to Oracle format:
  - `S` → `STANDARD`
  - `Z` → `ZERO`
  - `E` → `EXEMPT`
  - `O` → `OUT OF SCOPE`

#### Income Field Mapping

Income report aggregates by both credit branch (payment location) and debit branch (charge origin).

**Main Fields (from Credit Branch - where payment was taken):**
- Cost Centre: Retrieved from credit branch `$credit_branch_fields->{'Income Cost Centre'}` (default: RN03)
- Objective: Retrieved from credit branch `$credit_branch_fields->{'Income Objective'}` (default: CUL074)

**Transaction Fields (from Debit Type):**
- Subjective: Retrieved from `$debit_fields->{'Subjective'}` (default: 841800)
- Subanalysis: Retrieved from `$debit_fields->{'Subanalysis'}` (default: 8089)

#### Income Offset Fields

Income offset fields use a combination of configurable and branch-specific values:

- **Cost Centre Offset**: Configurable via plugin setting `default_income_costcentre_offset` (default: 'RZ00' - Libraries Income Suspense)
- **Objective Offset**: From debit branch `$debit_branch_fields->{'Income Objective'}` (where charge originated)
- **Subjective Offset**: Configurable via plugin setting `default_income_subjective_offset` (default: '810400')
- **Subanalysis Offset**: Configurable via plugin setting `default_income_subanalysis_offset` (default: '8201')

### 5. Configuration-Driven Design

- All default values stored in plugin configuration (plugin_data table)
- No hardcoded fallback values in code
- Initial defaults set via populate_plugin_defaults.sql setup script
- All defaults configurable through plugin administration interface

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
('branches', 'Income Objective', ...),
('branches', 'Income Cost Centre', ...);
```

**Note**: Acquisitions COA codes (Cost Centre, Objective, Subjective, Subanalysis) are configured at the budget/fund level via the plugin's Fund Field Mappings configuration table, not as branch additional fields.

### Setup Scripts

SQL scripts are provided in the `scripts/` directory:

- `setup_additional_fields.sql`: Creates field definitions
- `populate_branch_costcenters.sql`: Sets default cost centres
- `populate_branch_objectives.sql`: Sets default objectives
- `migrate_income_code_to_subanalysis.sql`: Migration from legacy field names

## Benefits

1. **Maintainability**: Zero hard-coded mappings - all values from database or plugin configuration
2. **Flexibility**: Easy to update COA codes via database or plugin configuration interface
3. **Performance**: Caching prevents repeated database queries during report generation
4. **Standards Compliance**: Uses proper Koha Objects and SQL::Abstract syntax
5. **Extensibility**: Easy to add new additional fields as needed
6. **Fully Configurable**: All default values set via SQL scripts or plugin interface - no code changes needed

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

#### 1. Income Report: Branch-Level COA Codes

Store branch-specific accounting codes using additional fields on the `branches` table:

**Implemented Additional Fields for branches:**

- `Income Cost Centre` - Cost Centre code for income transactions (e.g., RN03, RQ30)
- `Income Objective` - Objective code for income (e.g., CUL001-CUL037, CUL074)

**Benefits:**

- Library staff can configure per-branch via Admin → Libraries interface
- Supports multi-region library systems with different accounting structures
- Cached by plugin for performance

#### 1b. Acquisitions Report: Budget/Fund-Level COA Codes

Store fund-specific accounting codes using plugin configuration (since Koha does not support additional fields for `aqbudgets` table):

**Implemented Fund Field Mappings (via plugin configuration):**

- `Costcenter` - Cost Centre code for acquisitions transactions (e.g., RN05)
- `Objective` - Objective code for the fund (e.g., ZZZ999)
- `Subjective` - Subjective code for the fund (e.g., 503000)
- `Subanalysis` - Subanalysis code for the fund (e.g., 5460)

**Benefits:**

- Per-fund configuration provides granular control over COA mappings
- Configurable through plugin interface without requiring Koha core changes
- Supports different COA codes for different fund types or purposes

#### 2. Debit Type COA Mapping

Store transaction-type specific codes using additional fields on `account_debit_types`:

**Implemented Additional Fields for account_debit_types:**

- `VAT Code` - VAT classification (S, Z, E, O)
- `Subjective` - Subjective code (841800, etc.)
- `Subanalysis` - Subanalysis code (8089, etc.)
- `Extra Code` - Additional codes for future requirements

#### 3. Income Report Field Mapping

The income report CSV requires 16 fields per transaction. Current field mapping:

| CSV Field                 | Source               | Implementation                                      |
| ------------------------- | -------------------- | --------------------------------------------------- |
| D_Cost Centre (6)         | Credit Branch        | `Income Cost Centre` additional field (default: RN03) |
| D_Objective (7)           | Credit Branch        | `Income Objective` additional field (default: CUL074) |
| D_Subjective (8)          | Debit Type           | `Subjective` additional field (default: 841800)     |
| D_Subanalysis (9)         | Debit Type           | `Subanalysis` additional field (default: 8089)      |
| D_Cost Centre Offset (10) | Plugin Configuration | Configurable (default: 'RZ00' - Libraries Income Suspense) |
| D_Objective Offset (11)   | Debit Branch         | `Income Objective` from debit branch                |
| D_Subjective Offset (12)  | Plugin Configuration | Configurable (default: '810400' - Other Income)     |
| D_Subanalysis Offset (13) | Plugin Configuration | Configurable (default: '8201')                      |

**Note:** Income report aggregates by both credit branch (payment location) and debit branch (charge origin). Credit branch provides Cost Centre and Objective for main fields, while debit branch provides Objective for the offset field. This ensures proper accounting of where funds were collected vs. where charges originated.

#### 4. Configurable Defaults System

The plugin implements a two-tier default value precedence system:

1. **Database** - Values from additional_field_values (highest priority)
2. **Plugin Configuration** - Default values from plugin_data table (set via plugin configuration or SQL setup scripts)

**Configurable defaults (set via populate_plugin_defaults.sql or plugin configuration):**

**Income Report Defaults:**
- Default Income Cost Centre (default: RN03)
- Default Branch Objective (default: CUL074)
- Default VAT Code (default: O - Out of Scope)
- Default Subjective (default: 841800)
- Default Subanalysis (default: 8089)
- Default Income Cost Centre Offset (default: RZ00)
- Default Income Subjective Offset (default: 810400)
- Default Income Subanalysis Offset (default: 8201)

**Acquisitions Report Defaults (Fund-Level):**
- Default Acquisitions Cost Center (default: RN05)
- Default Acquisitions Objective (default: ZZZ999)
- Default Acquisitions Subjective (default: 503000)
- Default Acquisitions Subanalysis (default: 5460)

**Vendor Mapping Defaults:**
- Default Supplier Number
- Default Contract Number

#### 5. Setup and Installation

**SQL Scripts Provided:**

- `scripts/setup_additional_fields.sql` - Creates field definitions
- `scripts/populate_branch_costcenters.sql` - Sets branch-specific cost centres and plugin default (RN03)
- `scripts/populate_branch_objectives.sql` - Sets branch-specific objectives and plugin default (CUL074)
- `scripts/populate_plugin_defaults.sql` - Sets all WSCC-specific plugin configuration defaults
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

✅ **No hardcoded mappings** - All values from database or plugin configuration
✅ **Library staff configurable** - No developer intervention needed for changes
✅ **Two-tier defaults** - Database values override plugin configuration defaults
✅ **Oracle validation** - Ensures only valid COA combinations are used
✅ **Multi-region support** - Different branches can use different COA structures
✅ **Audit trail** - Changes tracked through Koha's interface
✅ **Performance optimized** - Caching prevents repeated database queries
✅ **Simple offset logic** - Fixed values for income offsets reduce complexity

This comprehensive approach moves COA configuration from static code into Koha's flexible additional fields system, enabling proper financial system integration while maintaining administrative control through both database and plugin configuration.
