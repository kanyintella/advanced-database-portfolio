// =====================================================================
// Greenfield Community Library Management System
// Portfolio 4, Step 3: Queries, updates and transactions
// =====================================================================
// Run each numbered block ON ITS OWN (paste it into the shell and
// press Enter), and screenshot the result.
// =====================================================================

db = db.getSiblingDB("library_nosql");   // switch to the library_nosql database


// ---------------------------------------------------------------------
// Q1. Search by author across ALL item types
// Dot notation reaches inside the embedded authors array.
// Finds Adichie's printed novel AND her e-book with one query.
// ---------------------------------------------------------------------
db.catalogue.find(
  { "authors.last_name": "Adichie" },
  { _id: 1, title: 1, item_type: 1, publication_year: 1 }
);


// ---------------------------------------------------------------------
// Q2. Titles with an AVAILABLE copy at Central Branch
// $elemMatch requires BOTH conditions to be true for the SAME copy.
// ---------------------------------------------------------------------
db.catalogue.find(
  { copies: { $elemMatch: { branch: "Central", status: "Available" } } },
  { _id: 0, title: 1, item_type: 1 }
);


// ---------------------------------------------------------------------
// Q3. E-books with a free licence right now
// $expr compares two fields inside the same document.
// ---------------------------------------------------------------------
db.catalogue.find(
  { item_type: "E-book", $expr: { $lt: ["$licences.in_use", "$licences.total"] } },
  { _id: 0, title: 1, licences: 1 }
);


// ---------------------------------------------------------------------
// Q4. Journal issues with their embedded articles
// One read returns the issue and all its articles: no JOIN needed.
// ---------------------------------------------------------------------
db.catalogue.find(
  { item_type: "Journal" },
  { _id: 0, title: 1, volume: 1, issue: 1, articles: 1 }
);


// ---------------------------------------------------------------------
// Q5. Overdue loans (still out and past the due date)
// ---------------------------------------------------------------------
db.loans.find(
  { return_date: null, due_date: { $lt: new Date() } },
  { _id: 0, member_id: 1, title: 1, due_date: 1 }
);


// ---------------------------------------------------------------------
// Q6. Atomic borrow of a specific copy (run it TWICE)
// The filter only matches if copy B001-C1 is still Available.
// The positional operator $ updates exactly the copy that matched.
// A single-document update in MongoDB is atomic, so two librarians
// cannot both succeed: the first run returns the updated document,
// the second run returns null because the copy is no longer Available.
// (Compare with the double-borrow problem in Portfolio 3, Demo 5.)
// ---------------------------------------------------------------------
db.catalogue.findOneAndUpdate(
  { _id: "B001", copies: { $elemMatch: { copy_id: "B001-C1", status: "Available" } } },
  { $set: { "copies.$.status": "On Loan" } },
  { returnDocument: "after", projection: { title: 1, copies: 1 } }
);


// ---------------------------------------------------------------------
// Q7. Multi-document TRANSACTION: borrow an e-book licence
// Borrowing an e-book changes TWO documents in TWO collections:
// the licence count in catalogue, and a new document in loans.
// A transaction makes both succeed or both fail, as in Portfolio 3.
// (Transactions need a replica set; Atlas clusters are replica sets.)
// ---------------------------------------------------------------------
// Wrapped in (() => { ... })() so the block can be re-run safely.
(() => {
  const session = db.getMongo().startSession();
  const sdb = session.getDatabase("library_nosql");
  session.startTransaction();
  try {
    const result = sdb.catalogue.updateOne(
      { _id: "E002", $expr: { $lt: ["$licences.in_use", "$licences.total"] } },
      { $inc: { "licences.in_use": 1 } }
    );
    if (result.modifiedCount === 0) {
      throw new Error("No free licence for E002");
    }
    sdb.loans.insertOne({
      member_id: "M105", item_id: "E002", licence: true,
      title: "Designing Data-Intensive Applications",
      borrow_date: new Date(), due_date: new Date(Date.now() + 14 * 86400000),
      return_date: null
    });
    session.commitTransaction();
    print("Transaction COMMITTED: licence taken and loan recorded");
  } catch (e) {
    session.abortTransaction();
    print("Transaction ABORTED: " + e.message);
  } finally {
    session.endSession();
  }
})();


// Q7 VERIFY: licences in use went from 1 to 2, and M105 has the loan
({
  licences: db.catalogue.findOne({ _id: "E002" }, { _id: 0, licences: 1 }).licences,
  m105_loans: db.loans.find({ member_id: "M105", item_id: "E002" },
                            { _id: 0, title: 1, borrow_date: 1 }).toArray()
});


// ---------------------------------------------------------------------
// Q8. Schema validation rejects a bad document (ERROR expected)
// "Magazine" is not an allowed item_type, so MongoDB refuses it,
// just as the CHECK constraint did in PostgreSQL.
// ---------------------------------------------------------------------
db.catalogue.insertOne({
  _id: "X001",
  item_type: "Magazine",
  title: "Library Monthly",
  category: "General",
  publication_year: 2026
});
