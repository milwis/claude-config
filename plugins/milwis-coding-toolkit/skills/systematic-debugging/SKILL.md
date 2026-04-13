---
name: systematic-debugging
description: "Use when encountering ANY bug, test failure, build failure, or unexpected behavior — BEFORE proposing or attempting fixes. Enforces a 4-phase root-cause discipline: investigate, compare, hypothesize, fix. Complements the `debugger` agent (execution) by providing the guardrails (when to stop, when to escalate, when the architecture is wrong)."
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Symptom fixes mask the real problem and come back next week with a new face.

**Core principle:** Always find the root cause *before* attempting any fix. Symptom fixes are failure, even if they make the test green.

**Announce at start:** "I'm using the systematic-debugging skill."

**Violating the letter of this process violates the spirit of debugging.**

---

## This Skill vs. the `debugger` Agent

- **This skill** = the **discipline / guardrails**: when to stop, when to escalate, when 3+ fixes means the architecture is wrong, how to resist "just one quick fix".
- **`debugger` agent** = the **execution / technique**: reading logs, following stack traces, isolating failure, forming hypotheses in depth.

Use the skill to frame the investigation. Dispatch the `debugger` agent when you need focused execution of a complex multi-step investigation that would pollute your main context.

---

## The Iron Law

```
NO FIXES WITHOUT ROOT-CAUSE INVESTIGATION FIRST
```

If you have not completed Phase 1, you cannot propose a fix. No exceptions — not even "obviously it's X".

---

## When to Use

Use this for **any** technical issue:
- Test failures
- Production bugs
- Unexpected behavior (UI, API, data)
- Performance regressions
- Build / CI failures
- Integration issues

**Use it especially when:**
- You're under time pressure ("emergencies" make guessing tempting — guessing is how emergencies become weeks of rework)
- "Just one quick fix" feels obvious
- You've already tried a fix that didn't work
- The user is frustrated and wants it fixed *now*
- You don't fully understand the issue

**Do not skip when:**
- The issue "seems simple" (simple bugs have root causes too — the process is fast for them)
- You're in a hurry (rushing guarantees rework)

---

## The Four Phases

You MUST complete each phase before proceeding to the next.

### Phase 1 — Root-Cause Investigation

Before touching any code:

**1. Read error messages carefully.**
Don't skip past them. They usually contain the solution. Read the *entire* stack trace — line numbers, file paths, error codes.

**2. Reproduce consistently.**
Can you trigger it reliably? What are the exact steps? Does it happen every time? If not reproducible → gather more data, *don't guess*.

**3. Check recent changes.**
```bash
git log --oneline -20
git diff HEAD~5
```
What changed that could plausibly cause this? New dependencies? Config changes? Environment differences?

**4. Read the logs first.**
The `debugger` agent's rule: **always start from logs**. App logs, framework logs, web server logs. Don't theorize without evidence from the logs.

**5. Gather evidence at component boundaries (multi-layer systems).**
When a system has multiple layers (frontend → API → service → DB, or CI → build → sign → deploy), you don't yet know *which layer* fails. Before guessing:

```
For EACH component boundary:
  - Log what enters the component
  - Log what exits the component
  - Verify env / config propagation
  - Check state at each layer
Run once → analyze evidence → identify the failing layer → investigate that layer only.
```

**6. Trace data flow backward.**
When the error is deep in the call stack:
- Where does the bad value originate?
- What called this with the bad value?
- Keep tracing *up* until you reach the source.
- Fix at the source, not at the symptom.

### Phase 2 — Pattern Analysis

Find the pattern before fixing.

**1. Find a working example.** In the same codebase, what similar thing already works correctly?

**2. Compare against a reference.** If you're applying a known pattern (e.g., a framework's API, a Laravel controller, a PSR-4 layout), read the reference *completely*. Don't skim. Every line.

**3. List every difference** between the working example and the broken one. However small. "That can't matter" is where bugs hide.

**4. Understand dependencies.** What config, env vars, settings, DB schema assumptions does this code make? What's different between the working and broken environments?

### Phase 3 — Hypothesis & Testing

Scientific method, one variable at a time.

**1. Form ONE hypothesis.**
Write it down in the form: *"I think X is the root cause because Y (evidence from Phase 1/2)."* Be specific, not vague.

**2. Test it minimally.**
The smallest possible change that would confirm or deny the hypothesis. **One variable at a time.** Don't fix multiple things at once — you'll never know which one worked.

**3. Verify before continuing.**
- Hypothesis confirmed → Phase 4.
- Hypothesis wrong → form a **new** hypothesis from the new evidence. **Don't stack fixes.**

**4. Say "I don't understand X" when true.**
Don't pretend. Don't hand-wave. Research, ask, read more.

### Phase 4 — Implementation

Fix the root cause, not the symptom.

**1. Write a failing test** that reproduces the bug (see `test-driven-development` skill).
- Automated test if possible
- One-off script if no framework exists
- MUST exist before the fix

**2. Implement ONE fix.**
Address the root cause identified in Phase 3. **One change.** No "while I'm here" improvements. No bundled refactoring. Scope discipline.

**3. Verify the fix.**
Apply the `verification-before-completion` gate:
- The new test passes now
- No other test broke
- The original symptom is gone (not just the proxy)

**4. If the fix doesn't work:**
- **STOP.**
- Count: how many fix attempts have you made this session?
- If `< 3` → return to Phase 1 and re-analyze with new evidence.
- If `≥ 3` → **STOP** and question the architecture (next section).

---

## 3+ Failed Fixes = Architectural Problem

**Pattern indicating an architectural bug, not a local bug:**
- Each fix reveals a new related problem in a different place
- Fixes start requiring "massive refactoring" to implement
- Each fix creates new symptoms somewhere else
- You're playing whack-a-mole across the codebase

This is NOT a failed hypothesis — it's a wrong architecture / pattern / abstraction.

**STOP and raise it with the user before attempting fix #4.** Ask:
- Is this pattern fundamentally sound?
- Are we "sticking with it through sheer inertia"?
- Should we refactor the architecture instead of continuing to patch symptoms?

Pushing through with fix #4 without this conversation is how multi-day debug sessions happen.

---

## Red Flags — STOP and Return to Phase 1

Catch yourself thinking any of these:

- "Quick fix for now, investigate later"
- "Just try changing X and see what happens"
- "Let me make several changes and run the tests"
- "Skip the test, I'll verify manually"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [list of fixes without investigation]"
- "One more fix attempt" (when you've already tried 2+)
- Each fix reveals a *new* problem in a *different* place

**All of these mean: STOP. Return to Phase 1.**

---

## User Signals You're Doing It Wrong

Watch for these from the user — they're redirections, not hints:

- *"Is that actually happening?"* → you assumed without verifying
- *"Will it show us X?"* → you should have added evidence gathering
- *"Stop guessing."* → you're proposing fixes without understanding
- *"Ultrathink this."* → question fundamentals, not just symptoms
- *"We're stuck?"* (frustrated) → your approach isn't working, reset
- Polish equivalents: *"nie zgaduj"*, *"sprawdź zanim poprawisz"*, *"to już nie działa trzeci raz"*

When you see these: **STOP. Return to Phase 1.**

---

## Rationalizations — All Wrong

| Excuse | Reality |
|---|---|
| "Issue is simple, no process needed" | Simple issues have root causes too. The process is fast. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | The first fix sets the pattern. Do it right from the start. |
| "I'll write the test after confirming the fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Creates new bugs. |
| "The reference is too long, I'll adapt it" | Partial understanding guarantees bugs. Read it all. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding the cause. |
| "One more fix" (after 2+ failures) | 3+ failures = architectural problem. Stop. Escalate. |

---

## Quick Reference

| Phase | Activities | Done when |
|---|---|---|
| **1. Root cause** | Read errors/logs, reproduce, check diffs, gather evidence | You understand **what** is wrong and **why** |
| **2. Pattern** | Find a working example, compare, list differences | You can articulate every relevant difference |
| **3. Hypothesis** | Form one theory, test minimally | Theory confirmed (→ Phase 4) or new theory |
| **4. Fix** | Failing test → one fix → verify → pass | Bug resolved, all tests green, no regressions |

---

## When Investigation Reveals "No Root Cause"

Occasionally the issue is truly environmental / timing-dependent / external (flaky network, 3rd-party outage, etc). In that case:

1. Document what you investigated
2. Implement appropriate handling: retry, timeout, error message, circuit breaker
3. Add logging / monitoring so next time you *can* investigate
4. Tell the user explicitly: "no deterministic root cause found, here's the mitigation"

**But:** ~95% of "no root cause" conclusions are incomplete investigation. Don't bail out early.

---

## Integration With Other Skills

- **`test-driven-development`** — Phase 4 step 1 (failing test before fix) is a TDD RED step.
- **`verification-before-completion`** — Phase 4 step 3 (verify the fix) is that gate.
- **`debugger` agent** — dispatch when you need the full log-first 6-step execution without polluting main context.
- **`executing-plans`** — when a Stop-the-Line event fires, this skill takes over.

---

## Final Rule

```
Symptom gone, cause unknown  →  NOT fixed
Cause known, symptom gone    →  fixed
```

If you can't explain *why* the fix worked in one sentence, you didn't find the root cause.
