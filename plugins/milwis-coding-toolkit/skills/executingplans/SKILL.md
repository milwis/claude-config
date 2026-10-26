---
name: executingplans
description: Use when you have a written implementation plan to execute. Drives task-by-task execution with parallel groups, scope discipline, and verification at group boundaries.
---

# Executing Plans

**Core:** Execute the plan group by group. Stop immediately when something breaks. Verify at group boundaries, not after every micro-step.

**Announce at start:** "I'm using the executingplans skill."

---

## Step 1: Load, Review, Plan the Dispatch

1. Read the plan file
2. For each task, decide: **DIRECT** (this session writes it) or **AGENT: {name}**?
3. Map dependencies → assign **Group numbers**
4. Create the todo list with labeled items (format below)
5. Concerns → raise before starting. Otherwise proceed.

### Dispatch mode — DIRECT vs AGENT

**DIRECT is the default: this session writes the task.** It has read the plan, the Canon and the code; a builder
would read them again, and the agents carry no checklist of their own, so a dispatch adds re-reading, not rigour
(`task-lifecycle` E29). Business logic, SQL, auth and money code are written here too, under the project's rules
and the `test-driven-development` / `systematic-debugging` / `migration` disciplines.

**AGENT** only when the task set has its own context:
- **`builder`** (`sonnet`): a task set that passes all four parallel conditions below against everything else and is
  big enough that running it beside this session pays for its orientation (more than one file of new logic, or
  roughly 40+ tool calls). Brief it per `task-lifecycle/references/briefy.md` §Builder.
- **A specialist** whose job is a context of its own: `debugger` (a failure with an unknown cause),
  `database-optimizer` (a measured slow path), `refactoring-orchestrator` (a cross-module refactor that is its own
  task), `test-automator` (a tests-only task set).

When unsure → DIRECT.

### Reuse ladder — decide WHERE the change lives before deciding WHO writes it

Per task, walk the ladder top-down and stop at the first rung that fits without distorting the architecture; write the rung into the task's dispatch prompt (or apply it yourself for DIRECT):

1. **The behavior already exists** (the plan's Canon from `writingplans` Step 0.5, or a `grep` you run now) → call it, or change nothing.
2. **A responsible layer / type / helper / pattern already owns it** → extend there, not beside it.
3. **The standard library, framework, database, runtime or an installed dependency owns it** → use it; no hand-rolled twin.
4. **A small new implementation fits the current architecture** → build it where the invariant belongs.
5. **The existing structure obstructs clear ownership** → the coherent refactor the task needs — as its own task, before the feature, never fused into it.

A duplicated guard, a second formula for the same quantity, or logic parked in the wrong layer to avoid touching the right one is a rung-1/2 miss and is the regression class the Canon & Variant Inventory exists to prevent. Ask the user only for material public-surface, security, data, billing or hard-to-reverse choices — everything else is decided by the ladder.

### Dependency analysis — find parallel groups

Tasks may run in parallel ONLY if ALL four hold:
1. **Disjoint files** — never write to the same file
2. **No data dependency** — neither consumes a symbol/type/column/route produced by the other
3. **No side-effect coupling** — no shared DB state, filesystem state, or config
4. **Independent verification** — each task's tests don't depend on the other

If ANY fails → sequential.

**Same-file rule (critical):** tasks that touch the same file are never split between this session and an agent, or between two agents — they clobber each other, AND you pay the boot-up cost twice.

**Split by context, never by layer.** This session carries every task that shares a file, a symbol, a column or a decision with another task, in dependency order, committing at each task boundary — a migration, the service on its new column and the front-end module that calls it are ONE context. A builder takes only a task set that passes all four conditions above against everything else. Writers split by layer re-read each other's files and doubled the review and fix rounds (`task-lifecycle` E29). On a long plan the todo list and `git log --oneline <base>..HEAD` carry the state across a compaction.

**Always sequential:** migrations before queries on new columns, git commits, the final review/test group.

**When in doubt → sequential.**

### Todo list format (survives context compaction)

One todo item per task (TodoWrite / the session's task tracker), labeled:

```
[GROUP N|PARALLEL|SEQ] Task K: <description> [AGENT: <name>] or [DIRECT]
```

Example:
```
[GROUP 1|PARALLEL] Tasks 1-3: Migration (status column), then Feature A and B endpoints+JS on it — in order [DIRECT]
[GROUP 1|PARALLEL] Task 4: Feature C JS module, ~300 lines — shares no file, symbol or state with tasks 1-3 [AGENT: builder]
[GROUP 2|SEQ]      Task 5: CSS polish [DIRECT]
[GROUP 3|SEQ]      Verify + code review [AGENT: code-reviewer]
[GROUP 3|SEQ]      Commit [DIRECT]
```

The todo list is your memory after compaction — the labels tell future-you what to dispatch and in what order.

---

## Step 2: Execute Group by Group

```
For each group G:

  If G contains ONE task (SEQ):
    - Mark in_progress → execute (dispatch or DIRECT) → mark completed
    - Advance to next group

  If G contains MULTIPLE tasks (PARALLEL):
    - Mark ALL in_progress
    - Send ONE assistant message with the Agent tool calls — concurrent dispatch
    - Do the group's DIRECT tasks meanwhile, then wait for the agents
    - Verify the group (Step 3)
    - If any failed → Stop-the-Line for that task; do NOT start the next group
    - Mark all completed → advance
```

**Dispatches must be self-contained.** Each agent prompt contains:
- The task block verbatim from the plan
- Exact files to create / modify
- Acceptance criteria for THIS task only
- Explicit "do NOT touch file X" when overlap risk exists
- **Canon hand-off (financial / state / document tasks):** if the plan names a canonical implementation for this task's quantity/state/document, the agent prompt MUST include it — *"Canon: `<file:line>` — call it or mirror it; report any forced divergence back instead of silently coding around it."* Dispatching a variant-path task without its canon reference is an incomplete dispatch: fix the prompt, not the agent.

**Plan vs reality mismatch:** if the code contradicts the plan (line moved, function renamed, assumption false) — trust the code, note the deviation. If the mismatch invalidates the task's approach, stop and reconcile before dispatching, don't improvise a new design mid-execution.

---

## Step 3: Verification (at group boundaries)

**At the end of each group**, one verification pass:
1. Syntax check modified files (`php -l`, `node --check`)
2. Run **TARGETED tests only** — the test classes/files covering what this group touched: `phpunit --filter <ChangedClass>` / `phpunit tests/Path/`, `pytest -k`, `vitest run <file>`. **NEVER the full suite at a group boundary** — on a 10k-test suite a full run costs minutes and proves nothing the targeted run doesn't; builders and subagents inherit this rule. Derive the filter from the group's changed files (`git diff --name-only` → matching test classes + tests added in this group).
3. Check acceptance criteria for each task in the group

**The FULL suite runs exactly ONCE per plan execution — in the final group, before commit** (it catches `failOnWarning`/`failOnRisky`, orphan tests and cross-module regressions that filters miss). It is run by this session in the final group — **builders never run it**. Report it with BOTH counts: passed AND skipped, with the skip reason.

**Verification fails → Stop-the-Line (Rule 1).** Invoke `systematic-debugging` for root cause before any fix.

**Before marking any todo item `completed`** — the verification for its group must have run in this session. This is the `verification-before-completion` gate applied at group granularity, not per-task.

**Final group** is always sequential and always contains (when this execution is the build stage of `task-lifecycle`, review and verification follow its Steps 2–4 instead of the two middle items):
- Comprehensive test pass — the single FULL-suite run of this execution (dispatch `test-automator` if new tests are needed)
- Code review (dispatch `code-reviewer`). If the project defines a review threshold (e.g. CLAUDE.md), it wins: a diff it exempts gets the project's self-audit checklist instead.
- **Surface verification** for user-facing changes: run the `verify-e2e` skill in a FRESH subagent (GUI → browser + screenshots, API → real request). Tests passing ≠ the surface working.
- Commit

The final test pass IS the comprehensive test coverage — don't add a separate "final testing task". Per-group verification + final pass is enough.

---

## The Three Rules

### Rule 1: Stop-the-Line

Test fails, build breaks, anything unexpected:

```
STOP → preserve error output → diagnose → fix root cause (not symptom) → re-verify → continue
```

Never rationalize past a failure. Invoke `systematic-debugging` before any fix.

### Rule 2: Scope Discipline

Only touch what the current task requires. Improvements outside scope → note as a separate TODO, don't fix now. "Przy okazji" changes are the #1 source of regressions.

### Rule 3: Read Before Modifying (when needed)

For tasks that modify existing files: read the file IF you need context you don't have (existing patterns, insertion points, related functions). For trivial edits on files just read in this session — don't re-read. Agents decide file-reading autonomously; don't force a preamble read on every dispatch.

---

## Agent Selection

| Task set | Agent |
|-----------|-------|
| Independent and sizeable, any language | `builder` |
| Query optimization, indexes, EXPLAIN | `database-optimizer` |
| Bug with an unknown cause | `debugger` |
| Refactoring across modules, as its own task | `refactoring-orchestrator` |
| Tests only | `test-automator` |
| Final code review, security included | `code-reviewer` |
| Surface verification (`verify-e2e` brief) | `test-automator` |

The agents are goal-only: they follow the project's own rules (CLAUDE.md, `.claude/rules`, `docs/standards`) and the lines of the brief, and a skill named in the brief does not load inside them. A rule they must apply goes into the brief as text. `backend-security-coder` is for audits; security in a build is reviewed by `code-reviewer`.

`code-reviewer` (subject to the project's review threshold) and `test-automator` (when new tests are needed) run only in the final sequential group.

---

## Red Flags

- 100+ lines written without running verification → verify now
- Modifying files not listed in the task → scope creep, stop
- "Probably fine" after an error → investigate
- Agent returns an error and you retry blindly → diagnose first
- Verification fails after 2 fix attempts → invoke `systematic-debugging`
- Each fix reveals a new problem elsewhere → architectural issue, escalate

---

## Companion Skills

- `verification-before-completion` — the verification gate (runs at group boundaries, not per-task)
- `verify-e2e` — surface-level verification in the final group (user-facing changes)
- `systematic-debugging` — mandatory when Stop-the-Line fires
- `test-driven-development` — for new production code written during execution; a builder gets it as brief lines (red test first, executed), not by the skill name
- `task-lifecycle` — when this plan execution is the build stage of a Large task (adds the review loop, verification and the report on top)
