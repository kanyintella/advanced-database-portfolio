# Advanced Database Systems Portfolio

**Course:** MIT 8103 – Advanced Database Systems
**Session:** 2026/2027 First Semester Continuous Assessment
**Student Name:** Adekanyinsola Tella
**Student ID:** 2026/A/MIT/0664 301878279

---

## Case Study: Greenfield Community Library Management System

### Organisation / Scenario

Greenfield Community Library is a simulated public library network with three
branches in the same city. It lends physical books, journals and e-books to
registered members, and each branch manages its own stock while sharing one
central catalogue.

### Nature of the System

The Library Management System is the central database that records the
library's collection, its members, and every borrowing activity across all
branches. It replaces manual registers and spreadsheets, so staff can see in
real time which items are available, who has borrowed what, and which loans
are overdue.

### Users of the Database

- **Librarians:** issue and receive books, register members, manage fines
- **Members:** search the catalogue, view their loans and fines
- **Branch Managers:** monitor stock levels and borrowing activity per branch
- **System Administrator:** manages user accounts, backups and access control

### Major Data to be Stored

- **Books:** title, ISBN, publisher, year, category and item type
  (book, journal, e-book)
- **Book copies:** each physical copy of a title and the branch that holds it
- **Authors:** author details, linked to the books they wrote
- **Members:** member ID, name, contact details, membership type, join date
- **Loans:** which member borrowed which copy, borrow date, due date, return date
- **Fines:** amount charged for overdue returns and payment status
- **Branches:** branch name and location
- **Staff:** staff ID, name, role and assigned branch

### Key Operations the Database Will Support

1. **Borrow a book:** create a loan record and mark the copy as on loan
   in a single transaction
2. **Return a book:** close the loan, mark the copy as available, and
   calculate a fine if the return is late
3. **Calculate fines:** compute overdue charges based on days late
4. **Search the catalogue:** find books by title, author, category or ISBN
5. **Member history:** retrieve a member's current and past loans
6. **Reports:** most borrowed books, overdue loans, unpaid fines, and
   stock levels per branch

### Why This Case Study

The library system is small enough to model clearly but still supports every
portfolio activity:

- clear entities and relationships for **ER modelling and normalisation**
- realistic reporting queries for **query optimisation and indexing**
- borrowing and returning as natural **transactions**, with competing
  requests for the last copy as a **concurrency** scenario
- a catalogue of items with varying attributes, suitable for a
  **NoSQL document model**
- multiple branches, which supports discussion of **replication,
  sharding and availability** in a **distributed/cloud** setting

---

## Portfolio Progress

| Portfolio                                            | Activity                                | Status    |
| ---------------------------------------------------- | --------------------------------------- | --------- |
| [Portfolio 1](portfolio-1-database-design/)          | Database Design and Modelling           | Completed |
| [Portfolio 2](portfolio-2-query-optimisation/)       | Query Processing and Optimisation       | Completed |
| [Portfolio 3](portfolio-3-transactions-concurrency/) | Transactions and Concurrency            | Completed |
| [Portfolio 4](portfolio-4-nosql/)                    | NoSQL and Advanced Data Models          | Completed |
| [Portfolio 5](portfolio-5-distributed-cloud/)        | Distributed and Cloud Database Exercise | Completed |

## Portfolio Summary

**[Portfolio 1 – Database Design and Modelling](portfolio-1-database-design/)**
An ER diagram and a PostgreSQL schema of nine tables with primary, foreign
and unique keys and `CHECK` constraints, normalised to 3NF. Design decisions
include separating `book` (titles) from `book_copy` (physical items) and a
junction table for the many-to-many book–author relationship.

**[Portfolio 2 – Query Processing and Optimisation](portfolio-2-query-optimisation/)**
A dataset of over 280,000 rows (including 203,000 loans) and six business
queries. Three indexing experiments with `EXPLAIN ANALYZE` showed a ~125×
speed-up for an index on a foreign key, ~12× for a 40 kB partial index, and
only ~1.2× for a non-selective date index, explained using execution plans
and buffer counts.

**[Portfolio 3 – Transactions and Concurrency](portfolio-3-transactions-concurrency/)**
Eight demonstrations of COMMIT, ROLLBACK, automatic rollback on error and
SAVEPOINT, and, using two concurrent sessions, a double-borrow race
condition, its fix with `SELECT ... FOR UPDATE`, non-repeatable reads under
READ COMMITTED versus REPEATABLE READ, a prevented lost update, and a
unique partial index enforcing one open loan per copy.

**[Portfolio 4 – NoSQL and Advanced Data Models](portfolio-4-nosql/)**
The catalogue modelled in MongoDB Atlas as flexible documents (books,
journals and e-books with different fields), with embedding versus
referencing decisions, `$jsonSchema` validation, an atomic single-document
borrow, a multi-document transaction, aggregation pipelines with `$lookup`,
a multikey index (COLLSCAN to IXSCAN), and a comparison with the relational
design.

**[Portfolio 5 – Distributed and Cloud Database Exercise](portfolio-5-distributed-cloud/)**
Inspection of the Atlas three-member replica set (reads served by primary
and secondary, write and read concerns), yearly range partitioning of the
loan table in PostgreSQL (partition pruning: 1,490 pages down to 351), and
a distributed design covering sharding strategy, the CAP theorem, failover
and cloud security.

## Repository Structure

| Folder                                  | Content                                                                      |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| `portfolio-1-database-design/`          | ER diagram, relational schema, keys, constraints, normalisation              |
| `portfolio-2-query-optimisation/`       | Sample data, SQL queries, execution plans, indexing and performance analysis |
| `portfolio-3-transactions-concurrency/` | Commit, rollback, savepoint, isolation and concurrency demonstrations        |
| `portfolio-4-nosql/`                    | MongoDB document model, queries, transactions, aggregation and indexes       |
| `portfolio-5-distributed-cloud/`        | Replication on Atlas, PostgreSQL partitioning, distributed design            |

Each folder contains its scripts, a `screenshots/` folder of evidence, and
a README explaining how the work was implemented and tested.

## Tools Used

- PostgreSQL 18 and pgAdmin 4 (relational database and management interface)
- MongoDB 8.0 on MongoDB Atlas (free M0 cloud cluster on Microsoft Azure)
- MongoDB Compass and its built-in MongoDB shell (mongosh)
- Git, GitHub and GitHub Desktop (version control)
- VS Code (editor)

---

## AI Use Declaration

**AI tool used:** Claude (Anthropic), accessed via claude.ai

**What the AI tool was used for:**

_General_

- Explaining the assessment brief in simpler terms and clarifying what each
  portfolio activity requires
- Comparing possible case studies and recommending one suitable for a
  beginner (Library Management System)
- Step-by-step guidance on setting up Git, GitHub Desktop, VS Code, pgAdmin,
  MongoDB Atlas and Compass, and on the repository folder structure
- Drafting the case study statement in this README
- Helping diagnose problems encountered while running the work

_Portfolio 1 – Database Design and Modelling_

- Generating the ER diagram image (`er-diagram.png`) from the entities and
  relationships of the case study
- Drafting the PostgreSQL schema script (`schema.sql`), including data types,
  keys and constraints
- Drafting the Portfolio 1 README, including the normalisation explanation
  and design decisions

_Portfolio 2 – Query Processing and Optimisation_

- Drafting the sample data generator, the six business queries and the
  indexing experiment scripts
- Drafting the Portfolio 2 README and performance analysis based on my
  execution plan results

_Portfolio 3 – Transactions and Concurrency_

- Drafting the setup, transaction and two-session concurrency scripts
- Drafting the Portfolio 3 README based on my screenshots and results

_Portfolio 4 – NoSQL and Advanced Data Models_

- Guidance on setting up MongoDB Atlas and Compass
- Drafting the MongoDB collection, data, query, aggregation and index scripts
- Drafting the Portfolio 4 README based on my screenshots and results

_Portfolio 5 – Distributed and Cloud Database Exercise_

- Drafting the replication and partitioning scripts
- Drafting the Portfolio 5 README, including the distributed design,
  sharding strategy and CAP discussion, based on my results

**How the output was reviewed and verified:**

- I checked the explanation of the brief against the original assessment
  document to confirm the requirements and mark allocations were accurate
- I followed the setup steps myself and confirmed that the repository,
  folders and commits appear correctly on GitHub
- I checked that every entity, attribute and relationship in the ER diagram
  matches the tables in `schema.sql`, and that each cardinality reflects how
  the library actually operates
- I ran `schema.sql` in pgAdmin on my own `library_db` database and confirmed
  that all nine tables were created (see screenshots in Portfolio 1)
- I tested the constraints by inserting invalid data (a duplicate fine, a loan
  for a non-existent copy, and an invalid item type) and confirmed that the
  database rejected each one
- I studied the normalisation explanation until I could explain 1NF, 2NF and
  3NF using my own schema, and edited the wording to reflect my understanding
- I ran all Portfolio 2 scripts myself in pgAdmin (PostgreSQL 18), recorded
  the execution times and buffer counts from my own execution plans, and
  checked that every figure in the Portfolio 2 README matches my screenshots
- I ran every Portfolio 3 demo myself using two pgAdmin sessions,
  confirmed each expected result and error, and re-ran Demos 1–4 on a
  fresh setup after noticing a borrow step had been run twice
- I ran every Portfolio 4 script myself on my own Atlas cluster, checked
  each result against the expected output, and diagnosed issues including
  a blocked IP address and queries running in the wrong database
- I ran the Portfolio 5 replication script on my Atlas cluster and the
  partitioning script in pgAdmin, confirmed every figure in the README
  against my screenshots, and reviewed my own Atlas security settings
- Where my results differed from what was expected (for example, the
  overdue-loan count in Portfolio 4 and the write concern timings in
  Portfolio 5), I investigated the cause and documented my own results
  rather than the predicted ones

AI was used as a learning aid. All scripts were run, tested and verified by
me on my own databases, and I am responsible for all
work submitted in this portfolio.
