// =====================================================================
// Greenfield Community Library Management System
// Portfolio 4, Step 1: Create the collections with schema validation
// =====================================================================
// Collections:
//   catalogue  one document per title (books, journals, e-books);
//              copies and authors are EMBEDDED inside each document
//   members    library members, with address and preferences embedded
//   loans      one document per loan, REFERENCING the member and item
// =====================================================================

db = db.getSiblingDB("library_nosql"); // switch to the library_nosql database

// Start clean
db.catalogue.drop();
db.members.drop();
db.loans.drop();

// ---------------------------------------------------------------------
// catalogue: flexible structure, but core rules are still enforced.
// Every item must have a title, a valid item_type, a category and a
// publication year. IF an item has copies or licences, they must have
// the right shape. Other fields (pages, issn, articles, file formats)
// are allowed freely, because they differ between item types.
// ---------------------------------------------------------------------
db.createCollection("catalogue", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["title", "item_type", "category", "publication_year"],
      properties: {
        title: { bsonType: "string", description: "must be a string" },
        item_type: {
          enum: ["Book", "Journal", "E-book"],
          description: "must be Book, Journal or E-book",
        },
        category: { bsonType: "string" },
        publication_year: { bsonType: "number", minimum: 1450, maximum: 2100 },
        copies: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["copy_id", "branch", "status"],
            properties: {
              copy_id: { bsonType: "string" },
              branch: { enum: ["Central", "Eastside", "Northgate"] },
              status: { enum: ["Available", "On Loan", "Lost", "Damaged"] },
            },
          },
        },
        licences: {
          bsonType: "object",
          required: ["total", "in_use"],
          properties: {
            total: { bsonType: "number", minimum: 0 },
            in_use: { bsonType: "number", minimum: 0 },
          },
        },
      },
    },
  },
  validationAction: "error",
});

db.createCollection("members");
db.createCollection("loans");

// Verification: list the collections
db.getCollectionNames();
