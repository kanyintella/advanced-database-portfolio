# Advanced Database Systems Portfolio

**Course:** MIT 8103 – Advanced Database Systems
**Session:** 2026/2027 First Semester Continuous Assessment
**Student Name:** Adekanyinsola Tella
**Student ID:** 2026/A/MIT/0664

---

## Case Study: Greenfield Community Library Management System

### Organisation / Scenario

Greenfield Community Library is a simulated public library network with three branches in the same city. It lends physical books, journals and e-books to registered members, and each branch manages its own stock while sharing one central catalogue.

### Nature of the System

The Library Management System is the central database that records the library's collection, its members, and every borrowing activity across all branches. It replaces manual registers and spreadsheets, so staff can see in real time which items are available, who has borrowed what, and which loans are overdue.

### Users of the Database

- **Librarians:** issue and receive books, register members, manage fines
- **Members:** search the catalogue, view their loans and fines
- **Branch Managers:** monitor stock levels and borrowing activity per branch
- **System Administrator:** manages user accounts, backups and access control

### Major Data to be Stored

- **Books and items:** title, ISBN, publisher, year, category, item type
  (book, journal, e-book) and number of copies per branch
- **Authors:** author details, linked to the books they wrote
- **Members:** member ID, name, contact details, membership type, join date
- **Loans:** which member borrowed which copy, borrow date, due date, return date
- **Fines:** amount charged for overdue returns and payment status
- **Branches:** branch name, location and the stock held there
- **Staff:** staff ID, name, role and assigned branch

### Key Operations the Database Will Support

1. **Borrow a book:** create a loan record and reduce available copies
   in a single transaction
2. **Return a book:** close the loan, increase available copies, and
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

## Repository Structure

| Folder                                  | Content                                                         |
| --------------------------------------- | --------------------------------------------------------------- |
| `portfolio-1-database-design/`          | ER diagram, relational schema, keys, constraints, normalisation |
| `portfolio-2-query-optimisation/`       | SQL queries, execution plans, indexing and performance analysis |
| `portfolio-3-transactions-concurrency/` | Commit, rollback, isolation and concurrency demonstrations      |
| `portfolio-4-nosql/`                    | NoSQL model and implementation of the catalogue                 |
| `portfolio-5-distributed-cloud/`        | Replication, sharding and cloud deployment work                 |

## Tools Used

- PostgreSQL (relational database)
- MongoDB (NoSQL database) – _planned_
- Git and GitHub (version control)
- VS Code (editor)

## AI Use Declaration

[To be completed at submission: tool used, what it was used for, and how
the output was reviewed and verified.]
