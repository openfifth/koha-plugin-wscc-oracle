-- Populate vendor supplier number mappings in plugin configuration
-- This script updates the plugin_data table to set vendor_supplier_mappings
-- based on the mapping table in docs/outgoings/outgoing_report.md Appendix A

-- NOTE: This script uses MySQL JSON functions to merge vendor mappings
-- It preserves any existing mappings and adds new ones based on vendor name matching

-- Set the plugin class name
SET @plugin_class = 'Koha::Plugin::Com::OpenFifth::Oracle';

-- Create a temporary table with the vendor name to supplier number mappings
CREATE TEMPORARY TABLE temp_vendor_mappings (
    vendor_name VARCHAR(255),
    supplier_number VARCHAR(20)
);

-- Insert all vendor mappings from Appendix A
INSERT INTO temp_vendor_mappings (vendor_name, supplier_number) VALUES
('Askews', '57028'),
('Ulverscroft', '6565'),
('BOLINDA DIGITAL LTD', '101563'),
('DIGITAL LIBRARY LTD', '109562'),
('CENGAGE LEARNING EMEA LTD', '90134'),
('OXFORD UNIVERSITY PRESS', '4614'),
('BIBLIOGRAPHICAL DATA SERVICES', '52423'),
('iSUBSCRiBE LTD', '97296'),
('ENCYCLOPAEDIA BRITANNICA', '46075'),
('Nielsen', '14673'),
('COBWEB INFORMATION LTD', '98804'),
('JCS ONLINE RESOURCES LIMITED', '102661'),
('NEWS UK & IRELAND LTD', '105721'),
('WELL INFORMED LIMITED', '98865'),
('OCLC (UK) LTD', '43401'),
('BOOKS ASIA', '97663'),
('MOODYS ANALYTICS UK LIMITED', '113279'),
('LATITUDE MAPPING LTD', '61107'),
('BAG BOOKS', '41600'),
('FOYLES', '55571'),
('IBISWORLD LTD', '114305'),
('THE BRITISH LIBRARY', '888'),
('ASCEL', '51470'),
('CALIBRE AUDIO LIBRARY', '97068'),
('OVERDRIVE GLOBAL LIMITED', '109358'),
('BOOK PROTECTORS & CO', '754'),
('WEST SUSSEX ARCHIVE SOCIETY', '46700'),
('SUSSEX ARCHAEOLOGICAL SOCIETY', '6146'),
('SUSSEX ORNITHOLOGICAL SOCIETY', '6183');

-- Build JSON object with vendor_id as key and supplier_number as value
SET @new_mappings = (
    SELECT CONCAT('{',
        GROUP_CONCAT(
            CONCAT('"', v.id, '":"', m.supplier_number, '"')
            SEPARATOR ','
        ),
    '}')
    FROM aqbooksellers v
    INNER JOIN temp_vendor_mappings m
        ON UPPER(TRIM(v.name)) = UPPER(TRIM(m.vendor_name))
);

-- Get existing mappings (if any)
SET @existing_mappings = (
    SELECT plugin_value
    FROM plugin_data
    WHERE plugin_class = @plugin_class
    AND plugin_key = 'vendor_supplier_mappings'
);

-- If existing mappings exist, merge them; otherwise use new mappings
SET @merged_mappings = CASE
    WHEN @existing_mappings IS NOT NULL AND @existing_mappings != '{}' THEN
        JSON_MERGE_PATCH(@existing_mappings, @new_mappings)
    ELSE
        @new_mappings
END;

-- Update or insert the merged mappings
INSERT INTO plugin_data (plugin_class, plugin_key, plugin_value)
VALUES (@plugin_class, 'vendor_supplier_mappings', @merged_mappings)
ON DUPLICATE KEY UPDATE plugin_value = @merged_mappings;

-- Clean up
DROP TEMPORARY TABLE temp_vendor_mappings;

-- Display results
SELECT
    'Vendor supplier mappings updated' as Status,
    JSON_LENGTH(@merged_mappings) as TotalMappings;

-- Show the mappings in a readable format
SELECT
    v.id as vendor_id,
    v.name as vendor_name,
    JSON_UNQUOTE(JSON_EXTRACT(@merged_mappings, CONCAT('$."', v.id, '"'))) as supplier_number
FROM aqbooksellers v
WHERE JSON_EXTRACT(@merged_mappings, CONCAT('$."', v.id, '"')) IS NOT NULL
ORDER BY v.name;

-- Show vendors without supplier number mappings (may need manual configuration)
SELECT
    v.id as vendor_id,
    v.name as vendor_name,
    'No supplier number mapped - configure in plugin settings' as note
FROM aqbooksellers v
WHERE v.active = 1
AND (
    JSON_EXTRACT(@merged_mappings, CONCAT('$."', v.id, '"')) IS NULL
    OR @merged_mappings IS NULL
)
ORDER BY v.name;
