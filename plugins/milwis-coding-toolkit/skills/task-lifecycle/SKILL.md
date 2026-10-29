---
name: task-lifecycle
description: "Use when implementing a feature, bugfix or issue end to end with little supervision, through a fresh review and a fresh verification to a report the user can merge from."
---

# Task Lifecycle

**Goal.** The change does what the spec asks and nothing it does not ask. Tests that can fail prove it. A fresh
reviewer leaves nothing CRITICAL or REQUIRED on the final commit, and the surface a user touches is verified. The
user gets one report to decide on. Merge, push and deploy are always the user's decision.

**This session implements.** Planning, implementation and testing share one context, so they stay in the session
that holds it. A chain of agents re-reads at every hand-off what the previous agent had already read (E29).
Subagents do four jobs only:
1. a broad search or a sweep: `Explore`;
2. the review: a fresh `code-reviewer`;
3. the verification: a fresh `test-automator` with a `verify-e2e` brief;
4. a sizeable task that is genuinely independent of the rest: `builder`.

Every `E<n>` points to the measurement behind a rule in `references/evidence.md`. Read it only when you question
or change a rule; the rule text alone binds.

## Limits

These hold even when everything else in this file has been summarised away.

- **Review rounds:** 2 for Standard and 3 for Large, never more than 3 (in a plan: per checkpoint group and for
  `R-final`, `executingplans` Step 4). Small gets one narrow pass and a
  re-review only for a CRITICAL finding. A review with a `Domknięcie:` line is closed by a tests/docs-only commit
  and its executed `Mutant-*` records, not by another round (Step 2).
- **Verification rounds:** 3.
- **One defect, three failed fixes:** stop and list the attempts. Outcome: `ambiguous. ask: <question>`.
- **A limit reached:** stop and report what remains and why it persists. Never widen the scope to make it pass,
  never carry review or security debt silently.
- **Never merge, push or deploy.** If the project's tracker uses a done label (e.g. "to be merged"), adding it is
  the only tracker write.

## Size classes

Classify at intake. Check the class again against the real diff before the review: a diff that touches money/VAT,
auth/permissions or regulated data is never Trivial or Small, whatever was predicted. When the project lists
sensitive paths (the queue's `## Bramka` section), those count too.

| class | what it is | review | verification |
|---|---|---|---|
| **Trivial** | copy, CSS, config, docs; or a test-only diff ≤ 10 lines proven by ONE executed mutation probe (RED/GREEN quoted). Without the probe it is Small (E1) | none | only if a surface changed |
| **Small** | one coherent fix, < 30 lines expected, ≤ 2 files, outside the sensitive areas | one NARROW pass (E3). When the project's own threshold (CLAUDE.md) exempts a diff this size from review, the self-audit checklist replaces it | only if a surface changed; a test-only diff, or ≤ 10 production lines, skips it |
| **Standard** | one coherent feature or fix | the loop, 2 rounds | Step 4 |
| **Large** | 3+ modules, needs design, or the project's decision tree asks for a written plan (> 3 implementation steps, a regulated or financial domain) | the loop, 3 rounds | Step 4 |

Large goes through `brainstorming`, then `writingplans`, then `executingplans` in this session. Only tasks that
are sizeable and share no file, symbol or decision with the rest go to a `builder`. This skill then owns Steps 2–5
on the combined result. When the plan's review checkpoints ran (`executingplans` Step 4), Step 2 here is the
plan's `R-final`: the whole branch, cross-group scope, with every group report attached.

## Hard rules

1. **Evidence or it did not happen.** `verification-before-completion` governs every claim. Every number in a
   report, a ledger or a brief comes from a command run in this session, quoted next to it. A number taken from a
   subagent's report is re-run first or written `reported` (E4, E18).
2. **Review and verification run in a fresh context, one agent per round, never resumed.** Each brief carries the
   task context, the previous round's findings and the current diff state (E27).
3. **Every spawn has an explicit `name:` and `model:`.** Reviewers use `opus`; the verifier, `Explore` and
   `builder` use `sonnet`. Subagents write long reports to the file the brief names. They follow the report
   contract in `references/briefy.md`, and a report that breaks it goes back.
4. **A skill does not reach a subagent by its name.** What a subagent must apply goes into its brief as lines
   (E16, E29).
5. **Use classifier-safe commands, in this session and in every brief** (E15):
   - copy with `cat <file> > .claude/tmp/<name>`, not `cp`;
   - restore with `cat .claude/tmp/<name> > <file>` plus `diff`, never `git checkout --` or `git restore`;
   - no `rm` outside `.claude/tmp/`;
   - no `mv` of a tracked or generated artefact.
6. **A manual step spotted twice gets automated.** A rule reported as broken a third time is a defect in the rule.
   Before calling it "an instance of an existing rule" again, compare what the verdict measured with what the rule
   says (`retro` Step 2). Then change the rule's mechanism: its scope, its check command, or a probe in the pipeline
   (E26). A new prose rule goes where it loads only when it applies: a path-tied rule goes into
   `.claude/rules/*.md` with `paths:`, not into `CLAUDE.md`.

## Step 0: Intake

1. **Restate the task** in 1–2 sentences. An ambiguity that changes the implementation is asked now, never
   mid-pipeline. When nobody is there to answer, the outcome is `ambiguous. ask:`.
2. **Classify the size** (table above).
3. **Write the task context block**, for Standard and Large, to `.claude/tmp/<task>/kontekst.md`:
   - target files;
   - canonical paths and services for any variant work;
   - decisions already taken;
   - hard constraints ("do NOT touch X").

   Every fact in it comes from a command run now (E4). It goes into every subagent brief. Before each review
   round, append that round's findings and what changed. Decisions that cross files land here too, so a
   compaction cannot lose them.
4. **Branch strategy.**
   - If the project deploys from its main branch, work on `agent/<slug>` or `agent/issue-<n>`.
   - Outside the main tree (the queue's worktree, parallel work), use the branch's own worktree with absolute
     paths everywhere. Apply the project's worktree checklist (`.env`, build flags, `node_modules`, tool binaries)
     before the first test run: a worktree without it gives a false baseline.

## Step 1: Implement

**Read `references/implementacja.md` before the first edit.** It holds the rules for whoever writes the code:
test first, root cause first, latches and their mutant tables, tests on a live database, the docblock cap,
targeted tests and the latches a symbol grep cannot find, generated artefacts, precedent, and the proof each kind
of fix needs. They bind this session. A `builder` gets them as lines of its brief (`references/briefy.md`).

- **Docs stay true.** A doc the change makes stale (flow, module doc, runbook, troubleshooting) is updated in the
  same commit as the code. The report lists the doc files, or says `docs: none stale` with the check that shows it.
- **Commit in stages.** A decision that crosses layers goes into a test, the commit message or the context block.
- **An issue too big for one run** is a `too-big. split: <n one-line tasks>` outcome, not a split by layer (E29).

## Step 2: Review loop

1. **Spawn a fresh `code-reviewer` on the committed diff.** The brief follows `references/briefy.md`:
   - the diff stat (the reviewer sizes itself; a sensitive path lifts its tier);
   - the project's rules files whose `paths:` match the diff, because a reviewer opens few files (E29);
   - the security triggers the diff touches (Step 3);
   - the context block.

   From round 2 on, it also carries the previous findings, the previous tip and the output of
   `scripts/nowe-warunki.sh <worktree> <previous tip>` (this skill's directory).
2. **Act on the findings by severity:**
   - **CRITICAL / REQUIRED:** fix them here, with the proof `references/implementacja.md` asks for each kind of
     fix. Every new guard, branch or log line (`scripts/nowe-warunki.sh` lists them) gets an executed mutant
     before the next round (E19). Then a fresh reviewer reviews the delta only: it closes each previous finding
     by its number and reviews every line of `<previous tip>..HEAD`, sized by that delta (`references/briefy.md`
     §Review 6, E31).
   - **A `Domknięcie:` line** (0 CRITICAL, every REQUIRED closable by a test or by docs): close them with commits
     that touch only tests and docs, adding assertions and never editing, removing or skipping one. Run each
     `Mutant-plik` / `Mutant-przed` / `Mutant-po` record against the tests you changed: RED with the mutant, GREEN
     restored, both quoted in the report. No further round; the queue's gate re-runs the records (E30).
   - **PLAUSIBLE** (a link in the chain is not measured): settle it first with a two-sided measurement ("X or
     not-X, and what decides it", E8). Only a measured finding gets fixed.
   - **OPTIONAL / NIT / FYI:** fix one only when the fix is small and proven the same way. Otherwise list it in
     the report. Never drop it.
3. **A test-only diff:** the reviewer re-runs one of your mutants plus a control mutant on a step the diff did not
   touch, on its own copy. Its report replaces Step 4.
4. **When the loop ends**, run the full suite once (`references/implementacja.md`, test economy). A red test
   that is not on the base branch is a finding of this change.

## Step 3: Security, inside the review

**Triggers:** the change touches auth or sessions, input parsing, SQL, file upload or download, payments or money,
secrets or config, permissions or groups, or an external API surface. The Step 2 reviewer covers security for a
triggered diff; its brief names the triggers and the touched entry points. No separate security agent runs here:
`backend-security-coder` serves `audit-360` and explicit security passes. Security findings share the loop and
its limit. A limit reached with a security finding open makes the finding a blocker for the user.

## Step 4: Verify (fresh subagent)

Run the `verify-e2e` skill:
- **who and how:** a fresh `test-automator` with an adversarial brief and evidence files (screenshots, HTTP
  dumps, recordings);
- **in a worktree:** the surface is served from that worktree, and the verifier shows a discriminator, i.e. an
  observation that differs between the fixed tree and the unfixed one;
- **the brief:** `verify-e2e` Step 3 with every line filled, by a measurement from this turn or
  `skipped: <reason>`. The `Entry point` line carries your own grep of the handler binding (E25).

**On the verdict:**
- **PASS:** go to the report with the evidence paths.
- **FAIL:** fix here, then a new verifier. When a gate needs the review and the verification on the same commit
  (the queue's `bramka.sh`), a fresh reviewer also reviews the fix.
- **BLOCKED** (account, key or tool missing): record the gap in `docs/VERIFICATION_ENV.md`. The report says
  "verified: NO (blocked on X)".

## Step 5: Report

The only thing the user reads:
```
## <Task title> — ready for review
**What changed & why:** 2-4 sentences.
**Branch / commits:** branch, tip SHA, N commits, diff stat.
**Review:** N round(s); fixed: <counts by severity>; remaining: <OPTIONAL/NIT/uncertain list or "none">.
**Security (in review):** covered / not triggered (+why); findings.
**Docs:** <files> or "none stale" (+ the check).
**Verification:** PASS/FAIL/BLOCKED + evidence paths.
**Decisions:** what you chose where the spec left room, and why.
**Open items / blockers:** anything needing a human decision.
**Your move:** e.g. "review evidence → merge" / "provide X to unblock verification".
```

## Integration

- `brainstorming`, `writingplans`, `executingplans`: the build stage for Large.
- `code-reviewer`: the review, security included.
- `verify-e2e`: the verification.
- `builder`: an independent sizeable task, briefed per `references/briefy.md`.
- `roadmapa`: the issue queue. Its lead runs this skill for one issue per session and merges through its gate.
- `nowe-issue`: issues sized for one run; a `too-big. split:` report goes there.
- `test-driven-development`, `systematic-debugging`, `migration`, `verification-before-completion`: this session
  applies them. In a subagent they act only through brief lines.
