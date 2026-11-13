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

## Project commands (KonkretnyTMS)

`K=~/Programowanie/KonkretnyTMS`. Other projects: replace this section.

- rig: `$K/.claude/tmp/stanowisko-slot.sh <abs tree> --plik=<file> --stary=<ref> --nowy=<ref> --etap=<name>`
  (calibration: `--stary=<S> --nowy=<S> --kalibracja`; code 7 = template DB lacks migrations → rebuild it with
  `tests/rownowaznosc/przygotuj-wzorzec.sh`). One run at a time; the slot queues.
- class mutants on the OLD code (A=S, B=S+patch), one run per patch — the rig refuses `--stary` = `--nowy`
  without `--kalibracja`/`--mutant-b` (L6c) and skips the positive control under `--kalibracja`:
  `<rig> --plik=<file> --stary=<S> --nowy=<S> --mutant-b=<abs patch> --tylko=<the patch's preamble regex>
  --bez-pokrycia --etap=mut-<k>-<n>` → exit **2** (RÓŻNICA) for every patch; any other exit = not detected.
- class mutants on the NEW code: the proof run takes `--mutanty=<abs dir>` (default `tests/rownowaznosc/mutanty/`
  holds the Gutschrift patches — never the proof for another class). Result: `<report>/kontrola-dodatnia.json`,
  `mutantow` = N, `bledow` = 0. A patch starts with `# scenariusze: <regex>` (the whole action family with its
  preparation); a patch that does not apply is red (L13), not skipped.
- synthetic data: a scenario's `dane` (request payload) and `przygotuj_sql` (state before the request), or the
  class's seed `tests/rownowaznosc/wzorzec/<Class>.sql` (fixed timestamps, no `NOW()`).
- suite: `$K/.claude/tmp/phpunit-slot.sh <abs tree>` → prints `names=<file>` (red test names).
- standard (Spec §1): `php vendor/bin/phpunit --filter GutschriftModuleStandardLatchTest` and
  `php -d register_argc_argv=On vendor/bin/phpstan analyse -c phpstan-modul-<module>.neon --memory-limit=1G`.
- the rig's files per class: `tests/rownowaznosc/{karta,inwentarz,scenariusze,maska}/<Class>.json`,
  `tests/rownowaznosc/mutanty/<Class>/` (old code) and `tests/rownowaznosc/mutanty/<Class>-po/` (new code);
  the worked example is `GutschriftDocumentController`.
- karta fields used by this skill (besides `plik`, `pliki_zapisu`, `pliki_modulu`, `prog_pokrycia_efektywnego`,
  `poza_pomiarem`, `uslugi_zewnetrzne`):
  - `mutanty` — the class's mutant directory relative to `tests/rownowaznosc` (`mutanty/<Class>`);
  - `bazy_wtorne` — every database the class uses besides the main one (e.g. `warsztatkonkret`); a non-empty
    list switches the rig to one mysqld instance per side, each with that database loaded from its own seed,
    and the SQL sequence and binlog delta cover both schemas;
  - `luki` — known measurement gaps approved in step 3 (section **Completeness**); the rig does not read it.
  TODO(claude-config): `mutanty` and `bazy_wtorne` are the names on branch `refaktor/warsztatdocumentcontroller`,
  not yet on `main_dev`; confirm them after its merge. Until then the `main_dev` rig ignores both fields
  (`lib/karta.php` skips unknown keys): a class with a second database cannot be calibrated there (Completeness §3),
  and the mutant directory goes through the flags above.
- launch a session (CLAUDE.md rule — every agent session through `hc run`):

  ```bash
  hc run --bg --outlive-parent --no-notify --name <n> --cwd <worktree> \
    env ENABLE_CLAUDEAI_MCP_SERVERS=false caffeinate -ims \
    claude --permission-mode auto --model opus --effort high -n "<n>" --remote-control "<n>" "<first prompt>"
  ```

## Steps

**0. Start.** Read your own session name (`ListAgents`: "This session is …"); the working sessions report to it.
`C=<Class>` (file name without `.php`), `k=<c lowercased>`. Base branch `main_dev`, up to date, clean.
Refuse and tell the owner when: another live `refaktor-*` session touches the same paths, or the file is under
active work (open branch or session on it).

**1. Worktree.** `git -C $K worktree add $K/.claude/worktrees/refaktor-$k -b refaktor/$k main_dev`, copy `.env`.
`OLD=<that SHA>`. Open queue issues naming the file get `status:odlozone` + a comment "refaktor w toku".

**2. Scenarios session** — skip if `tests/rownowaznosc/karta/$C.json` exists and the calibration passes.
Write the brief to `$K/.claude/tmp/refaktor/$k/brief-scenariusze.md` (template A), launch session
`scen-$k` with the first prompt = template A's goal line. Wait for its SendMessage (do not poll).

**3. Check the scenarios (you).** `S=<branch HEAD>`.
- `git -C <wt> diff --stat $OLD..$S -- . ':!tests/rownowaznosc'` → empty (only the measure changed), except new
  test files named in the karta's `luki` (`git diff --diff-filter=A --name-only`; nothing modified or deleted);
- calibration `--stary=$S --nowy=$S --kalibracja` → `Werdykt: IDENTYCZNY`, exit 0, coverage gate passed;
- **databases:** read the file and its inventory yourself; every connection the class reads or writes (main DB,
  `WarsztatDatabaseService`, `FMSDatabase`, …) is observed by the rig (karta `bazy_wtorne`). One unobserved →
  the calibration is INVALID, whatever its verdict;
- **class mutants:** `mutanty/$C/` on `$S`, one run per patch (project commands) → **N/N** exit 2. Then read the
  file against the catalogue: a rule, condition, limit or side effect without a mutant → write the missing
  patches yourself and send them to `scen-$k` to cover; a surviving mutant → a missing scenario (never delete
  the mutant);
- **input-class matrix** (from the session's brief report): every class of Completeness §1 has scenario names, or
  a reason it is unreachable through HTTP and CLI that you accept after reading the file;
- **gaps:** approve or reject every `luki` entry (Completeness §4);
- baseline: the suite on `$S` → keep the `names=` file as `$K/.claude/tmp/refaktor/$k/tlo.names`.
Fail → send the evidence back to `scen-$k`, repeat 3. Pass → `hc kill scen-$k`.

**4. Refactor session.** Spec = section **Spec** below, plus the owner's text when given (the owner's text wins
where they differ). Write `brief-refaktor.md` (template B, the Spec copied in full), launch session `ref-$k` with
template B's goal line. Wait for its SendMessage.

**5. Proof (you, never the session's word).** `F=<branch HEAD>`, tree clean. Run the rig from YOUR OWN worktree
checked out at `$S` (`git -C $K worktree add --detach $K/.claude/worktrees/refaktor-$k-kontrola $S`), so the
measure's tools are the ones the session never touched:
1. rig `--stary=$S --nowy=$F --mutanty=<abs ref-$k worktree>/tests/rownowaznosc/mutanty/$C-po` → `IDENTYCZNY`
   on every channel (status, body, headers, database incl. `bazy_wtorne`, SQL, logs, files), exit 0, coverage
   gate passed, positive control **N/N** (`kontrola-dodatnia.json`: `mutantow` = N of `mutanty/$C`,
   `bledow` = 0); no `--tylko`/`--kalibracja`/skipped control;
2. `git diff --stat $S..$F -- tests/rownowaznosc ':!tests/rownowaznosc/mutanty/'$C-po` → empty — the `-po`
   directory is the only allowed change to the measure, and only added files
   (`git diff --diff-filter=MDR --name-only $S..$F -- tests/rownowaznosc` → empty);
3. **mutant mapping 1:1:** `comm -3` of the file names in `mutanty/$C` and `mutanty/$C-po` → empty, the same
   `# scenariusze:` preamble in each pair; read every pair side by side (both patches): the same bug (same
   operator, same rule, same observable effect) in its new place, not an easier one. Doubt → back to `ref-$k`;
4. existing tests changed or deleted (`git diff --diff-filter=MD --stat $S..$F -- tests`) only by re-pointing to
   the moved code, by the module registration (Spec §4), or by removing tests of proven dead code; the list goes
   to the reviewer (point R7);
5. the suite on `$F` → red names = `tlo.names` (`comm`), nothing new;
6. the Spec measured by you on `$F`: the module's standard latch and its PHPStan config at level max → 0
   violations, 0 errors (Spec §1, project commands); every module file within the limits;
7. every old-code bug the session reported has its issue (`gh issue view <n>`), or the reason it has none;
8. a fresh `code-reviewer` (Agent tool): the Spec, `git diff $S..$F`, the rig verdict, both mutant directories,
   and the checklist `roadmapa/references/recenzja-refaktoru.md` — every point. 0 open REQUIRED.
Any failure → the evidence goes to `ref-$k` (SendMessage: "popraw, potem pokaż znowu sprawdzenia z celu"),
then repeat 5. After 3 failed rounds → stop and report to the owner.

**6. Merge — only after 5 passed in full.** `git -C $K merge --no-ff refaktor/$k` on `main_dev` (the merge rule:
no exceptions for "harmless" differences). Push only on the owner's word. Then: `hc kill ref-$k`, remove both
worktrees, drop `status:odlozone` from the deferred issues, report to the owner (SHAs, rig verdict, suite,
review, old-code bugs reported by the session as separate issues, cost from the session status lines).

**Several files (2–3).** One orchestrator may run steps 1–5 for up to 3 files whose paths do not overlap
(separate worktrees and sessions). The rig and the suite queue on their slots, so more than 3 costs more than it
gains. Merge one branch at a time; after each merge rebase the others on `main_dev` and repeat their step 5.

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
   public methods for outside callers (thin delegation) unless re-pointing the callers is mechanical.
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
   documentation per `CLAUDE.md` §4 (the file's flow in `flows/`, `09b-god-objects.md`).
5. **Bugs found in the old code** are NOT fixed (the merge rule: 1:1). Each gets a GitHub issue in the program's
   repo (KonkretnyTMS: `milwis/KonkretnyTMS`) through skill `nowe-issue` — consequence line, `POMIAR` from the old
   SHA, labels — created by the refactor session; a repeat of a known class → a comment on the class issue. The
   report lists the numbers.

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
   - every refusal: no session, every role without access, a read-only role, a wrong HTTP method, every error code
     and message in the file.
   Synthetic data goes into the scenario (`dane`, `przygotuj_sql`) or the class's seed, independent of the dev
   snapshot. The brief report carries the matrix `class → scenario names`; a class without a scenario needs a
   reason (unreachable through HTTP and CLI).
2. **Class mutant catalogue (readiness criterion).** The scenarios session writes `mutanty/<C>/` (karta
   `mutanty`): at least one mutant per rule, condition, boundary and side effect of the file. Operators to cover:
   inverted condition; boundary ±1; changed constant; swapped HTTP code and message; removed type cast;
   `empty()` ↔ `=== null` ↔ `isset()`; swapped arguments; removed call with a side effect (write, log, mail);
   reordered writes; changed WHERE / ORDER BY / LIMIT; changed rounding; changed JSON flags; changed log channel
   or level. Every mutant must give RÓŻNICA on the old code (A=S, B=S+patch). A surviving mutant = a missing
   scenario: add the scenario, never delete the mutant. The default `mutanty/` directory (Gutschrift patches)
   measures nothing in another file and never counts as this class's control.
3. **Every database of the class observed.** The inventory lists every connection the class uses (e.g.
   `WarsztatDatabaseService`, `FMSDatabase`). The calibration is INVALID when the class reads or writes a
   database the rig does not observe (delta, SQL sequence, binlog). The mechanism: one mysqld instance per side,
   the second database from its own seed, declared in karta `bazy_wtorne` (project commands).
4. **Known gaps (`luki`).** A karta entry `{"luka", "powod", "dowod"}` per limit of the measurement, approved by
   the orchestrator in step 3. Example: the clock is not frozen, so month/year boundaries are unreachable — allowed
   only when the file has no branch depending on such a boundary (proof: the lines read), or a separate unit test
   on the old code covers it and the refactor session re-points it to the new code. Gaps of the rig itself until
   the toolkit closes them: frozen clock per scenario (claude-config #74), differential input fuzzing per
   action with a fixed seed (claude-config #75), one-run positive control on the old code
   (claude-config #76).

## Template A — `brief-scenariusze.md` and its goal

Goal line (the session's first prompt, ≤ 4000 chars):

```
/goal Zadanie z pliku <abs brief-scenariusze.md> zrobione: w tej rozmowie widać, dla obecnego HEAD i czystego drzewa,
(1) kalibrację `<rig> --plik=<file> --stary=HEAD --nowy=HEAD --kalibracja --etap=scen-<k>` z „Werdykt: IDENTYCZNY”, kodem 0 i
bramką pokrycia „przechodzi”; (2) mutanty klasy N/N wykryte: dla każdej łatki z tests/rownowaznosc/mutanty/<C>/ przebieg
`<rig> --plik=<file> --stary=HEAD --nowy=HEAD --mutant-b=<łatka> --tylko=<regex z preambuły> --bez-pokrycia --etap=mut-<k>-<n>`
z kodem 2 (lista: łatka → kod), N ≥ liczba reguł, warunków, granic i efektów ubocznych pliku z briefu; (3) macierz
„klasa przypadku → scenariusze” z briefu kompletna (klasa bez scenariusza tylko z uzasadnieniem nieosiągalności);
(4) `git diff --stat <OLD>..HEAD -- . ':!tests/rownowaznosc'` pusty albo same nowe pliki testów z pola `luki` karty;
(5) wysłany SendMessage z raportem do „<orchestrator>”. Albo minęło 40 tur — wtedy raport, czego brakuje.
```

Brief body: the file and the class; the rig's four files for the class (`karta`, `inwentarz`, `scenariusze`,
`maska`) on the pattern of `GutschriftDocumentController`; every public action of the file reached through HTTP
(routes, roles, success and every refusal), each scenario with `oczekuj`; then section **Completeness** copied in
full — the input classes (§1) with synthetic data, the class mutant catalogue `mutanty/<C>/` and karta `mutanty`
(§2), every connection in the inventory and karta `bazy_wtorne` (§3), `luki` with reasons (§4); coverage ≥ the
karta's threshold, every uncovered range justified only from the allowed categories; change nothing outside
`tests/rownowaznosc/` except new characterization tests named in `luki`; commit after every green step; no push,
no merge; report ≤ 15 lines (SHA, scenarios, coverage, calibration, mutants N/N, the matrix file path, `luki`).
The matrix goes to `$K/.claude/tmp/refaktor/<k>/macierz.md`: `class → scenario ids`, one line per class.

## Template B — `brief-refaktor.md` and its goal

```
/goal Zadanie z pliku <abs brief-refaktor.md> zrobione: w tej rozmowie widać, dla obecnego HEAD i czystego drzewa,
(1) `<rig> --plik=<file> --stary=<S> --nowy=HEAD --mutanty=<abs worktree>/tests/rownowaznosc/mutanty/<C>-po --etap=ref-<k>`
z „Werdykt: IDENTYCZNY”, kodem 0, bramką pokrycia „przechodzi” i kontrolą dodatnią N/N (N = liczba łatek w mutanty/<C>/);
(2) pełną suitę przez `<suite>` ze zbiorem czerwonych nazw równym <tlo.names> (pokaż `comm`);
(3) `git diff --stat <S>..HEAD -- tests/rownowaznosc ':!tests/rownowaznosc/mutanty/<C>-po'` pusty, a `comm -3` nazw plików
mutanty/<C> i mutanty/<C>-po pusty; (4) zapadkę standardu i PHPStan modułu na level max:
0 naruszeń, 0 błędów; (5) wysłany SendMessage z raportem do „<orchestrator>”. Albo minęło 40 tur — wtedy raport,
czego brakuje.
```

Brief body: the Spec in full, then the target map (what moves where; the orchestrator's proposal from reading the
file, the session may change it with a reason); refactor first, then the rig; while iterating use fast checks (the
file's tests, a PHPUnit filter, the standard latch), the full rig and suite for the final check; on a difference
fix the production code, never the measure; **mutants after the refactor:** the old patches do not apply to the
new code, so every patch of `mutanty/<C>/` is re-made on the new code as the same bug in its new place, in
`mutanty/<C>-po/` under the same file name and with the same `# scenariusze:` preamble (mapping 1:1; the only
allowed change under `tests/rownowaznosc`; `mutanty/<C>/` itself stays untouched); a mutant that the new code
cannot express (its code is gone) is a question to the orchestrator, never a dropped file;
existing tests only re-pointed (assertions unchanged); a bug in the
OLD code → keep the old behaviour and create the issue (Spec §5); commit after every green step; no push, no
merge; report ≤ 15 lines (SHA, rig verdict, suite, standard and PHPStan, issues created, open questions).
