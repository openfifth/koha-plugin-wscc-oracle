-- Populate cost center additional field values for all branches
-- This script sets branch-specific cost centres based on the branch name mappings
-- It is idempotent - can be run multiple times safely
-- Branches not in the mapping will have their Income Cost Centre values removed
-- to allow fallback to the plugin's configured default (RN03)

-- =============================================================================
-- Populate Income Cost Centre for branches based on branch name mapping
-- =============================================================================

-- First, delete any existing Income Cost Centre values for branches not in our mapping
-- This allows them to fall back to the plugin's configured default (RN03)
DELETE afv
FROM additional_field_values afv
INNER JOIN additional_fields af ON afv.field_id = af.id
INNER JOIN branches b ON afv.record_id = b.branchcode
WHERE af.tablename = 'branches'
  AND af.name = 'Income Cost Centre'
  AND b.branchname NOT IN (
    'Angmering', 'Arundel', 'Billingshurst', 'Bognor Regis', 'Broadfield',
    'Broadwater', 'Burgess Hill', 'Chichester', 'Crawley', 'Durrington',
    'East Grinstead', 'East Preston', 'Ferring', 'Findon Valley', 'Goring',
    'Hassocks', 'Haywards Heath', 'Henfield', 'Horsham', 'Hurstpierpoint',
    'Lancing', 'Littlehampton', 'Midhurst', 'Petworth', 'Pulborough',
    'Rustington', 'Selsey', 'Shoreham', 'Southbourne', 'Southwater',
    'Southwick', 'Steyning', 'Storrington', 'Willowhale', 'Witterings',
    'Worthing'
  );

-- Insert or update Income Cost Centre values for mapped branches only
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT
    af.id AS field_id,
    b.branchcode AS record_id,
    CASE b.branchname
        WHEN 'Angmering' THEN 'RG02'
        WHEN 'Arundel' THEN 'RG03'
        WHEN 'Billingshurst' THEN 'RE01'
        WHEN 'Bognor Regis' THEN 'RH00'
        WHEN 'Broadfield' THEN 'RA01'
        WHEN 'Broadwater' THEN 'RK01'
        WHEN 'Burgess Hill' THEN 'RD00'
        WHEN 'Chichester' THEN 'RJ00'
        WHEN 'Crawley' THEN 'RA00'
        WHEN 'Durrington' THEN 'RK02'
        WHEN 'East Grinstead' THEN 'RB00'
        WHEN 'East Preston' THEN 'RG04'
        WHEN 'Ferring' THEN 'RG05'
        WHEN 'Findon Valley' THEN 'RK03'
        WHEN 'Goring' THEN 'RK04'
        WHEN 'Hassocks' THEN 'RD03'
        WHEN 'Haywards Heath' THEN 'RD01'
        WHEN 'Henfield' THEN 'RD02'
        WHEN 'Horsham' THEN 'RC00'
        WHEN 'Hurstpierpoint' THEN 'RD04'
        WHEN 'Lancing' THEN 'RF01'
        WHEN 'Littlehampton' THEN 'RG00'
        WHEN 'Midhurst' THEN 'RE02'
        WHEN 'Petworth' THEN 'RE03'
        WHEN 'Pulborough' THEN 'RE04'
        WHEN 'Rustington' THEN 'RG01'
        WHEN 'Selsey' THEN 'RJ01'
        WHEN 'Shoreham' THEN 'RF00'
        WHEN 'Southbourne' THEN 'RJ02'
        WHEN 'Southwater' THEN 'RC01'
        WHEN 'Southwick' THEN 'RF02'
        WHEN 'Steyning' THEN 'RF03'
        WHEN 'Storrington' THEN 'RE00'
        WHEN 'Willowhale' THEN 'RH01'
        WHEN 'Witterings' THEN 'RJ03'
        WHEN 'Worthing' THEN 'RK00'
    END AS value
FROM branches b
CROSS JOIN additional_fields af
WHERE af.tablename = 'branches'
  AND af.name = 'Income Cost Centre'
  AND b.branchname IN (
    'Angmering', 'Arundel', 'Billingshurst', 'Bognor Regis', 'Broadfield',
    'Broadwater', 'Burgess Hill', 'Chichester', 'Crawley', 'Durrington',
    'East Grinstead', 'East Preston', 'Ferring', 'Findon Valley', 'Goring',
    'Hassocks', 'Haywards Heath', 'Henfield', 'Horsham', 'Hurstpierpoint',
    'Lancing', 'Littlehampton', 'Midhurst', 'Petworth', 'Pulborough',
    'Rustington', 'Selsey', 'Shoreham', 'Southbourne', 'Southwater',
    'Southwick', 'Steyning', 'Storrington', 'Willowhale', 'Witterings',
    'Worthing'
  )
ON DUPLICATE KEY UPDATE
    value = VALUES(value);

-- =============================================================================
-- Set Plugin Default for Income Cost Centre
-- =============================================================================

-- Update the plugin's default_income_costcentre setting to 'RN03'
-- This is used as fallback for branches without explicit Income Cost Centre values
UPDATE plugin_data
SET plugin_value = 'RN03'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_income_costcentre';

-- If the setting doesn't exist, insert it
INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_income_costcentre', 'RN03'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_income_costcentre'
);

-- =============================================================================
-- Populate Acquisitions Cost Centre for all branches
-- =============================================================================

-- Insert or update Acquisitions Cost Centre value 'RN05' for each branch
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
ON DUPLICATE KEY UPDATE
    value = VALUES(value);

-- =============================================================================
-- Verification Query
-- =============================================================================

-- Run this query to verify the values were populated:
-- SELECT
--     b.branchcode,
--     b.branchname,
--     afv_income.value AS income_cost_centre,
--     afv_acq.value AS acquisitions_cost_centre,
--     CASE WHEN afv_income.value IS NULL THEN 'RN03 (plugin default)' ELSE afv_income.value END AS effective_income_cost_centre
-- FROM branches b
-- LEFT JOIN additional_fields af_income ON af_income.tablename = 'branches' AND af_income.name = 'Income Cost Centre'
-- LEFT JOIN additional_field_values afv_income ON afv_income.field_id = af_income.id AND afv_income.record_id = b.branchcode
-- LEFT JOIN additional_fields af_acq ON af_acq.tablename = 'branches' AND af_acq.name = 'Acquisitions Cost Centre'
-- LEFT JOIN additional_field_values afv_acq ON afv_acq.field_id = af_acq.id AND afv_acq.record_id = b.branchcode
-- ORDER BY b.branchcode;
--
-- Verify plugin default setting:
-- SELECT plugin_key, plugin_value
-- FROM plugin_data
-- WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
--   AND plugin_key = 'default_income_costcentre';
