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

## Oracle CSV Fields

| Field No. | Source Field               | Type   | Description                         | Sample Data                    |
| --------: | :------------------------- | :----- | :---------------------------------- | :----------------------------- |
|         1 | D_Document Document Number | TEXT   | Any Reference Number from O5TH      | SAMPLE1                        |
|         2 | D_Document Description     | TEXT   | `<slip_no>”-“<branch>”-LIB-Income”` | SEP15/20/CN-Crawley-LIB-Income |
|         3 | D_Document Date            | TEXT   | Accounting Date                     | 2025/03/21                     |
|         4 | D_Line Number              | TEXT   | Line Number                         | 1                              |
|         5 | D_Line Amount              | AMOUNT | Postive Amount (No Refunds)         | 450                            |
|         6 | D_Cost Centre              | TEXT   | Cost Centre                         | DG92                           |
|         7 | D_Objective                | TEXT   | Objective                           | CUL001                         |
|         8 | D_Subjective               | TEXT   | Subjective                          | 841800                         |
|         9 | D_Subanalysis              | TEXT   | Subanalysis                         | 5435                           |
|        10 | D_Cost Centre Offset       | TEXT   | Cost Centre                         | DM87                           |
|        11 | D_Objective Offset         | TEXT   | Objective                           | SRT003                         |
|        12 | D_Subjective Offset        | TEXT   | Subjective                          | 276001                         |
|        13 | D_Subanalysis Offset       | TEXT   | Subanalysis                         | 5435                           |
|        14 | D_Line Description         | TEXT   | Description from Source             | Withdrawn books for sale       |
|        15 | D_VAT Code                 | TEXT   | VAT Code                            | STD                            |
|        16 | D_VAT Amount               | AMOUNT | VAT Amount                          | 90                             |

## Koha Field mappings

## Additional notes

- Koha should post the sum of transactions per library per debit type per receipt type (configurable as payment type in Koha) per day.
- Koha should use location (branch) of the income to derive the Cost Centre and Objective
- For Objectives there is a mapping

  - We will add these as an 'Objective' additional field for the branches table
  - The mappings table follows:

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

- For all locations (branches) the "Cost centre" is 'RN03'
  - We will add this as a 'Cost center' additional field for the branches table
- The subjective, subanalysis and VAT code are derived from the debit type.
- Expected VAT Codes are STANDARD, ZERO, OUT OF SCOPE
- Payment types will be defined as:
  | CODE | Description |
  | ---- | ------------ |
  | CASH | includes both physical cash and cheques |
  | CARD KIOSK | debit or credit card payment to a kiosk |
  | CARD TERMINAL | debit or credit card payment to a handheld CHIP and PIN terminal |
  | PAY360 | payment using online payments system, Pay360 |

- The descriptions for lines will be:
  - Payment type followed by debit type
  - Example: CASH Book Sale
- Pay360 payments should be EXCLUDED from this report

## Error handling, Archiving and Recovery

Oracle will send emails to the business when parsing errors are encountered.

No specific requirements at the Koha side for archival or audit trail.
