// =====================================================================
// Greenfield Community Library Management System
// Portfolio 5, Part A: Replication on MongoDB Atlas
// =====================================================================
// Run in the MongoDB shell in Compass, ONE numbered block at a time.
// Your Atlas cluster is a REPLICA SET: three servers each holding a
// full copy of the data. One is the PRIMARY (accepts writes); the
// others are SECONDARIES (copy every change from the primary).
// =====================================================================

db = db.getSiblingDB("library_nosql");   // switch to the library_nosql database


// ---------------------------------------------------------------------
// R1. Inspect the replica set
// Shows the replica set name, its member servers, which one is the
// primary, and which one this shell is talking to.
// ---------------------------------------------------------------------
(() => {
  const h = db.hello();
  return {
    replica_set:  h.setName,
    members:      h.hosts,
    primary:      h.primary,
    connected_to: h.me,
    is_primary:   h.isWritablePrimary
  };
})();


// ---------------------------------------------------------------------
// R2. Which server answers a read?
// The read preference decides where reads go. explain() reports the
// host that actually ran the query.
// Expect two DIFFERENT host names: the primary and a secondary.
// ---------------------------------------------------------------------
({
  read_from_primary:   db.catalogue.find({ _id: "B001" }).readPref("primary").explain().serverInfo.host,
  read_from_secondary: db.catalogue.find({ _id: "B001" }).readPref("secondary").explain().serverInfo.host
});


// ---------------------------------------------------------------------
// R3. The data really is replicated
// Read Things Fall Apart from a SECONDARY. It returns the same data,
// including the copy status changed in Portfolio 4 (B001-C1 On Loan),
// proving that writes made on the primary were copied across.
// ---------------------------------------------------------------------
db.catalogue.find({ _id: "B001" }, { _id: 0, title: 1, copies: 1 }).readPref("secondary");


// ---------------------------------------------------------------------
// R4. Write concern: speed versus safety
// w: 1          -> acknowledged once the PRIMARY has the write (fast)
// w: "majority" -> acknowledged once MOST members have it (safer:
//                  survives the primary failing straight afterwards)
// Each is timed over 5 inserts into a scratch collection.
// ---------------------------------------------------------------------
(() => {
  db.replication_test.drop();
  const avgMs = (wc) => {
    let total = 0;
    for (let i = 0; i < 5; i++) {
      const start = Date.now();
      db.replication_test.insertOne({ write_concern: JSON.stringify(wc), at: new Date() },
                                    { writeConcern: wc });
      total += Date.now() - start;
    }
    return Math.round(total / 5);
  };
  return {
    "w:1 average ms":        avgMs({ w: 1 }),
    "w:majority average ms": avgMs({ w: "majority" }),
    documents_written:       db.replication_test.countDocuments()
  };
})();


// ---------------------------------------------------------------------
// R5. An impossible write concern (ERROR expected)
// Asking for 5 copies when the replica set only has 3 members cannot
// be satisfied, so MongoDB refuses instead of pretending.
// ---------------------------------------------------------------------
(() => {
  try {
    db.replication_test.insertOne({ write_concern: "w:5", at: new Date() },
                                  { writeConcern: { w: 5, wtimeout: 5000 } });
    return "Insert acknowledged (unexpected)";
  } catch (e) {
    return { error: e.codeName || e.name, message: e.message };
  }
})();


// ---------------------------------------------------------------------
// R6. Read concern "majority"
// Returns only data that a majority of members have confirmed, so the
// result can never be "rolled back" if the primary fails.
// ---------------------------------------------------------------------
db.catalogue.find({ _id: "E002" }, { _id: 0, title: 1, licences: 1 }).readConcern("majority");


// ---------------------------------------------------------------------
// R7. Clean up the scratch collection
// ---------------------------------------------------------------------
db.replication_test.drop();
