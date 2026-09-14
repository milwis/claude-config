---
name: issue-pipeline
description: "Use when the user wants a BATCH of issues resolved autonomously — GitHub issues, audit-360 findings, or a TODO backlog. Triages each item against current HEAD (stale findings die here), batches by file-disjointness, then runs one task-lifecycle orchestrator per issue on its own branch, monitoring by exception. Output: a status table (issue → branch → verification evidence → blockers). Replaces manually feeding issues to orchestrator agents one by one."
---

# Issue Pipeline (batch: triage → orchestrate → monitor by exception)

**Core:** One `task-lifecycle` per issue, dispatched and monitored by this session. Stale issues are killed at triage, parallel work is file-disjoint AND resource-disjoint, every issue ends as DONE / BLOCKED / SKIPPED in a single status table. **One run = one batch of ≤ 3 issues.** The user is contacted for launch approval, for exceptions, and for the go of the next batch — nothing else.

**Announce at start:** "I'm using the issue-pipeline skill."

---

## Step 0: Collect the backlog

Sources (pick per user request):
- **GitHub issues:** `gh issue list --state open [--label <label>] --json number,title,body,labels`
- **audit-360 output:** P0/P1 findings from `audit/REPORT.md` / `audit/FIX_PROPOSALS.md`
- **Explicit list** from the user.

Present the scope BEFORE launching: item count, titles, planned batch layout (which issues in parallel, which sequential, and why). Get a single go/no-go — after that, no per-issue questions unless an exception fires.

**Project-local rules:** if the project's CLAUDE.md points to a local-adaptations document for these cycles (pre-commit gate, doc agent, done-label, worktree checklist, shared-resource rules), read it now and carry its path into every orchestrator prompt (Step 3). The generic skill cannot know a project's shared DB, ports or labels — the local doc does.

## Step 1: Triage on HEAD (mandatory — findings go stale)

Field-proven lesson: when commits land between an audit and its remediation, **about half the findings are already fixed** and all line numbers have shifted. Working from stale issue text produces duplicate or destructive "fixes".

For each item, dispatch a cheap read-only subagent — `Explore` type, `model: sonnet` (never the parent's model: triage is reading, not judging), spawned with `name: triage-<n>`. All triage agents of a batch may run in parallel (read-only, no shared-resource conflict):

```
Issue: [title + body]
Verify against CURRENT HEAD:
1. Establish whether the described problem EXISTS on HEAD or NOT — and name the measurement that decides it. Do not stop at the premises the issue lists; measure the layer above/below them (global interceptor/middleware, DB constraint action, catch one frame down, whether the suite collects the file at all). Re-derive file:line yourself — do not trust line numbers in the issue.
2. Was it already fixed? If so, cite the evidence (commit / current code).
3. Is the issue actionable as written, or does it need clarification?
4. List the files a fix would touch, and flag: touches DB schema/migrations? touches a GUI surface? touches a file another issue in this batch also touches?
Return: VALID (with fresh file:line anchors + file list + flags) | ALREADY-FIXED (evidence) | NOT-A-BUG (the disproving measurement) | NEEDS-CLARIFICATION (question)
Label every load-bearing sentence MEASURED (command / file:line) or INFERRED.
```

- NOT-A-BUG → same handling as ALREADY-FIXED; the disproving measurement goes into the closing comment. An issue whose premises are all true but whose conclusion was never measured is the most common stale item in a wave.
- ALREADY-FIXED → close/comment (with user-approved `gh issue close -c "..."`) or mark in the table; never "re-fix".
- NEEDS-CLARIFICATION → park in the report with the question; do not guess.
- VALID items proceed with **fresh anchors** replacing the issue's stale ones.

## Step 2: Batch plan

1. For each VALID issue, take the file list and flags from triage.
2. Issues may run in **parallel** only under the `executingplans` four conditions: disjoint files, no data dependency, no side-effect coupling, independent verification. Any doubt → sequential.
3. **Parallel ⇒ worktree, always.** Each issue lives on its own branch `agent/issue-<n>`, and one working tree can hold only one checked-out branch — so two issues in one tree is never "no collision", it is a guaranteed clobber (a checkout by one agent discards the other's uncommitted work). Parallel issues run in per-issue worktrees (`isolation: worktree` or the project's worktree convention). If the project cannot provide worktree isolation → the batch is sequential.
4. **Shared-resource rule (side-effect coupling beyond files).** Parallel lifecycles still share: the dev database (full test suites and migrations write to it), the app server port (usually serves the MAIN tree, not a worktree), a single driven browser (Claude-in-Chrome is one Chrome), and the CI budget. Before launching, decide per resource: serialize (slot/lock), give each issue its own instance (per-worktree server port, Playwright instead of a shared Chrome), or run sequentially. **DB-touching issues (migrations, FK, indexes, data backfills) never run in parallel with each other.**
5. Batch width: **2-3 parallel issues, max 3 per run** (hard rule 3). A further batch is a further invocation of this skill with a fresh go from the user — never chained inside one run.
6. Order: risk-first within reason — security/data-integrity issues before cosmetics; migrations always before code that depends on them (never in the same parallel batch); issues that touch the same file/module chain go in consecutive batches, one link per batch.

### One lifecycle per issue — and the only exception

Default: **one task-lifecycle = one issue = one branch.** This is better on both axes:
- *Quality:* one diff per review, one branch per merge/revert, one verification per claim; a failure in one issue never blocks another; the reviewer's cost grows super-linearly with diff size, so a bundled diff gets a shallower review.
- *Tokens:* the fixed cost of a fresh agent (prompt prefix, project discovery) is a few percent of a lifecycle; the dominant cost is accumulated context paid on every turn — a multi-issue agent is the resumed-agent anti-pattern of `task-lifecycle` hard rule 6 in another guise (measured: resumed builder 94M tokens vs fresh builder 24M for the same iteration).

Exception — **bundle** several issues into ONE lifecycle only when ALL hold: they touch the same file(s) so separate lifecycles would conflict anyway; each alone is Trivial/Small (so the fixed cost would dominate); they share one verification surface. The bundle is then one spec with N tasks (`executingplans` same-file rule), one branch `agent/issues-<a>-<b>`, one report — and it counts as N issues against the cap of 3.

## Step 3: Execute — one task-lifecycle per issue

For each issue, dispatch an **orchestrator subagent** (`general-purpose`, `name: orch-<n>`, `model:` per the project's policy — default `opus`; switching the orchestrator to `sonnet` is a cost lever that changes quality on issues where the orchestrator must judge something outside the procedure, so it is adopted only after the project's A/B test, never by default) with a self-contained prompt:

```
You are the orchestrator for issue #<n>: <title>. Your agent name is orch-<n>.
Run the task-lifecycle skill IN FULL, including every delegation step it prescribes — do not shortcut a step because it looks small:
- branch: agent/issue-<n> (create from <base>); working tree: <path of your worktree — every command uses absolute paths under it>
- fresh anchors from triage: <file:line list>; files expected to change: <list>
- project-local rules: <path to the project's local-adaptations doc, if any> — pre-commit gate, doc agent, done-label, worktree checklist, shared-resource rules
- shared resources in this batch: <dev DB: serialize via <slot mechanism> | app port: <per-worktree port + discriminator> | browser: <Playwright / serialized Chrome>>
- build via specialist subagent → code-review loop (auto-fix CRITICAL/HIGH/MEDIUM, cap per task-lifecycle)
- security pass if [triggers]
- verify-e2e in a fresh subagent; env facts: docs/VERIFICATION_ENV.md — the verifier must prove WHICH tree the surface executes (discriminator), not only that a server answers
- commit on the branch; do NOT merge, do NOT push to <deploy branch>, do NOT close the issue; if the project uses a done-label, add it to the issue when DONE
- one agent per unit of work: review fixes go to a NEW builder (fresh context), never the resumed one; re-reviews to a fresh reviewer
- spawn every subagent with `name:` and an explicit `model:` (project policy), and instruct it to send its final report via SendMessage to orch-<n> — nested task-notifications may land with the top-level session instead of you
Return the task-lifecycle report package via SendMessage to <this session's agent name, or "the top-level session" if unnamed>. If blocked, return BLOCKED with the exact missing prerequisite — do not improvise around it.
```

**Monitor by exception.** While orchestrators run, this session only:
- collects report packages,
- answers orchestrator questions it can answer from context,
- escalates to the user ONLY: blockers (missing env/keys/decisions), cap-exhausted issues, scope conflicts between issues.

Do not poll orchestrators — they report when done; polling burns the top-level context. An orchestrator that exhausts its caps is marked SKIPPED with its partial report — the pipeline moves on. Never let one stuck issue stall the batch.

## Step 4: Final report — the status table

```
| Issue | Status  | Branch          | Tip SHA | Review (iter/fixed) | Verification        | Needs from you            |
|-------|---------|-----------------|---------|---------------------|---------------------|---------------------------|
| #231  | DONE    | agent/issue-231 | a1b2c3d | 2 / 3H+1M           | PASS (1 screenshot) | review → merge            |
| #234  | BLOCKED | agent/issue-234 | d4e5f6a | 1 / 1H              | BLOCKED: no KSeF test token | provide token → rerun |
| #229  | SKIPPED (already fixed in #227) | — | — | — | — | close issue |
```

Plus: evidence paths per issue, aggregated `VERIFICATION_ENV.md` gaps discovered this run, remaining LOW/uncertain review findings, and the list of worktrees left behind (the user removes them after merging).

---

## Hard rules

1. **No merge, no push to the deploy branch, no deploy, no `gh issue close` — without the user.** The pipeline ends at branches + table. A done-label on the issue (if the project uses one) is the only write to the tracker.
2. **Triage is never skipped**, even for issues written today — the anchor refresh alone pays for it.
3. **Caps propagate:** each task-lifecycle keeps its own review/verify caps; the pipeline adds one more — max **3 issues per run** (the binding constraint is the token budget, not wall-clock; raise the cap only on the user's explicit request). The next batch is a new run with a new go.
4. **DB-touching issues never run in parallel with each other** (shared dev DB = side-effect coupling).
5. **Parallel ⇒ worktree** (Step 2.3). No exceptions.
6. Batch results are reported when the batch completes; an issue that finishes early is reported early — the user sees progress, not silence.

---

## Integration

- `task-lifecycle` — the per-issue engine.
- `audit-360` — natural upstream: REPORT.md P0/P1 → (user approval) → `gh issue create` per finding → this pipeline.
- `executingplans` — source of the parallelism conditions, the same-file rule and the agent table.
- `verify-e2e` — verification inside each lifecycle; gaps accumulate in `docs/VERIFICATION_ENV.md`.
