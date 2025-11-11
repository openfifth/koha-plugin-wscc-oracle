# Acquisitions Report Field Mapping Guide

This document explains how Oracle Chart of Accounts (COA) fields are populated in acquisitions (invoices) reports, organized by the conceptual purpose of each field.

## Key Concepts

When processing a library acquisitions invoice, there are three important pieces of information:

1. **What you're buying** - The materials being purchased (books, journals, etc.)
2. **Which budget is paying for it** - The fund/budget that the purchase is charged to
3. **Who you're buying from** - The vendor/supplier providing the materials

## Report Structure

Acquisitions reports use a **header/line record format**:

- **Header record**: One per invoice, contains invoice-level information (invoice number, total, supplier, contract)
- **Line records**: One per order line (or per item if quantity > 1), contains item-level information and COA codes

## Field Mapping by Purpose

### Invoice-Level Fields (Header Record Only)

These fields identify the invoice and the vendor.

| Field | Source | Purpose |
|-------|--------|---------|
| **Invoice Number** | Invoice record | Unique identifier for this invoice |
| **Invoice Total** | Sum of all line amounts | Total value of the entire invoice |
| **Invoice Date** | Invoice close date | When the invoice was processed/closed |
| **Shipment Date** | Invoice shipment date | When materials were received |
| **Supplier Number** | Vendor mappings (required) | Oracle supplier account number |
| **Contract Number** | Vendor mappings (required) | Oracle contract reference |

**Important:** Supplier and Contract numbers must be configured in the plugin's vendor mappings table. There are no defaults - unmapped vendors will result in empty fields.

### Line-Level Fields: "WHAT you're buying"

These fields describe the materials being purchased.

| Field | Source | Purpose |
|-------|--------|---------|
| **Description** | Biblio title | What item is being purchased (defaults to "Library Materials") |
| **Line Amount** | Order line unit price | Cost per item (positive value) |
| **Tax Amount** | Order line tax value | VAT/tax amount per item (positive value) |
| **Tax Code** | Calculated from tax rate | Oracle tax code (STANDARD=20%, ZERO=0%) |
| **Line Number** | Sequential | Line sequence within this invoice |

### Line-Level Fields: "WHICH BUDGET is paying" (COA Codes)

These Chart of Accounts fields are **ALL determined by the fund/budget code** on the order line. Unlike income reports (which use branches), acquisitions use funds to determine accounting codes.

| Field | Priority 1 (Specific) | Priority 2 (Default) | Priority 3 (Fallback) | Purpose |
|-------|----------------------|---------------------|----------------------|---------|
| **Cost Centre** | Fund mapping: costcenter | Plugin config | Hardcoded (RN05) | Which department is spending this money |
| **Objective** | Fund mapping: objective | Plugin config | Hardcoded (ZZZ999) | What program/objective this spending supports |
| **Subjective** | Fund mapping: subjective | Plugin config | Hardcoded (503000) | Type of expenditure (books, journals, etc.) |
| **Subanalysis** | Fund mapping: subanalysis | Plugin config | Hardcoded (5460) | Detailed breakdown of expenditure type |

## Fund Field Mappings Configuration

Since Koha doesn't support additional fields for the `aqbudgets` table, acquisitions COA mappings are configured directly in the plugin via the **Fund Field Mappings** configuration table.

For each fund code, you can specify:
- `costcenter`: Cost centre for this fund
- `objective`: Objective code for this fund
- `subjective`: Subjective code for this fund
- `subanalysis`: Subanalysis code for this fund

**Resolution order for each COA field:**
1. Specific fund mapping (if configured)
2. Plugin default configuration
3. Hardcoded fallback

## Vendor Mappings Configuration

Each vendor in Koha must be mapped to Oracle supplier and contract numbers:

- **Vendor to Supplier Number**: Maps Koha vendor ID to Oracle supplier account
- **Vendor to Contract Number**: Maps Koha vendor ID to Oracle contract reference

**There are no defaults** - these must be configured for all vendors you purchase from.

## Real-World Example

**Scenario:** Chichester Library orders 2 copies of "The History of Sussex" from vendor "Book Supplier Ltd" for £25.00 each (plus 20% VAT), charged to the "Local Studies" fund.

**Invoice details:**
- Invoice Number: INV-2024-001
- Invoice Total: £60.00 (2 × £25.00 × 1.20)
- Vendor: Book Supplier Ltd (ID: 123)
- Fund: LOCAL_STUDIES

**Header record contains:**
- Invoice Number: INV-2024-001
- Invoice Total: 60.00
- Invoice Date: 15-JAN-25
- Supplier Number: From vendor mapping for vendor ID 123 (e.g., "SUP-001")
- Contract Number: From vendor mapping for vendor ID 123 (e.g., "CONTRACT-2024")
- Shipment Date: 14-JAN-25

**Line records (2 lines, one per copy):**

Each line contains:
- Invoice Number: INV-2024-001
- Line Amount: 25.00
- Tax Amount: 5.00
- Tax Code: STANDARD
- Description: The History of Sussex
- Cost Centre: From LOCAL_STUDIES fund mapping (or plugin default)
- Objective: From LOCAL_STUDIES fund mapping (or plugin default)
- Subjective: From LOCAL_STUDIES fund mapping (or plugin default)
- Subanalysis: From LOCAL_STUDIES fund mapping (or plugin default)
- Line Number: 1 (then 2)

## Key Differences from Income Reports

| Aspect | Income Reports | Acquisitions Reports |
|--------|---------------|---------------------|
| **Primary driver** | Debit type + Branch | Fund/Budget code |
| **Override levels** | Debit type can override branch | Only fund level (no branch concept) |
| **Additional fields** | Uses Koha additional fields system | Uses plugin configuration table |
| **Aggregation** | Aggregated by type/branch/date | Individual line items per invoice |
| **Double-entry** | Includes offset fields | No offset fields needed |

## When to Configure Fund Mappings

Configure fund-specific mappings when:

- Different budgets need to charge to different cost centres or objectives
- You have specialized funds for specific programs or departments
- Grant-funded purchases require specific COA codes
- Financial reporting requires fund-level tracking

Use plugin defaults when:

- All acquisitions use the same basic COA structure
- You want simplified maintenance (one setting for all funds)
- Most funds share common accounting treatment

## Configuration Priority Summary

**For all COA fields** (Cost Centre, Objective, Subjective, Subanalysis):
1. Fund-specific mapping in Fund Field Mappings table
2. Plugin configuration default
3. Hardcoded fallback

**For vendor fields** (Supplier Number, Contract Number):
1. Vendor mapping (required - no defaults)

**For tax codes**:
- Calculated automatically from order line tax rate (20% = STANDARD, 0% = ZERO)
