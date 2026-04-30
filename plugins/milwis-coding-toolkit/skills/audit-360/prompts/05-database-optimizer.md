# Prompt for `database-optimizer` — schema, indexes, perf

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: database-optimizer
description: DB performance + schema audit — indexes, N+1, EXPLAIN, partitioning
prompt: |
  You are auditing performance and structure of the database(s) listed in
  <INVENTORY_PATH> §6. Mode: READ-ONLY.

  Approach: measure first → identify bottleneck → one change at a time →
  document decisions.

  Categories (performance and schema only — security is sql-pro's domain):

  A) Indexes:
     for every column used in WHERE/JOIN/ORDER BY/GROUP BY — present?
     composite indexes with high-selectivity columns first;
     redundant indexes ((a,b) + (a) — second is waste);
     unused indexes (information_schema.statistics + slow log);
     missing index on FK = P1.

  B) N+1 queries (most common AI perf bug):
     ORM lazy loading without eager hint; SELECT inside foreach.

  C) EXPLAIN top queries:
     `type: ALL` = full scan = P1; high row counts in nested loops; Using
     filesort; Using temporary; key: NULL where index expected.

  D) Schema design (perf perspective):
     VARCHAR(255) everywhere (memory waste); TEXT/BLOB in hot tables (move
     to separate); missing partitioning for tables >10M rows; append-only
     tables with retention DELETE without partitioning (DELETE blocks
     INSERT through locks).

  E) Caching:
     positive cache TTL strategy; negative cache TTL with recovery awareness
     (short TTL for "may return", long for "structurally absent"); hit-ratio
     metrics; clean-on-prefetch as alternative.

  F) Connection management:
     max_connections vs expected peak; persistent connections (default OFF
     for web — leak transactions/session vars between requests); connection
     leaks (close in finally).

  G) Concurrent batch / cron protection:
     long-running scripts without flock + set_time_limit ⇒ races, duplicate
     HTTP, exhausted circuit breakers.

  Tools:
     mysqldumpslow /var/log/mysql/slow.log | head -30
     SELECT digest_text, count_star, avg_timer_wait/1000000 FROM
        performance_schema.events_statements_summary_by_digest ORDER BY count_star DESC LIMIT 30
     SELECT object_schema, object_name, index_name FROM
        performance_schema.table_io_waits_summary_by_index_usage WHERE count_star=0 AND index_name IS NOT NULL

  Output: audit/findings/05-db-perf.md, format from SKILL.md §7. Prefix: DB-.

  Every index recommendation MUST include: estimated impact (rows examined
  saved), cost (write overhead, storage), risk (locking on CREATE INDEX in
  production).
```
