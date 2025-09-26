-- Generate sample income data for testing the income report
-- This script creates realistic payment/credit transactions across multiple libraries

-- First, get some existing borrowers to use for the transactions
SET @borrower1 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'CPL' LIMIT 1);
SET @borrower2 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'FFL' LIMIT 1);
SET @borrower3 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'MPL' LIMIT 1);
SET @borrower4 = (SELECT borrowernumber FROM borrowers WHERE branchcode = 'SPL' LIMIT 1);

-- Create sample income transactions for different libraries and payment types
-- Using different credit types to simulate various income sources

-- CPL (Centerville) - Card payments and cash
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
-- Card terminal payments
(@borrower1, '2025-01-15', 12.50, 'Photocopy fees - card terminal', 'PAYMENT', 'VISA', 0.00, '2025-01-15 10:30:00', 'intranet', 'CPL'),
(@borrower1, '2025-01-15', 8.00, 'Printing fees - card terminal', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-15 11:15:00', 'intranet', 'CPL'),
(@borrower1, '2025-01-15', 15.25, 'Room booking - card terminal', 'PAYMENT', 'VISA', 0.00, '2025-01-15 14:20:00', 'intranet', 'CPL'),

-- Cash payments
(@borrower1, '2025-01-15', 5.00, 'Photocopy fees - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-15 09:45:00', 'intranet', 'CPL'),
(@borrower1, '2025-01-15', 3.50, 'Printing fees - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-15 16:30:00', 'intranet', 'CPL'),

-- Card kiosk payments
(@borrower1, '2025-01-16', 10.00, 'Library fines - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-16 12:00:00', 'self_check', 'CPL'),
(@borrower1, '2025-01-16', 7.75, 'Lost item replacement - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-16 15:45:00', 'self_check', 'CPL');

-- FFL (Fairfield) - Mixed payment types
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
-- Card terminal payments
(@borrower2, '2025-01-15', 20.00, 'Meeting room rental - card terminal', 'PAYMENT', 'VISA', 0.00, '2025-01-15 13:30:00', 'intranet', 'FFL'),
(@borrower2, '2025-01-15', 6.25, 'Laminating services - card terminal', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-15 14:45:00', 'intranet', 'FFL'),

-- Cash payments
(@borrower2, '2025-01-16', 4.00, 'Photocopying - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-16 10:15:00', 'intranet', 'FFL'),
(@borrower2, '2025-01-16', 8.50, 'Binding services - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-16 11:30:00', 'intranet', 'FFL'),

-- Card kiosk payments
(@borrower2, '2025-01-17', 12.00, 'Overdue fines - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-17 09:20:00', 'self_check', 'FFL'),
(@borrower2, '2025-01-17', 25.00, 'Interlibrary loan fees - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-17 16:10:00', 'self_check', 'FFL');

-- MPL (Midway) - Focus on different service types
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
-- Card terminal payments
(@borrower3, '2025-01-16', 30.00, 'Training course fee - card terminal', 'PAYMENT', 'VISA', 0.00, '2025-01-16 08:45:00', 'intranet', 'MPL'),
(@borrower3, '2025-01-16', 15.50, 'Equipment rental - card terminal', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-16 13:15:00', 'intranet', 'MPL'),

-- Cash payments
(@borrower3, '2025-01-17', 7.00, 'Scanning services - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-17 11:00:00', 'intranet', 'MPL'),
(@borrower3, '2025-01-17', 9.25, 'Research assistance - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-17 14:30:00', 'intranet', 'MPL'),

-- Card kiosk payments
(@borrower3, '2025-01-18', 18.00, 'Lost card replacement - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-18 10:45:00', 'self_check', 'MPL'),
(@borrower3, '2025-01-18', 22.50, 'Damage fees - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-18 15:20:00', 'self_check', 'MPL');

-- SPL (Springfield) - Various services
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
-- Card terminal payments
(@borrower4, '2025-01-17', 45.00, 'Conference room booking - card terminal', 'PAYMENT', 'VISA', 0.00, '2025-01-17 09:00:00', 'intranet', 'SPL'),
(@borrower4, '2025-01-17', 12.75, 'Printing services - card terminal', 'PAYMENT', 'MASTERCARD', 0.00, '2025-01-17 12:30:00', 'intranet', 'SPL'),

-- Cash payments
(@borrower4, '2025-01-18', 6.50, 'Fax services - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-18 08:30:00', 'intranet', 'SPL'),
(@borrower4, '2025-01-18', 14.00, 'Library membership - cash', 'PAYMENT', 'CASH', 0.00, '2025-01-18 10:00:00', 'intranet', 'SPL'),

-- Card kiosk payments
(@borrower4, '2025-01-19', 35.00, 'Event tickets - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-19 11:15:00', 'self_check', 'SPL'),
(@borrower4, '2025-01-19', 8.25, 'Storage locker rental - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, '2025-01-19 16:45:00', 'self_check', 'SPL');

-- Add some Purchase credits (different from payments)
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
(@borrower1, '2025-01-20', 25.00, 'Book purchase - card terminal', 'PURCHASE', 'VISA', 0.00, '2025-01-20 10:00:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-20', 18.50, 'Magazine subscription - cash', 'PURCHASE', 'CASH', 0.00, '2025-01-20 11:30:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-20', 32.00, 'DVD purchase - card terminal', 'PURCHASE', 'MASTERCARD', 0.00, '2025-01-20 14:15:00', 'intranet', 'MPL'),
(@borrower4, '2025-01-20', 15.75, 'Audiobook purchase - card kiosk', 'PURCHASE', 'KIOSK_CARD', 0.00, '2025-01-20 16:00:00', 'self_check', 'SPL');

-- Add some refunds to show variety
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
(@borrower1, '2025-01-21', 5.00, 'Overpayment refund - photocopying', 'REFUND', NULL, 0.00, '2025-01-21 09:30:00', 'intranet', 'CPL'),
(@borrower2, '2025-01-21', 12.00, 'Cancelled booking refund', 'REFUND', NULL, 0.00, '2025-01-21 13:45:00', 'intranet', 'FFL'),
(@borrower3, '2025-01-21', 8.50, 'Processing fee refund - lost item found', 'PROCESSING_FOUND', NULL, 0.00, '2025-01-21 15:20:00', 'intranet', 'MPL');

-- Add some credits for the current week to test recent data
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
(@borrower1, CURDATE(), 10.00, 'Today printing fee - card terminal', 'PAYMENT', 'VISA', 0.00, NOW(), 'intranet', 'CPL'),
(@borrower2, CURDATE(), 15.00, 'Today room booking - cash', 'PAYMENT', 'CASH', 0.00, NOW(), 'intranet', 'FFL'),
(@borrower3, CURDATE(), 7.50, 'Today scanning - card kiosk', 'PAYMENT', 'KIOSK_CARD', 0.00, NOW(), 'self_check', 'MPL'),
(@borrower4, CURDATE(), 20.00, 'Today event fee - card terminal', 'PAYMENT', 'MASTERCARD', 0.00, NOW(), 'intranet', 'SPL');

-- Show results
SELECT 
    branchcode,
    credit_type_code,
    payment_type,
    DATE(timestamp) as transaction_date,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount
FROM accountlines 
WHERE amount > 0 
    AND credit_type_code IS NOT NULL 
    AND timestamp >= '2025-01-15 00:00:00'
GROUP BY branchcode, credit_type_code, payment_type, DATE(timestamp)
ORDER BY branchcode, transaction_date, credit_type_code, payment_type;