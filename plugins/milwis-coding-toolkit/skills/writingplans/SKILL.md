---
name: writingplans
description: Use when you have a spec for a multi-step task. Creates implementation plans with vertical slicing, risk-first ordering, and acceptance criteria — describes intent, not inline code.
---

# Writing Plans

**Core:** A plan describes WHAT and WHY clearly enough for a subagent to execute — WITHOUT spelling out every line of code. Bite-sized tasks ordered by risk. Vertical slicing. DRY. YAGNI.

**Announce at start:** "I'm using the writingplans skill."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

---

## Step 0: Read-Only Analysis (before writing any plan content)

1. **Read flow docs** for the affected module (`docs/dokumentacja programu/flows/{module}.md` if it exists)
2. **Read the files** that will be modified. Note patterns: naming, error handling, imports, formatting
3. **Check DB schema** for affected tables (grep for CREATE/ALTER or inspect the DB)
4. **Map dependencies** — which JS calls which endpoint, which controllers use which services
5. **Identify risks** — missing `updated_at`, missing access migration (`views`/`group_views` AND `permissions_new` — both required), cross-file JS without `window.`
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

> **For Claude:** execute with the `executingplans` skill.

**Goal:** [one sentence describing what this builds]

**Architecture:** [2-3 sentences from Step 0 findings]

**Tech Stack:** [key technologies]

**Findings from code analysis:**
- [finding 1]
- [finding 2]
- [risk/gotcha identified]

**Canon:** [the existing implementation new code must call/mirror — `file:line`, or "none, created in Task 1" — from Step 0.5]
**Variants:** [every sibling path; for each: changed by this plan? if not, why skipping is safe — from Step 0.5]

**Rules for this plan:** [only what this plan decides (lock order, the owner's choices, the service to call) and pointers to project docs that do not load by themselves — never a copy of CLAUDE.md or an auto-loaded rule (§The plan's rules section)]

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

### Review checkpoints — mandatory

The plan says when the code is reviewed and in which groups. Without it, the executor reviews every task commit
one after another and its fixes go unreviewed (`task-lifecycle/references/evidence.md` E31). Tasks stay vertical
slices; a checkpoint reviews a finished section, split by layer.

**When — after a finished section of work.** A section is a module or one coherent feature: the tasks after which
that part works as a whole. Put a `### Review checkpoint R<k>` block right after the section's last task. Two
fixed points:
- **A migration first.** A task that adds or changes a schema migration gets its own checkpoint right after it,
  before any task builds on the new columns. A migration is the hardest change to reverse once deployed, and a
  defect found in it later is fixed again in every layer built on top.
- **The whole branch last:** `R-final` closes the plan (below).

**Who — one fresh reviewer per layer of the section, all in parallel:**

| Group | Paths (adapt to the project) | Also given, read-only, as the contract |
|---|---|---|
| `sql` | schema migrations, seed and permission migrations | — |
| `backend` | the module's request path: repository, service, controller, routes, cron, with their tests | the section's migration |
| `frontend` | the module's JS, views and CSS, with their tests | the controller and routes the front end calls (fields, error codes, permissions) |

A layer the section does not touch gets no group. By layer inside one module, because the rules a reviewer loads
differ per layer and a whole module overflows one reviewer: per-task reviews of 400–550 production lines (plus
tests) already ended at 230–262k context, at the compaction line (E31). Not one reviewer per language across
modules, because each module's invariants need their own domain context.

**Size of a group:** ≤ 400 changed production lines and ≤ 10 production files; tests come on top. A bigger group
splits along the module's own seams (read path vs write path, one aggregate vs another), never between a guard
and its test.

**A mechanical rollout** (one pattern applied across many modules: a CSS class, a marker, a renamed call) is ONE
group for the whole pattern, whatever the modules: the reviewer checks that it is applied the same way everywhere.
The size cap still holds: above it, split the rollout into batches of modules with the same pattern brief.

**`R-final` — the whole branch, cross-group only.** One fresh reviewer on `<base>..<tip>`, with every group report
marked "already reviewed, do not repeat". Its scope is what no group could see: the contract between groups (a
field the PHP returns and the JS reads, an error code, a permission name), migration vs code, logic duplicated
across groups, docs.

```markdown
### Review checkpoint R<k>: <section> (after Task <n>)
- **Covers:** Tasks <a>–<n>; diff `<base>..HEAD`, base = the previous checkpoint's tip or the branch base.
- **Groups:**
  - `backend`: `php/services/X/**`, `php/controllers/XController.php`, `php/routes/x.php` + tests — contract: `sql/migrations/<file>`
  - `frontend`: `js/modules/x/**`, `views/x.php` + tests — contract: `php/controllers/XController.php`, `php/routes/x.php`
- **Rules to check, one report line each:** the plan's own decisions this section implements (`§0 rule 3`, `D2`) and
  project docs a reviewer would not load by itself (outside `CLAUDE.md` and the auto-loaded rules files).
- **Done when:** every group is closed: 0 CRITICAL and 0 REQUIRED, or a `Domknięcie:` closed by its executed mutants and docs commits (`executingplans` Step 4).
```

### The plan's rules section — point, do not copy

The plan's rules section carries only what this plan decides (lock order, the owner's choices, the canonical
service to call) and pointers to project docs that do not load by themselves. A rule already in `CLAUDE.md` or in
an auto-loaded rules file (`.claude/rules` with `paths:`) is not copied: the executor and every reviewer have it in
context already, and a copy drifts from its source. Each checkpoint lists the rules its groups check, and the
reviewer answers one line per rule, so a rule the plan points to is verified, not assumed.

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
- Follow existing pattern in [reference file] — and name the latch that guards it (`tests/.../XTest::method`); the copy gets its own latch in the same task
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

**DO NOT put full implementation code in the plan.** Whoever executes the plan (the session running `executingplans`, or a `builder` for an independent task set) writes the code under the project's own rules (CLAUDE.md, `.claude/rules`, `docs/standards`). Plans describe intent; the executor implements.

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
- No review checkpoints, or one checkpoint per task → regroup by section
- A migration without its own checkpoint before the tasks that use it → add one
- A checkpoint group mixing two modules (other than a mechanical rollout), or above 400 production lines → split it
- No `R-final` → add it as the last checkpoint
- The rules section copies `CLAUDE.md` or an auto-loaded rule → keep only what the plan decides, point to the rest

---

## Step 2: Self-Audit & Refinement (mandatory before handoff)

**Do not present the plan to the user until this step is complete.** Gaps you don't catch here, the user has to catch manually.

### Pass 1 — General audit (main agent)

Re-read the entire saved plan as a reviewer seeing it for the first time. Hunt for:

- **Gaps:** missing tasks, untouched dependencies, assumed-but-unverified file locations, missing migrations, missing rollback, missing seed/fixture updates
- **Security / vulnerabilities:** auth/authz gaps, input validation, SQL injection, XSS, CSRF, secrets in code/logs, unsafe defaults, missing rate limits
- **Correctness risks:** race conditions, N+1 queries, missing indexes, broken invariants, silent failures, error paths without handling
- **Acceptance criteria quality:** vague/non-testable criteria, missing negative cases, missing edge cases (empty, null, large, concurrent)
- **Ordering / scoping:** risky task placed late, vertical slicing violated, task exceeds 5 files, dependencies between tasks not reflected in order
- **Review checkpoints:** every task covered by exactly one checkpoint, groups within size, each group with its contract files, `R-final` last
- **Operational:** logging, migrations reversible, feature flags, backward compatibility, data migration for existing rows
- **DRY/YAGNI:** duplicated work across tasks, speculative features, premature abstractions

Write findings as a checklist. Record every real gap you find, each with the task number, file:line or command that shows it. A short list is a valid result — don't pad it.

### Pass 2 — Rules and security audits (parallel; conditional)

**Run Pass 2 only for plans with more than 5 tasks OR touching money/VAT, auth/permissions, or regulated data — and cap it at 2 auditors.** Auditing the TEXT of a small plan with a panel of agents costs more than the reality-check the code itself will force during execution; the review loop in `task-lifecycle` catches what a plan audit would. For plans below the threshold, skip to Pass 3 with Pass 1 findings only.

The `builder` agent is a goal-only writer with no checklist of its own, so it is not a plan auditor. Pass 2 uses the reviewers, spawned **in parallel** (single message, multiple `Agent` calls):

| Plan touches | Agent | Audits |
|---|---|---|
| any code (the default auditor) | `code-reviewer` | the plan's tasks against the project's rules for the paths the plan names (it Reads the `.claude/rules` files whose `paths:` match) and against the code the tasks name |
| auth / permissions / input parsing / money / regulated data | `backend-security-coder` | the tasks on those paths: input reaching a sink, a missing permission check |

**Prompt each auditor** with:
- Absolute path to the plan file
- Exact section/task numbers to audit (not the whole plan)
- The file paths those tasks touch
- Instruction: *"Read-only review. Do not edit the plan. Return a numbered list of concrete issues: a task that breaks a project rule (cite it), a variant path that skips the canonical one, a missing edge case or acceptance criterion, a risky step. No generic advice — each item references a specific task and a file:line or rule."*

Example: PHP backend + JS frontend + MySQL schema touching invoices → `code-reviewer` (all tasks against the project's PHP, JS and SQL rules) and `backend-security-coder` (the tasks on the invoice endpoints) in one parallel batch.

### Pass 3 — Consolidate & fix

1. Merge Pass 1 + Pass 2 findings. Deduplicate.
2. Edit the plan file directly to address every valid finding: adjust the task, add an acceptance criterion, split a task, reorder, or add a new task.
3. Discard findings that are out of scope — but note *why* in the plan's Out-of-scope/Findings section so the user sees the decision.
4. If Pass 3 caused material structural changes (new tasks, re-ordering, new risks), run Pass 1 again on the changed sections only.

### Pass 4 — Report to user

Only now announce the plan as ready. Include a one-paragraph audit summary:

- How many issues were found across the general and Pass 2 audits
- Which auditors were consulted
- Which findings were fixed vs. deliberately deferred (with reason)

If no issues were found, say so and name what you checked, so the user can judge the coverage.

---

## Step 3: Execution Handoff

After the self-audit is complete and the plan is clean:

**"Plan saved to `docs/plans/<filename>.md`. Audited by [list auditors]; [N] issues found and resolved. Ready to execute with the `executingplans` skill?"**

---

## Companion Skills (active during execution, not pre-loaded)

- `executingplans` — drives the execution loop
- `test-driven-development` — for new production code (failing test first)
- `systematic-debugging` — when anything breaks during execution
- `verification-before-completion` — the verification gate (at group boundaries)
