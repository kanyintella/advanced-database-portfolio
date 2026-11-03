// =====================================================================
// Greenfield Community Library Management System
// Portfolio 4, Step 2: Insert documents
// =====================================================================

db = db.getSiblingDB("library_nosql"); // switch to the library_nosql database

// ---------------------------------------------------------------------
// CATALOGUE (10 items: 4 books, 3 journals, 3 e-books)
// ---------------------------------------------------------------------
db.catalogue.insertMany([
  // ---- Books: physical copies, held at branches ----
  {
    _id: "B001",
    item_type: "Book",
    title: "Things Fall Apart",
    authors: [{ first_name: "Chinua", last_name: "Achebe" }],
    publisher: "Heinemann",
    publication_year: 1958,
    category: "Fiction",
    pages: 209,
    tags: ["African literature", "classic"],
    copies: [
      { copy_id: "B001-C1", branch: "Central", status: "Available" },
      { copy_id: "B001-C2", branch: "Central", status: "On Loan" },
      { copy_id: "B001-C3", branch: "Eastside", status: "Available" },
    ],
  },
  {
    _id: "B002",
    item_type: "Book",
    title: "Half of a Yellow Sun",
    authors: [{ first_name: "Chimamanda Ngozi", last_name: "Adichie" }],
    publisher: "Farafina",
    publication_year: 2006,
    category: "Fiction",
    pages: 433,
    awards: ["Orange Prize for Fiction (2007)"],
    tags: ["African literature", "historical fiction"],
    copies: [
      { copy_id: "B002-C1", branch: "Northgate", status: "On Loan" },
      { copy_id: "B002-C2", branch: "Central", status: "Available" },
    ],
  },
  {
    _id: "B003",
    item_type: "Book",
    title: "Fundamentals of Database Systems",
    authors: [
      { first_name: "Ramez", last_name: "Elmasri" },
      { first_name: "Shamkant B.", last_name: "Navathe" },
    ],
    publisher: "Pearson",
    publication_year: 2016,
    edition: 7,
    category: "Technology",
    isbn: "978-0133970777",
    pages: 1272,
    tags: ["databases", "textbook"],
    copies: [
      { copy_id: "B003-C1", branch: "Central", status: "Available" },
      { copy_id: "B003-C2", branch: "Northgate", status: "Damaged" },
    ],
  },
  {
    _id: "B004",
    item_type: "Book",
    title: "Death and the King's Horseman",
    authors: [{ first_name: "Wole", last_name: "Soyinka" }],
    publisher: "Methuen",
    publication_year: 1975,
    category: "Drama",
    pages: 77,
    tags: ["African literature", "play"],
    copies: [{ copy_id: "B004-C1", branch: "Eastside", status: "Lost" }],
  },

  // ---- Journals: issues with editors and an embedded list of articles ----
  {
    _id: "J001",
    item_type: "Journal",
    title: "Journal of African Library and Information Science",
    editors: [{ first_name: "Ngozi", last_name: "Okafor" }],
    publication_year: 2026,
    category: "Library Science",
    issn: "2026-0012",
    volume: 12,
    issue: 3,
    frequency: "Quarterly",
    reference_only: true,
    articles: [
      {
        title: "Digital Lending in Community Libraries",
        authors: ["E. Bello", "F. Adeyemi"],
        pages: "1-14",
      },
      {
        title: "Cataloguing Indigenous Language Materials",
        authors: ["I. Musa"],
        pages: "15-29",
      },
    ],
    copies: [{ copy_id: "J001-C1", branch: "Central", status: "Available" }],
  },
  {
    _id: "J002",
    item_type: "Journal",
    title: "Journal of African Library and Information Science",
    editors: [{ first_name: "Ngozi", last_name: "Okafor" }],
    publication_year: 2026,
    category: "Library Science",
    issn: "2026-0012",
    volume: 12,
    issue: 2,
    frequency: "Quarterly",
    reference_only: true,
    articles: [
      {
        title: "Measuring Library Usage with Open Data",
        authors: ["C. Eze"],
        pages: "1-18",
      },
    ],
    copies: [{ copy_id: "J002-C1", branch: "Central", status: "Available" }],
  },
  {
    _id: "J003",
    item_type: "Journal",
    title: "West African Computing Review",
    editors: [
      { first_name: "Tunde", last_name: "Bello" },
      { first_name: "Aisha", last_name: "Lawal" },
    ],
    publication_year: 2025,
    category: "Technology",
    issn: "2025-0441",
    volume: 8,
    issue: 1,
    frequency: "Biannual",
    reference_only: false,
    articles: [
      {
        title: "NoSQL Adoption in Nigerian Fintech",
        authors: ["D. Nwosu"],
        pages: "3-21",
      },
      {
        title: "Cloud Databases for Public Services",
        authors: ["G. Johnson", "Y. Abubakar"],
        pages: "22-40",
      },
    ],
    copies: [
      { copy_id: "J003-C1", branch: "Eastside", status: "Available" },
      { copy_id: "J003-C2", branch: "Northgate", status: "Available" },
    ],
  },

  // ---- E-books: no physical copies; limited digital licences instead ----
  {
    _id: "E001",
    item_type: "E-book",
    title: "Python for Data Analysis",
    authors: [{ first_name: "Wes", last_name: "McKinney" }],
    publisher: "O'Reilly Media",
    publication_year: 2022,
    edition: 3,
    category: "Technology",
    isbn: "978-1098104030",
    formats: ["EPUB", "PDF"],
    file_size_mb: 12.4,
    drm: true,
    licences: { total: 2, in_use: 2 },
  },
  {
    _id: "E002",
    item_type: "E-book",
    title: "Designing Data-Intensive Applications",
    authors: [{ first_name: "Martin", last_name: "Kleppmann" }],
    publisher: "O'Reilly Media",
    publication_year: 2017,
    category: "Technology",
    isbn: "978-1449373320",
    formats: ["EPUB"],
    file_size_mb: 18.9,
    drm: true,
    licences: { total: 3, in_use: 1 },
  },
  {
    _id: "E003",
    item_type: "E-book",
    title: "Purple Hibiscus",
    authors: [{ first_name: "Chimamanda Ngozi", last_name: "Adichie" }],
    publisher: "Algonquin Books",
    publication_year: 2003,
    category: "Fiction",
    formats: ["EPUB", "MOBI"],
    file_size_mb: 2.1,
    drm: false,
    licences: { total: 2, in_use: 0 },
  },
]);

// ---------------------------------------------------------------------
// MEMBERS (5): address and preferences are embedded.
// Student members have extra fields that other members do not.
// ---------------------------------------------------------------------
db.members.insertMany([
  {
    _id: "M101",
    first_name: "Adaeze",
    last_name: "Okeke",
    email: "adaeze.okeke@mail.com",
    membership_type: "Student",
    phones: ["08031234567"],
    address: { street: "14 Ahmadu Bello Way", city: "Abuja" },
    student: {
      institution: "MIVA Open University",
      matric_no: "MIT/2026/0141",
    },
    preferences: { categories: ["Technology", "Fiction"], notify_by: "email" },
    join_date: new Date("2025-02-10"),
  },
  {
    _id: "M102",
    first_name: "Chinedu",
    last_name: "Obi",
    email: "chinedu.obi@mail.com",
    membership_type: "Standard",
    phones: ["08025550198", "09011112222"],
    address: { street: "3 Unity Avenue", city: "Abuja" },
    preferences: { categories: ["Fiction"], notify_by: "sms" },
    join_date: new Date("2023-07-01"),
  },
  {
    _id: "M103",
    first_name: "Fatima",
    last_name: "Ibrahim",
    email: "fatima.ibrahim@mail.com",
    membership_type: "Premium",
    phones: ["08067778899"],
    address: { street: "22 Lake Road", city: "Abuja" },
    preferences: {
      categories: ["Library Science", "Drama"],
      notify_by: "email",
    },
    join_date: new Date("2022-11-15"),
  },
  {
    _id: "M104",
    first_name: "Obinna",
    last_name: "Eze",
    email: "obinna.eze@mail.com",
    membership_type: "Student",
    phones: ["07034445566"],
    address: { street: "9 Independence Way", city: "Abuja" },
    student: { institution: "University of Abuja", matric_no: "CSC/22/1180" },
    join_date: new Date("2024-09-20"),
  },
  {
    _id: "M105",
    first_name: "Sade",
    last_name: "Ojo",
    email: "sade.ojo@mail.com",
    membership_type: "Standard",
    phones: ["08120001111"],
    address: { street: "5 Market Street", city: "Abuja" },
    join_date: new Date("2026-03-05"),
  },
]);

// ---------------------------------------------------------------------
// LOANS (8): each loan REFERENCES a member and an item.
// The title is copied into the loan (a "snapshot") so loan lists can be
// shown without looking up the catalogue. return_date: null = still out.
// E-book loans use a licence instead of a physical copy.
// ---------------------------------------------------------------------
db.loans.insertMany([
  {
    member_id: "M102",
    item_id: "B001",
    copy_id: "B001-C2",
    title: "Things Fall Apart",
    borrow_date: new Date("2026-10-01"),
    due_date: new Date("2026-10-15"),
    return_date: null,
  },
  {
    member_id: "M101",
    item_id: "B002",
    copy_id: "B002-C1",
    title: "Half of a Yellow Sun",
    borrow_date: new Date("2026-10-12"),
    due_date: new Date("2026-10-26"),
    return_date: null,
  },
  {
    member_id: "M101",
    item_id: "E001",
    licence: true,
    title: "Python for Data Analysis",
    borrow_date: new Date("2026-10-05"),
    due_date: new Date("2026-10-19"),
    return_date: null,
  },
  {
    member_id: "M104",
    item_id: "E001",
    licence: true,
    title: "Python for Data Analysis",
    borrow_date: new Date("2026-10-15"),
    due_date: new Date("2026-10-29"),
    return_date: null,
  },
  {
    member_id: "M103",
    item_id: "E002",
    licence: true,
    title: "Designing Data-Intensive Applications",
    borrow_date: new Date("2026-10-18"),
    due_date: new Date("2026-11-01"),
    return_date: null,
  },
  {
    member_id: "M101",
    item_id: "B003",
    copy_id: "B003-C1",
    title: "Fundamentals of Database Systems",
    borrow_date: new Date("2026-08-01"),
    due_date: new Date("2026-08-15"),
    return_date: new Date("2026-08-14"),
  },
  {
    member_id: "M105",
    item_id: "B001",
    copy_id: "B001-C1",
    title: "Things Fall Apart",
    borrow_date: new Date("2026-07-03"),
    due_date: new Date("2026-07-17"),
    return_date: new Date("2026-07-22"),
  },
  {
    member_id: "M101",
    item_id: "B001",
    copy_id: "B001-C3",
    title: "Things Fall Apart",
    borrow_date: new Date("2026-05-10"),
    due_date: new Date("2026-05-24"),
    return_date: new Date("2026-05-20"),
  },
]);

// Verification: document count in each collection
({
  catalogue: db.catalogue.countDocuments(),
  members: db.members.countDocuments(),
  loans: db.loans.countDocuments(),
});
