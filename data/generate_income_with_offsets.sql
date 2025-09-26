-- Generate sample income data with proper offsets for testing the income report
-- This script creates realistic payment/credit transactions with the offset entries
-- that track actual money movement, as required by the cashup methodology

-- First, let's create some debit transactions (what the money was for)
-- These represent fines, fees, and other charges that can be paid

-- Get some existing borrowers to use for the transactions
SET @borrower1 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'CPL' LIMIT 1);
SET @borrower2 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'FFL' LIMIT 1);
SET @borrower3 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'MPL' LIMIT 1);
SET @borrower4 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'SPL' LIMIT 1);

-- Create some debit transactions first (charges that can be paid)
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
-- Overdue fines
(@borrower1, '2025-01-15', 5.00, 'Overdue fine for "Library Book"', 'OVERDUE', 0.00, '2025-01-15 09:00:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-15', 8.00, 'Overdue fine for "Reference Manual"', 'OVERDUE', 0.00, '2025-01-15 10:00:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-16', 12.00, 'Overdue fine for "Academic Journal"', 'OVERDUE', 0.00, '2025-01-16 11:00:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-17', 15.00, 'Overdue fine for "Research Paper"', 'OVERDUE', 0.00, '2025-01-17 12:00:00', 'intranet', 'SPL'),

-- Lost item charges
(@borrower1, '2025-01-16', 25.00, 'Lost item charge for "Missing Book"', 'LOST', 0.00, '2025-01-16 14:00:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-17', 18.50, 'Lost item charge for "DVD Set"', 'LOST', 0.00, '2025-01-17 15:00:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-18', 32.00, 'Lost item charge for "Textbook"', 'LOST', 0.00, '2025-01-18 16:00:00', 'intranet', 'MPL'),

-- Printing and copying charges
(@borrower1, '2025-01-15', 3.50, 'Printing charges', 'PRINTING', 0.00, '2025-01-15 13:00:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-16', 7.25, 'Photocopying charges', 'COPYING', 0.00, '2025-01-16 14:30:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-17', 4.75, 'Binding charges', 'BINDING', 0.00, '2025-01-17 15:30:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-18', 6.00, 'Laminating charges', 'LAMINATING', 0.00, '2025-01-18 16:30:00', 'intranet', 'SPL'),

-- Room booking charges
(@borrower1, '2025-01-17', 20.00, 'Meeting room booking', 'ROOM_BOOKING', 0.00, '2025-01-17 09:30:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-18', 35.00, 'Conference room booking', 'ROOM_BOOKING', 0.00, '2025-01-18 10:30:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-19', 15.00, 'Study room booking', 'ROOM_BOOKING', 0.00, '2025-01-19 11:30:00', 'intranet', 'MPL'),

-- Equipment rental charges
(@borrower4, '2025-01-19', 12.75, 'Laptop rental', 'EQUIPMENT', 0.00, '2025-01-19 13:00:00', 'intranet', 'SPL'),
(@borrower1, '2025-01-20', 8.25, 'Projector rental', 'EQUIPMENT', 0.00, '2025-01-20 14:00:00', 'intranet', 'CPL'),

-- Course and training fees
(@borrower2, '2025-01-20', 45.00, 'Computer training course', 'TRAINING', 0.00, '2025-01-20 15:00:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-21', 30.00, 'Research workshop', 'TRAINING', 0.00, '2025-01-21 16:00:00', 'intranet', 'MPL');

-- Now create the credit transactions (payments) that pay off these debits
-- These will be linked via offsets to show actual money movement

-- Get the IDs of the debit transactions we just created
SET @debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'OVERDUE' AND amount = 5.00);
SET @debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'OVERDUE' AND amount = 8.00);
SET @debit3 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower3 AND debit_type_code = 'OVERDUE' AND amount = 12.00);
SET @debit4 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower4 AND debit_type_code = 'OVERDUE' AND amount = 15.00);

-- Create payment transactions
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
-- Cash payments
(@borrower1, '2025-01-15', -5.00, 'Cash payment for overdue fine', 'PAYMENT', 'CASH', 0.00, '2025-01-15 09:15:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-15', -8.00, 'Cash payment for overdue fine', 'PAYMENT', 'CASH', 0.00, '2025-01-15 10:15:00', 'intranet', 'FFL'),

-- Card terminal payments
(@borrower3, '2025-01-16', -12.00, 'Card payment for overdue fine', 'PAYMENT', 'VISA', 0.00, '2025-01-16 11:15:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-17', -15.00, 'Card payment for overdue fine', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-17 12:15:00', 'intranet', 'SPL');

-- Get the IDs of the payment transactions we just created
SET @payment1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND credit_type_code = 'PAYMENT' AND amount = -5.00);
SET @payment2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND credit_type_code = 'PAYMENT' AND amount = -8.00);
SET @payment3 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower3 AND credit_type_code = 'PAYMENT' AND amount = -12.00);
SET @payment4 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower4 AND credit_type_code = 'PAYMENT' AND amount = -15.00);

-- Create the offset entries that link payments to charges
-- These show the actual money movement and are what the cashup system uses
INSERT INTO account_offsets (
    credit_id,
    debit_id,
    type,
    amount,
    created_on
) VALUES
(@payment1, @debit1, 'Payment', -5.00, '2025-01-15 09:15:00'),
(@payment2, @debit2, 'Payment', -8.00, '2025-01-15 10:15:00'),
(@payment3, @debit3, 'Payment', -12.00, '2025-01-16 11:15:00'),
(@payment4, @debit4, 'Payment', -15.00, '2025-01-17 12:15:00');

-- Add more complex scenarios with partial payments and multiple charges
-- Get more debit IDs
SET @lost_debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'LOST' AND amount = 25.00);
SET @lost_debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'LOST' AND amount = 18.50);
SET @printing_debit = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'PRINTING' AND amount = 3.50);
SET @copying_debit = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'COPYING' AND amount = 7.25);
SET @room_debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'ROOM_BOOKING' AND amount = 20.00);
SET @room_debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'ROOM_BOOKING' AND amount = 35.00);

-- Create more payment transactions
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
-- Mixed payments combining different charge types
(@borrower1, '2025-01-16', -28.50, 'Card payment for lost item and printing', 'PAYMENT', 'VISA', 0.00, '2025-01-16 14:15:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-17', -25.75, 'Card payment for lost item and copying', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-17 15:15:00', 'intranet', 'FFL'),
(@borrower1, '2025-01-17', -20.00, 'Cash payment for room booking', 'PAYMENT', 'CASH', 0.00, '2025-01-17 09:45:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-18', -35.00, 'Kiosk payment for room booking', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-18 10:45:00', 'self_check', 'FFL');

-- Get IDs of the new payments
SET @payment5 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND credit_type_code = 'PAYMENT' AND amount = -28.50);
SET @payment6 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND credit_type_code = 'PAYMENT' AND amount = -25.75);
SET @payment7 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND credit_type_code = 'PAYMENT' AND amount = -20.00);
SET @payment8 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND credit_type_code = 'PAYMENT' AND amount = -35.00);

-- Create corresponding offsets for the complex payments
INSERT INTO account_offsets (
    credit_id,
    debit_id,
    type,
    amount,
    created_on
) VALUES
-- Payment 5 covers lost item (25.00) and printing (3.50) = 28.50
(@payment5, @lost_debit1, 'Payment', -25.00, '2025-01-16 14:15:00'),
(@payment5, @printing_debit, 'Payment', -3.50, '2025-01-16 14:15:00'),

-- Payment 6 covers lost item (18.50) and copying (7.25) = 25.75
(@payment6, @lost_debit2, 'Payment', -18.50, '2025-01-17 15:15:00'),
(@payment6, @copying_debit, 'Payment', -7.25, '2025-01-17 15:15:00'),

-- Payment 7 covers room booking
(@payment7, @room_debit1, 'Payment', -20.00, '2025-01-17 09:45:00'),

-- Payment 8 covers room booking
(@payment8, @room_debit2, 'Payment', -35.00, '2025-01-18 10:45:00');

-- Add some current day transactions
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
(@borrower1, CURDATE(), 10.00, 'Current day overdue fine', 'OVERDUE', 0.00, NOW(), 'intranet', 'CPL'),
(@borrower2, CURDATE(), 15.00, 'Current day printing charges', 'PRINTING', 0.00, NOW(), 'intranet', 'FFL');

-- Pay them immediately
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
(@borrower1, CURDATE(), -10.00, 'Cash payment for current day fine', 'PAYMENT', 'CASH', 0.00, NOW(), 'intranet', 'CPL'),
(@borrower2, CURDATE(), -15.00, 'Card payment for current day printing', 'PAYMENT', 'VISA', 0.00, NOW(), 'intranet', 'FFL');

-- Get the IDs and create offsets
SET @current_debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'OVERDUE' AND amount = 10.00 AND DATE(date) = CURDATE());
SET @current_debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'PRINTING' AND amount = 15.00 AND DATE(date) = CURDATE());
SET @current_payment1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND credit_type_code = 'PAYMENT' AND amount = -10.00 AND DATE(date) = CURDATE());
SET @current_payment2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND credit_type_code = 'PAYMENT' AND amount = -15.00 AND DATE(date) = CURDATE());

INSERT INTO account_offsets (
    credit_id,
    debit_id,
    type,
    amount,
    created_on
) VALUES
(@current_payment1, @current_debit1, 'Payment', -10.00, NOW()),
(@current_payment2, @current_debit2, 'Payment', -15.00, NOW());

-- Show summary of what we created
SELECT 
    'Credits (Payments)' as transaction_type,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM accountlines 
WHERE credit_type_code IS NOT NULL 
    AND date >= '2025-01-15'

UNION ALL

SELECT 
    'Debits (Charges)' as transaction_type,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM accountlines 
WHERE debit_type_code IS NOT NULL 
    AND date >= '2025-01-15'

UNION ALL

SELECT 
    'Offsets (Money Movement)' as transaction_type,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM account_offsets 
WHERE created_on >= '2025-01-15';

-- Show the data that the income report will now see
SELECT 
    'Income Report Data' as report_type,
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
ORDER BY transaction_date, c.branchcode;