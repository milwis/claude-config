---
name: task-lifecycle
description: "Use when implementing a complete feature, bugfix, or issue end-to-end with minimal supervision — the full autonomous cycle: build (subagent) → code review loop with auto-fix (cap 3) → security pass → e2e verification (verify-e2e, fresh subagent) → report package for the user. The main session acts as ORCHESTRATOR and never writes code itself. Input: a spec or issue. Output: reviewed, verified change + evidence, ready for the user's merge/push decision."
---

# Task Lifecycle (orchestrated build → review → fix → verify → report)

**Core:** The main session coordinates; ALL substantive work happens in subagents. The user reviews the final package (diff + evidence + open items), not the process. Every loop has a hard cap.

**Announce at start:** "I'm using the task-lifecycle skill."

---

## Pipeline overview

```
INPUT: spec / issue / user request
  │
  ├─ 0. Intake: classify size, pick branch strategy
  ├─ 1. BUILD        — builder subagent(s)          [via executing-plans for planned work]
  ├─ 2. REVIEW LOOP  — code-reviewer subagent
  │       findings CRITICAL/HIGH/MEDIUM → builder subagent fixes → re-review
  │       repeat ≤ 3×; LOW / uncertain → collect for report, do NOT auto-fix
  ├─ 3. SECURITY     — backend-security-coder subagent (only if triggers match)
  ├─ 4. VERIFY       — verify-e2e skill in a FRESH subagent
  │       FAIL → fix via builder → re-verify (≤ 3×); BLOCKED → record gap, report
  └─ 5. REPORT       — one package: what/why, review iterations, evidence, open items
OUTPUT: verified change on a branch + evidence — user decides merge/push/deploy
```

---

## Step 0: Intake

1. Restate the task in 1-2 sentences; if the spec is ambiguous on something that changes the implementation, ask now — never mid-pipeline.
2. Classify size:
   - **Trivial** (copy, CSS, config, docs) — skip to Step 1, DIRECT edit allowed (per `executing-plans` DIRECT rules), then jump to Step 4.
   - **Small** (single coherent fix, expected diff < 30 lines, ≤ 2 files, NOT touching money/VAT, auth/permissions, or regulated data) — one builder subagent, then ONE review pass (no loop; findings fixed once, no re-review unless CRITICAL). Skip Step 3. Step 4 only if a user-facing surface changed. This class exists to stop 8-line fixes from paying the full-pipeline cost.
   - **Standard** (single feature/bugfix, one coherent change) — Step 1 with one builder subagent.
   - **Large** (multi-task, 3+ modules, needs design) — route through `brainstorming` → `writingplans` → `executing-plans` for the build; this skill then owns Steps 2-5 on the combined result.
3. **Task context block (mandatory for Standard/Large):** at intake write a short context block — target files, canonical paths/services for any variant work, decisions already made, hard constraints ("do NOT touch X"). Paste it into EVERY subagent prompt in this lifecycle. Before each review iteration, append the previous iteration's findings + what was changed — reviewer N must know what reviewer N-1 found. Subagents rediscovering the project from scratch is both the main token cost and a source of contradictory decisions.
4. **Branch strategy:** if the project deploys from its main branch (deploy gate on push), create a feature branch first — `agent/<slug>` or `agent/issue-<n>`. Autonomous work must never have a direct path to production. Merge/push to main is ALWAYS the user's decision.

## Step 1: Build (in a subagent)

- Select the builder per the `executing-plans` agent table (php-pro / javascript-pro / sql-pro / backend-security-coder / ...). When unsure → specialist agent, not DIRECT.
- The builder prompt is self-contained: task block, exact files, acceptance criteria, canon references for variant paths, "do NOT touch X" where relevant.
- Discipline skills apply inside the builder: `test-driven-development` for new behavior, `systematic-debugging` on failures.
- The builder returns: files changed, tests added/updated, verification commands it ran. Confirm with `git diff --stat` — a builder's success report is not evidence (`verification-before-completion`).

## Step 2: Review loop (cap 3)

1. Dispatch `code-reviewer` subagent on the diff:
   - diff **< 100 lines** → standard-depth review;
   - diff **≥ 100 lines** → thorough review (all 7 axes, tests first).
2. Split findings by severity:
   - **CRITICAL / HIGH / MEDIUM** → dispatch a builder subagent with the findings **verbatim** (file:line, description, suggested direction). Then re-review the touched areas.
   - **LOW / stylistic / uncertain ("plausible")** → collect for the final report. Do not auto-fix, do not silently drop.
3. Repeat review→fix up to **2 iterations** (3 for Large tasks). Cap exhausted → STOP; report remaining findings and why they persist. Never loop indefinitely, never merge review debt silently.
4. **Test-run economy inside the loop:** builders run TARGETED tests ONLY (`--filter` / single file / directory matching their diff) — a builder NEVER runs the full suite. The FULL suite runs exactly once — at the final gate before the report, executed by the orchestrator or delegated to the reviewer alongside the final code review — and its result is reported with BOTH counts (passed AND skipped, with the skip reason). Re-running the full suite after every fix is waste, not rigor.

## Step 3: Security pass (conditional)

Trigger when the change touches: auth/session, input parsing, SQL, file upload/download, payments/money, secrets/config, permissions/groups, external API surface.
→ Dispatch `backend-security-coder` for a focused review of the touched paths. CRITICAL/HIGH findings feed back into the Step 2 fix loop (shares the same 3-iteration cap; if the cap is exhausted, security findings go to the user as blockers — security debt is never silently carried).

## Step 4: Verify (fresh subagent — anti-cheating gate)

Run the **`verify-e2e`** skill: fresh isolated subagent, adversarial prompt, evidence artifacts (screenshots / HTTP dumps / recordings).

- **PASS** → proceed to report with evidence paths.
- **FAIL** → repro steps go to a builder subagent; re-verify with a NEW fresh verifier. Cap 3 verify-fix cycles.
- **BLOCKED** (missing env: account, key, tool) → record the gap in `docs/VERIFICATION_ENV.md`, mark the task "verified: NO (blocked on X)" in the report. A blocked verification is a first-class result, not a footnote.

## Step 5: Report package

The ONLY thing the user needs to read. Structure:

```
## <Task title> — ready for review
**What changed & why:** 2-4 sentences.
**Branch / commits:** agent/<slug>, N commits, diff stat.
**Review:** X iteration(s); fixed: <counts by severity>; remaining (not auto-fixed): <LOW/uncertain list or "none">.
**Security pass:** run/skipped (+why) ; findings summary.
**Verification:** PASS/FAIL/BLOCKED + evidence paths (screenshots/recording/responses).
**Open items / blockers:** anything needing a human decision.
**Your move:** e.g. "review evidence → merge PR" / "provide X to unblock verification".
```

Never merge, push to the deploy branch, or deploy — present the package and stop.

---

## Hard rules

1. **Orchestrator writes no code.** Every implementation and fix goes through a subagent (trivial DIRECT edits from Step 0 are the only exception).
2. **Caps are absolute:** 3 review-fix iterations, 3 verify-fix cycles. Exhausted cap → stop and report, never widen scope to "make it pass".
3. **Fresh context for verification.** The verifier never shares context with any builder.
4. **Evidence or it didn't happen** — `verification-before-completion` governs every claim in the report.
5. **Manual step spotted twice → automate it.** If the user has to correct or remind you about a step of this lifecycle, propose adding it to this skill / project CLAUDE.md immediately.

---

## Integration

- `brainstorming` / `writingplans` / `executing-plans` — the build stage for large tasks.
- `code-reviewer`, `backend-security-coder` — review stages.
- `verify-e2e` — verification stage (Step 4).
- `issue-pipeline` — runs one task-lifecycle per issue for batch work.
- `test-driven-development`, `systematic-debugging`, `verification-before-completion` — active inside every subagent.
