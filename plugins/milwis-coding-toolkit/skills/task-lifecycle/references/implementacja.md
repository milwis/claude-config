# Implementation rules

These rules are for whoever writes the code: the session running `task-lifecycle`, or a `builder` that gets them as
brief lines (`briefy.md`). `E<n>` points to `evidence.md`.

## Order of work

- **Write first.** The anchors from intake (`file:line`, counts, decisions taken) exist so the investigation is not
  repeated. The first edit lands before the third file opened beyond the ones the task names. Commit in stages.
  A stop "for context" is legitimate only after the harness's own warning about the window (a builder quotes the
  relay hook's `RELAY_SUB_WARN` verbatim), never on a self-estimate. A report with zero lines of code and "context
  exhausted" without that message breaks the contract (E6).
- **A sweep is not part of the implementation.** "Does this defect class occur elsewhere" is a separate `Explore`
  brief (sonnet, ≤ 20 calls, hits only) or one grep with the hits listed. A sweep inside the writing context
  produces spin-off findings in the most expensive context there is (E2). On Small, the implementation budget is
  about 50 tool calls.
- **Precedent decides.** When the standards, `incident-lessons`, a runbook or an existing migration already use the
  idiom (e.g. `SET FOREIGN_KEY_CHECKS=0/1` around an `ALTER` on a referenced column), apply it and cite the
  precedent. `ambiguous. ask:` is for no precedent or conflicting ones (E14).

## Discipline

- **New behaviour gets a test seen red first** (`test-driven-development`).
- **A failure gets its root cause at `file:line` before any fix** (`systematic-debugging`). Three failed fixes of
  one defect: stop with `ambiguous. ask:` listing the attempts.
- **A diff that changes a persisted or public shape** (schema, data, API, config, dependency major) does only the
  requested stage and never performs Contract implicitly (`migration`).
- **Copying pattern X copies the latch of X:** name the test that goes red when X is broken, and the copy gets its
  own latch (E7).

## Latches and mutants

- **A latch or test proves named properties.** The report carries a mutant table with one row per property:
  `property | mutant <sed> | expected RED | result | command`. A property without a row is SKIPPED and the report is
  incomplete. Mutants picked freely end up on the branch that already works (E9).
- **For a latch:**
  - lists sit in a frozen baseline compared by content;
  - thresholds are set per tree or unit;
  - every test has an input on which it can fail.
- **The mutant is executed, never narrated.** If the project's probe script (`scripts/mutation-probe.sh` or an
  equivalent) does not fit the file after one attempt, build an ad-hoc harness: a copy of the file plus
  `--bootstrap` / `-d` / an env override. A "would fail" row without the quoted red output is not a row (E10).
- **A copy of a test file used for a probe keeps the file's directory depth**
  (`.claude/tmp/<probe>/tests/<same subdirectories>/`). A test that resolves paths through `dirname(__DIR__, n)`
  goes red at the wrong depth for a reason unrelated to the mutant (E20).
- **A test against a live database asserts on rows it wrote itself:**
  - seed its own fixture, in a transaction with rollback or with the project's run marker;
  - no `markTestSkipped` or early return whose condition depends on the database contents;
  - skips are legitimate only for infrastructure (host unreachable, opt-in variable missing) (E13).

## Comments and docs in code

- **Docblocks are capped at 10 lines** in production code and on any single test method. The full derivation (the
  measured race, the counts behind a threshold, library line numbers, why the alternative fails, the mine for the
  next task) goes into the test file's header block: the class docblock, or the docblock of the constant it
  explains. That block has no cap and carries only commands with results, `file:line` anchors and named mines.
- **Check the cap where it applies:** the longest run of added comment lines in
  `git diff <base>..<tip> -- <production trees>`, and inside a test file from the first `function` onward. Never
  run the same check over the whole diff: it measures the header the rule points to (E11).
- **A test of a kind the repo already has once** (a real library in jsdom, a live-DB parity test, an A/B route test)
  starts from that existing test as the template (E12).

## Test economy

During the work, run TARGETED tests only. The targeted set is the union of four groups:
1. **Symbol references.** The tests that reference the changed symbols, found by `git grep -l '<class or method>'
   tests/` across the whole tests tree. Never "the directory that mirrors the source": a repository behaviour
   change breaks mocks in service and controller tests.
2. **Test-corpus latches**, when the diff adds, removes or changes a test file or a skip call. These are tests that
   read `tests/` as text: skip registries, raw-PDO budgets, shape scanners. They reference no symbol, so the grep
   cannot find them (E13).
3. **Counter latches**, when the diff adds or removes an artefact the project counts: a route, a controller method,
   an endpoint, a permission entry, a raw SQL call site. These are snapshot, budget and ratchet tests asserting
   `assertSame(<N>, …)`. A removal leaves them red until the constant is ratcheted DOWN in the same commit. An
   upward bump is a design question for the report and the reviewer, never automatic.
4. **Generated artefacts**, when the diff touches the source of one (a route inventory, an API listing, a schema
   dump, a permission-matrix document). Regenerate the artefact in the same commit with the project's generator
   and run its freshness latch. A pre-commit hook does not regenerate it.

Derive the latch lists once per project: from the test rules or the endpoint checklist, or from
`git grep -l 'ls-files\|glob(' tests/` and `git grep -lE 'BUDGET|Snapshot' tests/`. A latch class missed here
surfaces only in the full suite, as an extra fix and a second suite run (E24).

**The full suite runs exactly once**, at the end of the review loop. Report both counts, passed and skipped, with
the skip reason. On a shared dev database the suite is a shared resource: take the project's exclusive slot or lock,
and read the result from your own log path, not from "the newest log file". A red test that is not red on the base
branch is a finding of this change.

## Proof for a review fix

- **Every new guard, condition, branch or log line** that a fix adds to production code gets an executed mutant
  (`line | mutant <sed> | expected RED | result | command`), whether or not the finding named that line. Before
  the next review round, list the new lines with `scripts/nowe-warunki.sh <worktree> <previous tip>` (this
  skill's directory: added production lines with a condition, a branch, a guard or a log, as `path:line`). Each
  one gets a RED row, both legs of a guard and every entry point that reaches it, or a stated reason (equivalent
  mutant, log text only, covered by row X). A GREEN mutant is fixed before the review, not left to cost a review
  round (E19). The list goes into the next reviewer's brief.
- **A closure (`Domknięcie:` in the review):** the REQUIRED findings it covers are closed with tests and docs only,
  and each `Mutant-*` record is executed against the changed tests: the literal `Mutant-przed` replaced by
  `Mutant-po` on the tracked file (copy and restore with `cat`, then `diff`), RED quoted, GREEN after restore
  quoted. A record that stays GREEN means the test misses the property: fix the test, never the record (E30).
- **A test-only or docs-only fix** of ≤ 40 lines that copies a neighbouring pattern: proof is one mutation probe
  for a test, or `ls` / `git grep -nF` showing a corrected reference resolves (E20).
- **A comment-only fix up to 30 lines in any file**, where no code token changes: proof is `git diff -w --stat`
  plus the language's syntax check on each touched file (`php -l`, `node --check`, `python -m py_compile`, or the
  migration runner's dry parse) plus the targeted run. A project comment latch, when there is one, runs with
  them. A comment edit in an already-applied migration that the runner keys by file name changes no database; say
  so (E21).
- **A semantic fix of ≤ 10 lines** (a missing `TRIM()`, an unlatched guard member, one added assertion): a
  one-command mutation probe on a copy, quoting RED under the mutant, GREEN restored, and the targeted run (E22).
- **A larger fix or a new mechanism** gets the same proof as new code: a test seen red, a mutant table, and the
  targeted set.

## Report contract

It binds every subagent report and the session's own ledger lines.
1. **The first line is one token you can grep:**

   | who | first line |
   |---|---|
   | implementer | `done.` / `too-big. split: <n one-line tasks>` / `ambiguous. ask: <one question>` / `needs-confirm. op: <command>` / `regressed. revert <path:line>. cause: <fragment>` |
   | reviewer | `No issues.` or its verdict line |
   | verifier | `VERDICT: PASS \| FAIL \| BLOCKED` |
2. **Findings:**
   - each starts with `path:line`, symbols are backticked, and load-bearing claims are labelled MEASURED or
     INFERRED;
   - every count carries the command that produced it, in the same sentence;
   - every `0` carries its positive control;
   - a number taken from elsewhere is written `reported: <source>`;
   - a builder walks the brief's numbered items as `DONE <path:line>` / `SKIPPED <reason>`; a missing item counts
     as SKIPPED (E17).
3. **No narration of tool calls, no exploration story, no restating the brief.** The diff is the artefact; the
   report is the proof.
4. **Plain words and exact names.** No invented abbreviations (`cfg`, `impl`, `req`, `res`, `fn`, `auth`) and no
   arrow chains in prose.
5. **A redacted or replaced value** (host, mailbox, path, credential, key) appears only as a placeholder such as
   `<host>`, never the real value, not even in a before/after pair.

Security warnings and confirmations of irreversible actions are always written in full sentences. A report that
breaks rule 1 or 2 goes back for the contract.
