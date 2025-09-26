-- Generate test data for Oracle plugin acquisitions report testing
-- Run this in your ktd database: docker exec -i kohadev-db-1 mysql -u root -ppassword koha_kohadev < generate_test_data.sql

-- Insert test budget periods
INSERT INTO aqbudgetperiods (budget_period_id, budget_period_startdate, budget_period_enddate, budget_period_active, budget_period_description, budget_period_total, budget_period_locked, sort1_authcat, sort2_authcat) VALUES
(1, '2024-01-01', '2024-12-31', 1, 'Test Budget Period 2024', 50000.00, 0, '', '')
ON DUPLICATE KEY UPDATE budget_period_id = budget_period_id;

-- Insert test budgets with codes from the plugin mapping
INSERT INTO aqbudgets (budget_id, budget_code, budget_name, budget_amount, budget_period_id, budget_owner_id, budget_permission) VALUES
(1, 'KAFI', 'Fiction Budget', 5000.00, 1, 1, 0),
(2, 'KANF', 'Non-Fiction Budget', 5000.00, 1, 1, 0),
(3, 'KARC', 'Archive Budget', 3000.00, 1, 1, 0),
(4, 'KBAS', 'Basic Budget', 2000.00, 1, 1, 0),
(5, 'KERE', 'Reference Budget', 4000.00, 1, 1, 0),
(6, 'KHLS', 'Health Budget', 3000.00, 1, 1, 0),
(7, 'KPER', 'Periodicals Budget', 6000.00, 1, 1, 0)
ON DUPLICATE KEY UPDATE budget_id = budget_id;

-- Insert test vendors with WSCC prefix (as required by plugin filter)
INSERT INTO aqbooksellers (id, name, address1, address2, address3, address4, phone, active, listprice, invoiceprice, gstreg, listincgst, invoiceincgst, tax_rate, discount, deliverytime) VALUES
(1, 'WSCC Books & More Ltd', '123 Library Street', 'London', 'England', 'SW1A 1AA', '020-7123-4567', 1, 'GBP', 'GBP', 1, 1, 1, 0.20, 0.05, 7),
(2, 'WSCC Academic Publishers', '456 Academic Ave', 'Cambridge', 'England', 'CB2 1AA', '01223-123456', 1, 'GBP', 'GBP', 1, 1, 1, 0.20, 0.03, 10),
(3, 'WSCC Digital Resources', '789 Tech Park', 'Reading', 'England', 'RG1 2BB', '0118-987-6543', 1, 'GBP', 'GBP', 1, 1, 1, 0.20, 0.07, 5)
ON DUPLICATE KEY UPDATE id = id;

-- Insert test invoices with recent dates
INSERT INTO aqinvoices (invoiceid, invoicenumber, booksellerid, shipmentdate, billingdate, closedate, shipmentcost, shipmentcost_budgetid) VALUES
(1, 'INV-2024-001', 1, '2024-07-01', '2024-07-02', '2024-07-10', 15.50, 1),
(2, 'INV-2024-002', 2, '2024-07-05', '2024-07-06', '2024-07-12', 22.00, 2),
(3, 'INV-2024-003', 3, '2024-07-08', '2024-07-09', '2024-07-14', 8.75, 3),
(4, 'INV-2024-004', 1, '2024-07-10', '2024-07-11', '2024-07-13', 12.25, 4),
(5, 'INV-2024-005', 2, '2024-07-12', '2024-07-13', '2024-07-14', 18.50, 5)
ON DUPLICATE KEY UPDATE invoiceid = invoiceid;

-- Insert test baskets
INSERT INTO aqbasket (basketno, basketname, note, booksellernote, contractnumber, creationdate, closedate, booksellerid, authorisedby, basketgroupid, deliveryplace, billingplace, branch, is_standing, create_items) VALUES
(1, 'Test Basket 1', 'Test basket for fiction books', '', NULL, '2024-07-01', '2024-07-10', 1, 1, NULL, '', '', 'CPL', 0, 'ordering'),
(2, 'Test Basket 2', 'Test basket for non-fiction books', '', NULL, '2024-07-05', '2024-07-12', 2, 1, NULL, '', '', 'CPL', 0, 'ordering'),
(3, 'Test Basket 3', 'Test basket for archives', '', NULL, '2024-07-08', '2024-07-14', 3, 1, NULL, '', '', 'CPL', 0, 'ordering'),
(4, 'Test Basket 4', 'Test basket for basic materials', '', NULL, '2024-07-10', '2024-07-13', 1, 1, NULL, '', '', 'CPL', 0, 'ordering'),
(5, 'Test Basket 5', 'Test basket for reference materials', '', NULL, '2024-07-12', '2024-07-14', 2, 1, NULL, '', '', 'CPL', 0, 'ordering')
ON DUPLICATE KEY UPDATE basketno = basketno;

-- Insert test biblio records with proper titles for realistic descriptions
INSERT INTO biblio (biblionumber, title, author, copyrightdate, abstract, serial, seriestitle, notes, unititle, datecreated, timestamp) VALUES
(1, 'The Great Gatsby', 'F. Scott Fitzgerald', '1925', 'A classic American novel', 0, NULL, NULL, NULL, '2024-07-01', NOW()),
(2, 'To Kill a Mockingbird', 'Harper Lee', '1960', 'A novel about justice and morality', 0, NULL, NULL, NULL, '2024-07-01', NOW()),
(3, 'Advanced Mathematics', 'John Smith', '2023', 'University level mathematics textbook', 0, NULL, NULL, NULL, '2024-07-01', NOW()),
(4, 'Modern History of Britain', 'Sarah Johnson', '2024', 'Contemporary British history', 0, NULL, NULL, NULL, '2024-07-05', NOW()),
(5, 'Computer Science Fundamentals', 'David Brown', '2024', 'Introduction to computer science', 0, NULL, NULL, NULL, '2024-07-05', NOW()),
(6, 'Archives and Records Management', 'Mary Wilson', '2023', 'Professional archival practices', 0, NULL, NULL, NULL, '2024-07-08', NOW()),
(7, 'Local History Collection', 'Various Authors', '2024', 'Sussex local history materials', 0, NULL, NULL, NULL, '2024-07-08', NOW()),
(8, 'Basic Literature Guide', 'Emma Davis', '2024', 'Introduction to literature', 0, NULL, NULL, NULL, '2024-07-10', NOW()),
(9, 'Children\'s Picture Book', 'Robert Miller', '2024', 'Illustrated children\'s book', 0, NULL, NULL, NULL, '2024-07-10', NOW()),
(10, 'Research Methods in Science', 'Dr. Lisa Anderson', '2024', 'Scientific research methodology', 0, NULL, NULL, NULL, '2024-07-12', NOW()),
(11, 'Health and Wellness Today', 'Dr. Michael Thompson', '2024', 'Contemporary health practices', 0, NULL, NULL, NULL, '2024-07-12', NOW()),
(12, 'Academic Periodicals Subscription', 'Various Publishers', '2024', 'Annual subscription to academic journals', 1, NULL, NULL, NULL, '2024-07-12', NOW())
ON DUPLICATE KEY UPDATE biblionumber = biblionumber;

-- Insert test orders with different tax rates and prices
INSERT INTO aqorders (ordernumber, biblionumber, entrydate, quantity, currency, listprice, datereceived, invoiceid, freight, unitprice, unitprice_tax_excluded, unitprice_tax_included, quantityreceived, basketno, budget_id, tax_rate_on_receiving, tax_value_on_receiving, orderstatus) VALUES
-- Invoice 1 orders
(1, 1, '2024-07-01', 1, 'GBP', 25.99, '2024-07-10', 1, 0.00, 25.99, 21.66, 25.99, 1, 1, 1, 0.20, 4.33, 'complete'),
(2, 2, '2024-07-01', 2, 'GBP', 15.50, '2024-07-10', 1, 0.00, 15.50, 15.50, 15.50, 2, 1, 1, 0.00, 0.00, 'complete'),
(3, 3, '2024-07-01', 1, 'GBP', 45.00, '2024-07-10', 1, 0.00, 45.00, 37.50, 45.00, 1, 1, 1, 0.20, 7.50, 'complete'),

-- Invoice 2 orders
(4, 4, '2024-07-05', 1, 'GBP', 32.99, '2024-07-12', 2, 0.00, 32.99, 27.49, 32.99, 1, 2, 2, 0.20, 5.50, 'complete'),
(5, 5, '2024-07-05', 3, 'GBP', 18.75, '2024-07-12', 2, 0.00, 18.75, 18.75, 18.75, 3, 2, 2, 0.00, 0.00, 'complete'),

-- Invoice 3 orders
(6, 6, '2024-07-08', 1, 'GBP', 65.00, '2024-07-14', 3, 0.00, 65.00, 54.17, 65.00, 1, 3, 3, 0.20, 10.83, 'complete'),
(7, 7, '2024-07-08', 2, 'GBP', 22.50, '2024-07-14', 3, 0.00, 22.50, 22.50, 22.50, 2, 3, 3, 0.00, 0.00, 'complete'),

-- Invoice 4 orders
(8, 8, '2024-07-10', 1, 'GBP', 28.99, '2024-07-13', 4, 0.00, 28.99, 24.16, 28.99, 1, 4, 4, 0.20, 4.83, 'complete'),
(9, 9, '2024-07-10', 1, 'GBP', 12.99, '2024-07-13', 4, 0.00, 12.99, 12.99, 12.99, 1, 4, 4, 0.00, 0.00, 'complete'),

-- Invoice 5 orders (using different budgets)
(10, 10, '2024-07-12', 1, 'GBP', 89.99, '2024-07-14', 5, 0.00, 89.99, 74.99, 89.99, 1, 5, 5, 0.20, 15.00, 'complete'),
(11, 11, '2024-07-12', 2, 'GBP', 35.50, '2024-07-14', 5, 0.00, 35.50, 35.50, 35.50, 2, 5, 6, 0.00, 0.00, 'complete'),
(12, 12, '2024-07-12', 1, 'GBP', 125.00, '2024-07-14', 5, 0.00, 125.00, 104.17, 125.00, 1, 5, 7, 0.20, 20.83, 'complete')
ON DUPLICATE KEY UPDATE ordernumber = ordernumber;

-- Display summary of created test data
SELECT 'Test Data Summary' as Info;
SELECT 'Vendors created:' as Type, COUNT(*) as Count FROM aqbooksellers WHERE name LIKE 'WSCC%';
SELECT 'Invoices created:' as Type, COUNT(*) as Count FROM aqinvoices WHERE invoiceid IN (1,2,3,4,5);
SELECT 'Orders created:' as Type, COUNT(*) as Count FROM aqorders WHERE invoiceid IN (1,2,3,4,5);
SELECT 'Budgets created:' as Type, COUNT(*) as Count FROM aqbudgets WHERE budget_id IN (1,2,3,4,5,6,7);

-- Show invoice totals for verification
SELECT 
    i.invoicenumber,
    b.name as vendor_name,
    i.closedate,
    COUNT(o.ordernumber) as order_count,
    SUM(o.unitprice) as total_value,
    SUM(o.tax_value_on_receiving) as total_tax
FROM aqinvoices i
JOIN aqbooksellers b ON i.booksellerid = b.id
LEFT JOIN aqorders o ON i.invoiceid = o.invoiceid
WHERE i.invoiceid IN (1,2,3,4,5)
GROUP BY i.invoiceid, i.invoicenumber, b.name, i.closedate
ORDER BY i.invoicenumber;