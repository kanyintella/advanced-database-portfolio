# Advanced Database Systems Portfolio

**Course:** MIT 8103 – Advanced Database Systems
**Session:** 2026/2027 First Semester Continuous Assessment
**Student Name:** Adekanyinsola Tella
**Student ID:** 2026/A/MIT/0664

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

| Portfolio                                            | Activity                                | Status      |
| ---------------------------------------------------- | --------------------------------------- | ----------- |
| [Portfolio 1](portfolio-1-database-design/)          | Database Design and Modelling           | Completed   |
| [Portfolio 2](portfolio-2-query-optimisation/)       | Query Processing and Optimisation       | Not started |
| [Portfolio 3](portfolio-3-transactions-concurrency/) | Transactions and Concurrency            | Not started |
| [Portfolio 4](portfolio-4-nosql/)                    | NoSQL and Advanced Data Models          | Not started |
| [Portfolio 5](portfolio-5-distributed-cloud/)        | Distributed and Cloud Database Exercise | Not started |

## Repository Structure

| Folder                                  | Content                                                         |
| --------------------------------------- | --------------------------------------------------------------- |
| `portfolio-1-database-design/`          | ER diagram, relational schema, keys, constraints, normalisation |
| `portfolio-2-query-optimisation/`       | SQL queries, execution plans, indexing and performance analysis |
| `portfolio-3-transactions-concurrency/` | Commit, rollback, isolation and concurrency demonstrations      |
| `portfolio-4-nosql/`                    | NoSQL model and implementation of the catalogue                 |
| `portfolio-5-distributed-cloud/`        | Replication, sharding and cloud deployment work                 |

## Tools Used

- PostgreSQL and pgAdmin 4 (relational database and management interface)
- MongoDB (NoSQL database) – _planned_
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
- Step-by-step guidance on setting up Git, GitHub Desktop, VS Code, pgAdmin
  and the repository folder structure
- Drafting the case study statement in this README

_Portfolio 1 – Database Design and Modelling_

- Generating the ER diagram image (`er-diagram.png`) from the entities and
  relationships of the case study
- Drafting the PostgreSQL schema script (`schema.sql`), including data types,
  keys and constraints
- Drafting the Portfolio 1 README, including the normalisation explanation
  and design decisions

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

AI was used as a learning aid. I am responsible for, and able to explain,
all work submitted in this portfolio.

_This declaration is updated as each portfolio activity is completed._
