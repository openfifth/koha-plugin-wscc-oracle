-- Populate objective additional field values for all branches
-- This script sets 'CUL00?' as the default income objective for all existing branches
-- Note: The '?' should be replaced with specific values for each branch as needed

-- =============================================================================
-- Populate Objective for all branches
-- =============================================================================

-- Insert Objective value 'CUL00?' for each branch
-- Uses a subquery to get the field_id for 'Objective'
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT
    af.id AS field_id,
    b.branchcode AS record_id,
    'CUL00?' AS value
FROM branches b
CROSS JOIN additional_fields af
WHERE af.tablename = 'branches'
  AND af.name = 'Objective'
  AND NOT EXISTS (
    SELECT 1
    FROM additional_field_values afv
    WHERE afv.field_id = af.id
      AND afv.record_id = b.branchcode
  );

-- =============================================================================
-- Verification Query
-- =============================================================================

-- Run this query to verify the values were populated:
-- SELECT
--     b.branchcode,
--     b.branchname,
--     afv.value AS objective
-- FROM branches b
-- LEFT JOIN additional_fields af ON af.tablename = 'branches' AND af.name = 'Objective'
-- LEFT JOIN additional_field_values afv ON afv.field_id = af.id AND afv.record_id = b.branchcode
-- ORDER BY b.branchcode;

-- =============================================================================
-- Update specific branch objectives (example)
-- =============================================================================

-- After running the initial insert, you can update specific branches:
-- UPDATE additional_field_values afv
-- JOIN additional_fields af ON af.id = afv.field_id
-- SET afv.value = 'CUL001'
-- WHERE af.tablename = 'branches'
--   AND af.name = 'Objective'
--   AND afv.record_id = 'BRANCH_CODE';
