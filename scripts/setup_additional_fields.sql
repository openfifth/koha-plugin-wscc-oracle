-- Setup script for additional fields required by WSCC Oracle Finance Plugin
-- This script creates the necessary additional field definitions for:
-- 1. account_debit_types table (VAT Code, Extra Code, Subjective, Subanalysis)
-- 2. branches table (Income Objective, Income Cost Centre, Acquisitions Cost Centre)

-- NOTE: Run this script against your Koha database to enable dynamic configuration
-- of COA (Chart of Accounts) mappings for Oracle Finance integration.

-- =============================================================================
-- Additional Fields for account_debit_types
-- =============================================================================

-- Insert additional field for VAT code
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, searchable)
VALUES ('account_debit_types', 'VAT Code', NULL, '', 0)
ON DUPLICATE KEY UPDATE
    tablename = 'account_debit_types',
    name = 'VAT Code';

-- Insert additional field for Extra code
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, searchable)
VALUES ('account_debit_types', 'Extra Code', NULL, '', 0)
ON DUPLICATE KEY UPDATE
    tablename = 'account_debit_types',
    name = 'Extra Code';

-- Insert additional field for Subjective code
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, searchable)
VALUES ('account_debit_types', 'Subjective', NULL, '', 0)
ON DUPLICATE KEY UPDATE
    tablename = 'account_debit_types',
    name = 'Subjective';

-- Insert additional field for Subanalysis code
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, searchable)
VALUES ('account_debit_types', 'Subanalysis', NULL, '', 0)
ON DUPLICATE KEY UPDATE
    tablename = 'account_debit_types',
    name = 'Subanalysis';

-- =============================================================================
-- Additional Fields for branches
-- =============================================================================

-- Insert additional field for Income Objective (Library-specific objective codes)
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, searchable)
VALUES ('branches', 'Income Objective', NULL, '', 0)
ON DUPLICATE KEY UPDATE
    tablename = 'branches',
    name = 'Income Objective';

-- Insert additional field for Income Cost Center
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, searchable)
VALUES ('branches', 'Income Cost Centre', NULL, '', 0)
ON DUPLICATE KEY UPDATE
    tablename = 'branches',
    name = 'Income Cost Centre';

-- Insert additional field for Acquisitions Cost Center
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, searchable)
VALUES ('branches', 'Acquisitions Cost Centre', NULL, '', 0)
ON DUPLICATE KEY UPDATE
    tablename = 'branches',
    name = 'Acquisitions Cost Centre';

-- =============================================================================
-- Verification Query
-- =============================================================================

-- Run this query to verify the fields were created successfully:
-- SELECT id, tablename, name FROM additional_fields
-- WHERE tablename IN ('account_debit_types', 'branches')
-- ORDER BY tablename, name;
