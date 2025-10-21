# Requirements for acquisitions CSV output to Oracle

## Interface

| Field                                       | Value                                             |
| ------------------------------------------- | ------------------------------------------------- |
| File Name (& extension)                     | KOHA_SaaS_APInvoice_DDMMYYYYHH24MISS.csv          |
| Delimiter                                   | "\|", Pipe                                        |
| Quotation Character                         | " ", Double Quote                                 |
| Record Terminator                           | "<CR><LF>", Carriage return followed by line feed |
| Average File Size                           | TBD                                               |
| Average Rows per File                       | N/A                                               |
| Maximum File Size                           | 100 (invoice per day)                             |
| Maximum Rows per File                       | N/A                                               |
| Source System Name                          | KOHA                                              |
| Target System Name                          | Oracle Fusion                                     |
| Interface Frequency                         | Daily                                             |
| Transfer Medium                             | Middleware                                        |
| Inbound / Outbound                          | Inbound                                           |
| Accept / Reject Atomic Transaction Criteria | Standard Oracle functionality will determine.     |

## CSV File Format

The CSV file uses a single header line with two types of records:

### Header Line (15 fields)

```
INVOICE_NUMBER,INVOICE_TOTAL,INVOICE_DATE,SUPPLIER_NUMBER_PROPERTY_KEY,CONTRACT_NUMBER,SHIPMENT_DATE,LINE_AMOUNT,TAX_AMOUNT,TAX_CODE,DESCRIPTION,COST_CENTRE_PROPERTY_KEY,OBJECTIVE,SUBJECTIVE,SUBANALYSIS,LIN_NUM
```

### Record Types

**Header Records**: Contain invoice-level information in the first 6 fields, with remaining 9 fields empty

- Fields 1-6: Invoice data (number, total, date, supplier, contract, shipment date)
- Fields 7-15: Empty (padded)

**Line Records**: Contain line-level information in fields 7-15, with fields 2-6 empty

- Field 1: Invoice number (links to header)
- Fields 2-6: Empty (padded)
- Fields 7-15: Line data (amount, tax, description, distribution codes)

## Oracle CSV Fields

### Header Records (Fields 1-6 populated, 7-15 empty)

**One line per invoice closed**

| Field Position | Field Name                    | Source                      | Sample Data      | Comments                                 |
| -------------- | ----------------------------- | --------------------------- | ---------------- | ---------------------------------------- |
| 1              | INVOICE_NUMBER                | invoice.invoicenumber       | INV-KOHA-RBKC-31 | Invoice number from Koha                 |
| 2              | INVOICE_TOTAL                 | Calculated from order lines | 5200             | Sum of all line amounts for invoice      |
| 3              | INVOICE_DATE                  | invoice.closedate           | 03/21/2025       | Date invoice was closed in Koha          |
| 4              | SUPPLIER_NUMBER_PROPERTY_KEY  | Vendor-based mapping        | 3513             | Mapped from vendor ID to supplier number |
| 5              | CONTRACT_NUMBER               | Vendor-based mapping        | C50335           | Mapped from vendor ID to contract number |
| 6              | SHIPMENT_DATE                 | invoice.shipmentdate        | 03/20/2025       | Date of shipment                         |
| 7-15           | (LINE_AMOUNT through LIN_NUM) | Empty                       | (empty)          | Empty fields for header records          |

#### Koha field mappings

1. Invoice Number = Koha invoicenumber
2. Invoice Total = Sum, in pence, of all line records 'unitprice \* quantity receipted' for the invoice
   _Question_: Should this total be tax inclusive or tax exclusive?
3. Invoice Date = Closed date for invoice in YYYY/MM/DD format
4. Supplier Number = WSCC Local number used to identify suppliers.
   Mapped from vendor ID using the plugin's 'Vendor Field Mappings' configuration.
   All vendors must be mapped - there is no default. Unmapped vendors will have empty supplier numbers.
   See Appendix A for supplier number mappings.
5. Contract Number = WSCC Local number used to identify supplier contracts.
   Mapped from vendor ID using the plugin's 'Vendor Field Mappings' configuration.
   All vendors must be mapped - there is no default. Unmapped vendors will have empty contract numbers.
6. Shipment Date = Shipment date for invoice in YYYY/MM/DD format

### Line Records (Field 1 populated, 2-6 empty, 7-15 populated)

**One line per unit received**

| Field Position | Field Name                            | Source                      | Sample Data                   | Comments                            |
| -------------- | ------------------------------------- | --------------------------- | ----------------------------- | ----------------------------------- |
| 1              | INVOICE_NUMBER                        | invoice.invoicenumber       | INV-KOHA-RBKC-31              | Links line to header record         |
| 2-6            | (INVOICE_TOTAL through SHIPMENT_DATE) | Empty                       | (empty)                       | Empty fields for line records       |
| 7              | LINE_AMOUNT                           | line.unitprice \* quantity  | 4000                          | Line amount in pence                |
| 8              | TAX_AMOUNT                            | line.tax_value_on_receiving | 0                             | Tax amount in pence                 |
| 9              | TAX_CODE                              | Derived from tax rate       | ZERO / STANDARD               | ZERO (0%), STANDARD (20%)           |
| 10             | DESCRIPTION                           | biblio.title or default     | Invoice for educational books | Item description                    |
| 11             | COST_CENTRE_PROPERTY_KEY              | Fund-based mapping          | RN05                          | Mapped from fund code (default: RN05) |
| 12             | OBJECTIVE                             | Fund-based mapping          | ZZZ999                        | Mapped from fund code (default: ZZZ999) |
| 13             | SUBJECTIVE                            | Fund-based mapping          | 503000                        | Mapped from fund code (default: 503000) |
| 14             | SUBANALYSIS                           | Fund-based mapping          | 5460                          | Mapped from fund code (default: 5460) |
| 15             | LIN_NUM                               | Line sequence               | 1                             | Line number within invoice          |

#### Koha Field mappings

1. Invoice Number = Koha invoicenumber (Will match Header record for invoice)

7) Line Amount = Unit price
   _Question_: Should this amount be tax inclusive or tax exclusive

8. Tax Amount = Tax value on receipt
9. Tax Code = Mapped from 'Tax rate on receipt', 20% = 'STANDARD', 0% = 'ZERO', anything else = 'UNMAPPED'
10. Description = Mapped to 'Biblio title' unless there is no biblio attached, 'Library Materials' otherwise
11. Cost Centre = Mapped from fund code using Plugin's 'Fund Field Mappings' configuration table, with configurable default (default: RN05)
12. Objective = Mapped from fund code using Plugin's 'Fund Field Mappings' configuration table, with configurable default (default: ZZZ999)
13. Subjective = Mapped from fund code using Plugin's 'Fund Field Mappings' configuration table, with configurable default (default: 503000)
14. Subanalysis = Mapped from fund code using Plugin's 'Fund Field Mappings' configuration table, with configurable default (default: 5460)
15. Line number = Running count of lines in the invoice indexed from '1'.

**Note on Fund-Level Mappings:** All COA fields (Cost Centre, Objective, Subjective, Subanalysis) are configured at the budget/fund level via the plugin's configuration interface under "Fund Field Mappings". This allows different funds to have different accounting codes as required by Oracle Finance. If no specific mapping is configured for a fund, the system uses the configurable defaults.

## Error handling, Archiving and Recovery

Oracle will send emails to the business when parsing errors are encountered.

No specific requirements at the Koha side for archival or audit trail.

## Appendix A - Vendor Supplier Numbers

| Supplier No | Vendor name                   |
| ----------- | ----------------------------- |
| 57028       | Askews                        |
| 6565        | Ulverscroft                   |
| 101563      | BOLINDA DIGITAL LTD           |
| 109562      | DIGITAL LIBRARY LTD           |
| 90134       | CENGAGE LEARNING EMEA LTD     |
| 4614        | OXFORD UNIVERSITY PRESS       |
| 52423       | BIBLIOGRAPHICAL DATA SERVICES |
| 97296       | iSUBSCRiBE LTD                |
| 46075       | ENCYCLOPAEDIA BRITANNICA      |
| 14673       | Nielsen                       |
| 98804       | COBWEB INFORMATION LTD        |
| 102661      | JCS ONLINE RESOURCES LIMITED  |
| 105721      | NEWS UK &amp; IRELAND LTD     |
| 98865       | WELL INFORMED LIMITED         |
| 43401       | OCLC (UK) LTD                 |
| 97663       | BOOKS ASIA                    |
| 113279      | MOODYS ANALYTICS UK LIMITED   |
| 61107       | LATITUDE MAPPING LTD          |
| 41600       | BAG BOOKS                     |
| 55571       | FOYLES                        |
| 114305      | IBISWORLD LTD                 |
| 888         | THE BRITISH LIBRARY           |
| 51470       | ASCEL                         |
| 97068       | CALIBRE AUDIO LIBRARY         |
| 109358      | OVERDRIVE GLOBAL LIMITED      |
| 754         | BOOK PROTECTORS &amp; CO      |
| 46700       | WEST SUSSEX ARCHIVE SOCIETY   |
| 6146        | SUSSEX ARCHAEOLOGICAL SOCIETY |
| 6183        | SUSSEX ORNITHOLOGICAL SOCIETY |
