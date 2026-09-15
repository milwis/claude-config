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
  ├─ 1. BUILD        — builder subagent(s)          [via executingplans for planned work]
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
   - **Trivial** (copy, CSS, config, docs; **also a test-only diff ≤ 10 lines whose proof is a one-command mutation probe** — a new latch entry, a fixture row, a deleted tautological assertion) — skip to Step 1, DIRECT edit allowed (per `executingplans` DIRECT rules), then jump to Step 4. For the test-only case the DIRECT edit is legitimate ONLY with the mutation probe run and its RED/GREEN line quoted in the report; without the probe it is a Small task. MEASURED (KonkretnyTMS batch 2.3): a 2-line latch addition done inline with the probe cost ~2k tokens; the same work through a builder subagent costs a 40k spawn minimum.
   - **Small** (single coherent fix, expected diff < 30 lines, ≤ 2 files, NOT touching money/VAT, auth/permissions, or regulated data) — one builder subagent, then ONE review pass (no loop; findings fixed once, no re-review unless CRITICAL). Skip Step 3. Step 4 only if a user-facing surface changed. This class exists to stop 8-line fixes from paying the full-pipeline cost. If the project's own review threshold (CLAUDE.md) exempts a diff of this size outside sensitive modules from the reviewer agent, the builder's self-audit checklist replaces the review pass — the project rule wins over this generic one. **Small tasks whose diff is test-only, or whose production diff is ≤ 10 lines outside sensitive modules, skip Step 4 entirely:** the builder's self-audit plus the targeted run IS the verification, and a fresh verifier would re-derive the same two commands for a 30k spawn. Step 4 stays mandatory the moment a user-facing surface changes.
   - **Standard** (single feature/bugfix, one coherent change) — Step 1 with one builder subagent.
   - **Large** (multi-task, 3+ modules, needs design — or the project's own decision tree routes it to a written plan, e.g. more than 3 implementation steps, a regulated/financial domain) — route through `brainstorming` → `writingplans` → `executingplans` for the build; this skill then owns Steps 2-5 on the combined result.
3. **Task context block (mandatory for Standard/Large):** at intake write a short context block — target files, canonical paths/services for any variant work, decisions already made, hard constraints ("do NOT touch X"). Paste it into EVERY subagent prompt in this lifecycle. Before each review iteration, append the previous iteration's findings + what was changed — reviewer N must know what reviewer N-1 found. Subagents rediscovering the project from scratch is both the main token cost and a source of contradictory decisions.
4. **Branch strategy:** if the project deploys from its main branch (deploy gate on push), create a feature branch first — `agent/<slug>` or `agent/issue-<n>`. Autonomous work must never have a direct path to production. Merge/push to main is ALWAYS the user's decision. If this lifecycle runs in parallel with others (issue-pipeline), it runs in its OWN worktree — a branch cannot share a working tree with another branch — and every command in every subagent prompt uses absolute paths under that worktree (the session cwd stays in the main tree). Apply the project's worktree checklist (missing `.env`, build flags, `node_modules`, tool binaries) before the first test run — a worktree without it produces a false baseline.

## Step 1: Build (in a subagent)

- Select the builder per the `executingplans` agent table (php-pro / javascript-pro / sql-pro / backend-security-coder / ...). When unsure → specialist agent, not DIRECT.
- The builder prompt is self-contained: task block, exact files, acceptance criteria, canon references for variant paths, "do NOT touch X" where relevant — and, when this orchestrator is itself a named subagent, its agent name with the instruction to deliver the final report via `SendMessage` to that name (see hard rule 7). When the orchestrator is the top-level session, subagent reports arrive as task-notifications on their own — do not ask for SendMessage to a name that does not exist.
- Discipline skills apply inside the builder: `test-driven-development` for new behavior, `systematic-debugging` on failures.
- **Verification-type briefs are two-sided.** "Establish whether X or not-X, and name what decides it" — never "check whether X". A confirmation-shaped brief was measured (2026-08-29/30) to make a subagent confirm a false thesis while holding its disproof in its own context. Every subagent report labels load-bearing claims MEASURED (command / file:line) or INFERRED; the orchestrator treats an INFERRED link under a CONFIRMED claim as unverified.
- The builder returns: files changed, tests added/updated, verification commands it ran. Confirm with `git diff --stat` — a builder's success report is not evidence (`verification-before-completion`).

## Step 2: Review loop (cap 3)

1. Dispatch `code-reviewer` subagent on the diff:
   - diff **< 100 lines** → standard-depth review;
   - diff **≥ 100 lines** → thorough review (all 7 axes, tests first).
2. Split findings by severity:
   - **CRITICAL / HIGH / MEDIUM** → dispatch a **NEW** builder subagent (fresh context — never resume the builder that produced the diff; hard rule 6) with the task context block + the findings **verbatim** (file:line, description, suggested direction) + the reviewer's proposed diff when one was given + the proof required for each fix (which test/probe must turn RED→GREEN) + the current `git diff --stat`. The fix-up prompt also says what the fixer must NOT do: no reading files outside the listed findings, no re-review of the untouched rest of the diff, no "while I'm here" changes — a fixer that re-explores the module pays the builder's cost a second time. Then re-review the touched areas — the sign-off re-review is likewise a fresh reviewer fed the diff and the previous findings, not the previous reviewer resumed with its full exploration context.
   - A finding the reviewer labels PLAUSIBLE (chain has an unmeasured link) is NOT dispatched as a fix — it goes back as a two-sided brief ("establish whether X or not-X") and only a MEASURED result enters the fix loop.
   - **LOW / stylistic / uncertain ("plausible")** → collect for the final report. Do not auto-fix, do not silently drop.
5. **Test-only diffs (new latch, new fixtures, deleted assertions):** the reviewer's brief requires it to RE-RUN at least one of the builder's mutants AND one CONTROL mutant of its own choosing on its own copy of the file (never on the tracked file), and to report each as `mutant → RED/GREEN` with the command. That report REPLACES Step 4 — there is no user-facing surface to verify, and a fresh verifier would repeat the same probe for a full spawn. A review of a test-only diff that only reads the assertions is a review of prose, not of a latch.
3. Repeat review→fix up to **2 iterations** for Standard tasks, **3 for Large** — 3 is the absolute ceiling (hard rule 2), 2 is where a Standard task stops even if findings remain. Cap exhausted → STOP; report remaining findings and why they persist. Never loop indefinitely, never merge review debt silently.
4. **Test-run economy inside the loop:** builders run TARGETED tests ONLY (`--filter` / single file / directory matching their diff) — a builder NEVER runs the full suite. The FULL suite runs exactly once — at the final gate before the report, executed by the orchestrator or delegated to the reviewer alongside the final code review — and its result is reported with BOTH counts (passed AND skipped, with the skip reason). Re-running the full suite after every fix is waste, not rigor. On a shared dev database the full suite is a shared resource: when other lifecycles run in parallel, take the project's exclusive slot/lock for it (never run two full suites against one DB at once), and read the result from YOUR log path, not from "the newest log file" — a parallel run's log may be newer.

## Step 3: Security pass (conditional)

Trigger when the change touches: auth/session, input parsing, SQL, file upload/download, payments/money, secrets/config, permissions/groups, external API surface.
→ Dispatch `backend-security-coder` for a focused review of the touched paths. CRITICAL/HIGH findings feed back into the Step 2 fix loop (shares the same 3-iteration cap; if the cap is exhausted, security findings go to the user as blockers — security debt is never silently carried).

## Step 4: Verify (fresh subagent — anti-cheating gate)

Run the **`verify-e2e`** skill: fresh isolated subagent, adversarial prompt, evidence artifacts (screenshots / HTTP dumps / recordings). When the change lives in a worktree, the surface under test must be served FROM that worktree (per-worktree server port), and the verifier must show a **discriminator** — an observation that differs between the fixed tree and the unfixed one — because a server that answers on some port proves only that a server is up, not which tree executes.

- **PASS** → proceed to report with evidence paths.
- **FAIL** → repro steps go to a builder subagent; re-verify with a NEW fresh verifier. Cap 3 verify-fix cycles.
- **BLOCKED** (missing env: account, key, tool) → record the gap in `docs/VERIFICATION_ENV.md`, mark the task "verified: NO (blocked on X)" in the report. A blocked verification is a first-class result, not a footnote.

## Step 5: Report package

The ONLY thing the user needs to read. Structure:

```
## <Task title> — ready for review
**What changed & why:** 2-4 sentences.
**Branch / commits:** agent/<slug>, tip SHA, N commits, diff stat (the SHA is what the user merges — without it the report is not actionable).
**Review:** X iteration(s); fixed: <counts by severity>; remaining (not auto-fixed): <LOW/uncertain list or "none">.
**Security pass:** run/skipped (+why) ; findings summary.
**Verification:** PASS/FAIL/BLOCKED + evidence paths (screenshots/recording/responses).
**Open items / blockers:** anything needing a human decision.
**Your move:** e.g. "review evidence → merge PR" / "provide X to unblock verification".
```

Never merge, push to the deploy branch, or deploy — present the package and stop. If the project uses a done-label on the tracker (e.g. "to be merged"), add it to the issue at this point — it is the only tracker write allowed, and without it the next wave re-triages the issue from scratch.

---

## Hard rules

1. **Orchestrator writes no code.** Every implementation and fix goes through a subagent (trivial DIRECT edits from Step 0 are the only exception).
2. **Caps are absolute:** review-fix iterations 2 (Standard) / 3 (Large) — never more than 3; verify-fix cycles 3. Exhausted cap → stop and report, never widen scope to "make it pass".
3. **Fresh context for verification.** The verifier never shares context with any builder.
4. **Evidence or it didn't happen** — `verification-before-completion` governs every claim in the report.
5. **Manual step spotted twice → automate it.** If the user has to correct or remind you about a step of this lifecycle, propose adding it to this skill / project CLAUDE.md immediately.
6. **One agent per unit of work — a finished agent is never resumed for the next unit.** Build, each review-fix iteration, each re-review, each security re-check and each verify run is its own fresh subagent whose prompt carries the task context block, the previous findings and the current diff state; the report of the previous agent is the compression point (200k of exploration → 2k of findings), so resuming carries ballast instead of trimming it. MEASURED (2026-09-13, batch of 5 issues, 32 subagents, 503M cache-read tokens): the builder resumed for three review iterations cost 94M input tokens over 497 turns and finally overflowed its context mid-iteration; the fresh builder spawned to finish that same iteration did more work for 24M. Resuming a 240k-context reviewer for a 15-tool-call sign-off cost ~25M; a fresh diff-only reviewer would cost ~3M. A resumed agent pays its whole accumulated context on every turn.
7. **Every subagent reports by `SendMessage` to the orchestrator BY NAME.** Spawn subagents with an explicit `name:`, put the orchestrator's own agent name in their prompt, and require the final report to be sent to it. MEASURED (same batch): task-notifications of subagents spawned by a nested orchestrator landed with the top-level session, not the spawner — every builder report had to be relayed by hand, doubling the reading and stalling one issue for 3 h. Agents whose `tools:` list is restricted must include `SendMessage`. Spawn every subagent with an explicit `model:` as well (project policy: writers `sonnet`, reviewers `opus`) — the agent registry loads at session start and can be stale. Exception: when the orchestrator is the top-level session (no agent name), reports arrive as task-notifications and no SendMessage target is given.

---

## Integration

- `brainstorming` / `writingplans` / `executingplans` — the build stage for large tasks.
- `code-reviewer`, `backend-security-coder` — review stages.
- `verify-e2e` — verification stage (Step 4).
- `issue-pipeline` — runs one task-lifecycle per issue for batch work.
- `test-driven-development`, `systematic-debugging`, `verification-before-completion` — active inside every subagent.
