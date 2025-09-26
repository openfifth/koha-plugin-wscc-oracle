-- Load additional field values for account_debit_types
-- Run this in your ktd database: docker exec -i kohadev-db-1 mysql -u root -ppassword koha_kohadev < fix_additional_field_values.sql

-- Get the field IDs
SET @extra_code_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'extra_code');
SET @income_code_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'income_code');
SET @vat_code_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'vat_code');

-- Create a comprehensive mapping table for ALL debit types including system ones
CREATE TEMPORARY TABLE debit_type_mappings (
    code VARCHAR(80),
    extra_code VARCHAR(20),
    income_code VARCHAR(20),
    vat_code VARCHAR(10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert all our CSV data plus defaults for system types
INSERT INTO debit_type_mappings (code, extra_code, income_code, vat_code) VALUES
-- System types (provide default mappings)
('ACCOUNT', '', '8623', 'O'),
('ACCOUNT_RENEW', '', '8623', 'O'),
('ARTICLE_REQUEST', '', '8502', 'O'),
('LOST', '', '8623', 'O'),
('MANUAL', '', '8623', 'O'),
('NEW_CARD', '', '8623', 'O'),
('OVERDUE', '', '8501', 'O'),
('PAYOUT', '', '8623', 'O'),
('PROCESSING', '', '8623', 'O'),
('RENT', '', '8505', 'O'),

-- CSV data (all the imported types)
('CREDIT', '', '8623', 'O'),
('ELECTPRT', '', '8623', 'S'),
('OVUNDER', '', '8623', 'O'),
('DONATIONS', '', '8191', 'O'),
('EVENTS', '', '8623', 'S'),
('EXHIBITION', '', '8623', 'E'),
('GREETINGS-B', 'RQ32', '8353', 'S'),
('GREETINGS-D', 'RQ32', '8353', 'S'),
('GREETINGS-DD', 'RQ32', '8353', 'S'),
('GREETINGS-EE', 'RQ32', '8353', 'S'),
('GREETINGS-F', 'RQ32', '8353', 'S'),
('GREETINGS-FF', 'RQ32', '8353', 'S'),
('GREETINGS-G', 'RQ32', '8353', 'S'),
('GREETINGS-GG', 'RQ32', '8353', 'S'),
('GREETINGS-GH', 'RQ32', '8353', 'S'),
('GREETINGS-H', 'RQ32', '8353', 'S'),
('GREETINGS-HH', 'RQ32', '8353', 'S'),
('GREETINGS-HI', 'RQ32', '8353', 'S'),
('GREETINGS-II', 'RQ32', '8353', 'S'),
('GREETINGS-IJ', 'RQ32', '8353', 'S'),
('GREETINGS-JJ', 'RQ32', '8353', 'S'),
('GREETINGS-K', 'RQ32', '8353', 'S'),
('GREETINGS-LL', 'RQ32', '8353', 'S'),
('GREETINGS-MM', 'RQ32', '8353', 'S'),
('GREETINGS-P', 'RQ32', '8353', 'S'),
('GREETINGS-QKK', 'RQ32', '8353', 'S'),
('GREETINGS-S', 'RQ32', '8353', 'S'),
('GREETINGS-1', 'RQ32', '8353', 'S'),
('GREETINGS-2', 'RQ32', '8353', 'S'),
('GREETINGS-3', 'RQ32', '8353', 'S'),
('GREETINGS-4', 'RQ32', '8353', 'S'),
('GREETINGS-5', 'RQ32', '8353', 'S'),
('GREETINGS-6', 'RQ32', '8353', 'S'),
('GREETINGS-7', 'RQ32', '8353', 'S'),
('GREETINGS-8', 'RQ32', '8353', 'S'),
('GREETINGS-9', 'RQ32', '8353', 'S'),
('GREETINGS-10', 'RQ32', '8353', 'S'),
('GREETINGS-11', 'RQ32', '8353', 'S'),
('GREETINGS-12', 'RQ32', '8353', 'S'),
('INTERNETHRLY', '', '8506', 'S'),
('JACKETING', '', '8623', 'S'),
('LAMINATION', '', '8623', 'S'),
('SPOKLOAN1', '', '8505', 'O'),
('SPOKLOAN9', '', '8505', 'O'),
('AUDIOLOAN1', '', '8505', 'O'),
('AUDIOLOAN9', '', '8505', 'O'),
('DIGAUDIOLOAN', '', '8505', 'O'),
('DVDLOAN', '', '8504', 'O'),
('CDLOAN', '', '8503', 'O'),
('LOSSADMIN', '', '8623', 'O'),
('LOSSREPLACE', '', '8623', 'O'),
('3DBOOKMARKS', 'RQ30', '8353', 'S'),
('ACTIVITYBOOK', '', '8353', 'E'),
('BAGECO', 'RQ30', '8353', 'S'),
('BAGREAD', 'RQ30', '8353', 'S'),
('BAGLOCAL', 'RQ30', '8353', 'S'),
('BAGIDEAL', 'RQ30', '8353', 'S'),
('HEADPHONES', '', '8353', 'S'),
('IFBOOKFAN', 'RQ30', '8353', 'S'),
('IFBOOKHOLDER', 'RQ30', '8353', 'S'),
('IFBOOKMARK50', 'RQ30', '8353', 'S'),
('IFBOOKTAILS', 'RQ30', '8353', 'S'),
('IFDOGEAR', 'RQ30', '8353', 'S'),
('IFMRMEN', 'RQ30', '8353', 'S'),
('IFPAGEPOINT', 'RQ30', '8353', 'S'),
('IFSEUSS', 'RQ30', '8353', 'S'),
('IFVA', 'RQ30', '8353', 'S'),
('IFLITTLEBOOK', 'RQ30', '8353', 'S'),
('IFMAGNIFCC', 'RQ30', '8353', 'S'),
('IFMAGNIFSHEET', 'RQ30', '8353', 'S'),
('IFMAGNIFLED', 'RQ30', '8353', 'S'),
('IFNOTEPADA5', 'RQ30', '8353', 'S'),
('IFSARDINES', 'RQ30', '8353', 'S'),
('IFPOPUPBOOK', 'RQ30', '8353', 'S'),
('IFTEETHMARKS', 'RQ30', '8353', 'S'),
('IFTINYLIGHT', 'RQ30', '8353', 'S'),
('MAGNIFYSHEET', '', '8353', 'S'),
('MEMORYSTICK', '', '8353', 'S'),
('HEIGHTCHART', 'RQ30', '8353', 'S'),
('JIGSAW', 'RQ30', '8353', 'S'),
('MUGREAD', 'RQ30', '8353', 'S'),
('STATIONERY', 'RQ30', '8353', 'S'),
('CENTBLACK', 'RQ30', '8353', 'S'),
('CENTGOLD', 'RQ30', '8353', 'S'),
('CENTPLAIN', 'RQ30', '8353', 'S'),
('CENTTOTE', 'RQ30', '8353', 'S'),
('QUOTEPEN', 'RQ30', '8353', 'S'),
('PENCILPEOPLE', 'RQ30', '8353', 'S'),
('SLANTPADS', 'RQ30', '8353', 'S'),
('SPACESHUTTLE', 'RQ30', '8353', 'S'),
('STICKYCATDOG', 'RQ30', '8353', 'S'),
('STICKYTRANS', 'RQ30', '8353', 'S'),
('WALLCHART', '', '8353', 'S'),
('MISC', '', '8623', 'S'),
('MISCNONVAT', '', '8623', 'O'),
('FINES', '', '8501', 'O'),
('COURT', '', '8620', 'O'),
('FINESFALLBACK', '', '8501', 'O'),
('PHOTOCOP', '', '8507', 'S'),
('LOCALPRINT1', '', '8623', 'S'),
('LOCALPRINT2', '', '8623', 'S'),
('LOCALPUB', '', '8623', 'Z'),
('READINGGR1', '', '8623', 'S'),
('READINGGR3', '', '8623', 'S'),
('READINGGR6', '', '8623', 'S'),
('READINGGR9', '', '8623', 'S'),
('REPTICK', '', '8623', 'O'),
('REQUEST1', '', '8502', 'O'),
('REQUESTBL', '', '8502', 'O'),
('REQUESTBLREN', '', '8502', 'O'),
('REQUESTILL', '', '8502', 'O'),
('SELFBOOK', '', '8502', 'O'),
('STAFFBOOK', '', '8502', 'O'),
('ROOM1', '', '8461', 'E'),
('ROOM2', '', '8461', 'E'),
('ROOM3', '', '8461', 'E'),
('ROOMPOD1', '', '8461', 'E'),
('ROOMPOD2', '', '8461', 'E'),
('ROOMVAT1', '', '8461', 'S'),
('ROOMVAT2', '', '8461', 'S'),
('ROOMVAT3', '', '8461', 'S'),
('ROOMINS', '', '8461', 'E'),
('ROOMOOH', '', '8461', 'E'),
('SCHOOLSLIB', 'RQ40', '8623', 'E'),
('PAYPHONE', '', '8623', 'S'),
('AVSALE', '', '8350', 'S'),
('BOOKSALE', '', '8350', 'Z'),
('POSURPLUS', '', '8623', 'O');

-- Insert missing extra_code values (only for non-empty extra_codes)
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT 
    @extra_code_field_id,
    dtm.code,
    dtm.extra_code
FROM debit_type_mappings dtm
JOIN account_debit_types dt ON dt.code = dtm.code
WHERE dtm.extra_code != '' 
  AND dtm.code NOT IN (
    SELECT record_id
    FROM additional_field_values 
    WHERE field_id = @extra_code_field_id
  );

-- Insert missing income_code values
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT 
    @income_code_field_id,
    dtm.code,
    dtm.income_code
FROM debit_type_mappings dtm
JOIN account_debit_types dt ON dt.code = dtm.code
WHERE dtm.code NOT IN (
    SELECT record_id  
    FROM additional_field_values 
    WHERE field_id = @income_code_field_id
  );

-- Insert missing vat_code values
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT 
    @vat_code_field_id,
    dtm.code,
    dtm.vat_code
FROM debit_type_mappings dtm
JOIN account_debit_types dt ON dt.code = dtm.code
WHERE dtm.code NOT IN (
    SELECT record_id 
    FROM additional_field_values 
    WHERE field_id = @vat_code_field_id
  );

-- Clean up
DROP TEMPORARY TABLE debit_type_mappings;

-- Display results
SELECT 'Additional Field Values Update Complete' as Status;

SELECT 'Field Value Counts:' as Info;
SELECT 
    af.name as field_name,
    COUNT(afv.id) as value_count
FROM additional_fields af 
LEFT JOIN additional_field_values afv ON af.id = afv.field_id 
WHERE af.tablename = 'account_debit_types' 
GROUP BY af.name;

SELECT 'Total Debit Types:' as Info, COUNT(*) as count FROM account_debit_types;

-- Show some examples with all fields populated
SELECT 'Sample Records:' as Info;
SELECT 
    dt.code,
    dt.description,
    (SELECT value FROM additional_field_values afv 
     JOIN additional_fields af ON afv.field_id = af.id 
     WHERE af.name = 'extra_code' AND afv.record_id = dt.code LIMIT 1) as extra_code,
    (SELECT value FROM additional_field_values afv 
     JOIN additional_fields af ON afv.field_id = af.id 
     WHERE af.name = 'income_code' AND afv.record_id = dt.code LIMIT 1) as income_code,
    (SELECT value FROM additional_field_values afv 
     JOIN additional_fields af ON afv.field_id = af.id 
     WHERE af.name = 'vat_code' AND afv.record_id = dt.code LIMIT 1) as vat_code
FROM account_debit_types dt
WHERE dt.code IN ('MANUAL', 'GREETINGS-B', 'IFBOOKFAN', 'ROOM1', 'OVERDUE')
ORDER BY dt.code;
