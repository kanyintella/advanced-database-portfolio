-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 5, Part B: Horizontal partitioning of the loan table
-- =====================================================================


-- ---------------------------------------------------------------------
-- P0. Setup: follow Portfolio 2's recommendation and drop the
-- borrow_date index, so the original table is compared fairly as
-- a plain table. Also remove anything left from an earlier run
-- (loan_2023 survives a DROP if it was detached in P8).
-- ---------------------------------------------------------------------
DROP INDEX IF EXISTS idx_loan_borrow_date;
DROP TABLE IF EXISTS loan_partitioned CASCADE;
DROP TABLE IF EXISTS loan_2023;


-- ---------------------------------------------------------------------
-- P1. Create the partitioned table (the "parent")
-- The parent holds no rows itself; rows are routed to partitions.
-- The primary key must include the partition key (borrow_date).
-- ---------------------------------------------------------------------
CREATE TABLE loan_partitioned (
    loan_id      INT  NOT NULL,
    copy_id      INT  NOT NULL,
    member_id    INT  NOT NULL,
    staff_id     INT  NOT NULL,
    borrow_date  DATE NOT NULL,
    due_date     DATE NOT NULL,
    return_date  DATE,
    PRIMARY KEY (loan_id, borrow_date)
) PARTITION BY RANGE (borrow_date);


-- ---------------------------------------------------------------------
-- P2. Create one partition per year, plus a DEFAULT partition that
-- catches any date outside these ranges.
-- (FROM is inclusive, TO is exclusive.)
-- ---------------------------------------------------------------------
CREATE TABLE loan_2023 PARTITION OF loan_partitioned
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE loan_2024 PARTITION OF loan_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE loan_2025 PARTITION OF loan_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE loan_2026 PARTITION OF loan_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE loan_2027 PARTITION OF loan_partitioned
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE loan_default PARTITION OF loan_partitioned DEFAULT;


-- ---------------------------------------------------------------------
-- P3. Copy every loan into the partitioned table.
-- PostgreSQL routes each row to the right partition automatically.
-- ---------------------------------------------------------------------
INSERT INTO loan_partitioned
SELECT loan_id, copy_id, member_id, staff_id, borrow_date, due_date, return_date
FROM loan;

ANALYZE loan_partitioned;


-- ---------------------------------------------------------------------
-- P4. VERIFY: how many rows landed in each partition?
-- tableoid::regclass shows which partition each row is stored in.
-- ---------------------------------------------------------------------
SELECT tableoid::regclass AS partition,
       COUNT(*)           AS row_count,
       MIN(borrow_date)   AS earliest,
       MAX(borrow_date)   AS latest
FROM loan_partitioned
GROUP BY tableoid
ORDER BY earliest;


-- ---------------------------------------------------------------------
-- P5. The ORIGINAL table: loans borrowed in 2026.
-- Expect a Seq Scan of the WHOLE loan table: every page is read
-- (look at the Buffers line: about 1,490 pages).
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM loan
WHERE borrow_date >= DATE '2026-01-01' AND borrow_date < DATE '2027-01-01';


-- ---------------------------------------------------------------------
-- P6. The PARTITIONED table: the same question.
-- Expect PARTITION PRUNING: only loan_2026 appears in the plan.
-- The other partitions are never read, so far fewer pages are touched.
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM loan_partitioned
WHERE borrow_date >= DATE '2026-01-01' AND borrow_date < DATE '2027-01-01';


-- ---------------------------------------------------------------------
-- P7. A query WITHOUT the partition key cannot be pruned.
-- Filtering by member only: every partition must be scanned.
-- (In a sharded system this becomes a "scatter-gather" query sent to
-- every server, which is why the choice of key matters.)
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM loan_partitioned
WHERE member_id = 1234;


-- ---------------------------------------------------------------------
-- P8. Archiving made cheap: detach the oldest year.
-- Removing a year of history becomes one quick metadata change
-- instead of a slow DELETE of tens of thousands of rows. The detached
-- table still exists and could be moved to cheaper storage.
-- ---------------------------------------------------------------------
ALTER TABLE loan_partitioned DETACH PARTITION loan_2023;

-- P8 VERIFY: loan_2023 is no longer part of loan_partitioned,
-- but its rows still exist as a standalone table.
SELECT
  (SELECT COUNT(*) FROM loan_partitioned) AS rows_in_partitioned_table,
  (SELECT COUNT(*) FROM loan_2023)        AS rows_in_detached_2023_table;
