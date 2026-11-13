---
name: refaktor
description: "Use when the owner asks to refactor a file (a god-file) end to end: this session orchestrates — it launches a scenarios session, then a refactor session under /goal, checks the 1:1 proof itself and merges only after it. Usage: /refaktor <file> [spec]."
---

# Refaktor — one orchestrator, two working sessions, proof before merge

Owner decision 2026-11-13: as simple as possible. The owner starts ONE session (Opus or Fable) with
`/refaktor <file> [spec]`. That session is the **orchestrator**: it writes no production code. It launches a
scenarios session, then a refactor session with `/goal`, checks the result with its own commands, and merges
only after proof that the old and the new code behave identically in every respect.

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

`K=~/Programowanie/KonkretnyTMS`. Other projects: replace these four lines.

- rig: `$K/.claude/tmp/stanowisko-slot.sh <abs tree> --plik=<file> --stary=<ref> --nowy=<ref> --etap=<name>`
  (calibration: `--stary=<S> --nowy=<S> --kalibracja`; code 7 = template DB lacks migrations → rebuild it with
  `tests/rownowaznosc/przygotuj-wzorzec.sh`). One run at a time; the slot queues.
- suite: `$K/.claude/tmp/phpunit-slot.sh <abs tree>` → prints `names=<file>` (red test names).
- standard (Spec §1): `php vendor/bin/phpunit --filter GutschriftModuleStandardLatchTest` and
  `php -d register_argc_argv=On vendor/bin/phpstan analyse -c phpstan-modul-<module>.neon --memory-limit=1G`.
- the rig's files per class: `tests/rownowaznosc/{karta,inwentarz,scenariusze,maska}/<Class>.json`;
  the worked example is `GutschriftDocumentController`.
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
- `git -C <wt> diff --stat $OLD..$S -- . ':!tests/rownowaznosc'` → empty (only the measure changed);
- calibration `--stary=$S --nowy=$S --kalibracja` → `Werdykt: IDENTYCZNY`, exit 0, coverage gate passed;
- baseline: the suite on `$S` → keep the `names=` file as `$K/.claude/tmp/refaktor/$k/tlo.names`.
Fail → send the evidence back to `scen-$k`, repeat 3. Pass → `hc kill scen-$k`.

**4. Refactor session.** Spec = section **Spec** below, plus the owner's text when given (the owner's text wins
where they differ). Write `brief-refaktor.md` (template B, the Spec copied in full), launch session `ref-$k` with
template B's goal line. Wait for its SendMessage.

**5. Proof (you, never the session's word).** `F=<branch HEAD>`, tree clean. Run the rig from YOUR OWN worktree
checked out at `$S` (`git -C $K worktree add --detach $K/.claude/worktrees/refaktor-$k-kontrola $S`), so the
measure's tools are the ones the session never touched:
1. rig `--stary=$S --nowy=$F` → `IDENTYCZNY` on every channel (status, body, headers, database, SQL, logs,
   files), exit 0, coverage gate passed, positive control (mutants) detected; no `--tylko`/`--kalibracja`/
   skipped control;
2. `git diff --stat $S..$F -- tests/rownowaznosc` → empty. Existing tests changed or deleted
   (`git diff --diff-filter=MD --stat $S..$F -- tests`) only by re-pointing to the moved code, by the module
   registration (Spec §4), or by removing tests of proven dead code; the list goes to the reviewer (point R7);
3. the suite on `$F` → red names = `tlo.names` (`comm`), nothing new;
4. the Spec measured by you on `$F`: the module's standard latch and its PHPStan config at level max → 0
   violations, 0 errors (Spec §1, project commands); every module file within the limits;
5. every old-code bug the session reported has its issue (`gh issue view <n>`), or the reason it has none;
6. a fresh `code-reviewer` (Agent tool): the Spec, `git diff $S..$F`, the rig verdict, and the checklist
   `roadmapa/references/recenzja-refaktoru.md` — every point. 0 open REQUIRED.
Any failure → the evidence goes to `ref-$k` (SendMessage: "popraw, potem pokaż znowu trzy sprawdzenia"),
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

## Template A — `brief-scenariusze.md` and its goal

Goal line (the session's first prompt, ≤ 4000 chars):

```
/goal Zadanie z pliku <abs brief-scenariusze.md> zrobione: w tej rozmowie widać, dla obecnego HEAD i czystego drzewa,
(1) kalibrację `<rig> --plik=<file> --stary=HEAD --nowy=HEAD --kalibracja --etap=scen-<k>` z „Werdykt: IDENTYCZNY”, kodem 0 i
bramką pokrycia „przechodzi”; (2) `git diff --stat <OLD>..HEAD -- . ':!tests/rownowaznosc'` pusty; (3) wysłany SendMessage
z raportem do „<orchestrator>”. Albo minęło 40 tur — wtedy raport, czego brakuje.
```

Brief body: the file and the class; the rig's four files for the class (`karta`, `inwentarz`, `scenariusze`,
`maska`) on the pattern of `GutschriftDocumentController`; every public action of the file reached through HTTP
(routes, roles, success and every refusal), each scenario with `oczekuj`; coverage ≥ the karta's threshold, every
uncovered range justified only from the allowed categories; change nothing outside `tests/rownowaznosc/`; commit
after every green step; no push, no merge; report ≤ 15 lines (SHA, scenarios, coverage, calibration).

## Template B — `brief-refaktor.md` and its goal

```
/goal Zadanie z pliku <abs brief-refaktor.md> zrobione: w tej rozmowie widać, dla obecnego HEAD i czystego drzewa,
(1) `<rig> --plik=<file> --stary=<S> --nowy=HEAD --etap=ref-<k>` z „Werdykt: IDENTYCZNY”, kodem 0, bramką pokrycia „przechodzi”
i wykrytą kontrolą dodatnią; (2) pełną suitę przez `<suite>` ze zbiorem czerwonych nazw równym <tlo.names> (pokaż `comm`);
(3) `git diff --stat <S>..HEAD -- tests/rownowaznosc` pusty; (4) zapadkę standardu i PHPStan modułu na level max:
0 naruszeń, 0 błędów; (5) wysłany SendMessage z raportem do „<orchestrator>”. Albo minęło 40 tur — wtedy raport,
czego brakuje.
```

Brief body: the Spec in full, then the target map (what moves where; the orchestrator's proposal from reading the
file, the session may change it with a reason); refactor first, then the rig; while iterating use fast checks (the
file's tests, a PHPUnit filter, the standard latch), the full rig and suite for the final check; on a difference
fix the production code, never the measure; existing tests only re-pointed (assertions unchanged); a bug in the
OLD code → keep the old behaviour and create the issue (Spec §5); commit after every green step; no push, no
merge; report ≤ 15 lines (SHA, rig verdict, suite, standard and PHPStan, issues created, open questions).
