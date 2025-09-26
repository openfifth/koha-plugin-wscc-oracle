-- Simple income test data with proper offsets using existing debit types

-- Get some existing borrowers
SET @borrower1 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'CPL' LIMIT 1);
SET @borrower2 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'FFL' LIMIT 1);
SET @borrower3 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'MPL' LIMIT 1);
SET @borrower4 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'SPL' LIMIT 1);

-- Create some debit transactions first (charges)
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
(@borrower1, '2025-01-15', 5.00, 'Overdue fine for library book', 'OVERDUE', 0.00, '2025-01-15 09:00:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-15', 8.00, 'Overdue fine for reference manual', 'OVERDUE', 0.00, '2025-01-15 10:00:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-16', 12.00, 'Overdue fine for academic journal', 'OVERDUE', 0.00, '2025-01-16 11:00:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-17', 15.00, 'Overdue fine for research paper', 'OVERDUE', 0.00, '2025-01-17 12:00:00', 'intranet', 'SPL'),

-- Lost item charges
(@borrower1, '2025-01-16', 25.00, 'Lost item replacement cost', 'LOST', 0.00, '2025-01-16 14:00:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-17', 18.50, 'Lost DVD replacement cost', 'LOST', 0.00, '2025-01-17 15:00:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-18', 32.00, 'Lost textbook replacement cost', 'LOST', 0.00, '2025-01-18 16:00:00', 'intranet', 'MPL'),

-- Manual fees (for services like printing, copying, room booking)
(@borrower1, '2025-01-15', 3.50, 'Printing charges', 'MANUAL', 0.00, '2025-01-15 13:00:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-16', 7.25, 'Photocopying charges', 'MANUAL', 0.00, '2025-01-16 14:30:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-17', 4.75, 'Binding charges', 'MANUAL', 0.00, '2025-01-17 15:30:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-18', 6.00, 'Laminating charges', 'MANUAL', 0.00, '2025-01-18 16:30:00', 'intranet', 'SPL'),

-- Rental fees (for room booking, equipment)
(@borrower1, '2025-01-17', 20.00, 'Meeting room rental', 'RENT', 0.00, '2025-01-17 09:30:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-18', 35.00, 'Conference room rental', 'RENT', 0.00, '2025-01-18 10:30:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-19', 15.00, 'Study room rental', 'RENT', 0.00, '2025-01-19 11:30:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-19', 12.75, 'Equipment rental', 'RENT', 0.00, '2025-01-19 13:00:00', 'intranet', 'SPL');

-- Get the IDs of some debit transactions
SET @debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'OVERDUE' AND amount = 5.00 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'OVERDUE' AND amount = 8.00 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @debit3 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower3 AND debit_type_code = 'OVERDUE' AND amount = 12.00 AND DATE(date) = '2025-01-16' LIMIT 1);
SET @debit4 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower4 AND debit_type_code = 'OVERDUE' AND amount = 15.00 AND DATE(date) = '2025-01-17' LIMIT 1);

SET @lost_debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'LOST' AND amount = 25.00 AND DATE(date) = '2025-01-16' LIMIT 1);
SET @lost_debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'LOST' AND amount = 18.50 AND DATE(date) = '2025-01-17' LIMIT 1);

SET @manual_debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'MANUAL' AND amount = 3.50 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @manual_debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'MANUAL' AND amount = 7.25 AND DATE(date) = '2025-01-16' LIMIT 1);

SET @rent_debit1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND debit_type_code = 'RENT' AND amount = 20.00 AND DATE(date) = '2025-01-17' LIMIT 1);
SET @rent_debit2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND debit_type_code = 'RENT' AND amount = 35.00 AND DATE(date) = '2025-01-18' LIMIT 1);

-- Create payment transactions (credits)
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
-- Simple one-to-one payments
(@borrower1, '2025-01-15', -5.00, 'Cash payment for overdue fine', 'PAYMENT', 'CASH', 0.00, '2025-01-15 09:15:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-15', -8.00, 'Cash payment for overdue fine', 'PAYMENT', 'CASH', 0.00, '2025-01-15 10:15:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-16', -12.00, 'Card payment for overdue fine', 'PAYMENT', 'VISA', 0.00, '2025-01-16 11:15:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-17', -15.00, 'Card payment for overdue fine', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-17 12:15:00', 'intranet', 'SPL'),

-- Combined payments
(@borrower1, '2025-01-16', -28.50, 'Card payment for lost item and printing', 'PAYMENT', 'VISA', 0.00, '2025-01-16 14:15:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-17', -25.75, 'Card payment for lost item and copying', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-17 15:15:00', 'intranet', 'FFL'),
(@borrower1, '2025-01-17', -20.00, 'Cash payment for room rental', 'PAYMENT', 'CASH', 0.00, '2025-01-17 09:45:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-18', -35.00, 'Kiosk payment for room rental', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-18 10:45:00', 'self_check', 'FFL');

-- Get payment IDs
SET @payment1 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND credit_type_code = 'PAYMENT' AND amount = -5.00 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @payment2 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND credit_type_code = 'PAYMENT' AND amount = -8.00 AND DATE(date) = '2025-01-15' LIMIT 1);
SET @payment3 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower3 AND credit_type_code = 'PAYMENT' AND amount = -12.00 AND DATE(date) = '2025-01-16' LIMIT 1);
SET @payment4 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower4 AND credit_type_code = 'PAYMENT' AND amount = -15.00 AND DATE(date) = '2025-01-17' LIMIT 1);

SET @payment5 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND credit_type_code = 'PAYMENT' AND amount = -28.50 AND DATE(date) = '2025-01-16' LIMIT 1);
SET @payment6 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND credit_type_code = 'PAYMENT' AND amount = -25.75 AND DATE(date) = '2025-01-17' LIMIT 1);
SET @payment7 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower1 AND credit_type_code = 'PAYMENT' AND amount = -20.00 AND DATE(date) = '2025-01-17' LIMIT 1);
SET @payment8 = (SELECT accountlines_id FROM accountlines WHERE borrowernumber = @borrower2 AND credit_type_code = 'PAYMENT' AND amount = -35.00 AND DATE(date) = '2025-01-18' LIMIT 1);

-- Create offset entries linking payments to charges
INSERT INTO account_offsets (
    credit_id,
    debit_id,
    type,
    amount,
    created_on
) VALUES
-- Simple one-to-one offsets
(@payment1, @debit1, 'APPLY', -5.00, '2025-01-15 09:15:00'),
(@payment2, @debit2, 'APPLY', -8.00, '2025-01-15 10:15:00'),
(@payment3, @debit3, 'APPLY', -12.00, '2025-01-16 11:15:00'),
(@payment4, @debit4, 'APPLY', -15.00, '2025-01-17 12:15:00'),

-- Combined payment offsets
(@payment5, @lost_debit1, 'APPLY', -25.00, '2025-01-16 14:15:00'),
(@payment5, @manual_debit1, 'APPLY', -3.50, '2025-01-16 14:15:00'),

(@payment6, @lost_debit2, 'APPLY', -18.50, '2025-01-17 15:15:00'),
(@payment6, @manual_debit2, 'APPLY', -7.25, '2025-01-17 15:15:00'),

(@payment7, @rent_debit1, 'APPLY', -20.00, '2025-01-17 09:45:00'),
(@payment8, @rent_debit2, 'APPLY', -35.00, '2025-01-18 10:45:00');

-- Show the results
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

-- Show what the income report will see
SELECT 
    'Income Report Data' as type,
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