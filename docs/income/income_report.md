# Requirements for cash management CSV output to Oracle

## Interface

| Field                                       | Value                                             |
| :------------------------------------------ | :------------------------------------------------ |
| File Name (& extension)                     | KOHA_SaaS_TaxableJournal_YYYYMMDDHHMMSS.csv       |
| Delimiter                                   | "\|", pipe                                        |
| Quotation Character                         | " ", Double Quote                                 |
| Record Terminator                           | "<CR><LF>", Corriage return followed by line feed |
| Average File Size                           | 300                                               |
| Average Rows per File                       | N/A                                               |
| Maximum File Size                           | N/A                                               |
| Maximum Rows per File                       | N/A                                               |
| Source System Name                          | KOHA                                              |
| Target System Name                          | Oracle Fusion                                     |
| Interface Frequency                         | Daily                                             |
| Transfer Medium                             | Batch File                                        |
| Inbound / Outbound                          | Inbound                                           |
| Accept / Reject Atomic Transaction Criteria | Standard Oracle functionality will determine.     |

## CSV File Format

The CSV file does not include a header line and there is only one type of record.

## Oracle CSV Fields

| Field No. | Source Field               | Type   | Description                                         | Sample Data                       |
| --------: | :------------------------- | :----- | :-------------------------------------------------- | :-------------------------------- |
|         1 | D_Document Document Number | TEXT   | Any Reference Number from O5TH                      | AGG000001                         |
|         2 | D_Document Description     | TEXT   | `<date>:<register_id>(<cashup_id>)-<branch>`        | Feb11/26/1(42)-CN                 |
|         3 | D_Document Date            | TEXT   | Accounting Date                                     | 2025/03/21                        |
|         4 | D_Line Number              | TEXT   | Line Number                                         | 1                                 |
|         5 | D_Line Amount              | AMOUNT | Amount (positive for income, negative for payouts)  | 450 or -450                       |
|         6 | D_Cost Centre              | TEXT   | Cost Centre (Credit branch 'Income Cost Centre')    | RN03                              |
|         7 | D_Objective                | TEXT   | Objective (Credit branch 'Income Objective')        | CUL001                            |
|         8 | D_Subjective               | TEXT   | Subjective (Debit type 'Subjective')                | 841800                            |
|         9 | D_Subanalysis              | TEXT   | Subanalysis (Debit type 'Subanalysis')              | 5435                              |
|        10 | D_Cost Centre Offset       | TEXT   | Cost Centre (Plugin configurable)                   | RZ00                              |
|        11 | D_Objective Offset         | TEXT   | Objective (Debit branch 'Income Objective')         | CUL001                            |
|        12 | D_Subjective Offset        | TEXT   | Subjective (Plugin configurable)                    | 810400                            |
|        13 | D_Subanalysis Offset       | TEXT   | Subanalysis (Plugin configurable)                   | 8201                              |
|        14 | D_Line Description         | TEXT   | Description ("REFUND" prefix for payouts)           | CASH OVERDUE or REFUND CASH LOST  |
|        15 | D_VAT Code                 | TEXT   | VAT Code                                            | STD                               |
|        16 | D_VAT Amount               | AMOUNT | VAT Amount (positive for income, negative for refunds) | 90 or -90                       |

## Koha Field mappings

Income report fields are resolved using a two-tier precedence system:

1. **Specific value** from Koha object fields and additional fields (highest priority)
2. **Plugin configured default** from plugin settings

### Main Fields (from Credit Branch - where payment was taken)

- **Cost Centre**: From credit branch `Income Cost Centre` additional field (default: RN03)
- **Objective**: From credit branch `Income Objective` additional field (default: CUL074)

### Transaction Fields (from Debit Type)

- **Subjective**: From debit type `Subjective` additional field (default: 841800)
- **Subanalysis**: From debit type `Subanalysis` additional field (default: 8089)
- **VAT Code**: From debit type `VAT Code` additional field (default: O - Out of Scope)

### Offset Fields

- **Cost Centre Offset**: Configurable at plugin level (default: `RZ00` {Libraries Income Suspense})
- **Objective Offset**: From debit branch `Income Objective` additional field (where charge originated)
- **Subjective Offset**: Configurable at plugin level (default: 810400 - Other Income)
- **Subanalysis Offset**: Configurable at plugin level (default: 8201)

## Payout (Refund) Handling

**As of 2026-02-11, the report now includes PAYOUT transactions (refunds) with negative amounts.**

### How Payouts Work

When a refund is issued in Koha:
1. A **REFUND credit** is created to reverse the original charge
2. A **PAYOUT debit** is created at the register where the refund is issued (cash leaving the till)
3. These are linked via account offsets

### Payout Representation in Report

- **Amount (Field 5)**: Negative value (e.g., -£10.00)
- **VAT Amount (Field 16)**: Negative value (e.g., -£2.00)
- **Document Description (Field 2)**: Ends with "LIB-REFUND" instead of "LIB-Income"
- **Line Description (Field 14)**: Prefixed with "REFUND" (e.g., "REFUND CASH OVERDUE")
- **Debit Type**: Shows the **original transaction type** that was refunded (e.g., OVERDUE, LOST, PURCHASE)

### Cross-Register Refunds

When a payment is made at Register A but refunded at Register B:
- Register A's cashup shows: +£10.00 (original income)
- Register B's cashup shows: -£10.00 (payout)
- Both appear in their respective cashup sessions
- This maintains accurate per-register cash accounting

### Same COA Codes

Payouts use the **same Chart of Accounts codes** as the original income transactions:
- Cost Centre, Objective, Subjective, Subanalysis resolved from the original debit type
- No separate GL accounts needed for refunds

### Report Balancing

The sum of all amounts (income + payouts) in the report equals the net cashup total:
- Example: £100 income - £20 payouts = £80 net

## Additional notes

- Koha should post the sum of transactions per library per debit type per receipt type (configurable as payment type in Koha) per day.
- Main COA fields use credit branch for Cost Centre and Objective
- Offset Objective uses debit branch (where the original charge was created)
- For Objectives there is a mapping
  - These are stored as an `Income Objective` additional field for the branches table
  - The mappings are detailed in Appendix B
- For all locations (branches) the default "Cost centre" is 'RN03'
  - This is stored as an `Income Cost Centre` additional field for the branches table
  - Configurable through plugin configuration or per-branch via additional fields
- The subjective, subanalysis and VAT code are derived from the debit type
  - Stored as `Subjective`, `Subanalysis`, and `VAT Code` additional fields for the account_debit_types table
  - Configurable through plugin configuration with sensible defaults
- Expected VAT Codes are STANDARD, ZERO, OUT OF SCOPE
- Payment types will be defined as:

  | CODE          | Description                                                      |
  | ------------- | ---------------------------------------------------------------- |
  | CASH          | includes both physical cash and cheques                          |
  | CARD KIOSK    | debit or credit card payment to a kiosk                          |
  | CARD TERMINAL | debit or credit card payment to a handheld CHIP and PIN terminal |
  | PAY360        | payment using online payments system, Pay360                     |

- The descriptions for lines will be:
  - Income: Payment type followed by debit type (e.g., "CASH OVERDUE")
  - Payouts: "REFUND" prefix, then payment type and original debit type (e.g., "REFUND CASH OVERDUE")
- Pay360 payments should be EXCLUDED from this report

## Error handling, Archiving and Recovery

Oracle will send emails to the business when parsing errors are encountered.

No specific requirements at the Koha side for archival or audit trail.

---

## Appendix A – Library Cost Centres

| Code     | Description                                               |
| -------- | --------------------------------------------------------- |
| RQ30     | Library Projects                                          |
| RQ42     | Library of Possibilities and Wonders                      |
| **RN03** | **Libraries Administration** (Default Income Cost Centre) |
| RN05     | Publications                                              |
| RN13     | Schools Library Management                                |
| **RZ00** | **Libraries Income Suspense** (Income Costcentre Offset)  |
| RL06     | Libraries Other Operational                               |

## Appendix B - Library Income Objectives

| Objective | Library                |
| --------- | ---------------------- |
| CUL001    | CRAWLEY LIBRARY        |
| CUL002    | BROADFIELD LIBRARY     |
| CUL003    | EAST GRINSTEAD LIBRARY |
| CUL004    | HORSHAM LIBRARY        |
| CUL005    | SOUTHWATER LIBRARY     |
| CUL006    | BURGESS HILL LIBRARY   |
| CUL007    | HAYWARDS HEATH LIBRARY |
| CUL008    | HENFIELD LIBRARY       |
| CUL009    | HASSOCKS LIBRARY       |
| CUL010    | HURSTPIERPOINT LIBRARY |
| CUL011    | STORRINGTON LIBRARY    |
| CUL012    | BILLINGSHURST LIBRARY  |
| CUL013    | MIDHURST LIBRARY       |
| CUL014    | PETWORTH LIBRARY       |
| CUL015    | PULBOROUGH LIBRARY     |
| CUL016    | SHOREHAM LIBRARY       |
| CUL017    | LANCING LIBRARY        |
| CUL018    | SOUTHWICK LIBRARY      |
| CUL019    | STEYNING LIBRARY       |
| CUL020    | LITTLEHAMPTON LIBRARY  |
| CUL021    | RUSTINGTON LIBRARY     |
| CUL022    | ANGMERING LIBRARY      |
| CUL023    | ARUNDEL LIBRARY        |
| CUL024    | EAST PRESTON LIBRARY   |
| CUL025    | FERRING LIBRARY        |
| CUL026    | BOGNOR REGIS LIBRARY   |
| CUL027    | WILLOWHALE LIBRARY     |
| CUL028    | BOGNOR MOBILE. LIBRARY |
| CUL029    | CHICHESTER LIBRARY     |
| CUL030    | SELSEY LIBRARY         |
| CUL031    | SOUTHBOURNE LIBRARY    |
| CUL032    | WITTERINGS LIBRARY     |
| CUL033    | WORTHING LIBRARY       |
| CUL034    | BROADWATER LIBRARY     |
| CUL035    | DURRINGTON LIBRARY     |
| CUL036    | FINDON LIBRARY         |
| CUL037    | GORING LIBRARY         |
| CUL074    | CENTRAL ADMIN          |

**Notes:**

- CUL074 (Central Admin) should be used as the default

## Appendix C – Library Income Subjectives

| Code       | Name                                         |
| ---------- | -------------------------------------------- |
| **810400** | **Other Income** (Default Offset Subjective) |
| 820000     | Sales                                        |
| 820100     | Fees and Charges                             |
| 820400     | Rents                                        |

**Common Usage:**

- 820100 - Used for most library fees and charges
- 810400 - Used as offset subjective for income transactions

## Appendix D – Library Income Subanalysis

| Code     | Name                             |
| -------- | -------------------------------- |
| **8201** | **(Default Offset Subanalysis)** |
| 8191     | Donations                        |
| 8350     | Sale of Books/Publications       |
| 8353     | Sale of Merchandise              |
| 8461     | Use of Building Income           |
| 8501     | Fines                            |
| 8502     | Book Reservations                |
| 8503     | Recorded Music                   |
| 8504     | Video & DVD Rental               |
| 8505     | Audiobooks                       |
| 8506     | Internet Fees                    |
| 8507     | Coin Operated Copier             |
| 8623     | Library Fees                     |
| 8771     | Property Rental Income           |

**Notes:**

- 8501 (Fines) is typically the most common subanalysis code for library income
- Different transaction types should be mapped to appropriate codes via debit type additional fields
- Code 8201 is used as the default offset subanalysis for all income transactions
