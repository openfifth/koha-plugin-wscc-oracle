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

| Field Position | Field Name                     | Source                          | Sample Data        | Comments                                               |
| -------------- | ------------------------------ | ------------------------------- | ------------------ | ------------------------------------------------------ |
| 1              | INVOICE_NUMBER                 | invoice.invoicenumber           | INV-KOHA-RBKC-31   | Invoice number from Koha                              |
| 2              | INVOICE_TOTAL                  | Calculated from order lines     | 5200               | Sum of all line amounts for invoice                    |
| 3              | INVOICE_DATE                   | invoice.closedate               | 03/21/2025         | Date invoice was closed in Koha                       |
| 4              | SUPPLIER_NUMBER_PROPERTY_KEY   | Fund-based mapping              | 3513               | Mapped from fund code to supplier number              |
| 5              | CONTRACT_NUMBER                | Constant                        | C50335             | Fixed contract number                                  |
| 6              | SHIPMENT_DATE                  | invoice.shipmentdate            | 03/20/2025         | Date of shipment                                       |
| 7-15           | (LINE_AMOUNT through LIN_NUM)  | Empty                           | (empty)            | Empty fields for header records                        |

### Line Records (Field 1 populated, 2-6 empty, 7-15 populated)

| Field Position | Field Name                     | Source                          | Sample Data                    | Comments                                               |
| -------------- | ------------------------------ | ------------------------------- | ------------------------------ | ------------------------------------------------------ |
| 1              | INVOICE_NUMBER                 | invoice.invoicenumber           | INV-KOHA-RBKC-31               | Links line to header record                           |
| 2-6            | (INVOICE_TOTAL through SHIPMENT_DATE) | Empty                   | (empty)                        | Empty fields for line records                         |
| 7              | LINE_AMOUNT                    | line.unitprice * quantity       | 4000                           | Line amount in pence                                   |
| 8              | TAX_AMOUNT                     | line.tax_value_on_receiving     | 0                              | Tax amount in pence                                    |
| 9              | TAX_CODE                       | Derived from tax rate           | ZERO / STANDARD                | ZERO (0%), STANDARD (20%)                             |
| 10             | DESCRIPTION                    | biblio.title or default         | Invoice for educational books  | Item description                                       |
| 11             | COST_CENTRE_PROPERTY_KEY       | Constant                        | RN05                           | Cost center for all acquisitions                      |
| 12             | OBJECTIVE                      | Constant                        | ZZZ999                         | Objective for all acquisitions                        |
| 13             | SUBJECTIVE                     | Constant                        | 503000                         | Subjective for all acquisitions                       |
| 14             | SUBANALYSIS                    | Fund-based mapping              | 5460                           | Mapped from fund code                                  |
| 15             | LIN_NUM                        | Line sequence                   | 1                              | Line number within invoice                             |

## Koha Field mappings

## Additional notes

- For accounts payable, for each item purchased we must set Cost Center, Objective, Subjective and SubAnalysis.
  - Cost Center = RN05
  - Objective = ZZZ999
  - Subjective = 503000
  - SubAnalysis depends on the type of item purchased

## Error handling, Archiving and Recovery

Oracle will send emails to the business when parsing errors are encountered.

No specific requirements at the Koha side for archival or audit trail.
