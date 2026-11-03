-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 3, Step 0: Set up demo data for the transaction tests
-- =====================================================================

DROP INDEX IF EXISTS uq_one_open_loan_per_copy;
DELETE FROM fine        WHERE fine_id = 90001
                           OR loan_id IN (SELECT loan_id FROM loan WHERE copy_id = 90001);
DELETE FROM loan        WHERE copy_id = 90001;
DELETE FROM book_copy   WHERE copy_id = 90001;
DELETE FROM book_author WHERE book_id = 90001;
DELETE FROM book        WHERE book_id = 90001;

-- The demo book and its single copy (held at Central Branch)
INSERT INTO book (book_id, isbn, title, publisher, publication_year, category, item_type)
VALUES (90001, '978-9999999999', 'Things Fall Apart (Demo Copy)', 'Heinemann', 1958, 'Fiction', 'Book');

INSERT INTO book_copy (copy_id, book_id, branch_id, status)
VALUES (90001, 90001, 1, 'Available');

-- A past loan, returned 5 days late, with an unpaid fine of 250.00.
-- loan_id 900001 is used because the sample data already contains
-- loan IDs 1 to 203,000.
INSERT INTO loan (loan_id, copy_id, member_id, staff_id, borrow_date, due_date, return_date)
VALUES (900001, 90001, 303, 1, DATE '2026-01-01', DATE '2026-01-15', DATE '2026-01-20');

INSERT INTO fine (fine_id, loan_id, amount, paid_status)
VALUES (90001, 900001, 250.00, 'Unpaid');

-- Verification
SELECT c.copy_id, b.title, c.status,
       (SELECT COUNT(*) FROM loan l
        WHERE l.copy_id = c.copy_id AND l.return_date IS NULL) AS open_loans,
       (SELECT amount || ' ' || paid_status FROM fine WHERE fine_id = 90001) AS demo_fine
FROM book_copy c
JOIN book b ON b.book_id = c.book_id
WHERE c.copy_id = 90001;
