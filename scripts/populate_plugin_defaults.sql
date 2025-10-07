-- Populate default plugin configuration values
-- This script sets WSCC-specific default values for the Oracle Finance Integration plugin
-- It is idempotent - can be run multiple times safely

-- =============================================================================
-- Income Cost Centre Default
-- =============================================================================

-- Set default_income_costcentre to 'RN03' (Libraries Administration)
UPDATE plugin_data
SET plugin_value = 'RN03'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_income_costcentre';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_income_costcentre', 'RN03'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_income_costcentre'
);

-- =============================================================================
-- Income Objective Default
-- =============================================================================

-- Set default_branch_objective to 'CUL074' (Central Admin)
UPDATE plugin_data
SET plugin_value = 'CUL074'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_branch_objective';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_branch_objective', 'CUL074'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_branch_objective'
);

-- =============================================================================
-- Income Offset Cost Centre Default
-- =============================================================================

-- Set default_income_costcentre_offset to 'RZ00' (Libraries Income Suspense)
UPDATE plugin_data
SET plugin_value = 'RZ00'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_income_costcentre_offset';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_income_costcentre_offset', 'RZ00'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_income_costcentre_offset'
);

-- =============================================================================
-- Income Offset Subjective Default
-- =============================================================================

-- Set default_income_subjective_offset to '810400' (Other Income)
UPDATE plugin_data
SET plugin_value = '810400'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_income_subjective_offset';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_income_subjective_offset', '810400'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_income_subjective_offset'
);

-- =============================================================================
-- Income Offset Subanalysis Default
-- =============================================================================

-- Set default_income_subanalysis_offset to '8201'
UPDATE plugin_data
SET plugin_value = '8201'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_income_subanalysis_offset';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_income_subanalysis_offset', '8201'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_income_subanalysis_offset'
);

-- =============================================================================
-- Default VAT Code
-- =============================================================================

-- Set default_vat_code to 'O' (Out of Scope)
UPDATE plugin_data
SET plugin_value = 'O'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_vat_code';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_vat_code', 'O'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_vat_code'
);

-- =============================================================================
-- Default Subjective
-- =============================================================================

-- Set default_subjective to '841800'
UPDATE plugin_data
SET plugin_value = '841800'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_subjective';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_subjective', '841800'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_subjective'
);

-- =============================================================================
-- Default Subanalysis
-- =============================================================================

-- Set default_subanalysis to '8089'
UPDATE plugin_data
SET plugin_value = '8089'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_subanalysis';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_subanalysis', '8089'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_subanalysis'
);

-- =============================================================================
-- Acquisitions Cost Center Default
-- =============================================================================

-- Set default_acquisitions_costcenter to 'RN05' (Publications)
UPDATE plugin_data
SET plugin_value = 'RN05'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_acquisitions_costcenter';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_acquisitions_costcenter', 'RN05'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_acquisitions_costcenter'
);

-- =============================================================================
-- Acquisitions Subanalysis Default
-- =============================================================================

-- Set default_acquisitions_subanalysis to '5460'
UPDATE plugin_data
SET plugin_value = '5460'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_acquisitions_subanalysis';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_acquisitions_subanalysis', '5460'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_acquisitions_subanalysis'
);

-- =============================================================================
-- Default Branch Acquisitions Cost Centre
-- =============================================================================

-- Set default_branch_acquisitions_costcentre to 'RN05' (Publications)
UPDATE plugin_data
SET plugin_value = 'RN05'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_branch_acquisitions_costcentre';

INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_branch_acquisitions_costcentre', 'RN05'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_branch_acquisitions_costcentre'
);

-- =============================================================================
-- Verification Query
-- =============================================================================

-- Run this query to verify all plugin defaults were set:
-- SELECT plugin_key, plugin_value
-- FROM plugin_data
-- WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
--   AND plugin_key IN (
--     'default_income_costcentre',
--     'default_branch_objective',
--     'default_vat_code',
--     'default_subjective',
--     'default_subanalysis',
--     'default_income_costcentre_offset',
--     'default_income_subjective_offset',
--     'default_income_subanalysis_offset',
--     'default_acquisitions_costcenter',
--     'default_acquisitions_subanalysis',
--     'default_branch_acquisitions_costcentre'
--   )
-- ORDER BY plugin_key;
