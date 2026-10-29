# Portfolio 4 – NoSQL and Advanced Data Models

**Case study:** Greenfield Community Library Management System
**Environment:** MongoDB 8.0 on MongoDB Atlas (free M0 cluster), MongoDB Compass, mongosh

This portfolio models part of the library in **MongoDB**, a **document
database**, and compares it with the relational design from Portfolios 1–3.
The focus is the **catalogue**, the part of the library whose data varies
most from item to item.

---

## 1. Files in this folder

| File | Description |
|---|---|
| `01_create_collections.js` | Creates the `library_nosql` database, its three collections and the catalogue's schema validation |
| `02_insert_data.js` | Inserts 10 catalogue items, 5 members and 8 loans |
| `03_queries.js` | Eight queries, including an atomic update, a transaction and a validation test |
| `04_aggregation_indexes.js` | Four aggregation pipelines and a before/after index experiment |
| `screenshots/` | Evidence for every step |

| Atlas cluster (free tier) | Compass connected |
|---|---|
| ![](screenshots/00-atlas-cluster.png) | ![](screenshots/00-compass-connected.png) |

---

## 2. Why a document model suits the catalogue

The library holds three kinds of item, and each has different data:

| Field | Book | Journal | E-book |
|---|---|---|---|
| Authors | ✓ | – (has editors) | ✓ |
| Pages, awards | ✓ | – | – |
| ISSN, volume, issue, frequency | – | ✓ | – |
| List of articles | – | ✓ | – |
| Physical copies at branches | ✓ | ✓ | – |
| File formats, file size, DRM | – | – | ✓ |
| Digital licences (total / in use) | – | – | ✓ |

In the relational design, this variety means either one wide `book` table
full of NULLs, or a separate table for every item type plus extra tables
for articles, formats and licences, joined back together for every
catalogue search. In a document database, **each document stores only the
fields that item actually has**, and nested data such as copies, authors
and articles sits inside the item itself.

| Book (B001) | Journal (J001) | E-book (E001) |
|---|---|---|
| ![](screenshots/docs-book.png) | ![](screenshots/docs-journal.png) | ![](screenshots/docs-ebook.png) |

The book has `pages`, `tags` and `copies`. The journal has `issn`,
`volume`, `issue`, `articles` and `reference_only`. The e-book has
`formats`, `file_size_mb`, `drm` and `licences`, and **no copies at all**.
All three live in the same `catalogue` collection.

---

## 3. Data Model Design

### Collections

| Collection | One document per | Embedded data | References |
|---|---|---|---|
| `catalogue` | title (book, journal or e-book) | authors/editors, copies, articles, licences | – |
| `members` | library member | address, phone numbers, preferences, student details | – |
| `loans` | loan | – | `member_id` → members, `item_id` → catalogue |

### Embedding or referencing?

The central design decision in MongoDB is whether related data is
**embedded** inside a document or stored separately and **referenced**.

| Data | Decision | Reason |
|---|---|---|
| Copies inside the item | **Embed** | Few per title (1–5), always shown with the item, and changing a copy's status then becomes a single-document (atomic) update |
| Authors inside the item | **Embed** | Small, rarely change, always displayed with the title |
| Articles inside a journal issue | **Embed** | Belong to exactly one issue and are always read with it |
| Address and preferences inside the member | **Embed** | One-to-one, always read with the member |
| Loans | **Reference** (separate collection) | Grow without limit (a popular book could have thousands of loans over its life, and a MongoDB document is capped at 16 MB), are written constantly, and are queried on their own (overdue lists, history) |

Each loan also stores a copy of the item's `title`. This is the **extended
reference** pattern: loan lists can be displayed without looking up the
catalogue, at the cost of a small amount of duplication. Titles almost
never change, so the duplication is a safe trade-off.

### Schema validation

"Schemaless" does not have to mean uncontrolled. The `catalogue`
collection has a `$jsonSchema` validator (see `01_create_collections.js`):

- every item **must** have `title`, `item_type`, `category` and
  `publication_year`
- `item_type` must be `Book`, `Journal` or `E-book`
- `publication_year` must be between 1450 and 2100
- **if** an item has `copies`, each copy needs a `copy_id`, a valid
  `branch` and a valid `status`
- **if** an item has `licences`, they need non-negative `total` and
  `in_use` values

Other fields are free to vary. This keeps the core rules that the
PostgreSQL `CHECK` constraints enforced in Portfolio 1, while still
allowing different item types.

| Collections created | Documents inserted |
|---|---|
| ![](screenshots/01-collections.png) | ![](screenshots/02-counts.png) |

---

## 4. Queries (`03_queries.js`)

### Q1 – Search by author across all item types

```javascript
db.catalogue.find({ "authors.last_name": "Adichie" }, ...)
```

Dot notation reaches **inside the embedded authors array**. One query
returns Adichie's printed novel (B002) **and** her e-book (E003). In the
relational design, this needed joins across `book`, `book_author` and
`author`.

![Q1](screenshots/q1-author-search.png)

### Q2 – Titles with an available copy at Central Branch

```javascript
db.catalogue.find({ copies: { $elemMatch: { branch: "Central", status: "Available" } } })
```

`$elemMatch` requires **both** conditions to be true for the **same**
copy. Without it, a title with one Available copy at Eastside and one
On Loan copy at Central would wrongly match. Five titles were returned.

![Q2](screenshots/q2-central-available.png)

### Q3 – E-books with a free licence

`$expr` compares two fields inside the same document
(`licences.in_use < licences.total`). Python for Data Analysis
(2 of 2 in use) is correctly excluded.

![Q3](screenshots/q3-free-licences.png)

### Q4 – Journals with their articles

A single read returns each issue with all its articles embedded. No join
is needed.

![Q4](screenshots/q4-journals.png)

### Q5 – Overdue loans

```javascript
db.loans.find({ return_date: null, due_date: { $lt: new Date() } })
```

Four overdue loans were returned. **Finding:** the loan due on
2026-10-29 appears as overdue on the same day, because due dates are
stored as **midnight** (`2026-10-29T00:00:00Z`) and the query compares
them with the current date **and time**. A member returning the book that
afternoon would be treated as late. The fix is to compare with the start
of the next day, or to store due dates as the end of the day. The same
subtlety exists in SQL, where Portfolio 2 avoided it by using the `DATE`
type, which has no time part.

![Q5](screenshots/q5-overdue.png)

---

## 5. Atomicity and Transactions

### Q6 – Atomic borrow of a single copy

```javascript
db.catalogue.findOneAndUpdate(
  { _id: "B001", copies: { $elemMatch: { copy_id: "B001-C1", status: "Available" } } },
  { $set: { "copies.$.status": "On Loan" } },
  { returnDocument: "after", ... }
);
```

The filter only matches if the copy is **still Available**, and the
positional operator `$` updates exactly the copy that matched. In MongoDB,
**an update to a single document is always atomic**, so checking and
changing the status happen as one indivisible step.

- **First run:** B001-C1 changes to On Loan.
- **Second run:** returns `null`. The copy is no longer Available, so
  nothing is changed.

This solves the double-borrow race condition from **Portfolio 3,
Demo 5** without an explicit lock, because the check is part of the update
itself. This works **because the copies are embedded**: the copy's status
lives in the same document as the condition being checked.

| First run | Second run |
|---|---|
| ![](screenshots/q6-first-run.png) | ![](screenshots/q6-second-run.png) |

**Limitation:** Q6 changes only the catalogue. A complete borrow also
needs a loan document, which lives in a **different** collection, and a
single-document update cannot cover both. That is what Q7 addresses.

### Q7 – Multi-document transaction: borrowing an e-book

Borrowing an e-book changes two documents in two collections:
1. increase `licences.in_use` in `catalogue`
2. insert a document into `loans`

Both steps run inside a **session transaction**
(`startTransaction` → `commitTransaction`, or `abortTransaction` on any
error). If no licence is free, the code throws an error and the whole
transaction is aborted, so the loan is never recorded without a licence.

The result shows `Transaction COMMITTED`. The verification shows E002's
licences going from **1 to 2 in use** and member M105's new loan existing.
Both changes were applied together.

Multi-document transactions require a **replica set**. Atlas clusters are
always replica sets, which is visible in the shell prompt:
`Atlas atlas-6mxapc-shard-0 [primary]`. The shell is connected to the
**primary** member of the replica set. This is explored further in
Portfolio 5.

| Transaction | Verification |
|---|---|
| ![](screenshots/q7-transaction.png) | ![](screenshots/q7-verify.png) |

### Q8 – Schema validation rejects a bad document

Inserting an item with `item_type: "Magazine"` fails with
`MongoServerError: Document failed validation`. This is the document
database equivalent of the PostgreSQL `CHECK` constraint from Portfolio 1.

![Q8](screenshots/q8-validation-error.png)

---

## 6. Aggregation Pipelines (`04_aggregation_indexes.js`)

An aggregation pipeline passes documents through a sequence of stages,
similar to an assembly line. Each one has an SQL equivalent:

| Pipeline | Stages used | SQL equivalent |
|---|---|---|
| A1 Stock per branch and status | `$unwind`, `$group`, `$sort` | `GROUP BY branch, status` over `book_copy` (Portfolio 2, Q6) |
| A2 Summary by item type | `$group` with `$sum`, `$max`, `$min` | `GROUP BY item_type` with `COUNT`, `MAX`, `MIN` |
| A3 Most active borrowers | `$group`, `$lookup`, `$unwind`, `$project`, `$sort` | `JOIN member ... GROUP BY member_id` |
| A4 Most borrowed titles | `$group` with `$first`, `$sort` | `GROUP BY item_id ORDER BY COUNT(*) DESC` |

**A1** uses `$unwind` to turn each embedded copy into its own document so
copies can be counted. This is the price of embedding: reports that
summarise copies across all titles need an extra step. After Q6, Central
shows 4 Available and 2 On Loan copies.

**A3** uses `$lookup`, MongoDB's join, to fetch member names via the
`member_id` reference. Adaeze Okeke (M101) is the most active borrower
with 4 loans, 2 still open.

**A4** shows Things Fall Apart borrowed 3 times. E002 now shows 2 loans,
including the one created by the Q7 transaction.

| A1 Stock | A2 Summary |
|---|---|
| ![](screenshots/a1-stock.png) | ![](screenshots/a2-summary.png) |
| **A3 Borrowers** | **A4 Top titles** |
| ![](screenshots/a3-borrowers.png) | ![](screenshots/a4-top-titles.png) |

---

## 7. Indexes

The same author search as Q1 was explained before and after creating an
index:

| | Before | After |
|---|---|---|
| Plan stages | `COLLSCAN` | `IXSCAN` → `FETCH` |
| Documents examined | 10 | 2 |
| Index keys examined | 0 | 2 |
| Documents returned | 2 | 2 |

- **Before:** `COLLSCAN` (collection scan), where every document is read,
  like PostgreSQL's Seq Scan in Portfolio 2.
- **After:** `IXSCAN` finds the two matching entries in the index, and
  `FETCH` reads only those two documents.

`idx_author_last_name` is a **multikey index**: because `authors` is an
array, MongoDB creates one index entry **per author**, so co-authored
books (such as B003, with two authors) are found by either author's name.

A compound index, `idx_member_open_loans` on `{ member_id, return_date }`,
was also created on `loans` to support "open loans for a member" lookups.

With only 10 documents the time saving is negligible. The point is the
change in **how much data is read** (10 documents down to 2). As in
Portfolio 2, that difference grows with the size of the collection.

| Before | After | Indexes |
|---|---|---|
| ![](screenshots/i1-before-index.png) | ![](screenshots/i3-after-index.png) | ![](screenshots/i4-indexes.png) |

---

## 8. Relational vs Document: Comparison

| Aspect | PostgreSQL (Portfolios 1–3) | MongoDB (this portfolio) |
|---|---|---|
| Structure | Fixed columns; every row of a table has the same shape | Flexible; each document has only the fields it needs |
| Different item types | Extra tables or NULL-filled columns | Different fields in the same collection |
| Related data | Separate tables joined at query time | Embedded in the document, or referenced |
| Catalogue search | Joins across `book`, `book_author`, `author` | Single collection read (Q1, Q4) |
| Integrity rules | `CHECK`, `NOT NULL`, `UNIQUE`, **foreign keys** | `$jsonSchema` validation; **no foreign key enforcement** |
| Atomicity | Multi-row transactions by default | Single-document updates are atomic; multi-document transactions on replica sets |
| Reporting | Mature SQL, `GROUP BY`, joins | Aggregation pipelines; joins via `$lookup` |
| Scaling | Mainly vertical (bigger server) | Designed for horizontal scaling (replication, sharding) |

### Where MongoDB is weaker for this library

- **No foreign keys.** A loan with `member_id: "M999"` would be accepted,
  even though no such member exists. In PostgreSQL, the foreign key
  would reject it. Referential integrity must be enforced by the
  application.
- **Loans and fines are naturally relational.** They are highly structured,
  link several entities, and involve money, where strong integrity
  matters most.
- **Reports across embedded data** need `$unwind` (A1), which is less
  direct than SQL on a normalised table.

### Recommendation: polyglot persistence

The strongest design uses each database for what it does best:

- **MongoDB for the catalogue:** varied item types, nested data, fast
  search by any attribute, and an easy fit for future item types such as
  audiobooks or DVDs without schema changes.
- **PostgreSQL for members, loans and fines:** structured transactional
  data where foreign keys, constraints and SQL reporting give the
  strongest guarantees.

---

## 9. How to Run

1. Create a free MongoDB Atlas cluster, add your IP address to the
   **IP Access List**, and connect with MongoDB Compass.
2. Open the shell in Compass (connection **⋯** → **Open MongoDB shell**).
3. Paste and run `01_create_collections.js`, then `02_insert_data.js`.
4. Run `03_queries.js` and `04_aggregation_indexes.js` **one block at a
   time**.

**Testing notes:**
- Every new shell session starts in the `test` database. Run
  `db = db.getSiblingDB("library_nosql");` first, and check the prompt
  shows `library_nosql>`. Queries run in the wrong database return
  nothing, without any error.
- Atlas only accepts connections from IP addresses on its access list.
  When the internet connection's IP changes, the new address must be
  added before Compass can connect.
- Q6 and Q7 change data. To repeat them, reset the copy status and the
  licence count first.
