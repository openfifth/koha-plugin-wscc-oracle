-- Load debit_types.csv into Koha's account_debit_types table with additional fields
-- Run this in your ktd database: docker exec -i kohadev-db-1 mysql -u root -ppassword koha_kohadev < load_debit_types.sql

-- First, create additional fields for the extra data from CSV
INSERT INTO additional_fields (tablename, name, authorised_value_category, marcfield, marcfield_mode, searchable, repeatable) VALUES
('account_debit_types', 'Extra Code', '', '', 'get', 1, 0),
('account_debit_types', 'Subanalysis', '', '', 'get', 1, 0),
('account_debit_types', 'VAT Code', '', '', 'get', 1, 0)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Create a temporary table to hold the parsed CSV data
CREATE TEMPORARY TABLE temp_debit_types (
    extra_code VARCHAR(20),
    income_code VARCHAR(20),
    finance_code VARCHAR(80),
    description VARCHAR(500),
    cost_text VARCHAR(50),
    vat_code VARCHAR(10),
    cost_amount DECIMAL(28,6)
);

-- Insert the CSV data manually (since we can't easily load CSV in this context)
-- Note: Prices have been cleaned and converted to decimal format

INSERT INTO temp_debit_types (extra_code, income_code, finance_code, description, cost_text, vat_code, cost_amount) VALUES
('', '8623', 'CREDIT', 'Borrower Account Credit', '', 'O', NULL),
('', '8623', 'ELECTPRT', 'Computer Printing', '£ -', 'S', NULL),
('', '8623', 'OVUNDER', 'Deficit/Surplus', '', 'O', NULL),
('', '8191', 'DONATIONS', 'Donations', '£ -', 'O', NULL),
('', '8623', 'EVENTS', 'Event tickets', '£ -', 'S', NULL),
('', '8623', 'EXHIBITION', 'Exhibition Booking Fee', '£ 15.50', 'E', 15.50),
('RQ32', '8353', 'GREETINGS-B', 'Greetings Cards - B', '£ 3.30', 'S', 3.30),
('RQ32', '8353', 'GREETINGS-D', 'Greetings Cards - D', '£ 2.60', 'S', 2.60),
('RQ32', '8353', 'GREETINGS-DD', 'Greetings Cards - DD', '£ 1.20', 'S', 1.20),
('RQ32', '8353', 'GREETINGS-EE', 'Greetings Cards - EE', '£ 1.30', 'S', 1.30),
('RQ32', '8353', 'GREETINGS-F', 'Greetings Cards - F', '£ 1.60', 'S', 1.60),
('RQ32', '8353', 'GREETINGS-FF', 'Greetings Cards - FF', '£ 1.60', 'S', 1.60),
('RQ32', '8353', 'GREETINGS-G', 'Greetings Cards - G', '£ 2.50', 'S', 2.50),
('RQ32', '8353', 'GREETINGS-GG', 'Greetings Cards - GG', '£ 1.90', 'S', 1.90),
('RQ32', '8353', 'GREETINGS-GH', 'Greetings Cards - GH', '£ 2.00', 'S', 2.00),
('RQ32', '8353', 'GREETINGS-H', 'Greetings Cards - H', '£ 2.00', 'S', 2.00),
('RQ32', '8353', 'GREETINGS-HH', 'Greetings Cards - HH', '£ 2.00', 'S', 2.00),
('RQ32', '8353', 'GREETINGS-HI', 'Greetings Cards - HI', '£ 2.25', 'S', 2.25),
('RQ32', '8353', 'GREETINGS-II', 'Greetings Cards - II', '£ 2.50', 'S', 2.50),
('RQ32', '8353', 'GREETINGS-IJ', 'Greetings Cards - IJ', '£ 2.60', 'S', 2.60),
('RQ32', '8353', 'GREETINGS-JJ', 'Greetings Cards - JJ', '£ 2.70', 'S', 2.70),
('RQ32', '8353', 'GREETINGS-K', 'Greetings Cards - K', '£ 2.25', 'S', 2.25),
('RQ32', '8353', 'GREETINGS-LL', 'Greetings Cards - LL', '£ 3.00', 'S', 3.00),
('RQ32', '8353', 'GREETINGS-MM', 'Greetings Cards - MM', '£ 3.40', 'S', 3.40),
('RQ32', '8353', 'GREETINGS-P', 'Greetings Cards - P', '£ 2.70', 'S', 2.70),
('RQ32', '8353', 'GREETINGS-QKK', 'Greetings Cards - Q/KK', '£ 2.90', 'S', 2.90),
('RQ32', '8353', 'GREETINGS-S', 'Greetings Cards - S', '£ 2.00', 'S', 2.00),
('RQ32', '8353', 'GREETINGS-1', 'Greetings Cards: Alan Nicholls', '£ 2.20', 'S', 2.20),
('RQ32', '8353', 'GREETINGS-2', 'Greetings Cards: Andrew Dandridge', '£ 1.40', 'S', 1.40),
('RQ32', '8353', 'GREETINGS-3', 'Greetings Cards: CFGC Bumper Pack', '£ 9.99', 'S', 9.99),
('RQ32', '8353', 'GREETINGS-4', 'Greetings Cards: CFGC Standard Pack', '£ 4.99', 'S', 4.99),
('RQ32', '8353', 'GREETINGS-5', 'Greetings Cards: Cherry Parsons', '£ 3.00', 'S', 3.00),
('RQ32', '8353', 'GREETINGS-6', 'Greetings Cards: Christmas C', '£ 3.99', 'S', 3.99),
('RQ32', '8353', 'GREETINGS-7', 'Greetings Cards: Dry Red Press', '£ 2.50', 'S', 2.50),
('RQ32', '8353', 'GREETINGS-8', 'Greetings Cards: Helen Budgen', '£ 2.25', 'S', 2.25),
('RQ32', '8353', 'GREETINGS-9', 'Greetings Cards: Julian Perry', '£ 2.50', 'S', 2.50),
('RQ32', '8353', 'GREETINGS-10', 'Greetings Cards: Leftovers', '£ 1.00', 'S', 1.00),
('RQ32', '8353', 'GREETINGS-11', 'Greetings Cards: Peter Iden Large', '£ 2.50', 'S', 2.50),
('RQ32', '8353', 'GREETINGS-12', 'Greetings Cards: Pulborough Society', '£ 1.25', 'S', 1.25),
('', '8506', 'INTERNETHRLY', 'Internet charge: hourly fee', '£ 2.30', 'S', 2.30),
('', '8623', 'JACKETING', 'Jackets and jacketing service', '£ 1.00', 'S', 1.00),
('', '8623', 'LAMINATION', 'Lamination service', '£ -', 'S', NULL),
('', '8505', 'SPOKLOAN1', 'Loan charge: Audiobook cass (1-8)', '£ 1.55', 'O', 1.55),
('', '8505', 'SPOKLOAN9', 'Loan charge: Audiobook cass (9+)', '£ 3.10', 'O', 3.10),
('', '8505', 'AUDIOLOAN1', 'Loan charge: Audiobook on CD (1-8)', '£ 1.55', 'O', 1.55),
('', '8505', 'AUDIOLOAN9', 'Loan charge: Audiobook on CD (9+)', '£ 3.10', 'O', 3.10),
('', '8505', 'DIGAUDIOLOAN', 'Loan charge: Digital audiobook (Playaway)', '£ 3.10', 'O', 3.10),
('', '8504', 'DVDLOAN', 'Loan charge: DVD', '£ 2.25', 'O', 2.25),
('', '8503', 'CDLOAN', 'Loan charge: Music CD', '£ 1.55', 'O', 1.55),
('', '8623', 'LOSSADMIN', 'Lost or damaged admin. charge', '£ 2.10', 'O', 2.10),
('', '8623', 'LOSSREPLACE', 'Lost or damaged replacement costs', '£ -', 'O', NULL),
('RQ30', '8353', '3DBOOKMARKS', 'Merchandise: 3D Bookmarks', '£ 1.00', 'S', 1.00),
('', '8353', 'ACTIVITYBOOK', 'Merchandise: Activity book', '£ 1.50', 'E', 1.50),
('RQ30', '8353', 'BAGECO', 'Merchandise: Bag - Eco Chic', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'BAGREAD', 'Merchandise: Bag - Go Away I\'m Reading', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'BAGLOCAL', 'Merchandise: Bag - Love your Local Library', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'BAGIDEAL', 'Merchandise: Bag - My Ideal Library', '£ 7.99', 'S', 7.99),
('', '8353', 'HEADPHONES', 'Merchandise: Headphones', '£ 1.05', 'S', 1.05),
('RQ30', '8353', 'IFBOOKFAN', 'Merchandise: IF products - Book Fan', '£ 4.50', 'S', 4.50),
('RQ30', '8353', 'IFBOOKHOLDER', 'Merchandise: IF products - Bookholder', '£ 5.50', 'S', 5.50),
('RQ30', '8353', 'IFBOOKMARK50', 'Merchandise: IF products - Bookmark - 50 Books', '£ 3.00', 'S', 3.00),
('RQ30', '8353', 'IFBOOKTAILS', 'Merchandise: IF products - Bookmark - Book Tails', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'IFDOGEAR', 'Merchandise: IF products - Bookmark - Dog Ear', '£ 2.99', 'S', 2.99),
('RQ30', '8353', 'IFMRMEN', 'Merchandise: IF products - Bookmark - Mr Men', '£ 2.99', 'S', 2.99),
('RQ30', '8353', 'IFPAGEPOINT', 'Merchandise: IF products - Bookmark - Page Pointers', '£ 3.50', 'S', 3.50),
('RQ30', '8353', 'IFSEUSS', 'Merchandise: IF products - Bookmark - Seuss/Walliams', '£ 2.29', 'S', 2.29),
('RQ30', '8353', 'IFVA', 'Merchandise: IF products - Bookmark - V&A', '£ 2.99', 'S', 2.99),
('RQ30', '8353', 'IFLITTLEBOOK', 'Merchandise: IF products - Little Book Holder', '£ 2.99', 'S', 2.99),
('RQ30', '8353', 'IFMAGNIFCC', 'Merchandise: IF products - Magnif-i - credit card', '£ 2.49', 'S', 2.49),
('RQ30', '8353', 'IFMAGNIFSHEET', 'Merchandise: IF products - Magnif-i - magnifying sheets', '£ 3.49', 'S', 3.49),
('RQ30', '8353', 'IFMAGNIFLED', 'Merchandise: IF products - Magnif-i - pocket lighted LED', '£ 6.25', 'S', 6.25),
('RQ30', '8353', 'IFNOTEPADA5', 'Merchandise: IF products - Notepad - Bookaroo A5', '£ 5.99', 'S', 5.99),
('RQ30', '8353', 'IFSARDINES', 'Merchandise: IF products - Page Markers - Tin of Sardines', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'IFPOPUPBOOK', 'Merchandise: IF products - Pop up book end', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'IFTEETHMARKS', 'Merchandise: IF products - Teeth Marks', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'IFTINYLIGHT', 'Merchandise: IF products - Tiny Booklight', '£ 5.99', 'S', 5.99),
('', '8353', 'MAGNIFYSHEET', 'Merchandise: Magnifying Sheets/Bookmarks', '£ 2.50', 'S', 2.50),
('', '8353', 'MEMORYSTICK', 'Merchandise: Memory Stick', '£ 8.00', 'S', 8.00),
('RQ30', '8353', 'HEIGHTCHART', 'Merchandise: Miscellaneous - Height Chart', '£ 5.50', 'S', 5.50),
('RQ30', '8353', 'JIGSAW', 'Merchandise: Miscellaneous - Jigsaw Puzzle', '£ 14.99', 'S', 14.99),
('RQ30', '8353', 'MUGREAD', 'Merchandise: Miscellaneous - Mug - Go Away I\'m Reading', '£ 8.99', 'S', 8.99),
('RQ30', '8353', 'STATIONERY', 'Merchandise: Stationery', '£ -', 'S', NULL),
('RQ30', '8353', 'CENTBLACK', 'Merchandise: Stationery - Centenary: lined notebook (black)', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'CENTGOLD', 'Merchandise: Stationery - Centenary: lined notebook (gold)', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'CENTPLAIN', 'Merchandise: Stationery - Centenary: plain wiro notepad', '£ 3.99', 'S', 3.99),
('RQ30', '8353', 'CENTTOTE', 'Merchandise: Stationery - Centenary: tote bag', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'QUOTEPEN', 'Merchandise: Stationery - Inspirational Quote Pen', '£ 2.50', 'S', 2.50),
('RQ30', '8353', 'PENCILPEOPLE', 'Merchandise: Stationery - Pencil People', '£ 1.99', 'S', 1.99),
('RQ30', '8353', 'SLANTPADS', 'Merchandise: Stationery - Slant pads (Andrew Dandridge)', '£ 3.99', 'S', 3.99),
('RQ30', '8353', 'SPACESHUTTLE', 'Merchandise: Stationery - Space Shuttle Set', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'STICKYCATDOG', 'Merchandise: Stationery - Sticky Notes - Cat/Dog', '£ 4.99', 'S', 4.99),
('RQ30', '8353', 'STICKYTRANS', 'Merchandise: Stationery - Transparent Sticky Notes', '£ 3.29', 'S', 3.29),
('', '8353', 'WALLCHART', 'Merchandise: Wall charts', '£ 1.50', 'S', 1.50),
('', '8623', 'MISC', 'Miscellaneous Income', '', 'S', NULL),
('', '8623', 'MISCNONVAT', 'Miscellaneous Income non VAT', '', 'O', NULL),
('', '8501', 'FINES', 'Overdue charges (fines)', '£ -', 'O', NULL),
('', '8620', 'COURT', 'Overdue charges: Court costs', '£ -', 'O', NULL),
('', '8501', 'FINESFALLBACK', 'Overdue charges: fallback charges', '£ -', 'O', NULL),
('', '8507', 'PHOTOCOP', 'Photocopying', '£ -', 'S', NULL),
('', '8623', 'LOCALPRINT1', 'Printing: Local Society Printouts', '£ -', 'S', NULL),
('', '8623', 'LOCALPRINT2', 'Printing: Microprints', '£ 0.25', 'S', 0.25),
('', '8623', 'LOCALPUB', 'Publications for Sale: Books', '£ -', 'Z', NULL),
('', '8623', 'READINGGR1', 'Reading Group - 1 year Jan-Dec', '£ 38.00', 'S', 38.00),
('', '8623', 'READINGGR3', 'Reading Group - 3 months Oct-Dec', '£ 9.50', 'S', 9.50),
('', '8623', 'READINGGR6', 'Reading Group - 6 months Jul-Dec', '£ 19.00', 'S', 19.00),
('', '8623', 'READINGGR9', 'Reading Group - 9 months Apr-Dec', '£ 28.50', 'S', 28.50),
('', '8623', 'REPTICK', 'Replacement Library Card', '£ 2.10', 'O', 2.10),
('', '8502', 'REQUEST1', 'Reservation charges: request', '£ 1.00', 'O', 1.00),
('', '8502', 'REQUESTBL', 'Reservation charges: request British Library', '£ 12.50', 'O', 12.50),
('', '8502', 'REQUESTBLREN', 'Reservation charges: request British Library renewal', '£ 6.25', 'O', 6.25),
('', '8502', 'REQUESTILL', 'Reservation charges: request Inter-Library Loan (ILL)', '£ 7.75', 'O', 7.75),
('', '8502', 'SELFBOOK', 'Reservation charges: request online (SELFBOOK)', '', 'O', NULL),
('', '8502', 'STAFFBOOK', 'Reservation charges: request via staff (SELFBOOK)', '', 'O', NULL),
('', '8461', 'ROOM1', 'Room Hire - Group 1: Community', '£ -', 'E', NULL),
('', '8461', 'ROOM2', 'Room Hire - Group 2: Business', '£ -', 'E', NULL),
('', '8461', 'ROOM3', 'Room Hire - Group 3: Commercial', '£ -', 'E', NULL),
('', '8461', 'ROOMPOD1', 'Room Hire - Pod 1: Large (8-seater)', '£ -', 'E', NULL),
('', '8461', 'ROOMPOD2', 'Room Hire - Pod 2: Small (3-seater)', '£ -', 'E', NULL),
('', '8461', 'ROOMVAT1', 'Room Hire Including VAT - Group 1: Community', '£ -', 'S', NULL),
('', '8461', 'ROOMVAT2', 'Room Hire Including VAT - Group 2: Business', '£ -', 'S', NULL),
('', '8461', 'ROOMVAT3', 'Room Hire Including VAT - Group 3: Commercial', '£ -', 'S', NULL),
('', '8461', 'ROOMINS', 'Room Hire Insurance', '', 'E', NULL),
('', '8461', 'ROOMOOH', 'Room Hire Out of Hours Cover', '', 'E', NULL),
('RQ40', '8623', 'SCHOOLSLIB', 'Schools Library Service', '£ -', 'E', NULL),
('', '8623', 'PAYPHONE', 'Telephone charges', '£ -', 'S', NULL),
('', '8350', 'AVSALE', 'Withdrawn A/V for sale', '£ -', 'S', NULL),
('', '8350', 'BOOKSALE', 'Withdrawn books for sale', '£ -', 'Z', NULL),
('', '8623', 'POSURPLUS', 'Z: Post Office Surplus (ONLY USE IF ADVISED)', '', 'O', NULL);

-- Now insert into account_debit_types with proper mapping
INSERT INTO account_debit_types (
    code,
    description,
    can_be_invoiced,
    can_be_sold,
    default_amount,
    is_system,
    archived,
    restricts_checkouts
)
SELECT DISTINCT
    finance_code,
    description,
    CASE
        WHEN cost_amount IS NOT NULL AND cost_amount > 0 THEN 1
        ELSE 1
    END as can_be_invoiced,
    CASE
        WHEN description LIKE 'Merchandise:%' OR description LIKE 'Greetings Cards%' THEN 1
        ELSE 0
    END as can_be_sold,
    cost_amount,
    0 as is_system,
    0 as archived,
    CASE
        WHEN finance_code IN ('FINES', 'COURT', 'FINESFALLBACK', 'LOSSADMIN', 'LOSSREPLACE') THEN 1
        ELSE 0
    END as restricts_checkouts
FROM temp_debit_types
WHERE finance_code NOT IN (SELECT code COLLATE utf8mb4_general_ci FROM account_debit_types)
ORDER BY finance_code;

-- Get the additional field IDs we just created
SET @extra_code_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'Extra Code');
SET @subanalysis_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'Subanalysis');
SET @vat_code_field_id = (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types' AND name = 'VAT Code');

-- Insert additional field values for extra_code (where not empty)
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT DISTINCT
    @extra_code_field_id,
    finance_code,
    extra_code
FROM temp_debit_types
WHERE extra_code != '' AND extra_code IS NOT NULL
  AND finance_code NOT IN (
    SELECT record_id COLLATE utf8mb4_general_ci FROM additional_field_values WHERE field_id = @extra_code_field_id
  );

-- Insert additional field values for subanalysis (from income_code column in CSV)
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT DISTINCT
    @subanalysis_field_id,
    finance_code,
    income_code
FROM temp_debit_types
WHERE finance_code NOT IN (
    SELECT record_id COLLATE utf8mb4_general_ci FROM additional_field_values WHERE field_id = @subanalysis_field_id
  );

-- Insert additional field values for vat_code
INSERT INTO additional_field_values (field_id, record_id, value)
SELECT DISTINCT
    @vat_code_field_id,
    finance_code,
    vat_code
FROM temp_debit_types
WHERE finance_code NOT IN (
    SELECT record_id COLLATE utf8mb4_general_ci FROM additional_field_values WHERE field_id = @vat_code_field_id
  );

-- Clean up temporary table
DROP TEMPORARY TABLE temp_debit_types;

-- Display summary
SELECT 'Debit Types Import Complete' as Status;
SELECT 'Total debit types:' as Info, COUNT(*) as Count FROM account_debit_types WHERE is_system = 0;
SELECT 'Additional fields created:' as Info, COUNT(*) as Count FROM additional_fields WHERE tablename = 'account_debit_types';
SELECT 'Additional field values:' as Info, COUNT(*) as Count FROM additional_field_values
  WHERE field_id IN (SELECT id FROM additional_fields WHERE tablename = 'account_debit_types');

-- Show sample of imported data
SELECT
    dt.code,
    dt.description,
    dt.default_amount,
    dt.can_be_sold,
    (SELECT value FROM additional_field_values afv
     JOIN additional_fields af ON afv.field_id = af.id
     WHERE af.name = 'Extra Code' AND afv.record_id = dt.code LIMIT 1) as extra_code,
    (SELECT value FROM additional_field_values afv
     JOIN additional_fields af ON afv.field_id = af.id
     WHERE af.name = 'Subanalysis' AND afv.record_id = dt.code LIMIT 1) as subanalysis,
    (SELECT value FROM additional_field_values afv
     JOIN additional_fields af ON afv.field_id = af.id
     WHERE af.name = 'VAT Code' AND afv.record_id = dt.code LIMIT 1) as vat_code
FROM account_debit_types dt
WHERE dt.is_system = 0
ORDER BY dt.code
LIMIT 10;

