-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 2, Step 3: Query optimisation with indexes
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 0: Reset, so the BEFORE measurements have no custom indexes.
-- (Primary key and UNIQUE indexes always exist and are not removed.)
-- ---------------------------------------------------------------------
DROP INDEX IF EXISTS idx_loan_member_id;
DROP INDEX IF EXISTS idx_loan_overdue;
DROP INDEX IF EXISTS idx_loan_borrow_date;


-- =====================================================================
-- EXPERIMENT 1: Member loan history (Q1)
-- Filter: WHERE l.member_id = 1234
-- PostgreSQL does NOT automatically index foreign key columns, so
-- without an index it must scan all 203,000 loans to find ~25 rows.
-- =====================================================================

-- 1a. BEFORE
EXPLAIN ANALYZE
SELECT l.loan_id, b.title, l.borrow_date, l.due_date, l.return_date
FROM loan l
JOIN book_copy c ON c.copy_id = l.copy_id
JOIN book b      ON b.book_id = c.book_id
WHERE l.member_id = 1234
ORDER BY l.borrow_date DESC;

-- 1b. Create a B-tree index on the foreign key
CREATE INDEX idx_loan_member_id ON loan (member_id);

-- 1c. AFTER (same query)
EXPLAIN ANALYZE
SELECT l.loan_id, b.title, l.borrow_date, l.due_date, l.return_date
FROM loan l
JOIN book_copy c ON c.copy_id = l.copy_id
JOIN book b      ON b.book_id = c.book_id
WHERE l.member_id = 1234
ORDER BY l.borrow_date DESC;


-- =====================================================================
-- EXPERIMENT 2: Overdue loans report (Q2)
-- Filter: WHERE return_date IS NULL AND due_date < CURRENT_DATE
-- Only about 3,000 of 203,000 loans are still open. A PARTIAL index
-- stores only those open loans, so it stays small and fast even as
-- the history of returned loans keeps growing.
-- =====================================================================

-- 2a. BEFORE
EXPLAIN ANALYZE
SELECT l.loan_id, m.first_name, m.last_name, b.title, br.name,
       l.due_date, CURRENT_DATE - l.due_date AS days_overdue
FROM loan l
JOIN member m    ON m.member_id  = l.member_id
JOIN book_copy c ON c.copy_id    = l.copy_id
JOIN book b      ON b.book_id    = c.book_id
JOIN branch br   ON br.branch_id = c.branch_id
WHERE l.return_date IS NULL
  AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;

-- 2b. Create a partial index covering only open loans
CREATE INDEX idx_loan_overdue ON loan (due_date) WHERE return_date IS NULL;

-- 2c. AFTER (same query)
EXPLAIN ANALYZE
SELECT l.loan_id, m.first_name, m.last_name, b.title, br.name,
       l.due_date, CURRENT_DATE - l.due_date AS days_overdue
FROM loan l
JOIN member m    ON m.member_id  = l.member_id
JOIN book_copy c ON c.copy_id    = l.copy_id
JOIN book b      ON b.book_id    = c.book_id
JOIN branch br   ON br.branch_id = c.branch_id
WHERE l.return_date IS NULL
  AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;


-- =====================================================================
-- EXPERIMENT 3: Top borrowed titles in the last 12 months (Q3)
-- Filter: WHERE borrow_date >= CURRENT_DATE - 12 months
-- This filter matches about 30% of all loans, which is NOT very
-- selective. Compare this result with Experiments 1 and 2: an index
-- helps far less when a query needs a large share of the table.
-- =====================================================================

-- 3a. BEFORE
EXPLAIN ANALYZE
SELECT b.title, COUNT(*) AS times_borrowed
FROM loan l
JOIN book_copy c ON c.copy_id = l.copy_id
JOIN book b      ON b.book_id = c.book_id
WHERE l.borrow_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY b.book_id, b.title
ORDER BY times_borrowed DESC
LIMIT 10;

-- 3b. Create an index on borrow_date
CREATE INDEX idx_loan_borrow_date ON loan (borrow_date);

-- 3c. AFTER (same query)
EXPLAIN ANALYZE
SELECT b.title, COUNT(*) AS times_borrowed
FROM loan l
JOIN book_copy c ON c.copy_id = l.copy_id
JOIN book b      ON b.book_id = c.book_id
WHERE l.borrow_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY b.book_id, b.title
ORDER BY times_borrowed DESC
LIMIT 10;


-- =====================================================================
-- STEP 4: List the indexes now on the loan table, and their sizes
-- =====================================================================
SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
       indexdef
FROM pg_indexes
WHERE tablename = 'loan'
ORDER BY indexname;
