# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Koha plugin for West Sussex County Council (WSCC) that integrates with Oracle Finance systems. The plugin generates daily financial reports in CSV format for both income (library transactions) and outgoing (acquisitions) data, supporting SFTP upload or local file output.

## Development Commands

### Version Management
```bash
npm run version:patch    # Increment patch version
npm run version:minor    # Increment minor version
npm run version:major    # Increment major version
```

### Release Management
```bash
npm run release:patch    # Bump version, commit, tag, and push
npm run release:minor    # Same for minor version
npm run release:major    # Same for major version
```

### Manual Release
```bash
./release_kpz.sh         # Create .kpz plugin file and release
```

### Testing
```bash
prove t/                 # Run all tests
prove t/00-load.t        # Run specific test file
```

The CI system runs tests against multiple Koha versions (main, stable, oldstable) using koha-testing-docker.

## Architecture

### Plugin Structure
- **Main Plugin**: `Koha/Plugin/Com/OpenFifth/Oracle.pm` - Core plugin class extending `Koha::Plugins::Base`
- **Templates**: `Koha/Plugin/Com/OpenFifth/Oracle/*.tt` - Template Toolkit files for UI
- **Tests**: `t/*.t` - Perl test files
- **Documentation**: `docs/` - Detailed technical specifications

### Core Components

#### Report Generation
The plugin generates two types of financial reports:

1. **Income Report** (`_generate_income_report`):
   - Processes library transactions (fines, fees, payments)
   - Output: `KOHA_SaaS_TaxableJournal_YYYYMMDDHHMMSS.csv`
   - 16 fields including VAT calculations and Chart of Accounts (COA) mappings

2. **Invoices Report** (`_generate_invoices_report`):
   - Processes acquisitions invoices
   - Output: `KOHA_SaaS_APInvoice_DDMMYYYYHH24MISS.csv`
   - Header/line record format for Oracle import

#### Key Methods
- `cronjob_nightly`: Automated daily report generation and upload
- `report_step1`/`report_step2`: Manual report generation UI
- `sftp_upload`: SFTP file transfer functionality
- `configure`: Plugin configuration interface

### Database Integration

#### Modern Koha Objects Pattern
The plugin uses proper Koha Objects and SQL::Abstract syntax:
```perl
use Koha::AdditionalFields;
use Koha::AdditionalFieldValues;
use Koha::Account::Lines;
use Koha::Account::Offsets;
```

#### Additional Fields System
Critical to functionality - the plugin relies on Koha's additional fields for dynamic configuration:

**For `account_debit_types` table**:
- `vat_code`: VAT classification (S=Standard, Z=Zero, E=Exempt, O=Out of Scope)
- `income_code`: Income/subanalysis mapping
- `extra_code`: Additional codes as needed
- Future COA fields: `subjective_code`, `subanalysis_code`, offset fields

**For `branches` table**:
- `objective`: Library-specific objective codes (CUL001, CUL002, etc.)
- `cost_center`: Cost center codes (typically RN03)

#### Performance Optimization
- Implements caching system for additional fields lookups
- `debit_type_fields_cache` and `branch_fields_cache` initialized in constructor
- Prevents repeated database queries during report generation

## Configuration

### Plugin Settings
- SFTP server configuration for automated uploads
- Scheduled days for automated report generation
- Output mode (upload vs local file)

### Chart of Accounts (COA) Requirements
Oracle integration requires valid COA code combinations. The plugin maps:
- Branch location → Cost Centre + Objective codes
- Transaction type → Subjective + Subanalysis codes
- VAT calculations → Oracle-compatible VAT codes

Invalid combinations cause "COA combination errors" in Oracle.

## Development Guidelines

### When Adding New Features
1. Use Koha Objects rather than raw SQL
2. Implement caching for frequently accessed data
3. Add corresponding additional field definitions if needed
4. Update both income and outgoing report logic if financial mappings change
5. Add tests in `t/` directory following existing patterns

### Financial Field Mapping
- Income transactions: 16-field CSV format with specific Oracle requirements
- Acquisitions: Header/line record format with supplier and fund mappings
- VAT calculations: Must convert between Koha and Oracle VAT code formats
- All monetary amounts in pence (not pounds)

### Template Development
- Use Template Toolkit (.tt files)
- Separate templates for HTML vs text output
- Configuration and report generation have different UI flows

## Dependencies

### Perl Modules
- Modern::Perl
- Koha::Plugins::Base (parent class)
- Koha::DateUtils, Koha::Number::Price
- Koha::File::Transports (SFTP functionality)
- Koha Objects (Account::Lines, AdditionalFields, etc.)
- Text::CSV, Mojo::JSON

### External Systems
- Oracle Finance (target system for CSV imports)
- SFTP servers for file transfer
- InfoSys middleware (mentioned in docs)

## File Locations

### Plugin Files
- Main: `Koha/Plugin/Com/OpenFifth/Oracle.pm`
- Templates: `Koha/Plugin/Com/OpenFifth/Oracle/`
- Output: `Koha/Plugin/Com/OpenFifth/Oracle/output/` (when using local file mode)

### Version Synchronization
Version must be updated in both:
- `package.json` (authoritative)
- `Koha/Plugin/Com/OpenFifth/Oracle.pm` (plugin metadata)

Use npm scripts to maintain synchronization automatically.