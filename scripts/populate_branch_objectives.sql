-- Populate objective additional field values for all branches
-- This script sets branch-specific income objectives based on the branch name mappings
-- It is idempotent - can be run multiple times safely
-- Branches not in the mapping will have their Income Objective values removed
-- to allow fallback to the plugin's configured default

-- =============================================================================
-- Populate Income Objective for branches based on branch name mapping
-- =============================================================================

-- First, delete any existing Income Objective values for branches not in our mapping
-- This allows them to fall back to the plugin's configured default (CUL074)
DELETE afv
FROM additional_field_values afv
INNER JOIN additional_fields af ON afv.field_id = af.id
INNER JOIN branches b ON afv.record_id = b.branchcode
WHERE af.tablename = 'branches'
  AND af.name = 'Income Objective'
  AND b.branchname NOT IN (
    'Crawley', 'Broadfield', 'East Grinstead', 'Horsham', 'Southwater',
    'Burgess Hill', 'Haywards Heath', 'Henfield', 'Hassocks', 'Hurstpierpoint',
    'Storrington', 'Billingshurst', 'Midhurst', 'Petworth', 'Pulborough',
    'Shoreham', 'Lancing', 'Southwick', 'Steyning',
    'Littlehampton', 'Rustington', 'Angmering', 'Arundel', 'East Preston', 'Ferring',
    'Bognor Regis', 'Willowhale', 'Bognor Mobile',
    'Chichester', 'Selsey', 'Southbourne', 'Witterings',
    'Worthing', 'Broadwater', 'Durrington', 'Findon Valley', 'Goring'
  );

-- Insert or update Income Objective values for mapped branches only
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT
    af.id AS field_id,
    b.branchcode AS record_id,
    CASE b.branchname
        WHEN 'Crawley' THEN 'CUL001'
        WHEN 'Broadfield' THEN 'CUL002'
        WHEN 'East Grinstead' THEN 'CUL003'
        WHEN 'Horsham' THEN 'CUL004'
        WHEN 'Southwater' THEN 'CUL005'
        WHEN 'Burgess Hill' THEN 'CUL006'
        WHEN 'Haywards Heath' THEN 'CUL007'
        WHEN 'Henfield' THEN 'CUL008'
        WHEN 'Hassocks' THEN 'CUL009'
        WHEN 'Hurstpierpoint' THEN 'CUL010'
        WHEN 'Storrington' THEN 'CUL011'
        WHEN 'Billingshurst' THEN 'CUL012'
        WHEN 'Midhurst' THEN 'CUL013'
        WHEN 'Petworth' THEN 'CUL014'
        WHEN 'Pulborough' THEN 'CUL015'
        WHEN 'Shoreham' THEN 'CUL016'
        WHEN 'Lancing' THEN 'CUL017'
        WHEN 'Southwick' THEN 'CUL018'
        WHEN 'Steyning' THEN 'CUL019'
        WHEN 'Littlehampton' THEN 'CUL020'
        WHEN 'Rustington' THEN 'CUL021'
        WHEN 'Angmering' THEN 'CUL022'
        WHEN 'Arundel' THEN 'CUL023'
        WHEN 'East Preston' THEN 'CUL024'
        WHEN 'Ferring' THEN 'CUL025'
        WHEN 'Bognor Regis' THEN 'CUL026'
        WHEN 'Willowhale' THEN 'CUL027'
        WHEN 'Bognor Mobile' THEN 'CUL028'
        WHEN 'Chichester' THEN 'CUL029'
        WHEN 'Selsey' THEN 'CUL030'
        WHEN 'Southbourne' THEN 'CUL031'
        WHEN 'Witterings' THEN 'CUL032'
        WHEN 'Worthing' THEN 'CUL033'
        WHEN 'Broadwater' THEN 'CUL034'
        WHEN 'Durrington' THEN 'CUL035'
        WHEN 'Findon Valley' THEN 'CUL036'
        WHEN 'Goring' THEN 'CUL037'
    END AS value
FROM branches b
CROSS JOIN additional_fields af
WHERE af.tablename = 'branches'
  AND af.name = 'Income Objective'
  AND b.branchname IN (
    'Crawley', 'Broadfield', 'East Grinstead', 'Horsham', 'Southwater',
    'Burgess Hill', 'Haywards Heath', 'Henfield', 'Hassocks', 'Hurstpierpoint',
    'Storrington', 'Billingshurst', 'Midhurst', 'Petworth', 'Pulborough',
    'Shoreham', 'Lancing', 'Southwick', 'Steyning',
    'Littlehampton', 'Rustington', 'Angmering', 'Arundel', 'East Preston', 'Ferring',
    'Bognor Regis', 'Willowhale', 'Bognor Mobile',
    'Chichester', 'Selsey', 'Southbourne', 'Witterings',
    'Worthing', 'Broadwater', 'Durrington', 'Findon Valley', 'Goring'
  )
ON DUPLICATE KEY UPDATE
    value = VALUES(value);

-- =============================================================================
-- Set Plugin Default for Income Objective
-- =============================================================================

-- Update the plugin's default_branch_objective setting to 'CUL074'
-- This is used as fallback for branches without explicit Income Objective values
UPDATE plugin_data
SET plugin_value = 'CUL074'
WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
  AND plugin_key = 'default_branch_objective';

-- If the setting doesn't exist, insert it
INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
SELECT 'Koha::Plugin::Com::OpenFifth::Oracle', 'default_branch_objective', 'CUL074'
WHERE NOT EXISTS (
    SELECT 1 FROM plugin_data
    WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
      AND plugin_key = 'default_branch_objective'
);

-- =============================================================================
-- Verification Query
-- =============================================================================

-- Run this query to verify the values were populated:
-- SELECT
--     b.branchcode,
--     b.branchname,
--     afv.value AS objective,
--     CASE WHEN afv.value IS NULL THEN 'CUL074 (plugin default)' ELSE afv.value END AS effective_objective
-- FROM branches b
-- LEFT JOIN additional_fields af ON af.tablename = 'branches' AND af.name = 'Income Objective'
-- LEFT JOIN additional_field_values afv ON afv.field_id = af.id AND afv.record_id = b.branchcode
-- ORDER BY b.branchcode;
--
-- Verify plugin default setting:
-- SELECT plugin_key, plugin_value
-- FROM plugin_data
-- WHERE plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle'
--   AND plugin_key = 'default_branch_objective';
