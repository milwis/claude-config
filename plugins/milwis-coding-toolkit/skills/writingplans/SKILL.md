---
name: writing-plans
description: Use when you have a spec for a multi-step task. Creates implementation plans with vertical slicing, risk-first ordering, and acceptance criteria — describes intent, not inline code.
---

# Writing Plans

**Core:** A plan describes WHAT and WHY clearly enough for a subagent to execute — WITHOUT spelling out every line of code. Bite-sized tasks ordered by risk. Vertical slicing. DRY. YAGNI.

**Announce at start:** "I'm using the writing-plans skill."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

---

## Step 0: Read-Only Analysis (before writing any plan content)

1. **Read flow docs** for the affected module (`docs/dokumentacja programu/flows/{module}.md` if it exists)
2. **Read the files** that will be modified. Note patterns: naming, error handling, imports, formatting
3. **Check DB schema** for affected tables (grep for CREATE/ALTER or inspect the DB)
4. **Map dependencies** — which JS calls which endpoint, which controllers use which services
5. **Identify risks** — missing `updated_at`, missing `$allowedResources`, cross-file JS without `window.`, missing `views`/`group_views` entries
6. **Write a findings summary** (2-3 sentences) at the top of the plan

Plans based on reading code work the first time. Plans based on imagination cause rework.

---

## Step 0.5: Canon & Variant Inventory (mandatory when the plan touches money, state columns, or document generation)

Before writing tasks, dispatch an Explore agent with this exact shape:

> "List EVERY place in the repo that already computes / writes / generates <the quantity, state column, or document this plan touches>. For each: file:line, the formula or guard used, and whether it looks canonical or a variant. Also list every sibling path of the operation being changed (correction / reversal / delete / cancel / batch / offline / single-vs-bulk export / import-update / analytics or reporting consumer / mobile or PWA twin). Report ONLY what exists in code, with file:line for every claim. Do not infer."

Then record in the Plan Header:
- **Canon:** the single implementation new code must call or mirror (`file:line`). If none exists, the plan's FIRST task is to create it — never a second parallel implementation of the same quantity.
- **Variants:** every sibling path found. For EACH: does this plan change it? If not — one sentence why skipping is safe.

Why mandatory: a variant path (correction, delete, batch, offline, import, a reporting consumer) reimplemented from scratch — instead of reusing the guard/formula/filter the main path already has — is one of the most common and most expensive regression classes. No per-file code agent can see it, because the defect lives *between* files (variant vs canon). Only this inventory surfaces it before implementation.

---

## Step 1: Write the Plan

### Plan Header

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** execute with the `executing-plans` skill.

**Goal:** [one sentence describing what this builds]

**Architecture:** [2-3 sentences from Step 0 findings]

**Tech Stack:** [key technologies]

**Findings from code analysis:**
- [finding 1]
- [finding 2]
- [risk/gotcha identified]

**Canon:** [the existing implementation new code must call/mirror — `file:line`, or "none, created in Task 1" — from Step 0.5]
**Variants:** [every sibling path; for each: changed by this plan? if not, why skipping is safe — from Step 0.5]

**Out of scope:** [what this plan deliberately does NOT touch — deferred findings, sibling features]

---
```

### Vertical slicing — mandatory

Each task = one complete vertical slice (DB → PHP → JS → UI → test). Not horizontal layers.

```
❌ WRONG:         ✅ RIGHT:
Task 1: all PHP   Task 1: Feature A — endpoint + JS + test
Task 2: all JS    Task 2: Feature B — endpoint + JS + test
Task 3: all tests Task 3: Feature C — endpoint + JS + test
```

Each slice delivers a testable piece. If Task 2 fails, Task 1 still works.

### Risk-first ordering

1. **First:** most uncertain / risky (new schema, unfamiliar API, complex logic)
2. **Middle:** medium-risk (standard CRUD, known patterns)
3. **Last:** low-risk (CSS, copy, config)

Find timeline-breaking issues in Task 1, not Task 8.

### Task sizing

| Size | Files | Lines | Rule |
|------|-------|-------|------|
| Small | 1-2 | <50 | obvious, single step |
| Medium | 3-5 | 50-150 | multiple steps, clear path |
| Large | >5 | >150 | **split further** |

**Max 5 files per task. Max 3 acceptance criteria per task.**

### Per-Task Template

```markdown
### Task N: [Feature/Component Name]

**Acceptance Criteria** (max 3, testable):
- [ ] [specific, verifiable outcome 1]
- [ ] [specific, verifiable outcome 2]
- [ ] [specific, verifiable outcome 3]

**Files:**
- Create: `exact/path/to/file.php`
- Modify: `exact/path/to/existing.php` (function `methodName` around line ~123)
- Test: `tests/exact/path/test.php`

**Intent:**
[1-2 sentences: what behavior this task should produce. Not the code — the behavior.]

**Approach:**
- Follow existing pattern in [reference file]
- Match naming convention from [similar function]
- Key constraint: [e.g., must preserve backward compatibility, must use existing validation helper]

**Invariants & Failure Semantics** (required when the task writes financial/critical data, a state column, or talks to an external system):
- DB invariant that keeps the rule true under races: UNIQUE / FK / CHECK named explicitly — or "none needed because <reason>". App-level COUNT/EXISTS-then-INSERT is not protection (TOCTOU).
- State-column writes: guarded UPDATE (`WHERE <expected pre-state>`) + affected-rows check. List ALL existing writers of the column; new writes go through the one canonical transition method — no side doors.
- External submit (payment, third-party API, e-mail, export file): after timeout/5xx the outcome is UNKNOWN, not failed — plan the write-ahead record before the physical call and the reconcile-by-reference step before any retry. Never wipe the payload on an ambiguous outcome.
- Batch operations: exported/marked content must come from the same guarded set — file contents from a pre-read list + partial-success marking = double booking.

**Verification:**
- Failing test for [specific behavior] → passes after implementation
- [other acceptance criterion checks]

**Commit message:** `feat(module): description (in Polish, per project convention)`
```

### No implementation code in the plan

**DO NOT put full implementation code in the plan.** The executing agent (`php-pro`, `sql-pro`, etc.) generates code following its own rules. Plans describe intent; agents implement.

The only reason to include code is a very specific, non-obvious pattern — and even then, reference it by file path rather than inline.

Token efficiency: inline code means paying to generate the same code twice (in the plan, then in execution). Describing intent means the code exists only once — in the final implementation.

---

## Red Flags — Plan Needs Rework

- Task without acceptance criteria → add before moving on
- Task modifying >5 files → split
- Horizontal layers (all PHP, then all JS) → remodel as vertical slices
- Easy tasks first, risky last → reverse the order
- Plan assumes file structure without checking → back to Step 0
- Plan contains full implementation code blocks → rewrite to describe intent
- Plan adds a variant of an existing operation without naming the canon and the reuse point → back to Step 0.5
- Plan introduces a second implementation of a quantity that already has one → the task must call the canon, or the plan must first consolidate it

---

## Step 2: Self-Audit & Refinement (mandatory before handoff)

**Do not present the plan to the user until this step is complete.** An un-audited plan typically contains 10-20 gaps the user would otherwise catch manually. Find and fix them first.

### Pass 1 — General audit (main agent)

Re-read the entire saved plan as a reviewer seeing it for the first time. Hunt for:

- **Gaps:** missing tasks, untouched dependencies, assumed-but-unverified file locations, missing migrations, missing rollback, missing seed/fixture updates
- **Security / vulnerabilities:** auth/authz gaps, input validation, SQL injection, XSS, CSRF, secrets in code/logs, unsafe defaults, missing rate limits
- **Correctness risks:** race conditions, N+1 queries, missing indexes, broken invariants, silent failures, error paths without handling
- **Acceptance criteria quality:** vague/non-testable criteria, missing negative cases, missing edge cases (empty, null, large, concurrent)
- **Ordering / scoping:** risky task placed late, vertical slicing violated, task exceeds 5 files, dependencies between tasks not reflected in order
- **Operational:** logging, migrations reversible, feature flags, backward compatibility, data migration for existing rows
- **DRY/YAGNI:** duplicated work across tasks, speculative features, premature abstractions

Write findings as a checklist. Don't stop at the first few — aim to match the 10-20 issues a fresh reviewer would find.

### Pass 2 — Language-specialist audits (parallel; conditional)

**Run Pass 2 only for plans with more than 5 tasks OR touching money/VAT, auth/permissions, or regulated data — and cap it at the 2 most relevant specialists.** Auditing the TEXT of a small plan with a panel of agents costs more than the reality-check the code itself will force during execution; the review loop in `task-lifecycle` catches what a plan audit would. For plans below the threshold, skip to Pass 3 with Pass 1 findings only.

Identify which languages/technologies the plan touches. Pick up to 2 matching specialists (by risk, not by coverage) and spawn them **in parallel** (single message, multiple `Agent` calls) to audit only their relevant sections:

| Technology in plan | Agent |
|---|---|
| PHP (Laravel/Symfony/plain) | `php-pro` |
| JavaScript / TypeScript / Node | `javascript-pro` |
| Python | `python-pro` |
| SQL / schema / queries | `sql-pro` |
| PWA / mobile / service workers | `mobile-pwa-developer` |
| Auth / API security / input validation | `backend-security-coder` |
| Database performance / indexing | `database-optimizer` |
| Tests / testability of the plan | `test-automator` |

**Prompt each specialist** with:
- Absolute path to the plan file
- Exact section/task numbers to audit (not the whole plan)
- Instruction: *"Read-only review. Do not edit the plan. Return a numbered list of concrete issues: gaps, vulnerabilities, anti-patterns, missing edge cases, risky patterns specific to [language]. No generic advice — each item must reference a specific task or file in the plan."*

Example: PHP backend + JS frontend + MySQL schema → spawn `php-pro` (PHP tasks), `javascript-pro` (JS tasks), `sql-pro` (schema/queries) in one parallel batch.

### Pass 3 — Consolidate & fix

1. Merge Pass 1 + Pass 2 findings. Deduplicate.
2. Edit the plan file directly to address every valid finding: adjust the task, add an acceptance criterion, split a task, reorder, or add a new task.
3. Discard findings that are out of scope — but note *why* in the plan's Out-of-scope/Findings section so the user sees the decision.
4. If Pass 3 caused material structural changes (new tasks, re-ordering, new risks), run Pass 1 again on the changed sections only.

### Pass 4 — Report to user

Only now announce the plan as ready. Include a one-paragraph audit summary:

- How many issues were found across general + specialist audits
- Which specialists were consulted
- Which findings were fixed vs. deliberately deferred (with reason)

If zero issues were found, state it explicitly — that is unusual and worth flagging so the user can sanity-check.

---

## Step 3: Execution Handoff

After the self-audit is complete and the plan is clean:

**"Plan saved to `docs/plans/<filename>.md`. Audited by [list specialists]; [N] issues found and resolved. Ready to execute with the `executing-plans` skill?"**

---

## Companion Skills (active during execution, not pre-loaded)

- `executing-plans` — drives the execution loop
- `test-driven-development` — for new production code (failing test first)
- `systematic-debugging` — when anything breaks during execution
- `verification-before-completion` — the verification gate (at group boundaries)
