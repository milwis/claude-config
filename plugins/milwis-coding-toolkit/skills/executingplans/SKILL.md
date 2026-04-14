---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session. Includes stop-the-line, scope discipline, and incremental verification.
---

# Executing Plans

## Overview

Load plan, review critically, execute ALL tasks from start to finish using specialized agents.

**Core principle:** Complete execution with agent delegation — run through entire plan without stopping. But STOP immediately when something breaks.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

---

## The Process

### Step 1: Load and Review Plan

1. Read plan file
2. Review critically — identify any questions or concerns
3. **Analyze each task** — determine which agent/skill is best suited
4. **Analyze dependencies** between tasks (see Step 1.2)
5. If concerns: Raise them with your human partner before starting
6. If no concerns: Create TodoWrite with agent assignments AND parallel groups, then proceed

### Step 1.2: Dependency Analysis — Identify Parallel Groups (CRITICAL)

**Before writing the todo list, map task dependencies to find work that can run in parallel.**

Vertical-slice plans (from `writing-plans`) are often naturally parallelizable — each slice is a self-contained feature touching different files/endpoints/UI areas. Do NOT waste this by running everything sequentially.

**A task can run in parallel with another ONLY if ALL of these hold:**
1. **Disjoint files** — the two tasks never write to the same file (same directory is fine, same file is not)
2. **No data dependency** — neither task consumes a symbol, type, column, route, or return value produced by the other
3. **No side-effect coupling** — neither depends on DB state, filesystem state, or config written by the other
4. **Independent verification** — each task's tests/checks do not depend on the other having completed

If ANY of the four fails → the tasks are sequential.

**Tasks that MUST stay sequential (examples):**
- Migration adds column → later task queries that column
- Task A defines a JS function → Task B imports it
- Two tasks both edit `routes.php`, `config.php`, translation files, or the same controller
- Task uses fixtures/seeds created by an earlier task
- Git commits (always one-at-a-time)
- Final `code-reviewer` and `test-automator` passes (run after everything else)

**When in doubt → sequential.** A wrongly-parallelized pair of agents can silently clobber each other's file writes, which is strictly worse than slow sequential execution. Parallelization is an optimization, not a requirement.

**Assign a "group" number to every task:**
- Group 1 = the first batch that can run (possibly a single foundation task)
- Group 2 = tasks that depend only on Group 1 completing
- …and so on
- Within the same group, tasks run **in parallel**. Between groups, sequential.

### Step 1.3: Create Todo List WITH Agents AND Parallel Groups (CRITICAL)

**After analyzing the plan and dependencies, ALWAYS create a TodoWrite with BOTH agent labels AND group labels in each todo item.**

This is critical because after context window compaction you lose earlier reasoning.
The todo list is the ONLY thing that persists — it must contain all routing AND dependency info.

**Format each todo item as:**
```
[GROUP N|PARALLEL|SEQ] Task K: <description> [AGENT: <agent-name>]
```
- `PARALLEL` = one of several siblings in its group, dispatched together
- `SEQ` = the only task in its group (runs alone)

**Example (vertical-slice plan with parallel middle):**
```javascript
TodoWrite([
  // Group 1: foundation — must land first (schema everyone else depends on)
  { content: "[GROUP 1|SEQ] Task 1: Migration — add status column [AGENT: sql-pro]", status: "pending" },

  // Group 2: three independent vertical slices — RUN IN PARALLEL
  { content: "[GROUP 2|PARALLEL] Task 2: Feature A endpoint + JS [AGENT: php-pro]", status: "pending" },
  { content: "[GROUP 2|PARALLEL] Task 3: Feature B endpoint + JS [AGENT: php-pro]", status: "pending" },
  { content: "[GROUP 2|PARALLEL] Task 4: Feature C JS module [AGENT: javascript-pro]", status: "pending" },

  // Group 3: UI polish — depends on Group 2 handlers existing
  { content: "[GROUP 3|SEQ] Task 5: CSS + HTML polish [DIRECT]", status: "pending" },

  // Group 4: verification (always last, always sequential)
  { content: "[GROUP 4|SEQ] VERIFY: linters + tests po całości [DIRECT]", status: "pending" },
  { content: "[GROUP 4|SEQ] Code review [AGENT: code-reviewer]", status: "pending" },
  { content: "[GROUP 4|SEQ] Testy automatyczne [AGENT: test-automator]", status: "pending" },
  { content: "[GROUP 4|SEQ] Commit [DIRECT]", status: "pending" }
])
```

**Rules:**
- Every task has BOTH a `[GROUP N|...]` prefix AND an `[AGENT: ...]` or `[DIRECT]` suffix
- Simple CSS/HTML edits → `[DIRECT]` (no agent needed)
- Complex JS logic → `[AGENT: javascript-pro]`
- PHP controllers/services → `[AGENT: php-pro]`
- `code-reviewer` and `test-automator` always land in the final group, sequential
- This list survives compaction — the labels tell future-you what to dispatch and in what order

### Step 1.5: Read Target Files BEFORE Modification (CRITICAL)

**Before executing ANY task that modifies existing files:**

1. **Read each file completely** using the Read tool
2. **Understand existing patterns:** naming, error handling, formatting
3. **Find correct insertion points** (plan may have wrong line numbers)
4. **Check for conflicts:** similar functions, duplicate code, breaking changes
5. **Adapt if needed:** follow existing patterns over plan assumptions

**Why:** Plans are written based on assumptions. Files may have changed since plan was written.

---

### Step 2: Execute ALL Tasks — Group by Group

**Walk through the todo list in group order. Within each group, parallelize.**

```
For each group G (Group 1, Group 2, …):

  If G contains ONE task (SEQ):
    1. Mark task in_progress
    2. Invoke the appropriate Agent with subagent_type (or do it DIRECT)
    3. Incremental Verification (Rule 3) — run checks for THIS task
    4. verification-before-completion → mark completed
    5. Advance to next group

  If G contains MULTIPLE tasks (PARALLEL):
    1. Mark ALL tasks in the group in_progress
    2. Send a SINGLE assistant message containing N Agent tool calls —
       one per task — so the harness dispatches them concurrently
    3. Wait for ALL agents to return before touching the todo list
    4. Run Incremental Verification on each task (Rule 3)
    5. If ANY failed → Stop-the-Line (Rule 1) for that task;
       do NOT start the next group until all are green
    6. verification-before-completion → mark all completed
    7. Advance to next group
```

**Why batches, not one-at-a-time:** groups encode dependency. Running every task sequentially throws away the parallelism your dependency analysis in Step 1.2 already proved is safe. Running everything in parallel ignores real dependencies. Batches give you both.

**Inside each agent prompt**, follow the plan steps exactly (plans have bite-sized steps) and always Read the target files first (Step 1.5).

---

## Three Execution Rules

### Rule 1: Stop-the-Line

**When a test fails, build breaks, or something unexpected happens:**

```
1. STOP — do NOT continue to the next task
2. PRESERVE — save the error output (copy exact message)
3. DIAGNOSE — read the error, check the file, understand WHY
4. FIX — address root cause, not symptoms
5. GUARD — write a test that catches this specific failure
6. VERIFY — run full test suite, confirm nothing else broke
7. CONTINUE — only after all green
```

**Never rationalize past a failure:**
- "It's probably fine" → It's not. Check.
- "I'll fix it later" → You won't. Fix now.
- "It's unrelated" → Prove it with evidence.

### Rule 2: Scope Discipline

**Only touch what the current task requires.**

- See something to improve outside current task? → **Note it as separate TODO, don't fix it now**
- Tempted to refactor adjacent code? → **Don't. It's not in the plan.**
- Want to add "nice to have" feature? → **Stop. YAGNI.**

**Why this matters:** "Przy okazji" changes are the #1 source of regressions in this codebase. Every unplanned change is an untested change.

### Rule 3: Incremental Verification

**After EVERY task (not just at the end):**

```bash
# 1. Syntax check modified PHP files
php -l php/controllers/ModifiedFile.php

# 2. Existing tests must still pass
vendor/bin/phpunit --testdox 2>&1 | tail -20
npm run test:js:run 2>&1 | tail -20

# 3. If task has acceptance criteria — verify each one
```

**If verification fails → invoke Stop-the-Line (Rule 1), then invoke `systematic-debugging` skill for root-cause analysis before any fix attempt.**

**Before marking ANY task `completed` in TodoWrite → invoke `verification-before-completion` skill.** No exceptions. The todo list is a commitment, and marking it complete without evidence is lying.

**Why:** Catching a break at Task 3 costs 5 minutes. Catching it at Task 10 costs an hour of untangling.

---

### Step 3: Verification Testing

**After ALL tasks are complete, run comprehensive tests using `test-automator` agent.**

Tests must verify TWO things:
1. **Poprawność techniczna** — czy kod działa (składnia, struktura, bezpieczeństwo)
2. **Zgodność z intencją** — czy implementacja realizuje zamysł planu (logika biznesowa)

#### 3.1: Analiza komponentów do testowania

Identify testable components:
- PHP controllers/services → test syntax, methods, security patterns
- JavaScript modules → test functions, exports, XSS protection
- API routes → test route configuration
- Database changes → test schema/migrations
- HTML structure → test element IDs, classes, nesting
- Integration points → test connections between components

#### 3.2: Testy poprawności technicznej

```php
// A. Składnia
test("PHP syntax valid", exec("php -l file.php") === 0);
test("JS syntax valid", exec("node --check file.js") === 0);

// B. Struktura
test("Function exists", strpos($content, 'function myFunc') !== false);
test("Element exists in HTML", strpos($html, 'id="myElement"') !== false);

// C. Bezpieczeństwo
test("Uses escapeHtml in innerHTML", preg_match('/innerHTML.*escapeHtml/s', $js));
test("Validates required input", strpos($php, "empty(\$input['field'])") !== false);
```

#### 3.3: Testy zgodności z intencją (CRITICAL)

Verify implementation matches the INTENT of the plan, not just syntax:

```php
// Intencja: "Opis usterki opcjonalny przy tworzeniu"
test("create() accepts null reported_issue",
    strpos($php, "!empty(\$input['reported_issue']) ? trim(...) : null") !== false);

// Intencja: "Wymagany przy zamykaniu"
test("complete() validates reported_issue before closing",
    strpos($php, '$missingFields') !== false);
```

**Key principle:** For each goal in the plan, write at least one test verifying the goal is met.

#### 3.4: Uruchomienie testów

1. **Create test file** in `tests/test_<feature_name>.php` using `test-automator` agent
2. **Run tests**: `php tests/test_<feature_name>.php`
3. **All tests MUST pass** — fix failures before proceeding

### Step 4: Complete and Report

After ALL tasks AND tests are complete:
1. Use `code-reviewer` agent for final code review
2. Present summary:
   - What was implemented
   - Which agents were used
   - **Test results** (X tests passed/failed)
   - Any issues encountered and how they were fixed
3. Say: "Plan execution complete. All tests passed. Ready for final review."

---

## Agent Selection Guide

### Primary Agents (use Agent tool with subagent_type)

| Task Type | Agent | When to use |
|-----------|-------|-------------|
| PHP code (controllers, services, API) | `php-pro` | Any PHP file creation or modification |
| JavaScript code (modules, services) | `javascript-pro` | Complex JS, async patterns, ES6+ |
| SQL queries, migrations | `sql-pro` | Database queries, schema changes |
| SQL optimization | `database-optimizer` | Adding indexes, EXPLAIN analysis |
| Bug fixing | `debugger` | When something doesn't work as expected |
| Security review | `backend-security-coder` | Input validation, auth, SQL injection |
| Code cleanup | `refactoring-specialist` | Removing dead code, simplifying |
| Final review | `code-reviewer` | Before commit, quality check |
| Test automation | `test-automator` | Creating test suites, test strategies |

### Task Type Detection

```
Files contain *.php → php-pro
Files contain *.js (complex) → javascript-pro
Files contain *.sql or "migration" → sql-pro
Task mentions "index", "EXPLAIN", "slow query" → database-optimizer
Task mentions "bug", "error", "doesn't work" → debugger
Task mentions "security", "validation", "injection" → backend-security-coder
Task mentions "cleanup", "remove", "refactor" → refactoring-specialist
Task mentions "review", "check" (at end) → code-reviewer
```

---

## Parallel Agent Execution — Full Playbook

Parallel execution is not a "nice to have" — it is the default for any group with multiple independent tasks. A correctly-grouped plan cuts wall-clock time dramatically with zero risk of conflicts.

### How to dispatch a parallel group

Send ONE assistant message containing multiple `Agent` tool calls — one per task in the group. The harness runs them concurrently. **Do not** dispatch them in separate messages one after another; that serializes them.

```
[Single assistant message:]
Agent(subagent_type="php-pro",        prompt="Task 2: Feature A — <fully self-contained prompt>")
Agent(subagent_type="php-pro",        prompt="Task 3: Feature B — <fully self-contained prompt>")
Agent(subagent_type="javascript-pro", prompt="Task 4: Feature C — <fully self-contained prompt>")
```

### Each parallel agent prompt MUST be self-contained

The agent cannot see the conversation — write the prompt as if briefing a new colleague:
- Exact files to create / modify (with paths)
- The relevant slice of the plan (copy the task block verbatim)
- Acceptance criteria for THAT task only
- Explicit "do NOT touch file X" if there's any risk of overlap
- Tell it to Read target files before editing

### Heavier parallelization: Agent Teams

For very large plans (e.g. >4 independent slices, or multi-day work), consider `TeamCreate` to spin up a persistent team of specialized agents that share a worktree. A transient parallel group of `Agent` calls is simpler and enough for most plans — reach for teams only when the parallel batch would otherwise be very wide or long-running.

### When NOT to parallelize — safety checklist

Run the tasks **sequentially** (one group each) whenever any of these applies:

1. **Same-file writes.** Two agents editing `UserController.php` will clobber each other. Sequential, even if the edits look "different enough."
2. **Shared config/translation/routes files.** `routes.php`, `.env`, i18n JSON, `composer.json`, `package.json` — treat as single-writer.
3. **Data dependency.** Task B uses a function, column, route, or type that Task A creates → A must finish and be visible before B starts.
4. **Schema/migration dependency.** Any task that queries a new column must wait for the migration task.
5. **Shared fixtures or DB seeds.** Tests that rely on the same fixture row cannot run safely in parallel if the fixture is created inside one of the tasks.
6. **Verification coupling.** Task B's tests assume Task A's side effects. If you can't verify B without A being done, they belong in the same sequential chain (or the same task).
7. **Git operations.** `git add` / `git commit` / `git push` are always sequential. One commit at a time.
8. **Final review and test passes.** `code-reviewer` and `test-automator` look at the whole change — they run last, after every other group is green.
9. **You are unsure.** Default to sequential. The cost of a false parallelization (silent overwrite) is much higher than the cost of a slower run.

### Recovery: one task in a parallel group fails

1. Stop-the-Line fires for that task only — do NOT continue to the next group
2. Other agents in the same group may still complete — let them finish and verify independently
3. Invoke `systematic-debugging` for the failed task
4. Fix, re-verify, mark completed
5. Only then advance to the next group

---

## Red Flags During Execution

- **100+ lines written without running tests** → STOP, run tests NOW
- **Modifying files not listed in the task** → STOP, that's scope creep
- **"This is probably fine" after an error** → It's not. Investigate.
- **Skipping incremental verification** → Rule 3 is not optional
- **Agent returns error and you retry blindly** → Diagnose first, then retry
- **Acceptance criteria not checked** → Task is NOT done

---

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Agent returns error or fails repeatedly
- Missing dependency or unclear instruction
- Verification fails after 2 fix attempts
- Task requires changes outside the plan's scope
- You don't understand something

**Ask for clarification rather than guessing.**

---

## Remember

- Review plan critically first
- **Do dependency analysis (Step 1.2) BEFORE touching code — find parallel groups**
- **Execute ALL tasks from start to finish, group by group**
- **Within a group, dispatch parallel agents in a SINGLE message** — never serialize what can run concurrently
- **Select appropriate agent for each task**
- Follow plan steps exactly
- **Stop-the-Line when anything breaks** → invoke `systematic-debugging` before fixing
- **Scope Discipline** — only change what the task says to change
- **Incremental Verification** — test after every task, not just at the end
- **Never mark a task `completed` without invoking `verification-before-completion`**
- **New code for each task** follows `test-driven-development` (failing test first)
- **When unsure about parallelism → sequential.** A false-parallel pair of agents can clobber files silently.
- **Todo list with `[GROUP N|PARALLEL|SEQ]` + `[AGENT: name]` labels is your memory after compaction**

## Companion Skills (always in scope during execution)

- **`verification-before-completion`** — gate before every "done / passing / fixed" claim and before marking any todo complete.
- **`systematic-debugging`** — mandatory when Stop-the-Line fires; prevents symptom-patching.
- **`test-driven-development`** — mandatory for any new production code written during execution.
- After compaction, READ the todo list first to know which agents to use
