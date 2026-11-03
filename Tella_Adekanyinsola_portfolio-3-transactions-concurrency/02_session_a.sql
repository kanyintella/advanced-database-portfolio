-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 3, Step 2: Concurrency — SESSION A
-- =====================================================================

-- =====================================================================
-- DEMO 5: THE PROBLEM — two librarians borrow the last copy
-- Both check the copy, both see "Available", both lend it out.
-- =====================================================================

-- STEP 0 (Session A): reset — make sure the copy is available
UPDATE loan SET return_date = CURRENT_DATE
WHERE copy_id = 90001 AND return_date IS NULL;
UPDATE book_copy SET status = 'Available' WHERE copy_id = 90001;

-- STEP 1 (Session A): Librarian A checks the copy
BEGIN;
SELECT copy_id, status FROM book_copy WHERE copy_id = 90001;

-- STEP 2 -> go to Session B

-- STEP 3 (Session A): A saw "Available", so lends it to member 101
INSERT INTO loan (copy_id, member_id, staff_id, due_date)
VALUES (90001, 101, 1, CURRENT_DATE + 14);
UPDATE book_copy SET status = 'On Loan' WHERE copy_id = 90001;
COMMIT;

-- STEP 4 -> go to Session B

-- STEP 5 (Session A): VERIFY — the same copy has TWO open loans
SELECT loan_id, copy_id, member_id, borrow_date, return_date
FROM loan
WHERE copy_id = 90001 AND return_date IS NULL;


-- =====================================================================
-- DEMO 6: THE FIX — SELECT ... FOR UPDATE (row locking)
-- FOR UPDATE locks the copy's row. Anyone else who tries to lock it
-- must WAIT until the first transaction finishes, then sees the new
-- status.
-- =====================================================================

-- STEP 6 (Session A): reset — close both open loans
UPDATE loan SET return_date = CURRENT_DATE
WHERE copy_id = 90001 AND return_date IS NULL;
UPDATE book_copy SET status = 'Available' WHERE copy_id = 90001;

-- STEP 7 (Session A): check AND lock the copy
BEGIN;
SELECT copy_id, status FROM book_copy WHERE copy_id = 90001 FOR UPDATE;

-- STEP 8 -> go to Session B (it will WAIT — leave it waiting)

-- STEP 9 (Session A): lend the copy to member 101 and commit.
-- As soon as this commits, Session B stops waiting.
INSERT INTO loan (copy_id, member_id, staff_id, due_date)
VALUES (90001, 101, 1, CURRENT_DATE + 14);
UPDATE book_copy SET status = 'On Loan' WHERE copy_id = 90001;
COMMIT;

-- STEP 10 -> go to Session B

-- STEP 11 (Session A): VERIFY — only ONE open loan this time
SELECT loan_id, copy_id, member_id, borrow_date, return_date
FROM loan
WHERE copy_id = 90001 AND return_date IS NULL;


-- =====================================================================
-- DEMO 7: ISOLATION LEVELS — a fines report while a fine is paid
-- Session A reads the same fine twice inside one transaction while
-- Session B changes it in between.
-- =====================================================================

-- ---- 7a. READ COMMITTED (PostgreSQL's default) ----

-- STEP 12 (Session A): start a report and read the fine
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT fine_id, amount, paid_status FROM fine WHERE fine_id = 90001;

-- STEP 13 -> go to Session B

-- STEP 14 (Session A): read the SAME fine again in the SAME transaction.
-- It now shows Paid: a NON-REPEATABLE READ.
SELECT fine_id, amount, paid_status FROM fine WHERE fine_id = 90001;
COMMIT;

-- ---- 7b. REPEATABLE READ ----

-- STEP 15 -> go to Session B (reset the fine to Unpaid)

-- STEP 16 (Session A): start a REPEATABLE READ report
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT fine_id, amount, paid_status FROM fine WHERE fine_id = 90001;

-- STEP 17 -> go to Session B

-- STEP 18 (Session A): read again — still Unpaid.
-- The transaction keeps a consistent snapshot from its first read.
SELECT fine_id, amount, paid_status FROM fine WHERE fine_id = 90001;
COMMIT;

-- STEP 19 (Session A): after committing, the new value is visible
SELECT fine_id, amount, paid_status FROM fine WHERE fine_id = 90001;

-- ---- 7c. REPEATABLE READ prevents a LOST UPDATE ----

-- STEP 20 (Session A): start REPEATABLE READ and read the fine
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT fine_id, amount, paid_status FROM fine WHERE fine_id = 90001;

-- STEP 21 -> go to Session B

-- STEP 22 (Session A): try to add a 50.00 late-payment charge.
-- ERROR (expected): could not serialize access due to concurrent update.
-- PostgreSQL refuses, because A would overwrite B's change without
-- having seen it.
UPDATE fine SET amount = amount + 50.00 WHERE fine_id = 90001;

-- STEP 23 (Session A): end the failed transaction
ROLLBACK;

-- STEP 24 (Session A): VERIFY — B's change survived
SELECT fine_id, amount, paid_status FROM fine WHERE fine_id = 90001;


-- =====================================================================
-- DEMO 8: DATABASE SAFEGUARD — one open loan per copy
-- FOR UPDATE only works if every program remembers to use it.
-- A UNIQUE partial index makes the database itself refuse a second
-- open loan on the same copy, whatever the application does.
-- =====================================================================

-- STEP 25 (Session A): reset, then create the safeguard index
UPDATE loan SET return_date = CURRENT_DATE
WHERE copy_id = 90001 AND return_date IS NULL;
UPDATE book_copy SET status = 'Available' WHERE copy_id = 90001;
CREATE UNIQUE INDEX uq_one_open_loan_per_copy
    ON loan (copy_id) WHERE return_date IS NULL;

-- STEP 26 (Session A): repeat the unsafe Demo 5 pattern (no FOR UPDATE)
BEGIN;
SELECT copy_id, status FROM book_copy WHERE copy_id = 90001;

-- STEP 27 -> go to Session B

-- STEP 28 (Session A): lend to member 101 and commit
INSERT INTO loan (copy_id, member_id, staff_id, due_date)
VALUES (90001, 101, 1, CURRENT_DATE + 14);
UPDATE book_copy SET status = 'On Loan' WHERE copy_id = 90001;
COMMIT;

-- STEP 29 -> go to Session B

-- STEP 30 (Session A): VERIFY — only ONE open loan
SELECT loan_id, copy_id, member_id, borrow_date, return_date
FROM loan
WHERE copy_id = 90001 AND return_date IS NULL;
