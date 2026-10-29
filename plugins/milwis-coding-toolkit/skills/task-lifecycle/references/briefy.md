# Subagent briefs

A subagent knows only its brief. A skill named in the brief does not load in a subagent (E29), and a rule left out
of the brief is not applied (E16). So every rule a subagent must follow is written into the brief as text. A line
that cannot be filled is written as `skipped: <reason>`, never left out. `E<n>` points to `evidence.md`.

## Every brief

- **`name:` and `model:` explicit.** Reviewers use `opus`; the verifier, `Explore` and `builder` use `sonnet`.
- **The task context block** from intake, with the findings of earlier rounds appended.
- **Facts measured in this turn**, each with the command that produced it. A wrong number in a brief is an anchor
  the subagent pays to unlearn (E4).
- **Questions are two-sided:** "establish whether X or not-X, and name what decides it", never "check whether X".
  A question shaped as a confirmation gets a false thesis confirmed while the disproof sits in the subagent's own
  context (E8).
- **Where the report goes:** the absolute path of the file to write the full report to. The final message carries
  only the first line and that path.
- **The report contract**, pasted as text from `implementacja.md` §Report contract, with the first-line tokens for
  this agent's role.
- **The classifier-safe block**, pasted as text (E15):
  > Copy with `cat <file> > .claude/tmp/<name>`, never `cp`. Restore with `cat .claude/tmp/<name> > <file>` and
  > confirm with `diff`; never `git checkout --` or `git restore`. No `rm` outside `.claude/tmp/`. No `mv` of a
  > tracked or generated file.

## Explore (a sweep or a broad search)

- `Explore`, `sonnet`, a budget of ≤ 20 tool calls.
- One two-sided question, and the paths or naming conventions to cover.
- "Report hits as `path:line` with one line each. Do not fix, do not dig past the hit." (E2)

## Builder (an independent sizeable task)

Use one only for work that shares no file, symbol or decision with what this session is writing. The builder ends
its turn after the report. Review fixes on its part are made by this session, which has the diff and the report.
Before the spawn, check that the brief carries each of these lines:

1. The task context block, and the exact files.
2. The numbered items the report will walk as `DONE <path:line>` / `SKIPPED <reason>` (E17).
3. The call budget.
4. The write-first line: "the first edit lands before the third file you open beyond the ones named here; commit
   in stages; a stop for context is legitimate only after the relay hook's own-window message (`RELAY_SUB_WARN`),
   quoted verbatim in the report, never on your own estimate" (E6).
5. The discipline lines:
   - a new behaviour gets a test seen red first;
   - a root cause at `file:line` comes before a fix;
   - three failed fixes of one defect mean `ambiguous. ask:` with the attempts listed;
   - only the requested migration stage, never Contract implicitly.
6. For every "copy pattern X": the latch of X, and the rule that the copy gets its own latch (E7).
7. For a latch or a test:
   - the property list;
   - the mutant-table rule;
   - "a mutant is executed, never narrated; one failed fit of the probe script, then an ad-hoc harness" (E9, E10).
8. The docblock cap with its scope: production code and single test methods are capped at 10 lines, and the
   derivation goes into the test file's header. Add the path of a template test when the repo has one of the
   kind (E11, E12).
9. For a live-DB test: the own-fixture rule and the project's test-corpus latch filter (E13).
10. The targeted-test rule: a whole-tree `git grep -l` of the changed symbols, plus each group the diff calls for:
    - the corpus-latch filter;
    - the counter-latch filter with "ratchet down in the same commit";
    - the generator command with "regenerate in the same commit".

    And: "never the full suite" (E24).
11. Precedent: "a decision the repo already documents is yours to take; cite it" (E14).
12. The docs line, with the project's doc map when there is one: a doc made stale is updated in the same commit,
    or the report says `docs: none stale` with the check.
13. The report contract and the classifier-safe block (above).

**When the report arrives:**
- confirm with `git diff --stat`, because the builder's report is not evidence;
- re-run every number that goes into the report, the ledger or the next brief, or write it as `reported` (E18);
- an item missing from the report counts as SKIPPED, and a SKIPPED item without a reason sends the report back;
- "context exhausted" with zero lines of code and no hook message is not resumed (E27). Its MEASURED findings
  become anchors in a fresh brief that starts with "start by writing" (E6).

## Review (fresh `code-reviewer`, `opus`)

0. **Spec:** the issue number or the plan/task file, with "read it yourself before my notes: it is the spec, my
   summary and decisions are claims to check". The reviewer judges the diff against the spec, not against your
   restatement of it; a reviewer framed by the implementer inherits the implementer's blind spot.
1. **Scope:**
   - `git diff --stat <base>...<tip>` and the tip SHA;
   - the stat, not a tier: the reviewer sizes itself, and a sensitive path (money/VAT/auth, migrations, CI,
     manifests) lifts the tier on its side;
   - the changed paths on the project's own sensitive list (the queue: `wrazliwe:` globs, printed by `reguly.sh`),
     named as sensitive: the reviewer cannot know that list otherwise.

   Never ask a small diff for a "thorough" review.
2. **Rules:**
   - the project's rules files whose `paths:` match the diff (the queue: `reguly.sh`);
   - "read each before judging the lines it covers" (E29).
3. **Security:** when the diff touches a Step 3 trigger, name the trigger and the touched entry points. Security is
   part of this review.
4. **What to report:** every finding with its severity. Never ask for only the high-severity ones: filtering
   happens on this side, by severity.
5. **Header lines:** `Otwarte: <n> CRITICAL, <m> REQUIRED`, counting every CRITICAL and REQUIRED finding,
   PLAUSIBLE ones included; then `Domknięcie: <a> mutant, <b> docs` when there is no CRITICAL and every REQUIRED
   closes by a test (a `Mutant-plik` / `Mutant-przed` / `Mutant-po` record each) or by docs alone. The queue adds
   the `SHA:` and `Tier:` lines (`roadmapa/references/cykl-lidera.md`).
6. **Round 2 and later — the delta only (E31):**
   - the previous findings verbatim and numbered, and what was changed for each;
   - `git diff --stat <previous tip>..<tip>`, the previous tip, and the output of
     `scripts/nowe-warunki.sh <worktree> <previous tip>` with the mutant row or the reason for each line;
   - the instruction: "review `<previous tip>..<tip>`; close each previous finding by its number, one line each
     (`F<n>: closed | open — <path:line or command>`); size your tier from this delta's stat (a sensitive path
     still lifts it); do not re-review the untouched rest unless the delta reaches it". In a plan checkpoint the
     range is the group's fix range `<from>..<to>` (`executingplans` Step 4), not `..HEAD`.
7. **Small, the narrow form:**
   - the diff stat plus 3–4 two-sided questions specific to the change;
   - tier S, about 15 calls (E3).
8. **A test-only diff:**
   - the brief carries the property list;
   - the reviewer first checks the mutant table against that list: a property without a RED row is a finding;
   - then it re-runs one of the implementer's mutants, plus one control mutant of its own on a step the diff did
     not touch (a sibling branch, the neighbouring tree, the untouched leg of a guard);
   - it works on its own copy, never on the tracked file, and reports each as `mutant: RED|GREEN` with the
     command;
   - this report replaces Step 4.
9. **A plan checkpoint group (`executingplans` Step 4):**
   - the group's paths, with "review only these";
   - the contract files, with "read-only: judge the group against them";
   - the checkpoint's rules, with "one line per rule: `<rule>: kept | broken path:line`";
   - for `R-final`, every group report, with "already reviewed: do not repeat; look for what crosses groups".

## Verification (fresh `test-automator`, `sonnet`, `verify-e2e` brief)

- The `verify-e2e` Step 3 template with every line filled: a measurement from this turn or `skipped: <reason>`.
- **Entry point:** your own grep of the handler binding, so an unreachable path is scoped out before the spawn
  (E25).
- **In a worktree:** the surface is served from that worktree (its own port), and the verifier must show a
  discriminator, i.e. an observation that differs between the fixed tree and the unfixed one. An answer on some
  port proves only that a server is up.
- **Evidence:** files at the paths the brief names (screenshots, HTTP dumps, recordings). The first line is
  `VERDICT: PASS|FAIL|BLOCKED`.
- **After a FAIL:** the next verifier is new and gets the previous repro and what was changed.
