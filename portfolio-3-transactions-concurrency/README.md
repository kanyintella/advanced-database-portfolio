# Portfolio 3 – Transactions and Concurrency

**Case study:** Greenfield Community Library Management System
**Environment:** PostgreSQL 18, pgAdmin 4

This portfolio shows how transactions keep the library database correct
when an operation involves several changes, and when several librarians
work on the same data at the same time. The demos use the library's two
most important operations, **borrowing** and **returning** a book, plus
**fine payments**.

---

## 1. Files in this folder

| File | Description |
|---|---|
| `00_setup.sql` | Creates the demo book, its single copy (`copy_id 90001`) and an unpaid fine (`fine_id 90001`); re-run to reset |
| `01_commit_rollback.sql` | Demos 1–4: COMMIT, ROLLBACK, automatic rollback on error, SAVEPOINT (one session) |
| `02_session_a.sql` | Demos 5–8: concurrency steps for librarian A |
| `02_session_b.sql` | Demos 5–8: concurrency steps for librarian B |
| `screenshots/` | Evidence for every demo |

The demo book has only **one copy**, so every concurrency demo is about the
situation that matters most: two people competing for the last copy.

![Setup](screenshots/00-setup-demo-data.png)

---

## 2. Why transactions matter in the library

Borrowing a book requires **two** changes:
1. insert a row into `loan`
2. set the copy's `status` to `'On Loan'`

If only one of these happened, the database would contradict itself: a
copy marked On Loan with no loan record, or a loan for a copy still shown
as Available. A transaction groups the changes so they follow the
**ACID** properties:

| Property | Meaning | Demonstrated in |
|---|---|---|
| **Atomicity** | All changes happen, or none do | Demos 1–4 |
| **Consistency** | Constraints are never broken | Demos 3 and 8 |
| **Isolation** | Concurrent transactions do not interfere incorrectly | Demos 5–7 |
| **Durability** | Committed changes are permanent | Demo 1 (data still there in later queries) |

---

## 3. Single-session demos (`01_commit_rollback.sql`)

### Demo 1 – COMMIT: borrowing a book

`BEGIN` starts the transaction, the loan is inserted, the copy is marked
On Loan, and `COMMIT` saves both changes together. The verification query
shows the copy On Loan with an open loan for member 101.

![Demo 1](screenshots/demo1-commit.png)

### Demo 2 – ROLLBACK: cancelling a mistake

A librarian starts processing a return, then cancels. **Inside** the
transaction, the copy already shows Available. After `ROLLBACK`, it is
back to On Loan and the loan is still open. Nothing was saved.

| Inside the transaction | After ROLLBACK |
|---|---|
| ![Demo 2 inside](screenshots/demo2-inside-transaction.png) | ![Demo 2 after](screenshots/demo2-after-rollback.png) |

### Demo 3 – Automatic rollback on error (atomicity)

The return is processed with two successful updates, then a fine of
**-50.00** is recorded. The fine breaks the `CHECK (amount > 0)`
constraint from Portfolio 1:

```
ERROR: new row for relation "fine" violates check constraint "fine_amount_check"
SQL state: 23514
```

Once a statement fails, PostgreSQL marks the whole transaction as
aborted. After `ROLLBACK`, the copy is still On Loan and the loan still
open. The two **successful** updates were undone along with the failed
insert, so the database never ends up half-updated.

| The error | After ROLLBACK |
|---|---|
| ![Demo 3 error](screenshots/demo3-error.png) | ![Demo 3 after](screenshots/demo3-after-rollback.png) |

### Demo 4 – SAVEPOINT: undoing part of a transaction

The book is returned on time, but a fine is added by mistake.
`ROLLBACK TO SAVEPOINT before_fine` removes only the fine, and `COMMIT`
saves the return. The result shows the loan returned, the copy Available,
and **0** fines on the loan.

![Demo 4](screenshots/demo4-savepoint.png)

---

## 4. Concurrency demos (`02_session_a.sql` and `02_session_b.sql`)

These demos use **two Query Tool tabs**, each with its own database
connection, acting as two librarians at different desks. The steps were
run in a strict order across both tabs.

### Demo 5 – The problem: double borrowing (race condition)

| Step | Librarian A | Librarian B |
|---|---|---|
| 1 | `BEGIN`; checks copy → **Available** | |
| 2 | | `BEGIN`; checks copy → **Available** |
| 3 | Lends to member 101, `COMMIT` | |
| 4 | | Lends to member 202, `COMMIT` |
| 5 | Two open loans on one copy | |

Both librarians checked the copy before either had changed it, so both
saw Available and both lent it out. The result is **two open loans
(203003 and 203004) on a single physical copy**: one member will turn up
for a book that is not there.

This is a **check-then-act race condition**. Each transaction was correct
on its own; the problem only appears when they overlap. PostgreSQL's
default isolation level, READ COMMITTED, does not prevent it, because the
check (`SELECT`) does not stop anyone else from reading or changing the row.

| A sees Available | B sees Available | Result |
|---|---|---|
| ![](screenshots/demo5-a-sees-available.png) | ![](screenshots/demo5-b-sees-available.png) | ![](screenshots/demo5-two-open-loans.png) |

### Demo 6 – The fix: `SELECT ... FOR UPDATE` (row locking)

The same scenario, but the check uses `SELECT ... FOR UPDATE`, which
**locks** the copy's row until the transaction ends.

| Step | Librarian A | Librarian B |
|---|---|---|
| 7 | Locks copy → **Available** | |
| 8 | | Tries to lock the same copy → **waits** |
| 9 | Lends to member 101, `COMMIT` (lock released) | |
| 10 | | Query returns → **On Loan**, so B cancels with `ROLLBACK` |
| 11 | One open loan (203005) | |

Session B's query was blocked for **over two minutes** (pgAdmin shows
`Waiting for the query to complete... 00:00:48.424` during the wait, and
`Query complete 00:02:04.207` when it finished). It only returned after A
committed, and by then it saw the **new** status, On Loan. Because B's
check now reflects reality, B correctly does not lend the book.

This is **pessimistic locking**: the transaction assumes a conflict may
happen and locks the row before acting on it.

| A locks the copy | B waits | B sees On Loan | Result |
|---|---|---|---|
| ![](screenshots/demo6-a-locks-copy.png) | ![](screenshots/demo6-b-waiting.png) | ![](screenshots/demo6-b-sees-on-loan.png) | ![](screenshots/demo6-one-open-loan.png) |

### Demo 7 – Isolation levels: a fines report while a fine is paid

Session A reads fine 90001 twice within one transaction, while Session B
changes it in between.

#### 7a. READ COMMITTED (PostgreSQL's default)

| Step | Session A | Session B |
|---|---|---|
| 12 | Reads fine → 250.00 **Unpaid** | |
| 13 | | Marks fine as Paid (commits) |
| 14 | Reads again → 250.00 **Paid** | |

The same query gave **two different answers inside one transaction**.
This is a **non-repeatable read**. Under READ COMMITTED, each statement
sees the data committed at the moment that statement starts, so a report
that reads the same data twice can contradict itself.

| First read | Second read |
|---|---|
| ![](screenshots/demo7a-first-read.png) | ![](screenshots/demo7a-second-read.png) |

#### 7b. REPEATABLE READ

| Step | Session A | Session B |
|---|---|---|
| 16 | Reads fine → **Unpaid** | |
| 17 | | Marks fine as Paid (commits) |
| 18 | Reads again → still **Unpaid** | |
| 19 | After `COMMIT`, reads → **Paid** | |

Under REPEATABLE READ, the transaction works from a **snapshot** taken at
its first query, so every read inside it is consistent. The change only
becomes visible once the transaction ends. PostgreSQL achieves this with
**MVCC** (multi-version concurrency control): it keeps the old version of
the row for A while B writes a new version, so neither has to wait for
the other.

| First read | Second read | After commit |
|---|---|---|
| ![](screenshots/demo7b-first-read.png) | ![](screenshots/demo7b-second-read.png) | ![](screenshots/demo7b-after-commit.png) |

#### 7c. REPEATABLE READ prevents a lost update

| Step | Session A (REPEATABLE READ) | Session B |
|---|---|---|
| 20 | Reads fine → 250.00 | |
| 21 | | Reduces fine to 200.00 (commits) |
| 22 | Tries `amount = amount + 50.00` → **ERROR** | |
| 24 | Final value → **200.00** | |

```
ERROR: could not serialize access due to concurrent update
SQL state: 40001
```

If A's update had succeeded, it would have been calculated from the
250.00 in its snapshot, saving 300.00 and silently wiping out B's
reduction. This is a **lost update**. PostgreSQL refuses instead, and
B's change survives. An application using REPEATABLE READ must be ready
to catch error `40001` and **retry** the transaction.

| The error | Final value |
|---|---|
| ![](screenshots/demo7c-serialization-error.png) | ![](screenshots/demo7c-final-value.png) |

### Demo 8 – Database safeguard: one open loan per copy

`FOR UPDATE` only works if every program that borrows books remembers to
use it. To make the rule impossible to break, a **unique partial index**
was added:

```sql
CREATE UNIQUE INDEX uq_one_open_loan_per_copy
    ON loan (copy_id) WHERE return_date IS NULL;
```

It allows many **returned** loans per copy (its history), but only **one
open** loan. Demo 5's unsafe pattern was then repeated without
`FOR UPDATE`. Librarian A's loan succeeded, and librarian B's was
rejected by the database itself:

```
ERROR: duplicate key value violates unique constraint "uq_one_open_loan_per_copy"
Key (copy_id)=(90001) already exists.
SQL state: 23505
```

Only one open loan (203006) exists.

| B's loan rejected | Result |
|---|---|
| ![](screenshots/demo8-duplicate-blocked.png) | ![](screenshots/demo8-one-open-loan.png) |

---

## 5. Summary of Findings

| Problem | Demo | Cause | Solution |
|---|---|---|---|
| Half-completed operations | 3 | One step of a multi-step change fails | Wrap the steps in one transaction (atomicity) |
| Double borrowing | 5 | Check-then-act race under READ COMMITTED | `SELECT ... FOR UPDATE` (Demo 6) and a unique partial index (Demo 8) |
| Non-repeatable read | 7a | Each statement sees the latest committed data | REPEATABLE READ for multi-read reports (7b) |
| Lost update | 7c | Update based on an out-of-date read | REPEATABLE READ detects it and aborts; the application retries |

### Recommendations for the library system

1. **Borrowing:** lock the copy with `SELECT ... FOR UPDATE` before
   creating the loan, so the second librarian waits and sees the correct
   status.
2. **Add `uq_one_open_loan_per_copy` to the schema permanently.** Rules
   enforced by the database cannot be bypassed by a buggy or forgetful
   application. This is an improvement to the Portfolio 1 design that was
   only discovered by testing concurrency.
3. **Reports** that read the same data more than once, such as an
   end-of-day fines summary, should run under **REPEATABLE READ** so their
   figures agree with each other.
4. **Payments and fine adjustments** should either lock the fine row or
   run under REPEATABLE READ with retry logic, so no change is silently
   lost.
5. Keep **READ COMMITTED** as the default for simple operations. Stronger
   isolation and locking cost waiting time and retries, so they should be
   used where the risk justifies it.

---

## 6. How to Run

1. Run `00_setup.sql` in `library_db` (requires the Portfolio 1 schema and
   Portfolio 2 sample data).
2. Run `01_commit_rollback.sql` one numbered block at a time.
3. Open **two** Query Tool tabs on `library_db`. Open `02_session_a.sql` in
   one and `02_session_b.sql` in the other, then follow the step numbers in
   order, switching tabs as instructed.
4. Re-run `00_setup.sql` at any time to reset the demo data.

**Testing notes:**
- pgAdmin only displays the result of the **last** highlighted statement.
  Where a step ends with `COMMIT`, the `SELECT` was run on its own first so
  its result could be captured.
- Every block must be run exactly once. Running a borrow block twice
  creates a second loan, so if a demo goes wrong, run `ROLLBACK` in both
  tabs, re-run `00_setup.sql`, and start that demo again.
