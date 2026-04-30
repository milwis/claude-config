# Prompt for `sql-pro` — injection, queries, dialect, immutability

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: sql-pro
description: SQL audit — injection, NULL, dialect, destructive ops, immutability
prompt: |
  You are auditing every SQL query in the application described in
  <INVENTORY_PATH>.

  Mode: READ-ONLY (your guardrails — no UPDATE/DELETE without WHERE,
  no DROP, no TRUNCATE).

  Priority order: Safety → Correctness → Performance → Readability.

  Categories:

  A) Injection (each = P0):
     concatenation of $_GET/$_POST/$_REQUEST or req.query/req.body into a query;
     whereRaw / DB::raw / RawSQL with user input; LIMIT $page without (int);
     ORDER BY $col without allowlist; dynamic table/column names from user input.

  B) Finalized-record mutations (each = P0 in regulated domains):
     UPDATE on fields like `*_sent`, `*_locked`, `*_finalized`, `*_exported`
     without WHERE-guard + caller checking rowCount===0.

  C) Domain service bypass (P0 when INVENTORY §9 hard-rules document a service):
     direct UPDATE/INSERT on tables documented as service-owned (inventory,
     accounting, payments).

  D) Destructive operations (DEFCON 1):
     UPDATE without WHERE = P0; DELETE without WHERE = P0; TRUNCATE in app
     code (should only live in migrations); DROP TABLE/DATABASE in code = P0;
     missing transactions for multi-row writes (financial flows!).

  E) Runtime DDL (each = P1, P0 if user input):
     CREATE TABLE / ALTER TABLE in controllers, services, save() handlers;
     string-concatenated DDL.

  F) NULL handling (each = P2):
     = NULL instead of IS NULL; NOT IN with subquery that may return NULL;
     LEFT JOIN where INNER intended; missing COALESCE on aggregates.

  G) Schema design:
     missing UNIQUE on business identifiers (document_number, supplier+document_number);
     missing FK with ON DELETE CASCADE/RESTRICT; FLOAT/DOUBLE for money (NEVER —
     always DECIMAL); generated column declared but not used (COALESCE inline drift);
     missing partition strategy on append-only tables with DELETE retention.

  H) Dialect-specific (per the engine listed in INVENTORY §6):
     MySQL: utf8 (3-byte) instead of utf8mb4; MyISAM instead of InnoDB.
     PostgreSQL: missing IS DISTINCT FROM where NULL-safety needed.
     SQL Server: TOP without ORDER BY; NVARCHAR without length.

  I) AI-typical SQL bugs:
     GROUP BY without all SELECT columns; SELECT *; correlated subquery where
     a window function fits; JOIN without condition (Cartesian); implicit type
     conversion (string vs int in WHERE).

  Tools:
     mysqldump --no-data --skip-comments
     SELECT table_name, index_name, column_name FROM information_schema.statistics ...
     EXPLAIN for non-trivial queries

  Output: audit/findings/04-sql.md, format from SKILL.md §7. Prefix: SQL-.

  CRITICAL: every query that mutates regulated/financial data must run
  inside a transaction with an idempotency key. Missing = P0.
```
