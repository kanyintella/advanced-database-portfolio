-- =====================================================================
-- Greenfield Community Library Management System
-- Portfolio 2, Step 1: Load realistic sample data
-- =====================================================================

TRUNCATE fine, loan, staff, member, book_copy, book_author, author, book, branch
RESTART IDENTITY CASCADE;

SELECT setseed(0.42);

-- ---------------------------------------------------------------------
-- Branches (3)
-- ---------------------------------------------------------------------
INSERT INTO branch (name, address) VALUES
  ('Central Branch',  '12 Independence Way'),
  ('Eastside Branch', '4 Lake Road'),
  ('Northgate Branch','27 Unity Avenue');

-- ---------------------------------------------------------------------
-- Staff (10 per branch = 30)
-- Staff 1-10 work at branch 1, 11-20 at branch 2, 21-30 at branch 3
-- ---------------------------------------------------------------------
INSERT INTO staff (first_name, last_name, role, branch_id)
SELECT
  (ARRAY['Ngozi','Emeka','Aisha','Tunde','Chioma','Ibrahim','Funke','Daniel','Grace','Yusuf'])[((s-1) % 10) + 1],
  (ARRAY['Okafor','Bello','Adeyemi','Musa','Eze','Ogunleye','Abubakar','Nwosu','Lawal','Johnson'])[((s * 7) % 10) + 1],
  CASE WHEN (s - 1) % 10 = 0 THEN 'Branch Manager'
       WHEN (s - 1) % 10 = 1 THEN 'Administrator'
       ELSE 'Librarian' END,
  ((s - 1) / 10) + 1
FROM generate_series(1, 30) AS s;

-- ---------------------------------------------------------------------
-- Authors (1,500)
-- ---------------------------------------------------------------------
INSERT INTO author (first_name, last_name)
SELECT
  (ARRAY['Chinua','Wole','Chimamanda','Ngugi','Ben','Buchi','Jane','George','Toni','Gabriel',
         'Ama','Teju','Helon','Sefi','Ayobami','Akwaeke','Nnedi','Elif','Haruki','Margaret'])[1 + floor(random() * 20)::int],
  (ARRAY['Achebe','Soyinka','Adichie','Thiong''o','Okri','Emecheta','Austen','Orwell','Morrison','Marquez',
         'Aidoo','Cole','Habila','Atta','Adebayo','Emezi','Okorafor','Shafak','Murakami','Atwood',
         'Okonkwo','Balogun','Danjuma','Ekwueme','Fashola'])[1 + floor(random() * 25)::int]
FROM generate_series(1, 1500);

-- ---------------------------------------------------------------------
-- Books (5,000)
-- Titles are built from word lists, e.g. "The Silent River of Kano"
-- ---------------------------------------------------------------------
INSERT INTO book (isbn, title, publisher, publication_year, category, item_type)
SELECT
  '978-' || lpad(n::text, 10, '0'),
  (ARRAY['The','A','Beyond the','Under the','Songs of the','Return of the','Secrets of the','Letters to the'])[1 + floor(random() * 8)::int]
    || ' ' ||
  (ARRAY['Silent','Burning','Hidden','Golden','Broken','Distant','Forgotten','Crimson','Endless','Quiet'])[1 + floor(random() * 10)::int]
    || ' ' ||
  (ARRAY['River','Kingdom','Harvest','Market','Season','Bridge','Storm','Garden','Journey','Drum'])[1 + floor(random() * 10)::int]
    || ' ' || n,
  (ARRAY['Heinemann','Cassava Republic','Farafina','Penguin','HarperCollins','Macmillan','Longman','Spectrum'])[1 + floor(random() * 8)::int],
  1950 + floor(random() * 76)::int,
  (ARRAY['Fiction','History','Science','Technology','Business','Children','Poetry','Biography','Law','Medicine'])[1 + floor(random() * 10)::int],
  CASE WHEN random() < 0.80 THEN 'Book'
       WHEN random() < 0.50 THEN 'Journal'
       ELSE 'E-book' END
FROM generate_series(1, 5000) AS n;

-- ---------------------------------------------------------------------
-- Book authors: every book gets 1 author, about 25% get a second
-- ---------------------------------------------------------------------
INSERT INTO book_author (book_id, author_id)
SELECT book_id, 1 + floor(random() * 1500)::int
FROM book;

INSERT INTO book_author (book_id, author_id)
SELECT book_id, 1 + floor(random() * 1500)::int
FROM book
WHERE random() < 0.25
ON CONFLICT DO NOTHING;   

-- ---------------------------------------------------------------------
-- Book copies: each book has 1 to 5 copies spread across branches
-- ---------------------------------------------------------------------
INSERT INTO book_copy (book_id, branch_id)
SELECT b.book_id, 1 + floor(random() * 3)::int
FROM book b
CROSS JOIN LATERAL generate_series(1, 1 + floor(random() * 5)::int + (b.book_id * 0)) AS c;

-- ---------------------------------------------------------------------
-- Members (10,000)
-- ---------------------------------------------------------------------
INSERT INTO member (first_name, last_name, email, phone, membership_type, join_date)
SELECT
  fn, ln,
  lower(fn) || '.' || lower(replace(ln, '''', '')) || n || '@mail.com',
  '080' || lpad((floor(random() * 100000000))::text, 8, '0'),
  CASE WHEN random() < 0.6 THEN 'Standard'
       WHEN random() < 0.7 THEN 'Student'
       ELSE 'Premium' END,
  DATE '2020-01-01' + floor(random() * 1900)::int
FROM (
  SELECT n,
    (ARRAY['Adaeze','Bola','Chinedu','Damilola','Efe','Fatima','Gbenga','Halima','Ikenna','Jumoke',
           'Kelechi','Lola','Musa','Nkechi','Obinna','Peace','Rasheed','Sade','Tobi','Uche'])[1 + floor(random() * 20)::int] AS fn,
    (ARRAY['Okeke','Adewale','Ibrahim','Obi','Salami','Nwachukwu','Ojo','Yakubu','Eze','Afolabi',
           'Uzor','Bakare','Garba','Okoro','Adeleke'])[1 + floor(random() * 15)::int] AS ln
  FROM generate_series(1, 10000) AS n
) AS names;

-- ---------------------------------------------------------------------
-- Historical (returned) loans: 200,000 over the past 3 years
-- Each loan lasts 14 days; about 20% are returned late.
-- Staff are chosen from the branch that holds the copy.
-- ---------------------------------------------------------------------
INSERT INTO loan (copy_id, member_id, staff_id, borrow_date, due_date, return_date)
SELECT
  copy_id, member_id,
  (branch_id - 1) * 10 + 1 + floor(random() * 10)::int,
  borrow_date,
  borrow_date + 14,
  CASE WHEN random() < 0.80
       THEN borrow_date + 1 + floor(random() * 14)::int      -- on time
       ELSE borrow_date + 15 + floor(random() * 30)::int     -- late
  END
FROM (
  SELECT
    c.copy_id, c.branch_id, r.member_id, r.borrow_date
  FROM (
    -- pick a random copy, member and date for each of the 200,000 loans
    -- (done in a subquery so each random value is generated only once)
    SELECT
      1 + floor(random() * (SELECT max(copy_id) FROM book_copy))::int AS copy_id,
      1 + floor(random() * 10000)::int AS member_id,
      CURRENT_DATE - 60 - floor(random() * 1035)::int AS borrow_date
    FROM generate_series(1, 200000)
  ) AS r
  JOIN book_copy c ON c.copy_id = r.copy_id
) AS x;

-- ---------------------------------------------------------------------
-- Current (open) loans: 3,000 distinct copies currently on loan.
-- return_date is NULL. Loans older than 14 days are overdue.
-- ---------------------------------------------------------------------
INSERT INTO loan (copy_id, member_id, staff_id, borrow_date, due_date, return_date)
SELECT
  copy_id, 1 + floor(random() * 10000)::int,
  (branch_id - 1) * 10 + 1 + floor(random() * 10)::int,
  bd, bd + 14, NULL
FROM (
  SELECT copy_id, branch_id, CURRENT_DATE - floor(random() * 45)::int AS bd
  FROM (
    SELECT copy_id, branch_id
    FROM book_copy
    ORDER BY random()
    LIMIT 3000
  ) AS picked
) AS open_loans;

-- Copies with an open loan are marked as On Loan
UPDATE book_copy SET status = 'On Loan'
WHERE copy_id IN (SELECT copy_id FROM loan WHERE return_date IS NULL);

-- A few copies are lost or damaged
UPDATE book_copy SET status = CASE WHEN random() < 0.5 THEN 'Lost' ELSE 'Damaged' END
WHERE status = 'Available' AND random() < 0.01;

-- ---------------------------------------------------------------------
-- Fines: 50.00 per day late, for every loan returned late.
-- About 85% have been paid.
-- ---------------------------------------------------------------------
INSERT INTO fine (loan_id, amount, paid_status)
SELECT loan_id,
       (return_date - due_date) * 50.00,
       CASE WHEN random() < 0.85 THEN 'Paid' ELSE 'Unpaid' END
FROM loan
WHERE return_date > due_date;

-- Update planner statistics so EXPLAIN shows accurate estimates
ANALYZE;

-- =====================================================================
-- Verification: row count for every table
-- =====================================================================
SELECT 'branch' AS table_name, COUNT(*) AS row_count FROM branch
UNION ALL SELECT 'staff',       COUNT(*) FROM staff
UNION ALL SELECT 'author',      COUNT(*) FROM author
UNION ALL SELECT 'book',        COUNT(*) FROM book
UNION ALL SELECT 'book_author', COUNT(*) FROM book_author
UNION ALL SELECT 'book_copy',   COUNT(*) FROM book_copy
UNION ALL SELECT 'member',      COUNT(*) FROM member
UNION ALL SELECT 'loan',        COUNT(*) FROM loan
UNION ALL SELECT 'fine',        COUNT(*) FROM fine;
