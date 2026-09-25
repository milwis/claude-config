---
name: systematic-debugging
description: "Use when encountering any bug, test failure, or unexpected behavior. Log-first evidence gathering, then 4-phase root-cause discipline before any fix: investigate, compare, hypothesize, fix."
---

# Systematic Debugging

**Core:** Find the root cause *before* attempting any fix. Symptom fixes are failure, even if they make the test green. Evidence comes from logs first, code second.

**Announce at start:** "I'm using the systematic-debugging skill."

**Entry:** a bug, failing test, or unexpected behavior whose cause is not evidence-backed yet.
**Stop:** the root cause is named with MEASURED evidence (command / `file:line`), its disproof was run and survived, and the regression test is red-then-green — or, after 3 failed fixes, the architectural question has been raised with the user.

This skill defines HOW to debug in any project. The project's own docs (CLAUDE.md, runbooks) define WHERE — log locations, symptom→log mappings, test commands. When the project documents a debugging path, follow it within this process.

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

**ALWAYS start from logs and observability — never from reading code.**

**Redact before you show anything.** Every command, log line, or captured artifact quoted in this session — from the first `grep` in this step through the final report — gets secrets replaced with `<REDACTED>` first: API keys, tokens, passwords, connection strings, PII. Build feedback loops against env vars so the credential stays in the environment rather than in what gets shown. If the redacted output isn't enough to diagnose the bug, say so and ask the user for a scoped/redacted artifact instead of pasting the raw one.

1. **Early-warning signals first**, if the project has any (health report, monitoring dashboard, alerting channel, anomaly detection). If something is flagged there, the issue is there — not in the raw error log.
2. **Map symptom → log source.** Use the project's documented mapping (CLAUDE.md, runbook) when one exists. No mapping → find the errors:
   ```bash
   grep -ri 'ERROR\|CRITICAL\|FATAL' logs/ --include="*.log" | tail -30
   ```
   App logs empty → check the framework logger's configured path, then web-server/container logs (Apache/Nginx, journald, `docker logs`).
3. **Read errors with context, trace one request end-to-end.** Learn the project's log line anatomy — timestamp, level, request/correlation ID, module, user — then follow a single correlation ID across all entries:
   ```bash
   grep '\[ERROR\]' logs/<module>.log | tail -30
   grep '<REQUEST_ID>' logs/*.log            # one request across layers
   grep '\[WARNING\]' logs/<module>.log | tail -30   # degradation, slow queries
   ```
4. **Check the solved-problems repository** — troubleshooting doc, runbooks, post-mortems, closed issues: `grep -ri "keyword" docs/troubleshooting* README* CHANGELOG*`. This exact bug may already have a documented cause and fix.

Only after reading the logs → Phase 1.

---

## The Four Phases

### Phase 1 — Root-Cause Investigation

1. **Read the FULL error message.** Complete stack trace — line numbers, file paths, error codes. Not just the first line.
2. **Build the feedback loop — one command that goes red on THIS bug.** Everything after this step consumes the loop; without it, hypotheses are vibes. Try in this order and stop at the first that works: a failing test at the nearest seam (unit → integration → e2e) → a `curl`/HTTP call against the dev server → a CLI run on a fixture, diffed against a known-good output → a headless-browser script (Playwright) → replay of a captured payload/log through the code path → a throwaway harness calling the one function → `git bisect run` when the bug appeared between two known states → a differential run (old vs new version, two configs) → **last resort** a human-in-the-loop script from `scripts/hitl-loop.template.sh` when the repro needs an action only a human can perform (record the gap in `docs/VERIFICATION_ENV.md` as `verify-e2e` does).

   **The step is done when you can name ONE command you have ALREADY RUN (invocation + output quoted, secrets redacted) that is:** red-capable (asserts the user's exact symptom, not "didn't crash"), deterministic (same verdict every run; for flaky bugs: loop the trigger 100×, add stress, narrow timing until the rate is high enough to debug), fast (seconds), agent-runnable. Reading code to build a theory before this command exists is the failure this skill prevents.
   - **One user affected, ten fine → probably data, not code.** Check time dependencies (scheduled jobs, timezone, cache expiry), the specific record's data, session/state (permissions, tenant, feature flags) while building the loop.
   - **Performance regression ("slow", "timeout", "spinning") → measure before you hypothesise.** Logs are usually silent or misleading on *why* something is slow. Build the loop as a baseline measurement instead: a timing harness (`performance.now()` / `microtime(true)` around the suspect call), a profiler run, or `EXPLAIN`/query plan for a DB-bound symptom. Once you have a number, bisect against it (old vs new commit/config, or cut load one piece at a time) the same way as any other loop — the number is the red/green signal, not a stack trace.
   - Cannot build a loop at all → say so, list what you tried, and ask the user for the environment, a redacted artifact (HAR, log dump, recording), or permission for temporary instrumentation. Do not proceed to a hypothesis without a loop.
   - **Minimise.** Once red, cut inputs, callers, config, data and steps **one at a time**, re-running the loop after each cut, until every remaining element is load-bearing (removing any one makes it go green). The minimal repro shrinks the hypothesis space in Phase 3 and becomes the regression test in Phase 4.
3. **Check recent changes.** `git log --oneline -20`, `git diff HEAD~5`. For regressions, bisect:
   ```bash
   git bisect start && git bisect bad && git bisect good <last-good-tag>
   # test each suggested commit, mark good/bad, then: git bisect reset
   ```
4. **Localize the failing layer** — identify it BEFORE investigating it. Gather evidence at component boundaries (what enters, what exits):

   | Layer | How to check |
   |---|---|
   | Frontend/UI | Browser console (F12) — ReferenceError, TypeError, broken rendering |
   | API/Network | Network tab / curl → status code, response body |
   | Backend entry point (controller/handler) | Log by correlation ID; syntax check the file |
   | Service / data-access layer | Stack trace in log, query params, transaction state |
   | Database | Slow query log, missing data, schema mismatch, locks |
   | External service (API, queue, mail) | Timeout, invalid response, credential expiry |
   | The test itself | Is the test correct? False negative? |

5. **Reduce to the minimal case.** Strip unrelated code/data; simplest input that still fails; isolate the component (entry point? service? repository? query?).
6. **Trace data flow backward.** Where does the bad value originate? Follow it up to the source. The fix belongs at the source, not at the symptom.

### Phase 2 — Pattern Analysis

1. **Find a working example** in the same codebase — what similar thing already works?
2. **Compare against a reference.** Read the reference completely (framework API, pattern doc). Every line.
3. **List every difference** between working and broken. However small. "That can't matter" is where bugs hide.
4. **Understand dependencies.** What config, env vars, schema assumptions? What differs between the working and broken environments?

### Phase 3 — Hypothesis & Testing

1. **Rank 3–5 falsifiable hypotheses before testing any** — a single hypothesis anchors on the first plausible idea. Each states its prediction: *"If X is the cause, then <changing Y> makes the loop go green / <changing Z> makes it worse."* No prediction → not a hypothesis; discard or sharpen. Show the ranked list to the user when they are present (they re-rank instantly: "we deployed #3 yesterday"); do not block on it when they are away. Then take them **one at a time**, top-ranked first: *"I think X is the root cause because Y (evidence from Phase 1/2)."*
2. **Write the disproof first.** Name the ONE measurement that would show X is NOT the cause — typically the layer above/below the code you are staring at (interceptor/middleware, FK `ON DELETE` action, a catch one frame down, a suite that never collects the file). Run it before anything else. Two measured premises + one unmeasured link is the shape of every false root cause in the 2026-08-29/30 wave.
3. **Test it minimally.** Smallest change that confirms or denies. **One variable at a time.**
4. **Verify before continuing:**
   - Confirmed → Phase 4
   - Wrong → new hypothesis from new evidence. Don't stack fixes.
5. **Say "I don't understand X"** when true. Don't hand-wave.
6. **Report MEASURED vs INFERRED.** Every load-bearing sentence in the diagnosis carries the command / file:line that produced it, or is labelled INFERRED. An INFERRED link never sits under a CONFIRMED root cause.

### Phase 4 — Fix, Guard, Verify

1. **Write a failing regression test** (see `test-driven-development`) from the minimised repro, **at a seam that exercises the real bug pattern** — the call chain that triggered it, not a shallower unit that cannot. It MUST fail without the fix, pass with it, and describe the scenario that caused the bug. **No correct seam exists → that is itself a finding:** the architecture prevents locking the bug down; record it in the report and the troubleshooting doc instead of writing a test that gives false confidence.
   - Every temporary debug log carries one unique tag, e.g. `[DEBUG-a4f2]`; cleanup at the end is `grep -rn 'DEBUG-a4f2'` — untagged logs survive into commits.
2. **Implement ONE fix at the root cause.** No bundled refactoring, no "while I'm here" improvements.

   ```
   ❌ try/catch that swallows the error
   ❌ null check without understanding WHY it's null
   ❌ raising a timeout without checking what is slow
   ✅ find WHY the value is null and fix the source
   ✅ optimize the slow query instead of raising the timeout
   ```
3. **Verify end-to-end:** new test passes → run the affected suites with the project's test commands (`phpunit`, `pytest`, `vitest`/`npm test`) → syntax/lint check modified files (`php -l`, `node --check`, `python -m py_compile`) → **re-run the Phase 1 loop on the original, un-minimised scenario** → `grep` the debug tag returns nothing → the confirmed hypothesis is stated in the commit message so the next debugger learns.
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

- "That's probably unrelated" → prove it: `git stash` — does the bug disappear?
- "I'll fix it later" → you won't. Fix it now.
- "It's an edge case, nobody will hit it" → the log says otherwise.

---

## When Investigation Reveals "No Root Cause"

Occasionally the issue is truly environmental / timing-dependent / external:

1. Document what you investigated
2. Implement appropriate handling: retry, timeout, error message, circuit breaker
3. Add logging so next time you *can* investigate
4. Tell the user: "no deterministic root cause, here's the mitigation"

**~95% of "no root cause" conclusions are incomplete investigation.** Don't bail out early.

---

## Universal Failure Patterns

Recurring bug classes that transcend any single project. Check the matching class before deep-diving:

| Symptom | Root-cause class | Where to look |
|---|---|---|
| `TypeError` at a data boundary (string expected, int/null given) | Strict typing meets untyped source — DB, JSON, env var feeding typed code without cast/default | Cast at the boundary; audit every consumer of that column/field |
| Works in dev, `ReferenceError`/undefined symbol in prod build | Build/bundle changes symbol visibility — implicit globals, tree-shaking, minification | Make cross-file references explicit (e.g. `window.fn = fn`); grep ALL usages |
| Page/endpoint suddenly slow, timeouts | N+1 queries, missing index, unbounded result set | Count queries per request; `EXPLAIN` the slow one |
| 403/401 on a new endpoint that "should work" | One more permission registry than you registered — whitelist, ACL table, route guard, middleware config | Find ALL registries an existing working endpoint is in; diff against yours |
| Data written but UI/consumers don't see the change | Change-detection relies on a timestamp/version column your write didn't touch | Update the tracking column in every write path |
| Works locally, fails in CI/prod | Environment drift — filesystem case sensitivity, timezone, locale, missing extension, different DB version | Diff the environments, not the code |
| Pipeline green, behavior broken | Fail-handler exits 0 (`die("msg")`, swallowed exception, missing `set -e`) — failures never reach the exit code | Make every failure path produce a non-zero exit / thrown exception |

For project-specific instances of these classes, check the project's troubleshooting doc (Step 0.4).

---

## Toolbox

```bash
php -l file.php / node --check file.js / python -m py_compile file.py   # syntax
phpunit --filter test_name / pytest -k name / vitest run -t 'name'      # one test, fast
git blame <file>                              # who touched it last
git log --oneline <last-good-tag>..HEAD       # what changed since it worked
```
```sql
EXPLAIN SELECT ...;  SHOW INDEX FROM <table>;  SHOW PROCESSLIST;
```
```javascript
debugger;  console.table(rows);  console.time('op'); /*...*/ console.timeEnd('op');
```

---

## Quick Checklist — When Stuck

- [ ] Read the FULL error message? (not just the first line)
- [ ] Got ONE command that goes red on this bug, already run, minimised to load-bearing elements?
- [ ] Read the logs? (app, framework, web-server/container)
- [ ] Checked the project's troubleshooting doc / closed issues for the keyword?
- [ ] Checked what changed recently? (`git log --oneline -10`)
- [ ] Tried the simplest input?
- [ ] Checked the data in the DB? (data, not code, may be the problem)
- [ ] Checked types? (int vs string, null vs empty)
- [ ] Checked permissions? (every whitelist/registry/guard on the path)
- [ ] Cleared caches? (browser, opcode, CDN, app cache)

---

## After the Fix — Document

For non-obvious problems (surprising cause, project-specific pattern — not typos):
update the project's troubleshooting doc (e.g. `docs/troubleshooting.md`) with symptom → cause → fix, following the project's documentation rules. The regression test is already written — that was Phase 4 step 1.

---

## Quick Reference — Phase exit criteria

| Phase | Done when |
|---|---|
| 1. Root cause | A red-capable loop command exists and was run, the repro is minimal, and you understand *what* is wrong and *why* |
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
