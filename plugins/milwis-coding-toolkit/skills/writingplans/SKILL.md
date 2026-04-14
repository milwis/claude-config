---
name: writing-plans
description: Use when you have a spec for a multi-step task. Creates implementation plans with vertical slicing, risk-first ordering, and acceptance criteria — describes intent, not inline code.
---

# Writing Plans

**Core:** Plans describe WHAT and WHY clearly enough for a subagent to execute, WITHOUT the plan spelling out every line of code. Bite-sized tasks ordered by risk. Vertical slicing. DRY. YAGNI.

**Announce at start:** "I'm using the writing-plans skill."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

---

## Step 0: Read-Only Analysis (before writing the plan)

Do not write plan content until you complete this.

1. **Read flow docs** for the affected module (`docs/dokumentacja programu/flows/{moduł}.md` if it exists)
2. **Read files** that will be modified. Note patterns: naming, error handling, imports, formatting
3. **Check DB schema** for affected tables (grep for CREATE/ALTER or inspect DB)
4. **Map dependencies** — which JS calls which endpoint, which controllers use which services
5. **Identify risks** — missing `updated_at`, missing `$allowedResources`, cross-file JS without `window.`, missing `views`/`group_views` entries
6. **Write findings summary** (2-3 sentences) at the top of the plan

Plans based on reading code work first time. Plans based on imagination cause rework.

---

## Plan Header

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

---
```

---

## Task Structure

### Vertical slicing — mandatory

Each task = one complete vertical slice (DB → PHP → JS → UI → test). Not horizontal layers.

```
❌ WRONG:         ✅ RIGHT:
Task 1: all PHP   Task 1: Feature A — endpoint + JS + test
Task 2: all JS    Task 2: Feature B — endpoint + JS + test
Task 3: all tests Task 3: Feature C — endpoint + JS + test
```

Each vertical slice delivers a testable piece. If Task 2 fails, Task 1 still works.

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

---

## Per-Task Template

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

**Verification:**
- Failing test for [specific behavior] → passes after implementation
- [other acceptance criterion checks]

**Commit message:** `feat(moduł): opis po polsku`
```

**DO NOT put full implementation code in the plan.** The agent (`php-pro`, `sql-pro`, etc.) generates code following its own rules during execution. Plans describe intent; agents implement.

The only reason to include code in the plan is a very specific, non-obvious pattern — and even then, reference by file path rather than inline.

**Why this matters for token efficiency:** inline code in the plan means you pay to generate the same code twice (in the plan, then in execution). Describing intent means the code exists only once — in the final implementation.

---

## Red Flags — Plan Needs Rework

- Task without acceptance criteria → add before moving on
- Task modifying >5 files → split
- Horizontal layers (all PHP, then all JS) → remodel as vertical slices
- Easy tasks first, risky last → reverse the order
- Plan assumes file structure without checking → back to Step 0
- Plan contains full implementation code blocks → rewrite to describe intent

---

## Execution Handoff

After saving the plan:

**"Plan saved to `docs/plans/<filename>.md`. Ready to execute with the `executing-plans` skill?"**

---

## Companion Skills (active during execution, not pre-loaded)

- `executing-plans` — drives the execution loop
- `test-driven-development` — for new production code (failing test first)
- `systematic-debugging` — when anything breaks during execution
- `verification-before-completion` — the verification gate (at group boundaries)
