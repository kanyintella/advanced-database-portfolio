-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 3, Step 1: COMMIT, ROLLBACK and SAVEPOINT
-- =====================================================================
-- Uses ONE Query Tool tab. Run 00_setup.sql first.
-- Highlight each numbered block and press F5.
-- Screenshot the VERIFY result after each demo.
-- =====================================================================


-- =====================================================================
-- DEMO 1: COMMIT — borrowing a book
-- Borrowing needs TWO changes: create a loan AND mark the copy as
-- On Loan. A transaction makes them succeed together.
-- =====================================================================

-- 1a. Start the transaction and borrow the copy for member 101
BEGIN;
INSERT INTO loan (copy_id, member_id, staff_id, due_date)
VALUES (90001, 101, 1, CURRENT_DATE + 14);
UPDATE book_copy SET status = 'On Loan' WHERE copy_id = 90001;

-- 1b. Make the changes permanent
COMMIT;

-- 1c. VERIFY: the copy is On Loan and member 101 has an open loan
SELECT c.copy_id, c.status, l.loan_id, l.member_id, l.borrow_date, l.due_date
FROM book_copy c
LEFT JOIN loan l ON l.copy_id = c.copy_id AND l.return_date IS NULL
WHERE c.copy_id = 90001;


-- =====================================================================
-- DEMO 2: ROLLBACK — undoing a mistake
-- A librarian starts processing a return for the wrong book and
-- cancels before committing. Nothing is saved.
-- =====================================================================

-- 2a. Start processing a return
BEGIN;
UPDATE loan SET return_date = CURRENT_DATE
WHERE copy_id = 90001 AND return_date IS NULL;
UPDATE book_copy SET status = 'Available' WHERE copy_id = 90001;

-- 2b. Inside the transaction, the changes are visible...
SELECT copy_id, status FROM book_copy WHERE copy_id = 90001;

-- 2c. ...but the librarian cancels
ROLLBACK;

-- 2d. VERIFY: still On Loan, and the loan is still open
SELECT c.copy_id, c.status, l.loan_id, l.member_id, l.return_date
FROM book_copy c
LEFT JOIN loan l ON l.copy_id = c.copy_id AND l.return_date IS NULL
WHERE c.copy_id = 90001;


-- =====================================================================
-- DEMO 3: Automatic rollback on error (ATOMICITY)
-- A return is processed, but recording the fine fails because the
-- amount breaks the CHECK (amount > 0) constraint. Because all three
-- steps are in one transaction, the return is cancelled too.
-- The database never ends up "half updated".
-- =====================================================================

-- 3a. Process the return (these two statements succeed)
BEGIN;
UPDATE loan SET return_date = CURRENT_DATE
WHERE copy_id = 90001 AND return_date IS NULL;
UPDATE book_copy SET status = 'Available' WHERE copy_id = 90001;

-- 3b. Record a fine with an invalid amount -> ERROR (expected)
INSERT INTO fine (loan_id, amount)
SELECT loan_id, -50.00 FROM loan
WHERE copy_id = 90001 AND return_date = CURRENT_DATE;

-- 3c. The transaction is now aborted; end it.
-- (If pgAdmin already rolled back automatically, this just shows a
--  "no transaction in progress" warning, which is fine.)
ROLLBACK;

-- 3d. VERIFY: still On Loan and the loan is still open.
-- The two successful updates were undone along with the failed insert.
SELECT c.copy_id, c.status, l.loan_id, l.member_id, l.return_date
FROM book_copy c
LEFT JOIN loan l ON l.copy_id = c.copy_id AND l.return_date IS NULL
WHERE c.copy_id = 90001;


-- =====================================================================
-- DEMO 4: SAVEPOINT — undoing only part of a transaction
-- The book is returned ON TIME, but the librarian adds a fine by
-- mistake. Rolling back to the savepoint removes only the fine and
-- keeps the return.
-- =====================================================================

-- 4a. Process the return and set a savepoint
BEGIN;
UPDATE loan SET return_date = CURRENT_DATE
WHERE copy_id = 90001 AND return_date IS NULL;
UPDATE book_copy SET status = 'Available' WHERE copy_id = 90001;
SAVEPOINT before_fine;

-- 4b. Mistakenly add a fine
INSERT INTO fine (loan_id, amount)
SELECT loan_id, 100.00 FROM loan
WHERE copy_id = 90001 AND return_date = CURRENT_DATE;

-- 4c. Undo only the fine, then commit the return
ROLLBACK TO SAVEPOINT before_fine;
COMMIT;

-- 4d. VERIFY: copy Available, loan returned today, and no fine on it
SELECT l.loan_id, l.member_id, l.return_date, c.status,
       (SELECT COUNT(*) FROM fine f WHERE f.loan_id = l.loan_id) AS fines_on_loan
FROM loan l
JOIN book_copy c ON c.copy_id = l.copy_id
WHERE l.copy_id = 90001 AND l.member_id = 101;
