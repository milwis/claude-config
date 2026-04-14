---
name: systematic-debugging
description: "Use when encountering any bug, test failure, or unexpected behavior. Enforces 4-phase root-cause discipline before proposing fixes: investigate, compare, hypothesize, fix."
---

# Systematic Debugging

**Core:** Always find the root cause *before* attempting any fix. Symptom fixes are failure, even if they make the test green.

**Announce at start:** "I'm using the systematic-debugging skill."

---

## This skill vs. the `debugger` agent

- **This skill** = the discipline (when to stop, when to escalate, how to resist "just one quick fix")
- **`debugger` agent** = the execution (reading logs, following stack traces, isolating failure)

Dispatch the `debugger` agent for focused execution of a complex multi-step investigation that would pollute your main context.

---

## The Iron Law

```
NO FIXES WITHOUT ROOT-CAUSE INVESTIGATION FIRST
```

If you have not completed Phase 1, you cannot propose a fix. No exceptions — not even "obviously it's X".

---

## The Four Phases

### Phase 1 — Root-Cause Investigation

Before touching any code:

1. **Read error messages carefully.** Full stack trace — line numbers, file paths, error codes.
2. **Reproduce consistently.** Exact steps, every time. Not reproducible → gather more data, don't guess.
3. **Check recent changes.** `git log --oneline -20`, `git diff HEAD~5`. What plausibly caused this?
4. **Read the logs first.** App logs, framework logs, web server logs. Don't theorize without evidence.
5. **Gather evidence at component boundaries** (multi-layer systems): for each boundary, log what enters and exits. Identify the failing layer BEFORE investigating it.
6. **Trace data flow backward.** Where does the bad value originate? Trace up until you reach the source. Fix at the source, not the symptom.

### Phase 2 — Pattern Analysis

1. **Find a working example** in the same codebase — what similar thing already works?
2. **Compare against a reference.** Read the reference completely (framework API, pattern doc). Every line.
3. **List every difference** between working and broken. However small. "That can't matter" is where bugs hide.
4. **Understand dependencies.** What config, env vars, schema assumptions? What's different between working and broken environments?

### Phase 3 — Hypothesis & Testing

1. **Form ONE hypothesis:** *"I think X is the root cause because Y (evidence from Phase 1/2)."*
2. **Test it minimally.** Smallest change that confirms or denies. **One variable at a time.**
3. **Verify before continuing:**
   - Confirmed → Phase 4
   - Wrong → new hypothesis from new evidence. Don't stack fixes.
4. **Say "I don't understand X"** when true. Don't hand-wave.

### Phase 4 — Implementation

1. **Write a failing test** that reproduces the bug (see `test-driven-development`).
2. **Implement ONE fix.** Address the root cause. One change. No bundled refactoring. No "while I'm here" improvements.
3. **Verify the fix:**
   - New test passes
   - No other test broke
   - Original symptom is gone
4. **If the fix doesn't work:**
   - `< 3` attempts → return to Phase 1 with new evidence
   - `≥ 3` attempts → STOP. Architectural problem (see below).

---

## 3+ Failed Fixes = Architectural Problem

Pattern indicating architectural, not local, bug:
- Each fix reveals a new related problem elsewhere
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms somewhere else
- Whack-a-mole across the codebase

**STOP and raise with the user before attempting fix #4.** Ask:
- Is this pattern fundamentally sound?
- Should we refactor the architecture instead of patching?

Pushing through fix #4 without this conversation is how multi-day debug sessions happen.

---

## When Investigation Reveals "No Root Cause"

Occasionally the issue is truly environmental / timing-dependent / external:

1. Document what you investigated
2. Implement appropriate handling: retry, timeout, error message, circuit breaker
3. Add logging so next time you *can* investigate
4. Tell the user: "no deterministic root cause, here's the mitigation"

**~95% of "no root cause" conclusions are incomplete investigation.** Don't bail out early.

---

## Quick Reference

| Phase | Done when |
|---|---|
| 1. Root cause | You understand *what* is wrong and *why* |
| 2. Pattern | You can articulate every relevant difference |
| 3. Hypothesis | Theory confirmed (→ Phase 4) or new theory |
| 4. Fix | Bug resolved, all tests green, no regressions |

---

## Integration

- `test-driven-development` — Phase 4 step 1 (failing test before fix) is a TDD RED step
- `verification-before-completion` — Phase 4 step 3 (verify fix) is that gate
- `debugger` agent — dispatch when full log-first investigation would pollute main context
- `executing-plans` — when Stop-the-Line fires, this skill takes over

---

## Final Rule

```
Symptom gone, cause unknown  → NOT fixed
Cause known, symptom gone    → fixed
```

If you can't explain *why* the fix worked in one sentence, you didn't find the root cause.
