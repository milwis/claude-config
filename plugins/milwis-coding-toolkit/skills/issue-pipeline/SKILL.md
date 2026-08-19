---
name: issue-pipeline
description: "Use when the user wants a BATCH of issues resolved autonomously — GitHub issues, audit-360 findings, or a TODO backlog. Triages each item against current HEAD (stale findings die here), batches by file-disjointness, then runs one task-lifecycle orchestrator per issue on its own branch, monitoring by exception. Output: a status table (issue → branch → verification evidence → blockers). Replaces manually feeding issues to orchestrator agents one by one."
---

# Issue Pipeline (batch: triage → orchestrate → monitor by exception)

**Core:** One `task-lifecycle` per issue, dispatched and monitored by this session. Stale issues are killed at triage, parallel work is file-disjoint, every issue ends as DONE / BLOCKED / SKIPPED in a single status table. The user is contacted only for launch approval and exceptions.

**Announce at start:** "I'm using the issue-pipeline skill."

---

## Step 0: Collect the backlog

Sources (pick per user request):
- **GitHub issues:** `gh issue list --state open [--label <label>] --json number,title,body,labels`
- **audit-360 output:** P0/P1 findings from `audit/REPORT.md` / `audit/FIX_PROPOSALS.md`
- **Explicit list** from the user.

Present the scope BEFORE launching: item count, titles, planned batch layout. Get a single go/no-go — after that, no per-issue questions unless an exception fires.

## Step 1: Triage on HEAD (mandatory — findings go stale)

Field-proven lesson: when commits land between an audit and its remediation, **about half the findings are already fixed** and all line numbers have shifted. Working from stale issue text produces duplicate or destructive "fixes".

For each item, dispatch a cheap read-only subagent (Explore-type):

```
Issue: [title + body]
Verify against CURRENT HEAD:
1. Does the described problem still exist? Re-derive file:line yourself — do not trust line numbers in the issue.
2. Was it already fixed? If so, cite the evidence (commit / current code).
3. Is the issue actionable as written, or does it need clarification?
Return: VALID (with fresh file:line anchors) | ALREADY-FIXED (evidence) | NEEDS-CLARIFICATION (question)
```

- ALREADY-FIXED → close/comment (with user-approved `gh issue close -c "..."`) or mark in the table; never "re-fix".
- NEEDS-CLARIFICATION → park in the report with the question; do not guess.
- VALID items proceed with **fresh anchors** replacing the issue's stale ones.

## Step 2: Batch plan

1. For each VALID issue, list the files it will touch (from triage anchors).
2. Issues may run in **parallel** only under the `executing-plans` four conditions: disjoint files, no data dependency, no side-effect coupling (shared DB state!), independent verification. Any doubt → sequential.
3. Default batch width: **2-3 parallel issues**; next batch starts only when the previous one is fully reported.
4. Isolation: each issue gets its own branch `agent/issue-<n>`. If parallel builders would collide in one working tree, use worktree isolation (`isolation: worktree`) — otherwise sequential.
5. Order: risk-first within reason — security/data-integrity issues before cosmetics; migrations always before code that depends on them (never in the same parallel batch).

## Step 3: Execute — one task-lifecycle per issue

For each issue, dispatch an **orchestrator subagent** with a self-contained prompt:

```
You are the orchestrator for issue #<n>: <title>.
Follow the task-lifecycle skill end-to-end:
- branch: agent/issue-<n> (create from <base>)
- fresh anchors from triage: <file:line list>
- build via specialist subagent → code-review loop (auto-fix CRITICAL/HIGH/MEDIUM, cap 3)
- security pass if [triggers]
- verify-e2e in a fresh subagent; env facts: docs/VERIFICATION_ENV.md
- commit on the branch; do NOT merge, do NOT push to <deploy branch>
Return the task-lifecycle report package. If blocked, return BLOCKED with the exact missing prerequisite — do not improvise around it.
```

**Monitor by exception.** While orchestrators run, this session only:
- collects report packages,
- answers orchestrator questions it can answer from context,
- escalates to the user ONLY: blockers (missing env/keys/decisions), cap-exhausted issues, scope conflicts between issues.

An orchestrator that exhausts its caps is marked SKIPPED with its partial report — the pipeline moves on. Never let one stuck issue stall the batch.

## Step 4: Final report — the status table

```
| Issue | Status  | Branch          | Review (iter/fixed) | Verification        | Needs from you            |
|-------|---------|-----------------|---------------------|---------------------|---------------------------|
| #231  | DONE    | agent/issue-231 | 2 / 3H+1M           | PASS (3 screenshots)| review → merge            |
| #234  | BLOCKED | agent/issue-234 | 1 / 1H              | BLOCKED: no KSeF test token | provide token → rerun |
| #229  | SKIPPED (already fixed in #227) | — | — | — | close issue |
```

Plus: evidence paths per issue, aggregated `VERIFICATION_ENV.md` gaps discovered this run, and remaining LOW/uncertain review findings.

---

## Hard rules

1. **No merge, no push to the deploy branch, no deploy, no `gh issue close` — without the user.** The pipeline ends at branches + table.
2. **Triage is never skipped**, even for issues written today — the anchor refresh alone pays for it.
3. **Caps propagate:** each task-lifecycle keeps its own review/verify caps; the pipeline adds one more — max **3 issues per run** without a fresh check-in with the user (the binding constraint is the token budget, not wall-clock; raise the cap only on the user's explicit request).
4. **DB-touching issues never run in parallel with each other** (shared dev DB = side-effect coupling).
5. Batch results are reported per batch if the run is long — the user sees progress, not silence.

---

## Integration

- `task-lifecycle` — the per-issue engine.
- `audit-360` — natural upstream: REPORT.md P0/P1 → (user approval) → `gh issue create` per finding → this pipeline.
- `executing-plans` — source of the parallelism conditions and agent table.
- `verify-e2e` — verification inside each lifecycle; gaps accumulate in `docs/VERIFICATION_ENV.md`.
