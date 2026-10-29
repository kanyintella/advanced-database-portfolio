# Portfolio 5 – Distributed and Cloud Database Exercise

**Case study:** Greenfield Community Library Management System
**Environment:** MongoDB 8.0 on MongoDB Atlas (free M0 cluster, Microsoft Azure, 1 region); PostgreSQL 18 with pgAdmin 4

Greenfield has three branches that all depend on one shared catalogue and
loan system. This portfolio examines how that data can be **replicated**
for availability, **partitioned** for scale, kept **consistent**, and
**deployed securely in the cloud**. It combines practical work on the
Atlas cluster from Portfolio 4 and the PostgreSQL database from
Portfolios 1–3 with a design for the library's distributed deployment.

---

## 1. Files in this folder

| File | Tool | Description |
|---|---|---|
| `01_replication.js` | MongoDB shell (Compass) | Part A: inspects the replica set, reads from primary and secondary, compares write concerns |
| `02_partitioning.sql` | pgAdmin | Part B: splits the 203,000-row loan table into yearly partitions and tests partition pruning |
| `screenshots/` | | Evidence for every step |

---

## 2. Part A – Replication on MongoDB Atlas

### R1 – The cluster is a three-member replica set

`db.hello()` reports the cluster's real topology:

| Property | Value |
|---|---|
| Replica set name | `atlas-6mxapc-shard-0` |
| Members | `ac-00gt3ax-shard-00-00`, `-01`, `-02` (port 27017) |
| Primary | `ac-00gt3ax-shard-00-02` |
| Shell connected to | `ac-00gt3ax-shard-00-02` (the primary) |

Every member holds a **full copy** of the data. Only the **primary**
accepts writes; the two **secondaries** continuously copy its changes
from the operation log (oplog). If the primary fails, the remaining
members hold an **election** and promote a secondary, so the database
stays available without manual intervention.

![R1](screenshots/r1-replica-set.png)

### R2 – Reads can be served by different servers

The **read preference** decides which member answers a read. `explain()`
reports the server that actually ran the query:

| Read preference | Server that answered |
|---|---|
| `primary` | `ac-00gt3ax-shard-00-02` |
| `secondary` | `ac-00gt3ax-shard-00-00` |

Two different machines answered the same query. Reading from secondaries
spreads the load, so busy catalogue searches at three branches do not
all compete with writes on the primary.

![R2](screenshots/r2-read-hosts.png)

### R3 – The data really is replicated

Reading Things Fall Apart **from a secondary** shows copy B001-C1 as
**On Loan**. That change was made on the primary in Portfolio 4 (Q6), so
the secondary has received and applied it.

![R3](screenshots/r3-secondary-read.png)

### R4 – Write concern: speed versus safety

| Write concern | Meaning | Average time (5 inserts) |
|---|---|---|
| `w: 1` | Acknowledged when the **primary** has the write | 216 ms |
| `w: "majority"` | Acknowledged when **2 of 3** members have it | 204 ms |

In theory, `majority` should be slower, because it waits for a secondary
to confirm. Here, the two were **effectively the same** (the difference
is within normal variation). **Finding:** about 200 ms of each write is
the network round trip between this computer and the Azure data centre.
All three members sit in the **same region**, so copying a write to a
secondary adds only a few milliseconds, which is lost in the internet
delay. The cost of `majority` would become visible if the members were
spread across **different regions**, where every write would have to
cross a long-distance link before being confirmed.

The practical conclusion is that, for a single-region cluster, the extra
safety of `w: "majority"` is almost free. A write acknowledged by a
majority **survives the primary failing immediately afterwards**, whereas
a `w: 1` write could be lost (rolled back) if the primary crashed before
copying it.

![R4](screenshots/r4-write-concern.png)

### R5 – An impossible write concern is refused

Requesting `w: 5` on a three-member set fails immediately:

```
error:   UnsatisfiableWriteConcern
message: Not enough data-bearing nodes
```

MongoDB refuses a durability guarantee it cannot provide, rather than
acknowledging the write and silently giving a weaker guarantee.

![R5](screenshots/r5-impossible-write.png)

### R6 – Read concern "majority"

A read with `readConcern("majority")` only returns data that a majority
of members have confirmed. E002 shows **2 of 3 licences in use**, the
value written by the Portfolio 4 transaction, so that transaction had
been fully replicated. A majority read can never return a value that is
later rolled back after a failover.

![R6](screenshots/r6-read-concern.png)

---

## 3. Part B – Horizontal Partitioning in PostgreSQL

**Sharding** (splitting a collection across several servers) requires a
dedicated Atlas tier and is not available on the free M0 cluster. The
same underlying idea, **horizontal partitioning**, was therefore
demonstrated on one server in PostgreSQL. In partitioning, a table's rows
are split into separate pieces by a key. Sharding places those pieces on
different machines.

### P0–P3 – Building the partitioned table

A new table, `loan_partitioned`, was created with
`PARTITION BY RANGE (borrow_date)`, with one partition per year plus a
`DEFAULT` partition for dates outside the defined ranges. All loans were
copied in, and PostgreSQL routed each row to the correct partition
automatically. The original `loan` table was left unchanged.

The index `idx_loan_borrow_date` was dropped first, following the
recommendation from Portfolio 2, so that the original table could be
compared fairly.

### P4 – Rows per partition

| Partition | Rows | Range |
|---|---|---|
| `loan_2023` | 13,723 | Oct–Dec 2023 |
| `loan_2024` | 70,733 | full year |
| `loan_2025` | 70,527 | full year |
| `loan_2026` | 48,019 | Jan–Oct 2026 |
| **Total** | **203,002** | |

`loan_2027` and `loan_default` are empty and ready for future data.

![P4](screenshots/p4-partition-counts.png)

### P5 vs P6 – Partition pruning

The same query, counting the loans borrowed in 2026, was run on both
tables:

| | Original `loan` (P5) | `loan_partitioned` (P6) |
|---|---|---|
| Plan | Parallel Seq Scan on `loan` | Seq Scan on **`loan_2026` only** |
| Pages read (Buffers) | **1,490** | **351** |
| Rows filtered out | 77,492 per worker | 0 |
| Execution time | 36.688 ms | **5.599 ms** |

PostgreSQL saw that only the 2026 partition could contain matching rows
and **never opened the other partitions**. This is **partition pruning**.
The query read **76% fewer pages** and ran about **6.5 times faster**.

This also solves the problem left open in **Portfolio 2, Experiment 3**:
an index on `borrow_date` barely helped a 12-month report, because the
matching rows were spread across every page of the table. Partitioning
by date physically groups each year's rows together, so a date-range
query reads only the relevant part of the data.

| P5 – Original table | P6 – Partitioned table |
|---|---|
| ![](screenshots/p5-original-table.png) | ![](screenshots/p6-partition-pruning.png) |

### P7 – The trade-off: queries without the partition key

Filtering by `member_id` instead of date gives PostgreSQL no way to skip
partitions. The plan scans **all six partitions** (1,492 pages, 48.108 ms),
slightly more work than the unpartitioned table.

**A partition key helps the queries that use it, and can hurt those
that do not.** In a sharded system this effect is much larger: a query
without the shard key becomes a **scatter-gather** query, sent to every
server with the results merged afterwards. Choosing the key around the
system's most important queries is therefore the central design decision
(see Section 4).

![P7](screenshots/p7-no-pruning.png)

### P8 – Archiving by detaching a partition

`ALTER TABLE loan_partitioned DETACH PARTITION loan_2023;` removed a year
of history from the active table instantly: **189,279** rows remain
active, while the **13,723** rows of 2023 still exist in a standalone
table. Doing the same with `DELETE` would scan the table and remove rows
one by one. The detached table could be moved to cheaper storage or
exported, which is how data **lifecycle management** works at scale.

![P8](screenshots/p8-detach.png)

---

## 4. Part C – Distributed Design for Greenfield Library

### 4.1 Proposed architecture

| Component | Deployment | Reason |
|---|---|---|
| Catalogue (MongoDB) | Atlas replica set of 3 members | Read-heavy and shared by all branches; replicas spread search load and survive a server failure |
| Members, loans, fines (PostgreSQL) | Managed cloud PostgreSQL with one primary and at least one standby replica | Transactional data that needs foreign keys and strong consistency (Portfolios 1–3) |
| Branch desks and the public website | Connect over TLS to the cloud databases | No database servers to run inside the branches |

At Greenfield's current size, **sharding is not needed**: 203,000 loans
occupy about 12 MB (1,490 pages of 8 kB), which one server handles
easily. Replication is needed now for **availability**. Sharding would
only become necessary if the library grew into a regional or national
network with far larger volumes.

### 4.2 Sharding strategy, if the library grows

Only the `loans` data would grow large enough to shard. The catalogue is
small and is best fully replicated. Three candidate shard keys:

| Shard key | Advantages | Disadvantages |
|---|---|---|
| `borrow_date` (range) | Date reports and archiving touch few shards (as P6 and P8 showed) | **Hot spot**: every new loan has today's date, so all writes hit the newest shard |
| `branch` (zone sharding) | Each branch's data can sit in a data centre near it | **Uneven**: the busiest branch overloads its shard; system-wide reports become scatter-gather |
| **hashed `member_id`** | Writes spread evenly across shards; a member's full history is on **one** shard | Date-range reports become scatter-gather (as P7 showed) |

**Recommendation: hashed `member_id`.** The most frequent operations are
borrowing, returning and showing a member's loans, and all of these
include the member, so they are routed to a single shard. Date-based
reports run less often and can tolerate scatter-gather, or can be served
from a separate reporting copy.

### 4.3 Consistency and the CAP theorem

The **CAP theorem** states that when a **network partition** splits a
distributed system, it must choose between **Consistency** (every read
sees the latest write) and **Availability** (every request gets an
answer).

A MongoDB replica set chooses **consistency** for writes. Only the side
of a split that can reach a **majority** of members can elect a primary.
The minority side cannot accept writes, so two branches can never update
the same data independently and create conflicts. Reads, however, are
**tunable** (R2, R6): reading from a secondary may return slightly stale
data, which is **eventual consistency**.

Greenfield should choose per operation:

| Operation | Read / write settings | Reason |
|---|---|---|
| Borrowing, returning, licences | Primary reads, `w: "majority"` | Must never double-lend or lose a loan |
| Paying fines | Primary, `w: "majority"`, `readConcern: "majority"` | Money: no lost or rolled-back updates |
| Catalogue browsing and search | `secondaryPreferred` | A copy status a second out of date is acceptable; the final borrow is still checked atomically on the primary (Portfolio 4, Q6) |
| Monthly reports | Secondary, or a separate reporting replica | Heavy reads kept away from the primary |

### 4.4 Availability and failover

- A **three-member** replica set survives the loss of **any one** member:
  the other two still form a majority and elect a new primary, usually
  within seconds. Modern drivers **retry writes** automatically during
  an election.
- The cluster runs in **one Azure region** ("Electable nodes: Azure,
  1 region" on the cluster page). An outage of the whole region would
  stop the service. Production should spread members across at least
  **two regions or availability zones**, accepting the extra write
  latency that R4 suggests.
- The free cluster shows **Backups: OFF** and **Auto-scaling: OFF**.
  Production needs scheduled backups with point-in-time recovery, since
  replication protects against server failure but **not** against
  mistakes: an accidental delete is replicated to every member within
  milliseconds.
- Failover testing was **not possible on the free tier**. On a dedicated
  cluster, Atlas can trigger a controlled primary failover to test that
  the application recovers.

![Atlas cluster](../portfolio-4-nosql/screenshots/00-atlas-cluster.png)

### 4.5 Cloud security

| Control | Evidence | Assessment |
|---|---|---|
| **Network access list** | Only listed IP addresses can connect | Effective, but the list holds **three** entries because the home internet IP changed during the project (Portfolio 4). A production system should use fixed IPs, VPC peering or a private endpoint, never `0.0.0.0/0` |
| **Encryption in transit** | Connections use TLS (the blocked connection in Portfolio 4 failed during the TLS handshake) | Good: data is encrypted between branch and cloud |
| **Authentication** | User `library_admin` with SCRAM | Good |
| **Authorisation** | `library_admin` has `atlasAdmin@admin` on **All Resources** | **Too broad.** The application should use a separate user with only `readWrite` on `library_nosql` (**least privilege**), so a stolen password cannot be used to delete other databases or change cluster settings |
| **Secrets** | The connection string and password are not committed to GitHub | Good: credentials are kept out of version control |

| Database users | IP access list (addresses partially hidden) |
|---|---|
| ![](screenshots/atlas-database-users.png) | ![](screenshots/atlas-network-access.png) |

---

## 5. Key Findings

1. **Replication works and is visible:** three members, reads served by
   two different servers, and a Portfolio 4 change already present on a
   secondary.
2. **Network distance dominates write latency.** `w: "majority"` cost
   nothing extra in a single region, because the 200 ms internet round
   trip outweighed the time to copy writes between nearby members.
3. **Partitioning makes date queries cheaper:** 1,490 pages down to
   351, and about 6.5 times faster. This fixes the case where an index
   could not help (Portfolio 2, Experiment 3).
4. **The partition or shard key is a trade-off:** queries that use it get
   faster, and those that do not touch every partition (P7) or every
   shard.
5. **Replication is not backup,** and the free tier has backups off.
6. **The cloud setup works but is not production-ready:** single region,
   no backups, and an over-privileged database user. Each has a clear fix.

---

## 6. How to Run

**Part A (MongoDB Atlas):**
1. Make sure your current IP address is on the Atlas IP Access List.
2. In Compass, open the MongoDB shell and run
   `db = db.getSiblingDB("library_nosql");`, then check the prompt shows
   `library_nosql>`.
3. Run each block of `01_replication.js` on its own.

**Part B (PostgreSQL):**
1. In pgAdmin, open the Query Tool on `library_db` (requires the
   Portfolio 1 schema and Portfolio 2 data).
2. Run each numbered block of `02_partitioning.sql` (P0 to P8) on its
   own. The script can be re-run; P0 cleans up any previous run.

**Note:** `01_replication.js` is JavaScript and only runs in the MongoDB
shell; `02_partitioning.sql` is SQL and only runs in pgAdmin.
