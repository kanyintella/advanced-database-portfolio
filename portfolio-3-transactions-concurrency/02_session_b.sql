-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 3, Step 2: Concurrency — SESSION B
-- =====================================================================


-- =====================================================================
-- DEMO 5: THE PROBLEM — two librarians borrow the last copy
-- =====================================================================

-- STEP 2 (Session B): Librarian B checks the same copy.
-- A has not lent it yet, so B also sees "Available".
BEGIN;
SELECT copy_id, status FROM book_copy WHERE copy_id = 90001;

-- STEP 3 -> go to Session A

-- STEP 4 (Session B): B also saw "Available", so lends it to member 202
INSERT INTO loan (copy_id, member_id, staff_id, due_date)
VALUES (90001, 202, 2, CURRENT_DATE + 14);
UPDATE book_copy SET status = 'On Loan' WHERE copy_id = 90001;
COMMIT;

-- STEP 5 -> go to Session A


-- =====================================================================
-- DEMO 6: THE FIX — SELECT ... FOR UPDATE
-- =====================================================================

-- STEP 8 (Session B): try to check AND lock the same copy.
-- This WAITS (the query keeps running) because A holds the lock.
BEGIN;
SELECT copy_id, status FROM book_copy WHERE copy_id = 90001 FOR UPDATE;

-- STEP 9 -> go to Session A (B finishes waiting once A commits)

-- STEP 10 (Session B): B's query has now returned "On Loan",
-- so B does NOT lend the copy and cancels.
ROLLBACK;

-- STEP 11 -> go to Session A


-- =====================================================================
-- DEMO 7: ISOLATION LEVELS
-- =====================================================================

-- STEP 13 (Session B): the member pays the fine (commits immediately)
UPDATE fine SET paid_status = 'Paid' WHERE fine_id = 90001;

-- STEP 14 -> go to Session A

-- STEP 15 (Session B): reset the fine to Unpaid for the next test
UPDATE fine SET paid_status = 'Unpaid' WHERE fine_id = 90001;

-- STEP 16 -> go to Session A

-- STEP 17 (Session B): the member pays the fine again
UPDATE fine SET paid_status = 'Paid' WHERE fine_id = 90001;

-- STEP 18 -> go to Session A

-- STEP 21 (Session B): a librarian reduces the fine to 200.00
UPDATE fine SET amount = 200.00 WHERE fine_id = 90001;

-- STEP 22 -> go to Session A


-- =====================================================================
-- DEMO 8: DATABASE SAFEGUARD
-- =====================================================================

-- STEP 27 (Session B): B checks the copy and also sees "Available"
BEGIN;
SELECT copy_id, status FROM book_copy WHERE copy_id = 90001;

-- STEP 28 -> go to Session A

-- STEP 29 (Session B): B tries to lend it to member 202.
-- ERROR (expected): duplicate key value violates unique constraint
-- "uq_one_open_loan_per_copy". The database blocks the double loan.
INSERT INTO loan (copy_id, member_id, staff_id, due_date)
VALUES (90001, 202, 2, CURRENT_DATE + 14);

-- STEP 29b (Session B): end the failed transaction
ROLLBACK;

-- STEP 30 -> go to Session A
