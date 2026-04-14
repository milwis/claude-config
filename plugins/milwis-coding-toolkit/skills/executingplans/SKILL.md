---
name: executing-plans
description: Use when you have a written implementation plan to execute. Drives task-by-task execution with parallel groups, scope discipline, and verification at group boundaries.
---

# Executing Plans

**Core:** Execute the plan group by group. Stop immediately when something breaks. Verify at group boundaries, not after every micro-step.

**Announce at start:** "I'm using the executing-plans skill."

---

## Step 1: Load, Review, Plan the Dispatch

1. Read the plan file
2. For each task, decide: **DIRECT** or **AGENT: {name}**?
3. Map dependencies → assign **Group numbers**
4. Create TodoWrite with labeled items (format below)
5. Concerns → raise before starting. Otherwise proceed.

### Dispatch mode — DIRECT vs AGENT

**DIRECT** (no agent dispatch, much cheaper) when the task is:
- CSS / HTML structure / copy / text changes
- Config values, environment variables
- Formatting, imports, renames
- Documentation edits

**AGENT** when the task introduces or modifies:
- Business logic, new functions / classes
- SQL queries or schema changes
- Input validation, auth, security-sensitive code
- Anything that benefits from the agent's checklist (type safety, injection prevention, async correctness)

When unsure → AGENT. Quality beats speed.

### Dependency analysis — find parallel groups

A task can run in parallel with another ONLY if ALL hold:
1. **Disjoint files** — never write to the same file
2. **No data dependency** — neither consumes a symbol/type/column/route produced by the other
3. **No side-effect coupling** — no shared DB state, filesystem state, or config
4. **Independent verification** — each task's tests don't depend on the other

If ANY fails → sequential.

**Same-file rule (critical):** if N tasks touch the same file, **dispatch ONE agent with all N tasks in its prompt**. Never dispatch parallel agents on the same file — they clobber each other, AND you waste N× the agent boot-up cost.

**Always sequential:** migrations before queries on new columns, git commits, final `code-reviewer` and `test-automator`.

**When in doubt → sequential.**

### Todo list format (survives context compaction)

```
[GROUP N|PARALLEL|SEQ] Task K: <description> [AGENT: <name>] or [DIRECT]
```

Example:
```javascript
TodoWrite([
  { content: "[GROUP 1|SEQ] Task 1: Migration — add status column [AGENT: sql-pro]" },
  { content: "[GROUP 2|PARALLEL] Task 2: Feature A endpoint+JS [AGENT: php-pro]" },
  { content: "[GROUP 2|PARALLEL] Task 3: Feature B endpoint+JS [AGENT: php-pro]" },
  { content: "[GROUP 2|PARALLEL] Task 4: Feature C JS module [AGENT: javascript-pro]" },
  { content: "[GROUP 3|SEQ] Task 5: CSS polish [DIRECT]" },
  { content: "[GROUP 4|SEQ] Verify + code review [AGENT: code-reviewer]" },
  { content: "[GROUP 4|SEQ] Commit [DIRECT]" }
])
```

The todo list is your memory after compaction — labels tell future-you what to dispatch and in what order.

---

## Step 2: Execute Group by Group

```
For each group G:

  If G contains ONE task (SEQ):
    - Mark in_progress → execute (dispatch or DIRECT) → mark completed
    - Advance to next group

  If G contains MULTIPLE tasks (PARALLEL):
    - Mark ALL in_progress
    - Send ONE assistant message with N Agent tool calls — concurrent dispatch
    - Wait for ALL to return
    - Verify the group (Step 3)
    - If any failed → Stop-the-Line for that task; don't start next group
    - Mark all completed → advance
```

**Parallel dispatches must be self-contained.** Each agent prompt contains:
- The task block verbatim from the plan
- Exact files to create / modify
- Acceptance criteria for THIS task only
- Explicit "do NOT touch file X" if overlap risk

---

## Step 3: Verification (at group boundaries)

**At the end of each group**, one verification pass:
1. Syntax check modified files (`php -l`, `node --check`)
2. Run affected tests (`phpunit`, `pytest`, `npm test`)
3. Check acceptance criteria for each task in the group

**Verification fails → Stop-the-Line (Rule 1).** Invoke `systematic-debugging` for root cause before any fix.

**Before marking any todo item `completed`** — the verification for its group must have run in this session. This is the `verification-before-completion` gate applied at group granularity, not per-task.

**Final group** is always sequential and always contains:
- Comprehensive test pass (dispatch `test-automator` if new tests are needed)
- Code review (dispatch `code-reviewer`)
- Commit

The final test pass IS the comprehensive test coverage — don't also do a "final testing task". Per-group verification + final pass is enough.

---

## The Three Rules

### Rule 1: Stop-the-Line

Test fails, build breaks, anything unexpected:

```
STOP → preserve error output → diagnose → fix root cause (not symptom) → re-verify → continue
```

Never rationalize past a failure. Invoke `systematic-debugging` before any fix.

### Rule 2: Scope Discipline

Only touch what the current task requires. Improvements outside scope → note as separate TODO, don't fix now. "Przy okazji" changes are the #1 source of regressions.

### Rule 3: Read Before Modifying (when needed)

For tasks that modify existing files: read the file IF you need context you don't have (existing patterns, insertion points, related functions). For trivial edits on files just read in this session — don't re-read. Agents decide file-reading autonomously; don't force a preamble read on every dispatch.

---

## Agent Selection

| Task Type | Agent |
|-----------|-------|
| PHP (controllers, services, API) | `php-pro` |
| Complex JS/TS, async patterns | `javascript-pro` |
| SQL queries, migrations | `sql-pro` |
| Query optimization, indexes, EXPLAIN | `database-optimizer` |
| Bug investigation | `debugger` |
| Security-sensitive code | `backend-security-coder` |
| Refactoring, cleanup | `refactoring-specialist` |
| Final code review | `code-reviewer` |
| Test creation | `test-automator` |
| PWA / mobile | `mobile-pwa-developer` |

`code-reviewer` and `test-automator` always in the final sequential group.

---

## Red Flags

- 100+ lines written without running verification → verify now
- Modifying files not listed in the task → scope creep, stop
- "Probably fine" after an error → investigate
- Agent returns error and you retry blindly → diagnose first
- Verification fails after 2 fix attempts → invoke `systematic-debugging`
- Each fix reveals a new problem elsewhere → architectural issue, escalate

---

## Companion Skills

- `verification-before-completion` — the verification gate (runs at group boundaries, not per-task)
- `systematic-debugging` — mandatory when Stop-the-Line fires
- `test-driven-development` — for new production code written during execution
