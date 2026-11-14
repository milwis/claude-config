---
name: refaktor
description: "Use when the owner asks to refactor a file (a god-file) end to end: this session orchestrates — it launches a scenarios session, then a refactor session under /goal, checks the 1:1 proof itself and merges only after it. Usage: /refaktor <file> [spec]."
---

# Refaktor — one orchestrator, two working sessions, proof before merge

Owner decision 2026-11-13: as simple as possible. The owner starts ONE session (Opus or Fable) with
`/refaktor <file> [spec]`. That session is the **orchestrator**: it writes no production code. It launches a
scenarios session, then a refactor session with `/goal`, checks the result with its own commands, and merges
only after proof that the old and the new code behave identically in every respect.

Owner's goal (2026-11-13): identical behaviour for **every input and every database state, including ones that
have not occurred yet**. A green run on the dev snapshot is not proof; section **Completeness** says what is.

## Who does what

| stage | how | model | effort |
|---|---|---|---|
| orchestrator | this session | Opus or Fable (owner's choice) | as started |
| 1. scenarios | separate session, `hc run` (visible in Herdr) | `opus` | `high` |
| 2. refactor | separate session, `hc run`, first prompt `/goal …` | `opus` | `high` |
| review | `Agent` tool, `subagent_type: code-reviewer` | the agent's own (`opus`) | — |
| checks | the orchestrator itself (Bash) | — | — |

`high`, not `xhigh`: measured on the queue (2026-09-25) — `xhigh` cost 2× with no gain, `medium` lost quality.
Fable orchestrates and audits; it does not write the refactor (2026-11-12 decision).

**Ledger.** Every session keeps its state in a file from its first turn (orchestrator
`$K/.claude/tmp/refaktor/$k/ledger.md`, sessions `ledger-scenariusze.md` / `ledger-refaktor.md` next to it):
decisions, SHAs, open questions, every number with the command that produced it. Compaction keeps only what
is written there (WDC: two compactions of the refactor session, saved by its notes file).

## Project commands and templates

- `references/projekt-konkretnytms.md` — rig, mutants, template DB, suite, standard, `scripts/usuniete-symbole.sh`,
  registry latches, commit mechanics, karta fields, `hc run` launch line. Read it at step 0; „project commands”
  below means this file. Another project: its own `references/projekt-<name>.md`.
- `references/szablony-briefow.md` — template A (scenarios) and template B (refactor): goal lines, turn limits,
  brief bodies. Read it at steps 2 and 4.

## Steps

**0. Start.** Read your own session name (`ListAgents`: "This session is …"); the working sessions report to it.
`C=<Class>` (file name without `.php`), `k=<c lowercased>`. Base branch `main_dev`, up to date, clean.
Refuse and tell the owner when: another live `refaktor-*` session touches the same paths, or the file is under
active work (open branch or session on it).
**Rig-fix gate.** List the open fixes of the rig and write them to the ledger, section `## Bramka stanowiska` —
it is the merge gate of step 6. Sources:
(a) open claude-config issues titled `procedura refaktoru`:
`gh issue list --repo milwis/claude-config --state open --search "procedura refaktoru in:title"`;
(b) unmerged KonkretnyTMS branches that change the measure: every local and `origin/` branch with commits outside
`main_dev` (`git -C $K log --oneline main_dev..<b>` non-empty) and a non-empty
`git -C $K diff --name-only main_dev...<b> -- tests/rownowaznosc`.
One line per item: issue/branch, its tip SHA, **blocking** or **not blocking**, and the reason. It blocks when it
changes the mechanism this class's proof uses (`stanowisko.sh`, `lib/`, verdict, coverage, control, database
observation, a channel the class produces) or this class's files; a branch touching only another class's
`karta/inwentarz/scenariusze/maska/mutanty` files does not. A non-blocking item stays listed with its reason.
A blocking item open → ask the owner: start now (step 5 runs again after it merges, ~1 h of rig and a review
round) or wait for it. A merge hold announced by another orchestrator goes to the same section.
**Reconnaissance (before brief A; each result goes to the ledger and the brief):**
- connections: every database the class and the services it calls read or write
  (`git grep -n -E 'DatabaseService|FMSDatabase|new PDO|getConnection' <file>`, then each service named) → the
  karta's `bazy_wtorne`; a connection the rig cannot observe → tell the owner before the start (a new rig
  capability, not a gap);
- the routes' middleware (`git grep -n <Class> -- php/routes`, then the middleware of each route group): session,
  roles, token headers, CSRF → brief A (scenario `naglowki`, refusal scenarios);
- the slot: `hc ls` and the rig/suite slot queue — who else uses it in the coming hours (repairs, procedure,
  another refactor); 2–3 refactors at once make the slot the bottleneck.

**1. Worktree.** `git -C $K worktree add $K/.claude/worktrees/refaktor-$k -b refaktor/$k main_dev`, copy `.env`.
`OLD=<that SHA>`. Template DB fresh (project commands) — stale → rebuild before launching `scen-$k`, never at the
first calibration. Open queue issues naming the file get `status:odlozone` + a comment "refaktor w toku".
**Working sessions build on the rig fixes in progress** that change the same area of the rig (blocking branches
of the gate): both briefs list them; the session merges each into its branch (`git merge --no-edit <branch>`,
never rebase), merges again after new commits on it, and its report gives each branch's merged SHA.
`main_dev` itself is merged into the scenarios branch ONCE, before the class mutants run (the mutants and the final
calibration then share one `S`), not after every move (WDC: 5 moves during the run).

**2. Scenarios session** — skip if `tests/rownowaznosc/karta/$C.json` exists and the calibration passes.
Write the brief to `$K/.claude/tmp/refaktor/$k/brief-scenariusze.md` (template A), launch session
`scen-$k` with the first prompt = template A's goal line. Wait for its SendMessage (do not poll).

**3. Check the scenarios (you).** `S=<branch HEAD>`. Your control worktree, from which you run every rig check
yourself: `git -C $K worktree add --detach $K/.claude/worktrees/refaktor-$k-kontrola $S` (later `git checkout --detach`).
- `git -C <wt> diff --stat $OLD..$S -- . ':!tests/rownowaznosc'` → empty (only the measure changed), except new
  test files named in the karta's `luki` (`git diff --diff-filter=A --name-only`; nothing modified or deleted) and
  files brought in by a merged rig-fix branch or by `main_dev` (the same change as `main_dev...<branch>`);
- calibration `--stary=$S --nowy=$S --kalibracja` from YOUR control worktree → `Werdykt: IDENTYCZNY`, exit 0,
  coverage gate passed; `wzorzec_sha256` = the ledger's;
- **databases:** read the file and its inventory yourself; every connection the class reads or writes (main DB,
  `WarsztatDatabaseService`, `FMSDatabase`, …) is observed by the rig (karta `bazy_wtorne`). One unobserved →
  the calibration is INVALID, whatever its verdict;
- **class mutants:** `mutanty/$C/` on `$S` → **N/N detected** (Completeness §2 rule, not exit 2 alone). You check
  the rig's artifacts, not the session's list: for every patch its run's `meta.json` (`stary` = `nowy` = `$S`,
  `mutant_b` = the patch's name, `stanowisko_zmiany_niezacommitowane` 0 — the patch came from the committed tree,
  `kod_wyjscia` 2) and `raport.md` (the differing scenario and path, classified by the
  rule); then re-run from your control worktree every SUSPECT and a sample of max(3, N/10) patches you choose.
  Until claude-config #76 this replaces N re-runs. Then read the file against the catalogue: a rule, condition,
  limit or side effect without a mutant → write the missing patches yourself and send them to `scen-$k` to
  cover; a surviving mutant → a missing scenario (never delete the mutant);
- **masks:** every `maska` rule names its phenomenon (column, header, channel) and why it is nondeterministic;
  a rule that would hide a behaviour difference is rejected;
- **input-class matrix** (from the session's brief report): every class of Completeness §1 has scenario names, or
  a reason it is unreachable through HTTP and CLI that you accept after reading the file;
- **gaps:** approve or reject every `luki` entry (Completeness §4);
- baseline: the suite on `$S` → keep the `names=` file as `$K/.claude/tmp/refaktor/$k/tlo.names`.
Fail → send the evidence back to `scen-$k`, repeat 3. Pass → the measure is **frozen** at this `S` (the proof's
`S`). `hc kill scen-$k` once `ref-$k` has reported its full rig run on this `S`: B-side keys it proposes (step 4)
still go through `scen-$k` as one more `S`. For that `S` step 3 repeats the diff check and the calibration, and
`git diff --name-only <S before> <S after> -- tests/rownowaznosc` lists only `uzasadnienia/$C.json` with keys only
added (no removed or changed line in its diff) — anything else is a new measure and step 3 runs in full.

**4. Refactor session — starts during step 2**, as soon as `scen-$k` reports the first green calibration (`S1`:
`IDENTYCZNY`, exit 0, coverage gate passed, diff outside the measure empty — your check). It does not wait for
the mutants (WDC: the code was ready when the mutants finished). Branch `refaktor/$k-kod` from `main_dev` in
worktree `$K/.claude/worktrees/refaktor-$k-kod`. The current `S` lives in `$K/.claude/tmp/refaktor/$k/S` (one SHA; you
rewrite it with every „S=” message) and the baseline in `tlo.names` next to it (written in step 3); template B's
goal reads both files when it is checked, never a SHA fixed at launch. Spec = section **Spec** below, plus the owner's text when given
(the owner's text wins where they differ). Write `brief-refaktor.md` (template B, the Spec copied in full),
launch session `ref-$k` with template B's goal line.
**Measure updates before the freeze.** Every scenarios commit `Sn` you checked (diff outside the measure empty)
goes to `ref-$k` as „S=<sha>”; it merges it (`git merge --no-ff`) and re-runs the rig on it. Between `S1` and the
freeze the measure only gains — scenarios, mutants, masks you reviewed — plus **B-side coverage keys**, the one
place where the measure follows the new code, under this rule: `ref-$k` writes proposals outside the measure to
`$K/.claude/tmp/refaktor/$k/uzasadnienia-po.json`, each with `z_klucza_A` (the A key it carries over 1:1);
you accept one only when that A key exists, the category is the same and the range is that code in its new
place; `scen-$k` commits the accepted ones as the next `Sn`. A new uncovered range without an A counterpart is
not allowed — `ref-$k` covers it in code or asks for a scenario. Wait for its SendMessage.

**5. Proof (you, never the session's word).** `F=<refaktor/$k-kod HEAD>`, tree clean. Three layers, in order —
cheap checks first, so an expensive run never starts on a version a cheap check would have sent back.
**The rig used = `tests/rownowaznosc` of the current `main_dev` tip** (plus the blocking rig-fix branches still
open, at their current tips). When they moved past `$S`: in the control worktree (step 3)
`git checkout --detach $S && git merge --no-edit main_dev <open blocking branches>` → the new `S`, the tree the rig
runs from. Every point below uses this `S`.

*(a) Cheap checks (you, minutes):*
1. `git merge-base --is-ancestor main_dev $F` → exit 0, and the same for every open blocking rig-fix branch —
   otherwise back to `ref-$k` (it merges and resolves on its branch) before anything else;
2. `git diff --stat $S..$F -- tests/rownowaznosc ':!tests/rownowaznosc/mutanty/'$C-po` → empty — the `-po`
   directory is the only allowed change to the measure, and only added files
   (`git diff --diff-filter=MDR --name-only $S..$F -- tests/rownowaznosc` → empty);
3. **mutant mapping 1:1:** `comm -3` of the file names in `mutanty/$C` and `mutanty/$C-po` → empty, the same
   `# scenariusze:` and `# kanal:` preamble in each pair; read every pair side by side (both patches): the same
   bug (same operator, same rule, same observable effect) in its new place, not an easier one. Doubt → back to
   `ref-$k`;
4. the refactor's own changes = `git diff main_dev $F -- . ':!tests/rownowaznosc'` (with point 1 true; `S..F` mixes in
   `main_dev`'s changes — WDC: 21 assertion lines came from #2134; the measure reaches `main_dev` only with this
   merge, so it is judged on `S..F` in point 2, never inside the own changes). Existing tests changed or deleted
   (`git diff --diff-filter=MD --stat main_dev $F -- tests ':!tests/rownowaznosc'`) only by re-pointing to the
   moved code, by the module registration (Spec §4), or by removing tests of proven dead code; the list goes to
   the reviewer (R7);
5. registry latches (project commands): `git diff main_dev $F -- <those files>` → only the module's entries in
   `MODULES`/`MODULES_FLOOR` and registration lists; a grown allow-list, ratchet or pin → back to `ref-$k`;
6. `usuniete-symbole.sh $S $F <file>` → every hit judged; a current-state reference → back to `ref-$k`;
7. the Spec measured by you on `$F`: the module's standard latch and its PHPStan config at level max → 0
   violations, 0 errors (Spec §1, project commands); every module file within the limits;
8. every old-code bug the session reported has its issue (`gh issue view <n>`), or the reason it has none.

*(b) Review:* a fresh `code-reviewer` (Agent tool): the Spec, the refactor's changes (a) 4, the
measure's changes `git diff $S..$F -- tests/rownowaznosc`, both mutant directories, the outputs of (a) 4–6, and the
checklist `roadmapa/references/recenzja-refaktoru.md` — every point. From round 2: the previous findings as a
list „verify by execution, not on the word” (WDC round 2: clock in 4 time zones, an S/F probe 56/56), two-sided
questions, and the round's delta next to the full scope. 0 open REQUIRED.

*(c) Rig and suite* — on the version (b) passed. With free slots (c) may run in parallel with (b) (a background
run costs no tokens; a REQUIRED finding throws it away); with a busy slot (b) first.
1. the `-po` patches taken from `$F`, not from a live worktree: `P=$K/.claude/tmp/refaktor/$k/po-$F; mkdir -p $P &&
   git -C $K archive $F tests/rownowaznosc/mutanty/$C-po | tar -x -C $P`; then
   rig `--stary=$S --nowy=$F --mutanty=$P/tests/rownowaznosc/mutanty/$C-po` → `IDENTYCZNY`
   on every channel (status, body, headers, database incl. `bazy_wtorne`, SQL, logs, files), exit 0, coverage
   gate passed, positive control **N/N** (`kontrola-dodatnia.json`: `mutantow` = N of `mutanty/$C`,
   `bledow` = 0, and every `<report>/kontrola-dodatnia/<n>/raport.md` DETECTED by the Completeness §2 rule — until
   claude-config #79 the rig counts any exit 2); no `--tylko`/`--kalibracja`/skipped control; `stanowisko_sha` from the run's `meta.json` =
   `$S` and `git merge-base --is-ancestor main_dev <stanowisko_sha>` → exit 0 (the rig contains the `main_dev`
   tip); the SHA and the `samotest` field go to the report, and `git rev-parse main_dev` at that moment goes to the
   ledger as `main_dev_dowodu`;
2. the suite on `$F` → red names = `tlo.names` (`comm`), nothing new; `tlo.names` measured on this `$S` (re-measure
   when `$S` changed since step 3).

Any failure → the evidence goes to `ref-$k` (SendMessage: "popraw, potem pokaż znowu sprawdzenia z celu"),
then repeat 5 from (a). After 3 failed rounds → stop and report to the owner.
**Proof carried over (documentation-only fix).** When the fix after a full proof on `F` changes only
documentation — `git diff --name-only $F $F2` lists only files under `docs/claude-reference/`,
`docs/architektura/` or `docs/dokumentacja programu/flows/`, each in the karta's `poza_pomiarem`, and
`git grep -n -F '<path>' $F2 -- php js apps views cron scripts` gives 0 for each (positive control: the same command
for a path the code does read gives ≥ 1) — the rig verdict, the suite and the review carry over from `F` to `F2` if: `php vendor/bin/phpunit tests/Static
tests/Config` passes on `F2` (documentation latches scan whole directories), (a) 6 is clean on `F2`, and you read
the fix yourself. The report names `F`
and `F2`. Anything else changed → full step 5.

**6. Merge — only after 5 passed in full.** Precondition: every **blocking** item of the ledger's rig-fix gate is
on `main_dev` (`git -C $K merge-base --is-ancestor <branch> main_dev` → exit 0, `gh issue view <n>` → CLOSED).
Then `refaktor/$k-kod` takes the current `main_dev` (`git merge --no-edit main_dev` on the branch, never rebase)
and step 5 is repeated IN FULL on the new SHAs, with the rig from the `main_dev` tip — unless the merge brought
only documentation allowed by the carry-over rule of step 5 (`git diff --name-only <F of the proof> <new F>`, with
all that rule's conditions on the new `F`) and `git diff <main_dev_dowodu>..main_dev -- tests/rownowaznosc` is
empty: then the proof stands, with its `stanowisko_sha` (both outputs in the ledger; R22 accepts this exception). A verdict obtained on an older rig
does not count. The only exception is the owner's explicit consent, written in the ledger and in the report.
Then `git -C $K merge --no-ff refaktor/$k-kod` on `main_dev` (the merge rule:
no exceptions for "harmless" differences). Push only on the owner's word.
**Before cleanup:** copy the final proof's `meta.json`, `raport.md` and `kontrola-dodatnia.json` to
`$K/.claude/tmp/refaktor/$k/dowod/` (the report directory lives in an ignored folder of the worktree and goes with
`git worktree remove`), and read each session's cost from its status line (`hc read --lines 5 <session>`) — gone
after `hc kill`. Then: `hc kill ref-$k`, remove the worktrees, drop `status:odlozone` from the deferred issues,
report to the owner (SHAs, `stanowisko_sha` of the final proof, the rig-fix gate — each item closed or the owner's
consent, rig verdict, suite, review rounds, old-code bugs reported by the session as separate issues, every
exception from this skill with its reason, totals: wall time from step 0 to the merge, each session's cost and
turns, review tokens).

**Several files (2–3).** One orchestrator may run steps 1–5 for up to 3 files whose paths do not overlap
(separate worktrees and sessions). The rig and the suite queue on their slots, so more than 3 costs more than it
gains. Merge one branch at a time; after each merge the others take `main_dev` (merge, not rebase) and repeat their
step 5.

## Spec — professional code (default; KonkretnyTMS: the Gutschrift standard)

The file becomes a module like Gutschrift: `docs/architektura/modul-gutschrift.md` is the worked example (map of
classes, façade, pattern), `.claude/rules/php-rules.md` §„Reużycie zamiast kopii” and §„Moduły ze standardem”
are the rules. Behaviour stays 1:1 — every point below gives way to that.

1. **Size and shape** — measured by `tests/Static/GutschriftModuleStandardLatchTest.php` (its definitions):
   every file ≤ **300 SLOC** (lines with code, without comments and blank lines) and ≤ **800 lines**; method
   ≤ 40 SLOC; cyclomatic complexity ≤ 10; ≤ 5 parameters; nesting ≤ 3; `declare(strict_types=1)`, `final`
   classes, `readonly` properties; PHPStan **level max** on the module, no baseline, no `ignoreErrors`.
2. **Structure.** The controller is a thin façade: permission and HTTP method, input read and cast, one call of
   one use case; no PDO, no repositories, no domain rules. A write action = `UseCase/<Name>`, a read =
   `Query/<Name>`, each with one public `execute()`. A rule without database and request → a rules class (pure
   functions). SQL only in repositories. Refusals = one exception type mapped to the response in one place
   (`GutschriftActionRejected` + `runAction()`). Services: no superglobals, no output. A god-service keeps its
   public methods for outside callers (thin delegation) unless re-pointing the callers is mechanical. All new
   code lives under the directories of the karta's `pliki_modulu`; touching routes or repositories outside the
   module needs the karta to foresee it before the proof's `S` (otherwise the rig reports INVALID).
3. **Clean code.**
   - **Duplication:** one rule in one place. Duplicates inside the file are merged. Before writing a helper,
     `git grep` 2–3 distinctive fragments (constant, message, pattern); an existing one elsewhere is reused, not
     copied — only when the rig stays IDENTYCZNY. Twins that behave differently stay as they are and become an
     issue (point 5).
   - **Dead code** is removed only with proof: 0 callers in `php js apps views cron scripts tests` and routes,
     with a positive control. "Not covered" is not proof.
   - **Comments** say why, not what. No history: issue numbers, dates, "previously", "now", "extracted from".
     Historical knowledge from old comments moves to `docs/claude-reference/incydenty/<module>.md`.
   - Names say what a thing does; no new behaviour, no fixes "while here", no unused parameters or imports.
4. **Module registration** (part of the refactor, same branch): `docs/architektura/modul-<module>.md` on the
   Gutschrift document's pattern; an entry in `MODULES` and `MODULES_FLOOR` of the standard latch and in the
   list in `php-rules.md`; `phpstan-modul-<module>.neon` and its CI step in `.github/workflows/tests.yml`;
   documentation per `CLAUDE.md` §4 (the file's flow in `flows/`, `09b-god-objects.md`); every mention of a
   removed or moved method in documentation of the current state re-pointed (`usuniete-symbole.sh`).
5. **Bugs found in the old code** are NOT fixed (the merge rule: 1:1). Each gets a GitHub issue in the program's
   repo (KonkretnyTMS: `milwis/KonkretnyTMS`) through skill `nowe-issue` — consequence line, `POMIAR` from the old
   SHA, labels — created by the refactor session; a repeat of a known class → a comment on the class issue. The
   report lists the numbers.
6. **Tests and latches of the module.** Every new class gets its test in the same commit that extracts it — the
   class-inventory pin is never raised. Tests use their own fixtures (written in a transaction rolled back in
   `tearDown`), never rows that happen to exist in the dev database; skip only when the database is unreachable.
   Control question before the commit: what is left of this test on an empty database built from the schema (CI)?
   A registry latch (project commands) that goes red after the extraction means the module is not done: time
   read → inject the clock; untested-classes pin → tests; allow-lists and ratchets change only through the
   module's `MODULES`/`MODULES_FLOOR` entries, anything else is a question to the orchestrator first.

## Completeness — inputs that can exist, not only those that do

The scenarios prove 1:1 only for the inputs and states they run. Line coverage counts a line run once with one
input as covered; its boundaries are not. So the scenarios session covers classes of input, and mutants of this
class prove that the scenarios would see a change.

1. **Input classes (mandatory).** For every action and every public helper in the inventory (a helper called only
   from other classes is reached through the caller's route), one scenario per class:
   - boundaries of every constant and limit in the file: the value, value−1, value+1 (lengths, digit counts,
     amount thresholds);
   - input types: string, int, float, bool, array (`x[]=`), null, `''`, only spaces, upper/lower case, unicode,
     input over the length limit, a negative number, `'0'`/`0`, `'12abc'`;
   - database states: no row, NULL in every nullable column the file reads, `decimal` values on a rounding
     boundary, an empty string in ENUM columns (the database runs without strict mode), dictionary values outside
     the canon, duplicates, an empty list;
   - settings and configuration the file reads (`settings`, env): every value that changes a branch, and absent;
   - every refusal: no session, every role without access, a read-only role, a wrong HTTP method, a missing or
     wrong token header the middleware requires, every error code and message in the file.
   Synthetic data goes into the scenario (`dane`, `przygotuj_sql`, `naglowki`) or the class's seed, independent
   of the dev snapshot. The brief report carries the matrix `class → scenario names`; a class without a scenario
   needs a reason (unreachable through HTTP and CLI).
2. **Class mutant catalogue (readiness criterion).** The scenarios session writes `mutanty/<C>/` (karta
   `mutanty`): at least one mutant per rule, condition, boundary and side effect of the file. Operators to cover:
   inverted condition; boundary ±1; changed constant; swapped HTTP code and message; removed type cast;
   `empty()` ↔ `=== null` ↔ `isset()`; swapped arguments; removed call with a side effect (write, log, mail);
   reordered writes; changed WHERE / ORDER BY / LIMIT; changed rounding; changed JSON flags; changed log channel
   or level. Each patch's preamble: `# scenariusze:` (the scenarios that reach the change AND the scenarios that
   prepare their state — a filter without its preparation gives code 9, not a result) and `# kanal:` (the
   difference path the change produces). **Detection rule:** a mutant is DETECTED only when its run (A=S,
   B=S+patch) has exit 2 and a difference in a scenario matching `# scenariusze:` on a path matching `# kanal:`
   that is not noise (`created_at`/`updated_at`, auto `.id`, timestamps on both sides, a pure reordering unless
   order is the patch's channel). Exit 2 without such a difference = SUSPECT → one repeat → still SUSPECT =
   survivor. Until claude-config #79 the rig does not apply this rule; you do (step 3 on the old code, step 5 (c) on the
`-po` reports). A survivor = a missing
   scenario: add the scenario, never delete the mutant. The default `mutanty/` directory (Gutschrift patches)
   measures nothing in another file and never counts as this class's control.
3. **Every database of the class observed.** The inventory lists every connection the class uses (e.g.
   `WarsztatDatabaseService`, `FMSDatabase`). The calibration is INVALID when the class reads or writes a
   database the rig does not observe (delta, SQL sequence, binlog). The mechanism: one mysqld instance per side,
   the second database from its own template, declared in karta `bazy_wtorne` (project commands).
4. **Known gaps (`luki`).** A karta entry `{"luka", "powod", "dowod"}` per limit of the measurement, approved by
   the orchestrator in step 3. Example: the clock is not frozen, so month/year boundaries are unreachable — allowed
   only when the file has no branch depending on such a boundary (proof: the lines read), or a separate unit test
   on the old code covers it and the refactor session re-points it to the new code. Gaps of the rig itself until
   the toolkit closes them: frozen clock per scenario (claude-config #74), differential input fuzzing per
   action with a fixed seed (claude-config #75), one-run positive control on the old code
   (claude-config #76), detection by channel (claude-config #79).
