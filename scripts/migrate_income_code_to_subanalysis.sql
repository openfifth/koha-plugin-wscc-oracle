-- Migrate 'Income Code' additional field values to 'Subanalysis'
-- This script consolidates the two synonymous fields into a single 'Subanalysis' field

-- =============================================================================
-- Step 1: Copy values from 'Income Code' to 'Subanalysis' where Subanalysis is empty
-- =============================================================================

-- Get the field IDs
SET @income_code_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'Income Code');
SET @subanalysis_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'Subanalysis');

-- Copy Income Code values to Subanalysis where Subanalysis doesn't exist
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT
    @subanalysis_field_id,
    afv_income.record_id,
    afv_income.value
FROM additional_field_values afv_income
WHERE afv_income.field_id = @income_code_field_id
  AND NOT EXISTS (
    SELECT 1
    FROM additional_field_values afv_sub
    WHERE afv_sub.field_id = @subanalysis_field_id
      AND afv_sub.record_id = afv_income.record_id
  );

-- =============================================================================
-- Step 2: Delete all 'Income Code' field values
-- =============================================================================

DELETE FROM additional_field_values
WHERE field_id = @income_code_field_id;

-- =============================================================================
-- Step 3: Delete the 'Income Code' additional field definition
-- =============================================================================

DELETE FROM additional_fields
WHERE id = @income_code_field_id;

-- =============================================================================
-- Verification Query
-- =============================================================================

-- Run this query to verify the migration was successful:
-- SELECT
--     dt.code,
--     dt.description,
--     afv.value AS subanalysis
-- FROM account_debit_types dt
-- LEFT JOIN additional_fields af ON af.tablename = 'account_debit_types' AND af.name = 'Subanalysis'
-- LEFT JOIN additional_field_values afv ON afv.field_id = af.id AND afv.record_id = dt.code
-- WHERE dt.is_system = 0
-- ORDER BY dt.code
-- LIMIT 20;

-- Verify Income Code field is gone:
-- SELECT COUNT(*) as income_code_fields_remaining
-- FROM additional_fields
-- WHERE tablename = 'account_debit_types' AND name = 'Income Code';
-- (Should return 0)
