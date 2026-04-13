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
4. If concerns: Raise them with your human partner before starting
5. If no concerns: Create TodoWrite with agent assignments and proceed

### Step 1.1: Create Todo List WITH Agent Assignments (CRITICAL)

**After analyzing the plan, ALWAYS create a TodoWrite with agent labels in each todo item.**

This is critical because after context window compaction you lose earlier reasoning.
The todo list is the ONLY thing that persists — so it must contain all routing info.

**Format each todo item as:**
```
Task N: <description> [AGENT: <agent-name>]
```

**Example:**
```javascript
TodoWrite([
  { content: "Task 1: CSS - klasa .screen-footer-actions [DIRECT]", status: "pending" },
  { content: "Tasks 2-5: HTML - poprawki ekranów [DIRECT]", status: "pending" },
  { content: "Tasks 6-10: JS app.js - logika tworzenia zlecenia [AGENT: javascript-pro]", status: "pending" },
  { content: "Tasks 11-12: PHP - walidacja kontrolera [AGENT: php-pro]", status: "pending" },
  { content: "Task 13: JS desktop - usunięcie walidacji [AGENT: javascript-pro]", status: "pending" },
  { content: "VERIFY: php -l + testy po każdym tasku [DIRECT]", status: "pending" },
  { content: "Weryfikacja kodu [AGENT: code-reviewer]", status: "pending" },
  { content: "Testy automatyczne [AGENT: test-automator]", status: "pending" },
  { content: "Commit zmian [DIRECT]", status: "pending" }
])
```

**Rules:**
- Group related tasks that use the same agent (e.g., "Tasks 7-11")
- Simple CSS/HTML edits → `[DIRECT]` (no agent needed)
- Complex JS logic → `[AGENT: javascript-pro]`
- PHP controllers/services → `[AGENT: php-pro]`
- Always include code-reviewer and test-automator at the end
- This list survives compaction — the agent labels tell future-you what to do

### Step 1.5: Read Target Files BEFORE Modification (CRITICAL)

**Before executing ANY task that modifies existing files:**

1. **Read each file completely** using the Read tool
2. **Understand existing patterns:** naming, error handling, formatting
3. **Find correct insertion points** (plan may have wrong line numbers)
4. **Check for conflicts:** similar functions, duplicate code, breaking changes
5. **Adapt if needed:** follow existing patterns over plan assumptions

**Why:** Plans are written based on assumptions. Files may have changed since plan was written.

---

### Step 2: Execute ALL Tasks

**Execute every task from the plan sequentially:**

For each task:
1. Mark as in_progress
2. **Determine task type** (see Agent Selection below)
3. **Invoke appropriate agent** using Agent tool with `subagent_type`
4. Follow each step exactly (plan has bite-sized steps)
5. **Incremental Verification** (see below)
6. Mark as completed
7. **Continue to next task immediately**

**Run independent tasks in parallel when possible.**

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

## Parallel Agent Execution

**When tasks are independent, run agents in parallel:**

```
Tasks 4 and 5 have no dependencies:
- Task 4: Create JS service (javascript-pro)
- Task 5: Add SQL indexes (database-optimizer)

→ Invoke both agents simultaneously using multiple Agent tool calls in single message
```

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
- **Execute ALL tasks from start to finish**
- **Select appropriate agent for each task**
- Follow plan steps exactly
- **Stop-the-Line when anything breaks** → invoke `systematic-debugging` before fixing
- **Scope Discipline** — only change what the task says to change
- **Incremental Verification** — test after every task, not just at the end
- **Never mark a task `completed` without invoking `verification-before-completion`**
- **New code for each task** follows `test-driven-development` (failing test first)
- Prefer parallel execution when tasks are independent
- **Todo list with [AGENT: name] labels is your memory after compaction**

## Companion Skills (always in scope during execution)

- **`verification-before-completion`** — gate before every "done / passing / fixed" claim and before marking any todo complete.
- **`systematic-debugging`** — mandatory when Stop-the-Line fires; prevents symptom-patching.
- **`test-driven-development`** — mandatory for any new production code written during execution.
- After compaction, READ the todo list first to know which agents to use
