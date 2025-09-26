-- Load comprehensive income test data for Oracle plugin testing
-- This script creates realistic payment scenarios using existing debit types and libraries

-- Get some existing borrowers from different libraries
SET @borrower_aw = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'AW' LIMIT 1);
SET @borrower_bn = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'BN' LIMIT 1); 
SET @borrower_bw = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'BW' LIMIT 1);
SET @borrower_cn = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'CN' LIMIT 1);
SET @borrower_cw = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'CW' LIMIT 1);

-- If no borrowers exist, create some test borrowers
INSERT IGNORE INTO borrowers (borrowernumber, cardnumber, surname, firstname, branchcode, categorycode, userid, password)
SELECT 999991, 'TEST001', 'Test', 'User1', 'AW', 'PT', 'testuser1', 'password'
WHERE NOT EXISTS (SELECT 1 FROM borrowers WHERE branchcode = 'AW' LIMIT 1);

INSERT IGNORE INTO borrowers (borrowernumber, cardnumber, surname, firstname, branchcode, categorycode, userid, password)
SELECT 999992, 'TEST002', 'Test', 'User2', 'BN', 'PT', 'testuser2', 'password'
WHERE NOT EXISTS (SELECT 1 FROM borrowers WHERE branchcode = 'BN' LIMIT 1);

INSERT IGNORE INTO borrowers (borrowernumber, cardnumber, surname, firstname, branchcode, categorycode, userid, password)
SELECT 999993, 'TEST003', 'Test', 'User3', 'BW', 'PT', 'testuser3', 'password'
WHERE NOT EXISTS (SELECT 1 FROM borrowers WHERE branchcode = 'BW' LIMIT 1);

INSERT IGNORE INTO borrowers (borrowernumber, cardnumber, surname, firstname, branchcode, categorycode, userid, password)
SELECT 999994, 'TEST004', 'Test', 'User4', 'CN', 'PT', 'testuser4', 'password'
WHERE NOT EXISTS (SELECT 1 FROM borrowers WHERE branchcode = 'CN' LIMIT 1);

INSERT IGNORE INTO borrowers (borrowernumber, cardnumber, surname, firstname, branchcode, categorycode, userid, password)
SELECT 999995, 'TEST005', 'Test', 'User5', 'CW', 'PT', 'testuser5', 'password'
WHERE NOT EXISTS (SELECT 1 FROM borrowers WHERE branchcode = 'CW' LIMIT 1);

-- Update our variables to use existing or created borrowers
SET @borrower_aw = COALESCE(@borrower_aw, 999991);
SET @borrower_bn = COALESCE(@borrower_bn, 999992);
SET @borrower_bw = COALESCE(@borrower_bw, 999993);
SET @borrower_cn = COALESCE(@borrower_cn, 999994);
SET @borrower_cw = COALESCE(@borrower_cw, 999995);

-- Create realistic debit transactions (charges) using actual debit types from the database
INSERT INTO accountlines (
    borrowernumber, 
    date, 
    amount, 
    description, 
    debit_type_code, 
    amountoutstanding, 
    timestamp, 
    interface, 
    branchcode
) VALUES
-- Overdue fines across different libraries
(@borrower_aw, '2025-01-15', 2.50, 'Overdue fine for "Pride and Prejudice"', 'FINES', 0.00, '2025-01-15 09:00:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-15', 5.00, 'Overdue fine for "The Great Gatsby"', 'FINES', 0.00, '2025-01-15 10:30:00', 'intranet', 'BN'),
(@borrower_bw, '2025-01-16', 7.50, 'Overdue fine for "To Kill a Mockingbird"', 'FINES', 0.00, '2025-01-16 14:15:00', 'intranet', 'BW'),
(@borrower_cn, '2025-01-17', 3.75, 'Overdue fine for "1984"', 'FINES', 0.00, '2025-01-17 11:45:00', 'intranet', 'CN'),
(@borrower_cw, '2025-01-18', 6.25, 'Overdue fine for "Brave New World"', 'FINES', 0.00, '2025-01-18 16:20:00', 'intranet', 'CW'),

-- Photocopying charges
(@borrower_aw, '2025-01-15', 4.50, 'Photocopying - 15 pages', 'PHOTOCOP', 0.00, '2025-01-15 13:30:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-16', 3.20, 'Photocopying - 8 pages', 'PHOTOCOP', 0.00, '2025-01-16 15:45:00', 'intranet', 'BN'),
(@borrower_bw, '2025-01-17', 6.80, 'Photocopying - 17 pages', 'PHOTOCOP', 0.00, '2025-01-17 10:15:00', 'intranet', 'BW'),
(@borrower_cn, '2025-01-18', 2.40, 'Photocopying - 6 pages', 'PHOTOCOP', 0.00, '2025-01-18 12:30:00', 'intranet', 'CN'),

-- Computer printing charges
(@borrower_aw, '2025-01-16', 1.80, 'Computer printing - 6 pages', 'PRINTING', 0.00, '2025-01-16 09:15:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-17', 3.60, 'Computer printing - 12 pages', 'PRINTING', 0.00, '2025-01-17 14:45:00', 'intranet', 'BN'),
(@borrower_cw, '2025-01-18', 2.70, 'Computer printing - 9 pages', 'PRINTING', 0.00, '2025-01-18 08:30:00', 'intranet', 'CW'),

-- Room hire charges
(@borrower_aw, '2025-01-17', 25.00, 'Group Study Room - 2 hours', 'ROOM1', 0.00, '2025-01-17 09:00:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-18', 50.00, 'Business Meeting Room - 4 hours', 'ROOM2', 0.00, '2025-01-18 10:00:00', 'intranet', 'BN'),
(@borrower_bw, '2025-01-19', 15.00, 'Small Pod - 1 hour', 'ROOMPOD2', 0.00, '2025-01-19 13:00:00', 'intranet', 'BW'),

-- Lost item replacement costs
(@borrower_cn, '2025-01-16', 12.99, 'Lost book replacement - "Digital Photography"', 'LOSSREPLACE', 0.00, '2025-01-16 11:00:00', 'intranet', 'CN'),
(@borrower_cw, '2025-01-17', 8.50, 'Lost book replacement - "Local History Guide"', 'LOSSREPLACE', 0.00, '2025-01-17 15:30:00', 'intranet', 'CW'),

-- Reservation/request charges
(@borrower_aw, '2025-01-18', 1.50, 'Book reservation charge', 'REQUEST1', 0.00, '2025-01-18 14:00:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-19', 3.00, 'Inter-library loan request', 'REQUESTILL', 0.00, '2025-01-19 10:30:00', 'intranet', 'BN'),

-- Event tickets
(@borrower_bw, '2025-01-20', 8.00, 'Author talk ticket - "Local Writers Evening"', 'EVENTS', 0.00, '2025-01-20 16:00:00', 'intranet', 'BW'),
(@borrower_cn, '2025-01-20', 12.00, 'Workshop ticket - "Digital Skills for Seniors"', 'EVENTS', 0.00, '2025-01-20 09:45:00', 'intranet', 'CN'),

-- Merchandise sales
(@borrower_cw, '2025-01-19', 3.50, 'Library bag purchase', 'BAGREAD', 0.00, '2025-01-19 11:15:00', 'intranet', 'CW'),
(@borrower_aw, '2025-01-20', 2.25, 'Bookmark set purchase', 'IFBOOKTAILS', 0.00, '2025-01-20 13:45:00', 'intranet', 'AW'),

-- Current week transactions for testing recent data
(@borrower_bn, CURDATE(), 4.20, 'Current day photocopying', 'PHOTOCOP', 0.00, NOW(), 'intranet', 'BN'),
(@borrower_bw, CURDATE(), 1.50, 'Current day overdue fine', 'FINES', 0.00, NOW(), 'intranet', 'BW'),
(@borrower_cn, CURDATE(), 30.00, 'Current day room hire', 'ROOM1', 0.00, NOW(), 'intranet', 'CN');

-- Now create corresponding payment transactions (credits) for these charges
INSERT INTO accountlines (
    borrowernumber, 
    date, 
    amount, 
    description, 
    credit_type_code, 
    payment_type, 
    amountoutstanding, 
    timestamp, 
    interface, 
    branchcode
) VALUES
-- Cash payments for fines
(@borrower_aw, '2025-01-15', -2.50, 'Cash payment for overdue fine', 'PAYMENT', 'CASH', 0.00, '2025-01-15 09:15:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-15', -5.00, 'Cash payment for overdue fine', 'PAYMENT', 'CASH', 0.00, '2025-01-15 10:45:00', 'intranet', 'BN'),
(@borrower_bw, '2025-01-16', -7.50, 'Card payment for overdue fine', 'PAYMENT', 'VISA', 0.00, '2025-01-16 14:30:00', 'intranet', 'BW'),
(@borrower_cn, '2025-01-17', -3.75, 'Card payment for overdue fine', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-17 12:00:00', 'intranet', 'CN'),
(@borrower_cw, '2025-01-18', -6.25, 'Cash payment for overdue fine', 'PAYMENT', 'CASH', 0.00, '2025-01-18 16:35:00', 'intranet', 'CW'),

-- Payments for photocopying
(@borrower_aw, '2025-01-15', -4.50, 'Cash payment for photocopying', 'PAYMENT', 'CASH', 0.00, '2025-01-15 13:45:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-16', -3.20, 'Card payment for photocopying', 'PAYMENT', 'VISA', 0.00, '2025-01-16 16:00:00', 'intranet', 'BN'),
(@borrower_bw, '2025-01-17', -6.80, 'Cash payment for photocopying', 'PAYMENT', 'CASH', 0.00, '2025-01-17 10:30:00', 'intranet', 'BW'),
(@borrower_cn, '2025-01-18', -2.40, 'Card payment for photocopying', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-18 12:45:00', 'intranet', 'CN'),

-- Payments for printing
(@borrower_aw, '2025-01-16', -1.80, 'Cash payment for printing', 'PAYMENT', 'CASH', 0.00, '2025-01-16 09:30:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-17', -3.60, 'Card payment for printing', 'PAYMENT', 'VISA', 0.00, '2025-01-17 15:00:00', 'intranet', 'BN'),
(@borrower_cw, '2025-01-18', -2.70, 'Cash payment for printing', 'PAYMENT', 'CASH', 0.00, '2025-01-18 08:45:00', 'intranet', 'CW'),

-- Payments for room hire
(@borrower_aw, '2025-01-17', -25.00, 'Card payment for room hire', 'PAYMENT', 'VISA', 0.00, '2025-01-17 09:15:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-18', -50.00, 'Card payment for room hire', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-18 10:15:00', 'intranet', 'BN'),
(@borrower_bw, '2025-01-19', -15.00, 'Cash payment for room hire', 'PAYMENT', 'CASH', 0.00, '2025-01-19 13:15:00', 'intranet', 'BW'),

-- Payments for lost items
(@borrower_cn, '2025-01-16', -12.99, 'Card payment for lost item', 'PAYMENT', 'VISA', 0.00, '2025-01-16 11:15:00', 'intranet', 'CN'),
(@borrower_cw, '2025-01-17', -8.50, 'Cash payment for lost item', 'PAYMENT', 'CASH', 0.00, '2025-01-17 15:45:00', 'intranet', 'CW'),

-- Payments for reservations
(@borrower_aw, '2025-01-18', -1.50, 'Cash payment for reservation', 'PAYMENT', 'CASH', 0.00, '2025-01-18 14:15:00', 'intranet', 'AW'),
(@borrower_bn, '2025-01-19', -3.00, 'Card payment for ILL request', 'PAYMENT', 'VISA', 0.00, '2025-01-19 10:45:00', 'intranet', 'BN'),

-- Payments for events
(@borrower_bw, '2025-01-20', -8.00, 'Card payment for event ticket', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-20 16:15:00', 'intranet', 'BW'),
(@borrower_cn, '2025-01-20', -12.00, 'Cash payment for workshop ticket', 'PAYMENT', 'CASH', 0.00, '2025-01-20 10:00:00', 'intranet', 'CN'),

-- Payments for merchandise
(@borrower_cw, '2025-01-19', -3.50, 'Cash payment for library bag', 'PAYMENT', 'CASH', 0.00, '2025-01-19 11:30:00', 'intranet', 'CW'),
(@borrower_aw, '2025-01-20', -2.25, 'Card payment for bookmarks', 'PAYMENT', 'VISA', 0.00, '2025-01-20 14:00:00', 'intranet', 'AW'),

-- Kiosk payments (self-service payments)
(@borrower_bn, '2025-01-21', -15.00, 'Kiosk payment for combined services', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-21 12:00:00', 'self_check', 'BN'),
(@borrower_bw, '2025-01-21', -8.75, 'Kiosk payment for fines and printing', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-21 14:30:00', 'self_check', 'BW'),

-- Current day payments
(@borrower_bn, CURDATE(), -4.20, 'Cash payment for current day photocopying', 'PAYMENT', 'CASH', 0.00, NOW(), 'intranet', 'BN'),
(@borrower_bw, CURDATE(), -1.50, 'Card payment for current day fine', 'PAYMENT', 'VISA', 0.00, NOW(), 'intranet', 'BW'),
(@borrower_cn, CURDATE(), -30.00, 'Card payment for current day room hire', 'PAYMENT', 'MASTERCARD', 0.00, NOW(), 'intranet', 'CN');

-- Now create the offset entries that link payments to charges
-- This is crucial for the cashup methodology to work

-- Get debit IDs for linking (using a more robust approach)
SET @debit_fine_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND debit_type_code = 'FINES' AND amount = 2.50 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @debit_fine_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND debit_type_code = 'FINES' AND amount = 5.00 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @debit_fine_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND debit_type_code = 'FINES' AND amount = 7.50 AND DATE(date) = '2025-01-16' LIMIT 1);
SET @debit_fine_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND debit_type_code = 'FINES' AND amount = 3.75 AND DATE(date) = '2025-01-17' LIMIT 1);
SET @debit_fine_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND debit_type_code = 'FINES' AND amount = 6.25 AND DATE(date) = '2025-01-18' LIMIT 1);

-- Get corresponding payment IDs
SET @payment_fine_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND credit_type_code = 'PAYMENT' AND amount = -2.50 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @payment_fine_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND credit_type_code = 'PAYMENT' AND amount = -5.00 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @payment_fine_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND credit_type_code = 'PAYMENT' AND amount = -7.50 AND DATE(date) = '2025-01-16' LIMIT 1);
SET @payment_fine_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND credit_type_code = 'PAYMENT' AND amount = -3.75 AND DATE(date) = '2025-01-17' LIMIT 1);
SET @payment_fine_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND credit_type_code = 'PAYMENT' AND amount = -6.25 AND DATE(date) = '2025-01-18' LIMIT 1);

-- Create offset entries for fine payments
INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_fine_aw, @debit_fine_aw, 'APPLY', -2.50, '2025-01-15 09:15:00'),
(@payment_fine_bn, @debit_fine_bn, 'APPLY', -5.00, '2025-01-15 10:45:00'),
(@payment_fine_bw, @debit_fine_bw, 'APPLY', -7.50, '2025-01-16 14:30:00'),
(@payment_fine_cn, @debit_fine_cn, 'APPLY', -3.75, '2025-01-17 12:00:00'),
(@payment_fine_cw, @debit_fine_cw, 'APPLY', -6.25, '2025-01-18 16:35:00');

-- Get photocopying debit and payment IDs and create offsets
SET @debit_photo_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND debit_type_code = 'PHOTOCOP' AND amount = 4.50 LIMIT 1);
SET @payment_photo_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND credit_type_code = 'PAYMENT' AND amount = -4.50 LIMIT 1);
SET @debit_photo_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND debit_type_code = 'PHOTOCOP' AND amount = 3.20 LIMIT 1);
SET @payment_photo_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND credit_type_code = 'PAYMENT' AND amount = -3.20 LIMIT 1);
SET @debit_photo_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND debit_type_code = 'PHOTOCOP' AND amount = 6.80 LIMIT 1);
SET @payment_photo_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND credit_type_code = 'PAYMENT' AND amount = -6.80 LIMIT 1);
SET @debit_photo_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND debit_type_code = 'PHOTOCOP' AND amount = 2.40 LIMIT 1);
SET @payment_photo_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND credit_type_code = 'PAYMENT' AND amount = -2.40 LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_photo_aw, @debit_photo_aw, 'APPLY', -4.50, '2025-01-15 13:45:00'),
(@payment_photo_bn, @debit_photo_bn, 'APPLY', -3.20, '2025-01-16 16:00:00'),
(@payment_photo_bw, @debit_photo_bw, 'APPLY', -6.80, '2025-01-17 10:30:00'),
(@payment_photo_cn, @debit_photo_cn, 'APPLY', -2.40, '2025-01-18 12:45:00');

-- Get printing debit and payment IDs and create offsets
SET @debit_print_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND debit_type_code = 'PRINTING' AND amount = 1.80 LIMIT 1);
SET @payment_print_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND credit_type_code = 'PAYMENT' AND amount = -1.80 LIMIT 1);
SET @debit_print_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND debit_type_code = 'PRINTING' AND amount = 3.60 LIMIT 1);
SET @payment_print_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND credit_type_code = 'PAYMENT' AND amount = -3.60 LIMIT 1);
SET @debit_print_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND debit_type_code = 'PRINTING' AND amount = 2.70 LIMIT 1);
SET @payment_print_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND credit_type_code = 'PAYMENT' AND amount = -2.70 LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_print_aw, @debit_print_aw, 'APPLY', -1.80, '2025-01-16 09:30:00'),
(@payment_print_bn, @debit_print_bn, 'APPLY', -3.60, '2025-01-17 15:00:00'),
(@payment_print_cw, @debit_print_cw, 'APPLY', -2.70, '2025-01-18 08:45:00');

-- Get room hire debit and payment IDs and create offsets
SET @debit_room_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND debit_type_code = 'ROOM1' AND amount = 25.00 LIMIT 1);
SET @payment_room_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND credit_type_code = 'PAYMENT' AND amount = -25.00 LIMIT 1);
SET @debit_room_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND debit_type_code = 'ROOM2' AND amount = 50.00 LIMIT 1);
SET @payment_room_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND credit_type_code = 'PAYMENT' AND amount = -50.00 LIMIT 1);
SET @debit_room_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND debit_type_code = 'ROOMPOD2' AND amount = 15.00 LIMIT 1);
SET @payment_room_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND credit_type_code = 'PAYMENT' AND amount = -15.00 LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_room_aw, @debit_room_aw, 'APPLY', -25.00, '2025-01-17 09:15:00'),
(@payment_room_bn, @debit_room_bn, 'APPLY', -50.00, '2025-01-18 10:15:00'),
(@payment_room_bw, @debit_room_bw, 'APPLY', -15.00, '2025-01-19 13:15:00');

-- Create offsets for lost item payments
SET @debit_lost_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND debit_type_code = 'LOSSREPLACE' AND amount = 12.99 LIMIT 1);
SET @payment_lost_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND credit_type_code = 'PAYMENT' AND amount = -12.99 LIMIT 1);
SET @debit_lost_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND debit_type_code = 'LOSSREPLACE' AND amount = 8.50 LIMIT 1);
SET @payment_lost_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND credit_type_code = 'PAYMENT' AND amount = -8.50 LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_lost_cn, @debit_lost_cn, 'APPLY', -12.99, '2025-01-16 11:15:00'),
(@payment_lost_cw, @debit_lost_cw, 'APPLY', -8.50, '2025-01-17 15:45:00');

-- Create offsets for reservation payments
SET @debit_res_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND debit_type_code = 'REQUEST1' AND amount = 1.50 LIMIT 1);
SET @payment_res_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND credit_type_code = 'PAYMENT' AND amount = -1.50 LIMIT 1);
SET @debit_res_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND debit_type_code = 'REQUESTILL' AND amount = 3.00 LIMIT 1);
SET @payment_res_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND credit_type_code = 'PAYMENT' AND amount = -3.00 LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_res_aw, @debit_res_aw, 'APPLY', -1.50, '2025-01-18 14:15:00'),
(@payment_res_bn, @debit_res_bn, 'APPLY', -3.00, '2025-01-19 10:45:00');

-- Create offsets for event payments
SET @debit_event_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND debit_type_code = 'EVENTS' AND amount = 8.00 LIMIT 1);
SET @payment_event_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND credit_type_code = 'PAYMENT' AND amount = -8.00 LIMIT 1);
SET @debit_event_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND debit_type_code = 'EVENTS' AND amount = 12.00 LIMIT 1);
SET @payment_event_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND credit_type_code = 'PAYMENT' AND amount = -12.00 LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_event_bw, @debit_event_bw, 'APPLY', -8.00, '2025-01-20 16:15:00'),
(@payment_event_cn, @debit_event_cn, 'APPLY', -12.00, '2025-01-20 10:00:00');

-- Create offsets for merchandise payments
SET @debit_merc_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND debit_type_code = 'BAGREAD' AND amount = 3.50 LIMIT 1);
SET @payment_merc_cw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cw AND credit_type_code = 'PAYMENT' AND amount = -3.50 LIMIT 1);
SET @debit_merc_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND debit_type_code = 'IFBOOKTAILS' AND amount = 2.25 LIMIT 1);
SET @payment_merc_aw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_aw AND credit_type_code = 'PAYMENT' AND amount = -2.25 LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_merc_cw, @debit_merc_cw, 'APPLY', -3.50, '2025-01-19 11:30:00'),
(@payment_merc_aw, @debit_merc_aw, 'APPLY', -2.25, '2025-01-20 14:00:00');

-- Create offsets for current day payments
SET @debit_curr_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND debit_type_code = 'PHOTOCOP' AND amount = 4.20 AND DATE(date) = CURDATE() LIMIT 1);
SET @payment_curr_bn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bn AND credit_type_code = 'PAYMENT' AND amount = -4.20 AND DATE(date) = CURDATE() LIMIT 1);
SET @debit_curr_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND debit_type_code = 'FINES' AND amount = 1.50 AND DATE(date) = CURDATE() LIMIT 1);
SET @payment_curr_bw = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_bw AND credit_type_code = 'PAYMENT' AND amount = -1.50 AND DATE(date) = CURDATE() LIMIT 1);
SET @debit_curr_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND debit_type_code = 'ROOM1' AND amount = 30.00 AND DATE(date) = CURDATE() LIMIT 1);
SET @payment_curr_cn = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower_cn AND credit_type_code = 'PAYMENT' AND amount = -30.00 AND DATE(date) = CURDATE() LIMIT 1);

INSERT INTO account_offsets (credit_id, debit_id, type, amount, created_on) VALUES
(@payment_curr_bn, @debit_curr_bn, 'APPLY', -4.20, NOW()),
(@payment_curr_bw, @debit_curr_bw, 'APPLY', -1.50, NOW()),
(@payment_curr_cn, @debit_curr_cn, 'APPLY', -30.00, NOW());

-- Show summary of what was created
SELECT 
    'Summary' as info,
    'Credits (Payments)' as transaction_type,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM accountlines 
WHERE credit_type_code IS NOT NULL 
    AND date >= '2025-01-15'
    
UNION ALL

SELECT 
    'Summary' as info,
    'Debits (Charges)' as transaction_type,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM accountlines 
WHERE debit_type_code IS NOT NULL 
    AND date >= '2025-01-15'
    
UNION ALL

SELECT 
    'Summary' as info,
    'Offsets (Money Movement)' as transaction_type,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM account_offsets 
WHERE created_on >= '2025-01-15';

-- Show what the income report will process
SELECT 
    'Income Report Preview' as type,
    c.branchcode,
    c.credit_type_code,
    d.debit_type_code,
    c.payment_type,
    DATE(c.date) as transaction_date,
    COUNT(*) as transaction_count,
    SUM(o.amount) as total_offset_amount
FROM account_offsets o
JOIN accountlines c ON c.accountlines_id = o.credit_id
JOIN accountlines d ON d.accountlines_id = o.debit_id
WHERE c.debit_type_code IS NULL
    AND c.amount < 0
    AND c.date >= '2025-01-15'
    AND c.description NOT LIKE '%Pay360%'
GROUP BY c.branchcode, c.credit_type_code, d.debit_type_code, c.payment_type, DATE(c.date)
ORDER BY transaction_date, c.branchcode, d.debit_type_code;