-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 2, Step 2: Business queries
-- =====================================================================
-- Each query answers a real question the library needs answered.
-- In pgAdmin, highlight ONE query at a time and press F5 to run it,
-- so the result grid shows that query's output.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Member loan history
-- "Show everything member 1234 has borrowed, newest first."
-- Used at the front desk and in the member's online account.
-- ---------------------------------------------------------------------
SELECT l.loan_id,
       b.title,
       br.name        AS branch,
       l.borrow_date,
       l.due_date,
       l.return_date,
       CASE WHEN l.return_date IS NULL THEN 'Still on loan'
            WHEN l.return_date > l.due_date THEN 'Returned late'
            ELSE 'Returned on time' END AS loan_status
FROM loan l
JOIN book_copy c ON c.copy_id   = l.copy_id
JOIN book b      ON b.book_id   = c.book_id
JOIN branch br   ON br.branch_id = c.branch_id
WHERE l.member_id = 1234
ORDER BY l.borrow_date DESC;


-- ---------------------------------------------------------------------
-- Q2. Overdue loans report
-- "Which books are overdue right now, who has them, and by how long?"
-- Run daily by librarians to send reminders.
-- ---------------------------------------------------------------------
SELECT l.loan_id,
       m.first_name || ' ' || m.last_name AS member_name,
       m.email,
       b.title,
       br.name                    AS branch,
       l.due_date,
       CURRENT_DATE - l.due_date  AS days_overdue
FROM loan l
JOIN member m    ON m.member_id  = l.member_id
JOIN book_copy c ON c.copy_id    = l.copy_id
JOIN book b      ON b.book_id    = c.book_id
JOIN branch br   ON br.branch_id = c.branch_id
WHERE l.return_date IS NULL
  AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;


-- ---------------------------------------------------------------------
-- Q3. Top 10 most borrowed titles in the last 12 months
-- "What should we buy more copies of?"
-- ---------------------------------------------------------------------
SELECT b.title,
       b.category,
       COUNT(*) AS times_borrowed
FROM loan l
JOIN book_copy c ON c.copy_id = l.copy_id
JOIN book b      ON b.book_id = c.book_id
WHERE l.borrow_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY b.book_id, b.title, b.category
ORDER BY times_borrowed DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q4. Members with the highest unpaid fines
-- "Who owes the library the most money?"
-- ---------------------------------------------------------------------
SELECT m.member_id,
       m.first_name || ' ' || m.last_name AS member_name,
       COUNT(f.fine_id)  AS unpaid_fines,
       SUM(f.amount)     AS total_owed
FROM fine f
JOIN loan l   ON l.loan_id   = f.loan_id
JOIN member m ON m.member_id = l.member_id
WHERE f.paid_status = 'Unpaid'
GROUP BY m.member_id, member_name
HAVING SUM(f.amount) > 1000
ORDER BY total_owed DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- Q5. Catalogue search by author
-- "Which books by an author named Achebe do we have?"
-- STRING_AGG combines co-authors into one line per book.
-- ---------------------------------------------------------------------
SELECT b.isbn,
       b.title,
       b.publication_year,
       STRING_AGG(a.first_name || ' ' || a.last_name, ', ') AS authors
FROM book b
JOIN book_author ba ON ba.book_id  = b.book_id
JOIN author a       ON a.author_id = ba.author_id
WHERE b.book_id IN (
    SELECT ba2.book_id
    FROM book_author ba2
    JOIN author a2 ON a2.author_id = ba2.author_id
    WHERE a2.last_name = 'Achebe'
)
GROUP BY b.book_id, b.isbn, b.title, b.publication_year
ORDER BY b.title;


-- ---------------------------------------------------------------------
-- Q6. Stock levels per branch
-- "How many copies does each branch hold, and how many are available?"
-- FILTER counts only the rows that match each condition.
-- ---------------------------------------------------------------------
SELECT br.name AS branch,
       COUNT(*)                                        AS total_copies,
       COUNT(*) FILTER (WHERE c.status = 'Available')  AS available,
       COUNT(*) FILTER (WHERE c.status = 'On Loan')    AS on_loan,
       COUNT(*) FILTER (WHERE c.status IN ('Lost', 'Damaged')) AS lost_or_damaged
FROM book_copy c
JOIN branch br ON br.branch_id = c.branch_id
GROUP BY br.branch_id, br.name
ORDER BY br.name;
