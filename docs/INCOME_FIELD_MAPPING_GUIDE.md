# Income Report Field Mapping Guide

This document explains how Oracle Chart of Accounts (COA) fields are populated in the income report, organized by the conceptual purpose of each field.

## Key Concepts

When a library transaction occurs, there are three important pieces of information:

1. **What the money was for** - The type of charge (debit type): OVERDUE fine, RENTAL fee, LOST item, ACTIVITYBOOK merchandise etc.
2. **Where the money was collected** - The library branch (credit branch) where the payment was taken
3. **Where the charge originated** - The library branch (debit branch) where the fine/fee was created, for merchandise sales with will match the branch
   where the sale takes place

Additionally, there's: 4. **How the money was paid** - The payment method (Cash, Credit Card, etc.)

## Field Mapping by Purpose

### Fields Describing "WHAT the money was for" (Debit Type)

These fields are determined by the **debit type** - what was the customer being charged for?

| Field           | Always From | Fallback                          | Purpose                                                   |
| --------------- | ----------- | --------------------------------- | --------------------------------------------------------- |
| **Subjective**  | Debit Type  | Plugin default (841800)           | Nature of the income (e.g., library fines vs rental fees) |
| **Subanalysis** | Debit Type  | Plugin default (8089)             | More detailed breakdown of the income type                |
| **VAT Code**    | Debit Type  | Plugin default (O - Out of Scope) | Tax treatment for this type of transaction                |

### Fields Describing "WHERE/HOW the money was collected"

These fields can come from **either** the debit type (for fine-grained control) **or** the branch where payment was taken (for general cases).

| Field           | Priority 1 (Override)          | Priority 2 (Default)               | Priority 3 (Fallback)   | Purpose                                               |
| --------------- | ------------------------------ | ---------------------------------- | ----------------------- | ----------------------------------------------------- |
| **Cost Centre** | Debit Type "Cost Centre" field | Credit Branch "Income Cost Centre" | Plugin default (RN03)   | Which department/cost center is receiving this income |
| **Objective**   | Debit Type "Objective" field   | Credit Branch "Income Objective"   | Plugin default (CUL074) | What program/objective this income supports           |

**Why the flexibility?** Most transactions use the branch-level settings (where the money was collected). But some transaction types need special handling - for example, a specific type of merchandise might need to go to a different cost centre regardless of which branch collected it.

### Offset Fields

These balance the main transaction.

| Offset Field           | Source                                 | Purpose                               |
| ---------------------- | -------------------------------------- | ------------------------------------- |
| **Cost Centre Offset** | Plugin configuration (default: RZ00)   | Suspense account for balancing        |
| **Objective Offset**   | Debit Branch "Income Objective"        | Where the original charge was created |
| **Subjective Offset**  | Plugin configuration (default: 810400) | Income offset account                 |
| **Subanalysis Offset** | Plugin configuration (default: 8201)   | Detailed offset breakdown             |

**Why use the debit branch for Objective Offset?** This shows where the charge originated. If Branch A creates a fine, but it's paid at Branch B, the main record shows Branch B collected it (credit branch), but the offset shows it was Branch A's charge (debit branch).

## Real-World Example

**Scenario:** A patron borrows a book from Chichester Library, loses it, and later pays the LOST fee at Worthing Library using a credit card.

- **Debit Type:** LOST
- **Credit Branch:** Worthing (where payment was taken)
- **Debit Branch:** Chichester (where the charge was created)
- **Payment Type:** Credit Card

**Field Resolution:**

1. **Subjective** → From LOST debit type settings (e.g., 841850)
2. **Subanalysis** → From LOST debit type settings (e.g., 8090)
3. **VAT Code** → From LOST debit type settings (e.g., O)
4. **Cost Centre** → From LOST debit type IF configured, OTHERWISE from Worthing branch
5. **Objective** → From LOST debit type IF configured, OTHERWISE from Worthing branch
6. **Objective Offset** → From Chichester branch (where charge originated)

## When to Use Debit Type Overrides

Use debit type-level overrides for Cost Centre and Objective when:

- A specific transaction type needs different accounting treatment regardless of location
- Central services or cross-branch programs require specific COA codes
- Legal or financial reporting requires certain transaction types to be tracked separately

Leave the debit type fields empty (null) when:

- Standard branch-level accounting is sufficient
- The location where money is collected determines the correct COA codes
- You want simpler maintenance (only update branch settings, not each transaction type)

## Configuration Priority Summary

For **most fields** (Subjective, Subanalysis, VAT):

1. Debit type configuration
2. Plugin default

For **Cost Centre and Objective** (NEW with override capability):

1. Debit type configuration (override)
2. Credit branch configuration (default)
3. Plugin default (fallback)

For **Offset fields**:

- Objective Offset: Always from debit branch
- Other offsets: Plugin configuration
