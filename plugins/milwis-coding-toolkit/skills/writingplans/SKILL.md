---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code. Creates comprehensive implementation plans with read-only analysis, vertical slicing, and acceptance criteria.
---

# Writing Plans

## Overview

Write implementation plans assuming the engineer has zero context for our codebase.
Document everything: which files to touch, code, testing, how to verify.
Plans are bite-sized tasks ordered by risk. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

---

## Step 0: Read-Only Analysis (BEFORE writing the plan)

**Do NOT write ANY plan content until you complete this step.**

1. **Read the flow docs** for the affected module:
   - `docs/dokumentacja programu/flows/{moduł}.md`
   - Understand: UI → JS → API → PHP → DB flow

2. **Read the files** that will be modified:
   - Grep for existing functions/methods that do similar things
   - Note patterns: naming, error handling, imports, formatting
   - Check DB schema: `grep -rn "CREATE TABLE\|ALTER TABLE" sql/` or check in DB

3. **Map dependencies** between components:
   - Which JS modules call which API endpoints?
   - Which controllers use which services/repositories?
   - Which tables are related via foreign keys?

4. **Identify risks** — what's most likely to go wrong:
   - New table without `updated_at`? → ChangesTracker won't work
   - New endpoint without `$allowedResources`? → 403 for everyone
   - Cross-file JS function without `window.`? → Bundle crash
   - Missing entry in `views`/`group_views` tables? → Dynamic nav broken

5. **Write findings summary** at the top of the plan (2-3 sentences).

**Why this matters:** Plans based on imagination cause rework. Plans based on reading code work the first time.

---

## Plan Document Header

**Every plan MUST start with:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILLS during execution:
> - `executingplans` — drives the task-by-task execution loop
> - `test-driven-development` — for every production code change in every task
> - `systematic-debugging` — when anything breaks (Stop-the-Line)
> - `verification-before-completion` — before marking any task complete or claiming anything is done

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach — based on Step 0 findings]

**Tech Stack:** [Key technologies/libraries]

**Findings from code analysis:**
- [Key finding 1 from Step 0]
- [Key finding 2 from Step 0]
- [Risk or gotcha identified]

---
```

---

## Task Structure

### Vertical Slicing — MANDATORY

**Each task = one complete vertical slice (DB → PHP → JS → UI → test).**

```
❌ WRONG (horizontal layers):
  Task 1: All PHP controllers
  Task 2: All JS modules
  Task 3: All tests

✅ RIGHT (vertical slices):
  Task 1: Feature A — endpoint + controller + JS handler + test
  Task 2: Feature B — endpoint + controller + JS handler + test
  Task 3: Feature C — endpoint + controller + JS handler + test
```

**Why:** Each completed task delivers a testable piece. If Task 2 fails, Task 1 still works.

### Risk-First Ordering

**Order tasks by risk, not by layer or convenience:**

1. **FIRST:** Most uncertain/risky tasks (new DB schema, unfamiliar API, complex logic)
2. **MIDDLE:** Medium-risk tasks (standard CRUD, known patterns)
3. **LAST:** Low-risk tasks (CSS, copy changes, config)

**Why:** If something is going to blow up the timeline, find out in Task 1 — not Task 8.

### Task Sizing

| Size | Files | Lines changed | Guide |
|------|-------|---------------|-------|
| **Small** | 1-2 | <50 | Single step, obvious |
| **Medium** | 3-5 | 50-150 | Multiple steps, clear path |
| **Large** | >5 | >150 | **MUST be broken down further** |

**Max 5 files per task.** Tasks touching >5 files = split them.

### Per-Task Template

```markdown
### Task N: [Feature/Component Name]

**Acceptance Criteria** (max 3, testable):
- [ ] [Specific, verifiable outcome 1]
- [ ] [Specific, verifiable outcome 2]
- [ ] [Specific, verifiable outcome 3]

**Files:**
- Create: `exact/path/to/file.php`
- Modify: `exact/path/to/existing.php` (function `methodName` around line ~123)
- Test: `tests/exact/path/to/test.php`

**Step 1: Write the failing test**

```php
// test code here
```

**Step 2: Run test to verify it fails**

Run: `vendor/bin/phpunit tests/path/test.php --filter test_name`
Expected: FAIL with "method not defined"

**Step 3: Write minimal implementation**

```php
// implementation code here
```

**Step 4: Run test to verify it passes**

Run: `vendor/bin/phpunit tests/path/test.php --filter test_name`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.php src/path/file.php
git commit -m "feat(moduł): opis po polsku"
```
```

---

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

---

## Remember

- Exact file paths always (with approximate line numbers for modifications)
- Complete code in plan (not "add validation")
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits
- **Vertical slices, not horizontal layers**

## Companion skills the plan relies on

The plan's execution loop leans on three discipline skills from this toolkit. The plan should *not* re-explain them — just reference them in the header and assume they're active:

- **`test-driven-development`** — every task follows red → verify red → green → verify green → refactor. The "Step 1: Write the failing test" in the per-task template is a RED step.
- **`systematic-debugging`** — when a task fails, the Stop-the-Line rule delegates to this skill before any fix attempt. Plans don't need to write debug steps — the skill provides them.
- **`verification-before-completion`** — applied before each acceptance-criterion checkmark and before marking the task complete.
- **Risk-first ordering**
- **Max 5 files per task**
- **Max 3 acceptance criteria per task**
- **ZAWSZE kończ plan taskiem testowym** (sekcja poniżej)

---

## MANDATORY: Final Testing Task

**Every plan MUST end with a comprehensive testing task:**

```markdown
### Task [FINAL]: Kompleksowe testy automatyczne

**Cel:** Dogłębna weryfikacja całej implementacji przed zakończeniem prac.

**Testy do przeprowadzenia:**

#### 1. Testy poprawności kodu
- Statyczna analiza kodu (linting, type checking)
- Sprawdzenie czy nie ma błędów składniowych
- Weryfikacja importów i zależności

#### 2. Testy poprawności logiki działania
- Unit testy dla każdej nowej funkcji/metody
- Testy edge cases (wartości graniczne, puste dane, null/undefined)
- Testy błędnych danych wejściowych
- Testy integracyjne łączące komponenty

#### 3. Testy sensu biznesowego
- Scenariusze użycia z perspektywy użytkownika końcowego
- Weryfikacja czy wynik odpowiada oczekiwaniom biznesowym
- Sprawdzenie czy nie złamano istniejącej funkcjonalności (regression)

#### 4. Testy zgodności z intencją użytkownika
- Porównanie wyniku z oryginalnym opisem zadania
- Weryfikacja czy wszystkie wymagania zostały spełnione
- Test "czy użytkownik będzie zadowolony z tego rozwiązania?"

**Kryteria akceptacji:**
- [ ] Wszystkie testy jednostkowe przechodzą
- [ ] Brak regresji w istniejących testach
- [ ] Kod przechodzi statyczną analizę
- [ ] Scenariusze biznesowe działają poprawnie
- [ ] Rozwiązanie realizuje cel użytkownika
```

**WAŻNE:** Ten task jest OBOWIĄZKOWY i MUSI być ostatnim zadaniem w każdym planie.

---

## Red Flags — Plan wymaga przeróbki

- Task bez acceptance criteria → dodaj zanim przejdziesz dalej
- Task modyfikujący >5 plików → rozbij
- Wszystkie PHP tasks, potem wszystkie JS tasks → przemodeluj na vertical slices
- Łatwe tasks pierwsze, ryzykowne ostatnie → odwróć kolejność
- Plan zakłada strukturę pliku bez jej sprawdzenia → wróć do Step 0
- Brak final testing task → dodaj

---

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (this session)** — I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — Open new session with executing-plans, batch execution with checkpoints

**Which approach?"**
