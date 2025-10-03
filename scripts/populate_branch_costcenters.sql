-- Populate cost center additional field values for all branches
-- This script sets default cost centres for all existing branches:
-- - 'RZ00' for Income Cost Centre
-- - 'RN05' for Acquisitions Cost Centre

-- =============================================================================
-- Populate Income Cost Centre for all branches
-- =============================================================================

-- Insert Income Cost Centre value 'RZ00' for each branch
-- Uses a subquery to get the field_id for 'Income Cost Centre'
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT
    af.id AS field_id,
    b.branchcode AS record_id,
    'RZ00' AS value
FROM branches b
CROSS JOIN additional_fields af
WHERE af.tablename = 'branches'
  AND af.name = 'Income Cost Centre'
  AND NOT EXISTS (
    SELECT 1
    FROM additional_field_values afv
    WHERE afv.field_id = af.id
      AND afv.record_id = b.branchcode
  );

-- =============================================================================
-- Populate Acquisitions Cost Centre for all branches
-- =============================================================================

-- Insert Acquisitions Cost Centre value 'RN05' for each branch
-- Uses a subquery to get the field_id for 'Acquisitions Cost Centre'
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT
    af.id AS field_id,
    b.branchcode AS record_id,
    'RN05' AS value
FROM branches b
CROSS JOIN additional_fields af
WHERE af.tablename = 'branches'
  AND af.name = 'Acquisitions Cost Centre'
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
--     afv_income.value AS income_cost_centre,
--     afv_acq.value AS acquisitions_cost_centre
-- FROM branches b
-- LEFT JOIN additional_fields af_income ON af_income.tablename = 'branches' AND af_income.name = 'Income Cost Centre'
-- LEFT JOIN additional_field_values afv_income ON afv_income.field_id = af_income.id AND afv_income.record_id = b.branchcode
-- LEFT JOIN additional_fields af_acq ON af_acq.tablename = 'branches' AND af_acq.name = 'Acquisitions Cost Centre'
-- LEFT JOIN additional_field_values afv_acq ON afv_acq.field_id = af_acq.id AND afv_acq.record_id = b.branchcode
-- ORDER BY b.branchcode;
