---
name: migration
description: "Use when a change alters a persisted or public shape — DB schema, stored data, API contract, message/protocol format, config keys, a dependency's major version. Enforces a reversible, compatibility-safe transition: map readers/writers first, forward AND rollback path, expand → migrate → verify → contract, destructive steps authorized separately, never contract implicitly."
---

# Migration (reversible, compatibility-safe transitions)

**Core:** A migration is a transition between two shapes while readers and writers keep working. The dangerous part is never the `ALTER` — it is the reader you did not map, the rollback you cannot run, and the `DROP` that happened one step too early.

**Announce at start:** "I'm using the migration skill."

**Entry:** the task changes a persisted or public shape (schema, data, API, protocol, config, dependency major).
**Stop:** the requested stage passes with old and new paths verified — and no later destructive stage has been performed implicitly.

---

## Step 0: Map before editing

Before any change, list with `file:line`:

1. **Readers and writers** of the shape — every query, model, serializer, export, import, report, cron, mobile/PWA twin, analytics consumer. Same inventory as `writingplans` Step 0.5 (canon + variants); a reader you did not list is the one that breaks in production.
2. **Data shape today** — from physical evidence (`SHOW CREATE TABLE`, real rows, actual API responses), never from comments or docs. Count rows that violate the target shape (`GROUP BY … HAVING`, nulls, duplicates) — a migration that assumes clean data is a migration that fails halfway.
3. **Compatibility window** — can old and new code run at the same time (rolling deploy, queued jobs still in flight, cached clients, mobile app versions)? If yes, every intermediate state must be readable by both.
4. **Ownership** — which versioned migration mechanism the project uses (`sql/migrations/`, Liquibase/Flyway, framework migrations). Runtime DDL in application code is an automatic P1 (`sql-pro`).

---

## Step 1: Define both paths

- **Forward path:** the ordered steps, each idempotent (safe to re-run after a partial failure: `IF NOT EXISTS`, upsert semantics, a checkpoint column or batch marker).
- **Rollback path:** how to return to the previous shape *with the data intact* at every step. "Restore from backup" is a rollback path only when the backup is named, fresh, and its restore has been exercised.
- **Destructive steps** (`DROP`, column removal, data deletion, irreversible transforms) are listed separately and require **explicit, separate authorization** from the user — never bundled into a "run migration" approval.

---

## Step 2: Expand → migrate → verify → contract

| Stage | What | Rule |
|---|---|---|
| **Expand** | Add the new column / table / field / endpoint alongside the old one | Old code untouched and still green |
| **Migrate** | Backfill / dual-write / translate; batch large tables | Idempotent, resumable; partial failure observable (log the batch, the count, the last key) |
| **Verify** | Old path AND new path produce the same observable result on real data | Counts match, samples match, both paths under test; `verification-before-completion` applies |
| **Contract** | Remove the old shape | **Only when explicitly requested as its own stage** — a task asking for the migration stops after Verify |

Mixed-version safety: during Expand and Migrate the old reader must still work and the new reader must tolerate not-yet-migrated rows.

---

## Step 3: Verify at the requested stage

- Run the migration on the dev DB (`wczytaj-baze-dev` gives a fresh production copy); inspect schema and affected rows before/after — DDL diff + row samples are the evidence (`verify-e2e` surface "DB migration").
- Run the **rollback** at least once on the dev copy and show the shape is restored. An untested rollback is a hypothesis.
- Run the old and new read paths under the project's targeted tests.
- Report exactly: which stage was executed, which was not, what is left for Contract, and which destructive step still awaits authorization.

---

## Never

- Perform Contract because "it was obviously next" — a later destructive stage is never implied by an earlier one.
- Write a migration that is not idempotent, or a backfill without a resume point.
- Seed from a same-named legacy twin table by ID (`sql-pro` — join by name, never by ID across twins).
- Claim "migration done" without the rollback having been run on a copy.

---

## Integration

- `writingplans` Step 0.5 — the reader/writer inventory is the same canon-and-variants inventory.
- `executingplans` — migrations are always sequential and precede the code that depends on them.
- `issue-pipeline` — DB-touching issues never run in parallel with each other (shared-resource rule).
- `code-reviewer` — flags a migration without a rollback path or with an implicit Contract as CRITICAL.
- `sql-pro` — the writer agent for the migration itself; `verify-e2e` — the DB-migration surface row.
