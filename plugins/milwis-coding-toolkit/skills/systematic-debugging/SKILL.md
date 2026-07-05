---
name: systematic-debugging
description: "Use when encountering any bug, test failure, or unexpected behavior. Log-first evidence gathering, then 4-phase root-cause discipline before any fix: investigate, compare, hypothesize, fix."
---

# Systematic Debugging

**Core:** Find the root cause *before* attempting any fix. Symptom fixes are failure, even if they make the test green. Evidence comes from logs first, code second.

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

## Step 0: Logs First (before ANY code analysis)

**ALWAYS start from server logs — never from reading code.**

1. **Early-warning report first** (if the project has one — FakturyKonkret: branch `log-reports`, sections HEALTH STATUS / ANOMALIES). If something is flagged there, the issue is there — not in `[ERROR]`.
2. **Map symptom → module log** using the project's mapping (FakturyKonkret: table in CLAUDE.md section DEBUGOWANIE). Unknown module → `grep '\[ERROR\]' logs/*.log | tail -30`.
3. **Read errors with context, trace the request:**
   ```bash
   grep '\[ERROR\]' logs/{modul}.log | tail -30
   grep 'REQUEST_ID' logs/{modul}.log        # follow one request across entries
   grep '\[WARNING\]' logs/{modul}.log | tail -30   # slow queries, degradation
   ```
   Log line format:
   ```
   [2026-03-19 14:23:45] [ERROR] [a1b2c3d4] [saveOrder] [user:admin] Message | ExceptionClass: message | File:line
   ```
4. **Check the solved-problems repository:** `grep -i "keyword" docs/troubleshooting.md` — this exact bug may already have a documented cause and fix.

Only after reading the logs → Phase 1.

---

## The Four Phases

### Phase 1 — Root-Cause Investigation

1. **Read the FULL error message.** Complete stack trace — line numbers, file paths, error codes. Not just the first line.
2. **Reproduce consistently.** Exact steps, every time — always / sometimes / randomly? Which inputs? One user or all?
   - Not reproducible → check time dependencies (cron, timezone, cache expiry), the specific record's data, session state (permissions, instance). Add defensive logging and wait for the next occurrence — don't guess.
   - **One user affected, ten fine → probably data, not code.**
3. **Check recent changes.** `git log --oneline -20`, `git diff HEAD~5`. For regressions, bisect:
   ```bash
   git bisect start && git bisect bad && git bisect good v3.5.0
   # test each suggested commit, mark good/bad, then: git bisect reset
   ```
4. **Localize the failing layer** — identify it BEFORE investigating it. Gather evidence at component boundaries (what enters, what exits):

   | Layer | How to check |
   |---|---|
   | UI/JS | Browser console (F12) — ReferenceError, TypeError, broken rendering |
   | API/Network | Network tab → status code, response body |
   | PHP controller | Log by requestId, `php -l` syntax check |
   | PHP service/repo | Stack trace in log, query params |
   | Database | Slow query log, missing data, schema mismatch |
   | External service | KSeF/GPS/WAPRO timeout, invalid response |
   | The test itself | Is the test correct? False negative? |

5. **Reduce to the minimal case.** Strip unrelated code/data; simplest input that still fails; isolate the component (controller? service? repo? query?).
6. **Trace data flow backward.** Where does the bad value originate? Follow it up to the source. The fix belongs at the source, not at the symptom.

### Phase 2 — Pattern Analysis

1. **Find a working example** in the same codebase — what similar thing already works?
2. **Compare against a reference.** Read the reference completely (framework API, pattern doc). Every line.
3. **List every difference** between working and broken. However small. "That can't matter" is where bugs hide.
4. **Understand dependencies.** What config, env vars, schema assumptions? What differs between the working and broken environments?

### Phase 3 — Hypothesis & Testing

1. **Form ONE hypothesis:** *"I think X is the root cause because Y (evidence from Phase 1/2)."*
2. **Test it minimally.** Smallest change that confirms or denies. **One variable at a time.**
3. **Verify before continuing:**
   - Confirmed → Phase 4
   - Wrong → new hypothesis from new evidence. Don't stack fixes.
4. **Say "I don't understand X"** when true. Don't hand-wave.

### Phase 4 — Fix, Guard, Verify

1. **Write a failing regression test** (see `test-driven-development`). It MUST fail without the fix, pass with it, and describe the scenario that caused the bug.
2. **Implement ONE fix at the root cause.** No bundled refactoring, no "while I'm here" improvements.

   ```
   ❌ try/catch that swallows the error
   ❌ if ($value !== null) without understanding WHY it's null
   ❌ raising a timeout without checking what is slow
   ✅ find WHY the value is null and fix the source
   ✅ optimize the slow query instead of raising the timeout
   ```
3. **Verify end-to-end:** new test passes → affected suites (`vendor/bin/phpunit`, `npm run test:js:run`) → syntax check modified files (`php -l`) → original symptom gone.
4. **If the fix doesn't work:**
   - `< 3` attempts → return to Phase 1 with the new evidence
   - `≥ 3` attempts → STOP. Architectural problem (below).

---

## 3+ Failed Fixes = Architectural Problem

Pattern indicating an architectural, not local, bug:
- Each fix reveals a new related problem elsewhere
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms somewhere else — whack-a-mole across the codebase

**STOP and raise with the user before attempting fix #4.** Ask: is this pattern fundamentally sound? Should we refactor instead of patching? Pushing through fix #4 without this conversation is how multi-day debug sessions happen.

---

## Never Rationalize

- "To pewnie niezwiązane" → prove it: `git stash` — does the bug disappear?
- "Naprawię to później" → you won't. Fix it now.
- "To edge case, nikt tego nie trafi" → the log says otherwise.

---

## When Investigation Reveals "No Root Cause"

Occasionally the issue is truly environmental / timing-dependent / external:

1. Document what you investigated
2. Implement appropriate handling: retry, timeout, error message, circuit breaker
3. Add logging so next time you *can* investigate
4. Tell the user: "no deterministic root cause, here's the mitigation"

**~95% of "no root cause" conclusions are incomplete investigation.** Don't bail out early.

---

## Known Failure Patterns (FakturyKonkret)

| Symptom | Root cause (verified) | Fix |
|---|---|---|
| `TypeError: str_pad()/trim(): Argument #1 must be of type string` | `strict_types=1` + int/null from DB fed into a string function | Cast at the boundary: `(string)$val`, `$row['x'] ?? ''` |
| Works in dev, `ReferenceError: fn is not defined` in prod bundle | Cross-file JS call without `window.` prefix | `window.fn = fn` at definition; `grep -rn "fn" js/` — check ALL usages |
| Page loads >5s, log: `[WARNING] SLOW API` | N+1 queries (100+ SELECTs per request) | JOIN or batch load; confirm with `EXPLAIN` |
| 403 on a new module's endpoint | Missing entry in `$allowedResources` (`php/helpers.php`) — 99% of cases | Add resource to `$allowedResources` + permissions/resources tables |
| Data changed but table doesn't auto-refresh | INSERT/UPDATE without `updated_at = NOW()` | Add it — ChangesTracker depends on it |

---

## Toolbox

```bash
php -l php/controllers/File.php                    # syntax
vendor/bin/phpunit --filter test_name              # one test, fast
git blame php/controllers/OrderController.php      # who touched it last
git log --oneline v3.5.10..HEAD                    # what changed since the last build
```
```sql
EXPLAIN SELECT ...;  SHOW INDEX FROM orders;  SHOW PROCESSLIST;
```
```javascript
debugger;  console.table(rows);  console.time('op'); /*...*/ console.timeEnd('op');
```

---

## Quick Checklist — When Stuck

- [ ] Read the FULL error message? (not just the first line)
- [ ] Read the server logs? (`grep '\[ERROR\]' logs/*.log`)
- [ ] Checked `docs/troubleshooting.md` for the keyword?
- [ ] Checked what changed recently? (`git log --oneline -10`)
- [ ] Tried the simplest input?
- [ ] Checked the data in the DB? (data, not code, may be the problem)
- [ ] Checked types? (int vs string, null vs empty)
- [ ] Checked permissions? (`$allowedResources`, permissions table)
- [ ] Cleared caches? (browser cache included)

---

## After the Fix — Document

For non-obvious problems (surprising cause, project-specific pattern — not typos):
update `docs/troubleshooting.md` with symptom → cause → fix, per the project's rules (after the user confirms and asks to commit). The regression test is already written — that was Phase 4 step 1.

---

## Quick Reference — Phase exit criteria

| Phase | Done when |
|---|---|
| 1. Root cause | You understand *what* is wrong and *why* |
| 2. Pattern | You can articulate every relevant difference |
| 3. Hypothesis | Theory confirmed (→ Phase 4) or new theory formed |
| 4. Fix | Bug resolved, all tests green, no regressions |

---

## Integration

- `test-driven-development` — Phase 4 step 1 (failing test before fix) is a TDD RED step
- `verification-before-completion` — Phase 4 step 3 (verify fix) is that gate
- `debugger` agent — dispatch when full log-first investigation would pollute main context
- `executing-plans` — when Stop-the-Line fires there, this skill takes over

---

## Final Rule

```
Symptom gone, cause unknown  → NOT fixed
Cause known, symptom gone    → fixed
```

If you can't explain *why* the fix worked in one sentence, you didn't find the root cause.
