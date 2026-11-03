# Portfolio 2 – Query Processing and Optimisation

**Case study:** Greenfield Community Library Management System
**Environment:** PostgreSQL 18, pgAdmin 4

This portfolio loads a realistic volume of data into the library database,
runs six business queries, and uses `EXPLAIN ANALYZE` to measure how three
indexes change the way PostgreSQL executes queries and how long they take.

---

## 1. Files in this folder

| File | Description |
|---|---|
| `01_sample_data.sql` | Generates realistic sample data (over 280,000 rows in total) |
| `02_queries.sql` | Six business queries used by the library |
| `03_optimisation.sql` | Three before/after indexing experiments using `EXPLAIN ANALYZE` |
| `screenshots/` | Query results, execution plans and index sizes |

---

## 2. Sample Data

Optimisation cannot be demonstrated on a handful of rows, because every
query on a tiny table is instant. `01_sample_data.sql` uses
`generate_series()` and `random()` to create a realistic dataset.
`setseed()` makes the random values the same on every run, so the
dataset can be reproduced exactly.

| Table | Rows |
|---|---|
| branch | 3 |
| staff | 30 |
| author | 1,500 |
| book | 5,000 |
| book_author | 6,186 |
| book_copy | 14,907 |
| member | 10,000 |
| loan | 203,000 |
| fine | 40,295 |

The data follows the library's real rules:
- 200,000 historical loans over three years, about 20% returned late
- 3,000 open loans on distinct copies, 1,959 of them overdue
- copies with an open loan have the status 'On Loan'
- staff are chosen from the branch that holds the copy
- a fine of 50.00 per day late exists for every late return

![Row counts](screenshots/data-row-counts.png)

---

## 3. Business Queries

| # | Query | Business purpose | Rows returned |
|---|---|---|---|
| Q1 | Member loan history | Show everything one member has borrowed (front desk, member account) | 25 |
| Q2 | Overdue loans report | Daily list of overdue books with member contact details | 1,959 |
| Q3 | Top 10 borrowed titles (12 months) | Guide purchasing decisions | 10 |
| Q4 | Highest unpaid fines | Identify members owing more than 1,000.00 | 20 |
| Q5 | Catalogue search by author | Find all books by an author named Achebe, with co-authors | 258 |
| Q6 | Stock levels per branch | Total, available, on-loan and lost/damaged copies per branch | 3 |

SQL features used across the queries include multi-table `JOIN`s,
`CASE` expressions (Q1), date arithmetic (Q2, Q3), `GROUP BY` with
`HAVING` (Q4), a subquery with `IN` and `STRING_AGG` (Q5), and conditional
aggregation with `COUNT(*) FILTER (WHERE ...)` (Q6).

| Q1 | Q2 |
|---|---|
| ![Q1](screenshots/q1-member-history.png) | ![Q2](screenshots/q2-overdue-loans.png) |
| **Q3** | **Q4** |
| ![Q3](screenshots/q3-top-borrowed.png) | ![Q4](screenshots/q4-unpaid-fines.png) |
| **Q5** | **Q6** |
| ![Q5](screenshots/q5-author-search.png) | ![Q6](screenshots/q6-branch-stock.png) |

---

## 4. Optimisation Experiments

### Method

Each experiment followed the same steps:
1. Run `EXPLAIN ANALYZE` on the query with no custom index (**before**).
2. Create an index designed for that query's `WHERE` condition.
3. Run `EXPLAIN ANALYZE` on the same query again (**after**).

Each query was run several times and the typical execution time was
recorded, since the first run is slower while data is loaded into memory.
PostgreSQL 18 also reports **Buffers** by default. Each buffer is one
8 kB page of data, so the buffer count measures how much data the query
had to touch, which is a more stable measure than time.

### Summary of results

| Experiment | Index | Before | After | Speed-up | Pages touched (before → after) |
|---|---|---|---|---|---|
| 1. Member history (Q1) | `idx_loan_member_id` | 43.418 ms | 0.347 ms | **~125×** | 1,643 → 177 |
| 2. Overdue loans (Q2) | `idx_loan_overdue` (partial) | 108.624 ms | 9.010 ms | **~12×** | 1,987 → 329 |
| 3. Top borrowed (Q3) | `idx_loan_borrow_date` | 65.544 ms | 55.250 ms | **~1.2×** | 1,676 → 1,731 |

Timings depend on the computer and will vary between runs, but the
pattern of large, medium and small gains is consistent.

---

### Experiment 1 – Member loan history

**Condition:** `WHERE l.member_id = 1234`

**Before:** PostgreSQL used a **Parallel Seq Scan on loan**. Two
processes read the whole table, and the plan reports
`Rows Removed by Filter: 101488` per process. About 203,000 rows were
checked to find 25.

**After:** the plan changed to a **Bitmap Index Scan on
idx_loan_member_id**, followed by a Bitmap Heap Scan with
`Heap Blocks: exact=25`. PostgreSQL went straight to the 25 matching rows
and read only the 25 table pages that hold them.

**Why it worked:** the condition is highly **selective**: 25 rows out of
203,000 (about 0.01%). An important finding is that **PostgreSQL does not
automatically create indexes on foreign key columns**. The primary key
`loan_id` is indexed, but `member_id` was not until this index was added.
Every lookup of a member's loans would otherwise scan the whole table.

| Before | After |
|---|---|
| ![Exp 1 before](screenshots/exp1-before.png) | ![Exp 1 after](screenshots/exp1-after.png) |

---

### Experiment 2 – Overdue loans report

**Condition:** `WHERE l.return_date IS NULL AND l.due_date < CURRENT_DATE`

**Before:** a **Parallel Seq Scan on loan** with
`Rows Removed by Filter: 100520` per process, reading the entire table to
find 1,959 overdue loans.

**After:** a **Bitmap Index Scan on idx_loan_overdue**, reading only 20
table pages (`Heap Blocks: exact=20`).

**Why a partial index:** only 3,000 of 203,000 loans are open at any
time. A partial index (`WHERE return_date IS NULL`) stores only those
open loans, so it is tiny and stays small as the history of returned
loans grows every day. It also matches the query exactly, because the
query only asks about open loans.

**Why only 20 pages:** the 1,959 matching rows are physically stored
close together, because the open loans were inserted last and sit
together at the end of the table. How rows are physically arranged on
disk affects how much an index can save.

| Before | After |
|---|---|
| ![Exp 2 before](screenshots/exp2-before.png) | ![Exp 2 after](screenshots/exp2-after.png) |

---

### Experiment 3 – Top borrowed titles in the last 12 months

**Condition:** `WHERE l.borrow_date >= CURRENT_DATE - INTERVAL '12 months'`

**Before:** a **Seq Scan on loan** that kept 62,317 rows and removed
140,683 (`Rows Removed by Filter: 140683`).

**After:** PostgreSQL chose a **Bitmap Index Scan on
idx_loan_borrow_date**, but the improvement was small (about 16%), and
the number of pages touched actually rose slightly, from 1,676 to 1,731.

**Why the index barely helped:** the condition matches about **31% of
the table**, so it is not selective. The after plan shows
`Heap Blocks: exact=1490`, which is every page of the loan table (the
before plan's Seq Scan also read 1,490 pages). Recent loans are spread
across the whole table, so almost every page contains at least one
match. PostgreSQL still had to read the whole table, plus the index
pages on top. The small time saving comes from not having to test the
date condition on every row, not from reading less data.

**Lesson:** indexes are most effective when a query needs a small
fraction of the rows. For a report that summarises a large share of the
table, better options would be a **materialized view** or summary table
of borrow counts refreshed nightly, or table **partitioning** by
`borrow_date`, so only the relevant year's partition is scanned.

| Before | After |
|---|---|
| ![Exp 3 before](screenshots/exp3-before.png) | ![Exp 3 after](screenshots/exp3-after.png) |

---

## 5. Index Size and Trade-offs

| Index | Size | Type |
|---|---|---|
| `loan_pkey` | 4,472 kB | Primary key (created automatically) |
| `idx_loan_member_id` | 1,592 kB | B-tree on `member_id` |
| `idx_loan_borrow_date` | 1,416 kB | B-tree on `borrow_date` |
| `idx_loan_overdue` | **40 kB** | Partial B-tree on `due_date` where `return_date IS NULL` |

![Index sizes](screenshots/index-sizes.png)

The partial index is about **2.5% of the size** of the full indexes,
because it stores only open loans. It gave a 12× speed-up for very little
storage.

Indexes are not free:
- **Storage:** the three new indexes add about 3 MB to a table whose data
  occupies about 12 MB (1,490 pages of 8 kB).
- **Slower writes:** every new loan must now also be added to three extra
  indexes. Borrowing and returning books are the library's most frequent
  operations, so every index slows them down slightly.

### Recommendation

| Index | Keep? | Reason |
|---|---|---|
| `idx_loan_member_id` | **Yes** | Huge gain on a frequent lookup; foreign keys used in searches should be indexed |
| `idx_loan_overdue` | **Yes** | 12× faster for a daily report, at almost no storage cost |
| `idx_loan_borrow_date` | **No** | Small gain does not justify its size and the extra cost on every insert; a materialized view suits this report better |

---

## 6. Key Findings

1. **Selectivity decides whether an index helps.** The fewer rows a query
   needs, the bigger the gain: 0.01% of rows gave ~125×, about 1% gave
   ~12×, and 31% gave only ~1.2×.
2. **Foreign keys are not indexed automatically in PostgreSQL**, and they
   are often the columns that queries filter and join on.
3. **Partial indexes** suit queries that always target a small, well-defined
   subset of rows, such as open loans.
4. **Execution plans explain the timings.** The change from Seq Scan to
   Index Scan, the rows removed by filter, and the pages touched (buffers
   and heap blocks) show why a query became faster, or why it did not.
5. **Every index has a cost**, so indexes should be chosen based on the
   queries the system actually runs most often.

---

## 7. How to Run

1. Run `../portfolio-1-database-design/schema.sql` in `library_db`.
2. Run `01_sample_data.sql` (about 30 seconds). The final query shows the
   row counts.
3. In `02_queries.sql`, highlight one query at a time and press F5.
4. In `03_optimisation.sql`, run the Step 0 reset first, then each
   experiment's statements in order (before, create index, after),
   highlighting one statement at a time.
