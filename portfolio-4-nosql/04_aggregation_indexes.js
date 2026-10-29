// =====================================================================
// Greenfield Community Library Management System
// Portfolio 4, Step 4: Aggregation pipelines and indexes
// =====================================================================
// Run each numbered block ON ITS OWN and screenshot the result.
// An aggregation pipeline passes documents through stages, like an
// assembly line: $match filters, $unwind splits arrays, $group
// summarises, $lookup joins, $sort orders.
// =====================================================================

db = db.getSiblingDB("library_nosql");   // switch to the library_nosql database


// ---------------------------------------------------------------------
// A1. Stock levels per branch and status
// The same report as SQL query Q6 in Portfolio 2. $unwind turns each
// embedded copy into its own document so the copies can be grouped.
// ---------------------------------------------------------------------
db.catalogue.aggregate([
  { $unwind: "$copies" },
  { $group: { _id: { branch: "$copies.branch", status: "$copies.status" },
              copies: { $sum: 1 } } },
  { $sort: { "_id.branch": 1, "_id.status": 1 } }
]);


// ---------------------------------------------------------------------
// A2. Catalogue summary by item type
// ---------------------------------------------------------------------
db.catalogue.aggregate([
  { $group: { _id: "$item_type",
              titles: { $sum: 1 },
              newest: { $max: "$publication_year" },
              oldest: { $min: "$publication_year" } } },
  { $sort: { titles: -1 } }
]);


// ---------------------------------------------------------------------
// A3. Most active borrowers, with names from the members collection
// $lookup joins loans to members using the member_id reference.
// ---------------------------------------------------------------------
db.loans.aggregate([
  { $group: { _id: "$member_id", total_loans: { $sum: 1 },
              open_loans: { $sum: { $cond: [{ $eq: ["$return_date", null] }, 1, 0] } } } },
  { $lookup: { from: "members", localField: "_id", foreignField: "_id", as: "member" } },
  { $unwind: "$member" },
  { $project: { _id: 0, member_id: "$_id",
                name: { $concat: ["$member.first_name", " ", "$member.last_name"] },
                membership_type: "$member.membership_type",
                total_loans: 1, open_loans: 1 } },
  { $sort: { total_loans: -1 } }
]);


// ---------------------------------------------------------------------
// A4. Most borrowed titles
// ---------------------------------------------------------------------
db.loans.aggregate([
  { $group: { _id: "$item_id", title: { $first: "$title" }, times_borrowed: { $sum: 1 } } },
  { $sort: { times_borrowed: -1, title: 1 } }
]);


// ---------------------------------------------------------------------
// I1. BEFORE an index: how does MongoDB find books by author?
// The summary shows the plan stages and how many documents were read.
// Expect COLLSCAN (collection scan): every document is examined.
// ---------------------------------------------------------------------
(() => {
  const ex = db.catalogue.find({ "authors.last_name": "Adichie" }).explain("executionStats");
  return {
    stages: JSON.stringify(ex.queryPlanner.winningPlan).match(/"stage":"[A-Z_]+"/g),
    docsExamined: ex.executionStats.totalDocsExamined,
    keysExamined: ex.executionStats.totalKeysExamined,
    returned: ex.executionStats.nReturned
  };
})();


// ---------------------------------------------------------------------
// I2. Create indexes
// The author index is a MULTIKEY index: MongoDB adds one index entry
// for every author in the array, so co-authored books are found too.
// The loans index supports "open loans for a member" lookups.
// ---------------------------------------------------------------------
db.catalogue.createIndex({ "authors.last_name": 1 }, { name: "idx_author_last_name" });
db.loans.createIndex({ member_id: 1, return_date: 1 }, { name: "idx_member_open_loans" });


// ---------------------------------------------------------------------
// I3. AFTER the index: run the same summary again.
// Expect IXSCAN (index scan) and only the matching documents examined.
// ---------------------------------------------------------------------
(() => {
  const ex = db.catalogue.find({ "authors.last_name": "Adichie" }).explain("executionStats");
  return {
    stages: JSON.stringify(ex.queryPlanner.winningPlan).match(/"stage":"[A-Z_]+"/g),
    docsExamined: ex.executionStats.totalDocsExamined,
    keysExamined: ex.executionStats.totalKeysExamined,
    returned: ex.executionStats.nReturned
  };
})();


// ---------------------------------------------------------------------
// I4. List the indexes on both collections
// ---------------------------------------------------------------------
({
  catalogue: db.catalogue.getIndexes().map(i => i.name),
  loans:     db.loans.getIndexes().map(i => i.name)
});
