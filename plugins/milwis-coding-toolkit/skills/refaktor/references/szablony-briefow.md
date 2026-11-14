# Brief templates — scenarios (A) and refactor (B)

Read by the `refaktor` orchestrator at steps 2 and 4. `<rig>` (with `--wzorzec`), `<suite>` and the script paths
come from `references/projekt-<project>.md`; `<abs plik S>` = `$K/.claude/tmp/refaktor/<k>/S`; sections **Spec** and **Completeness** come from `SKILL.md`.

## Template A — `brief-scenariusze.md` and its goal

Turn limit `<TA>` = 40 + 6 × the number of routes in the inventory (WDC: 27 routes and a second database used
200 turns).

Goal line (the session's first prompt, ≤ 4000 chars):

```
/goal Zadanie z pliku <abs brief-scenariusze.md> zrobione: w tej rozmowie widać, dla obecnego HEAD i czystego drzewa,
(1) kalibrację `<rig> --plik=<file> --stary=HEAD --nowy=HEAD --kalibracja --etap=scen-<k>` z „Werdykt: IDENTYCZNY”, kodem 0 i
bramką pokrycia „przechodzi”; (2) mutanty klasy N/N WYKRYTE (po scaleniu main_dev; mutanty i kalibracja z punktu 1 na tym samym HEAD) według reguły z briefu (kod 2 i różnica w scenariuszu z
`# scenariusze:` na ścieżce z `# kanal:`, nie szum): dla każdej łatki z tests/rownowaznosc/mutanty/<C>/ przebieg
`<rig> --plik=<file> --stary=HEAD --nowy=HEAD --mutant-b=<łatka> --tylko=<regex z preambuły> --bez-pokrycia --etap=mut-<k>-<n>`,
lista „łatka → kod → scenariusz i ścieżka różnicy”, `meta.json` i `raport.md` każdego przebiegu w <abs katalog>/mutanty-logi/,
N ≥ <liczba z briefu: reguły, warunki, granice i efekty uboczne pliku>; (3) macierz „klasa przypadku → scenariusze” z briefu
kompletna (klasa bez scenariusza tylko z uzasadnieniem nieosiągalności); (4) `git diff --stat <OLD>..HEAD -- . ':!tests/rownowaznosc'`
pusty albo same nowe pliki testów z pola `luki` karty i zmiany z main_dev/gałęzi poprawek; (5) wysłany SendMessage z raportem
do „<orchestrator>”; po pierwszej zielonej kalibracji osobny SendMessage „S1=<sha>”. Albo minęło <TA> tur — wtedy raport,
czego brakuje.
```

Brief body: the file and the class; your list of the file's rules, conditions, boundaries and side effects with
their count (the N of goal point 2); the reconnaissance from step 0 (connections, middleware, template DB path and
`sha256`); the rig's four files for the class (`karta`, `inwentarz`, `scenariusze`, `maska`) on the pattern of
`GutschriftDocumentController` / `WarsztatDocumentController`; the karta from the start with `poza_pomiarem`
entries for `phpstan-modul-<module>.neon` and `phpstan-baseline.neon` (module name from the target map),
`bazy_wtorne` and `mutanty`; the seed picks accounts and groups by login/name, never by id; every public action
of the file reached through HTTP (routes, roles, the middleware's headers, success and every refusal), each
scenario with `oczekuj`; masks by phenomenon (column/table), each with its reason; then section **Completeness**
copied in full — the input classes (§1) with synthetic data, the class mutant catalogue `mutanty/<C>/` with both
preamble lines and the detection rule (§2), every connection in the inventory and karta `bazy_wtorne` (§3),
`luki` with reasons (§4); before a batch of mutants one run without a patch (A only) per distinct preamble →
IDENTYCZNY (a preamble missing its preparation gives code 9); mutants in batches of ~10 under one slot lock;
coverage ≥ the karta's threshold, every uncovered range justified only from the allowed categories; change
nothing outside `tests/rownowaznosc/` except new characterization tests named in `luki`; merge the blocking
rig-fix branches the brief lists (Step 1) and `main_dev` once, before the mutant runs — order: merge `main_dev` →
mutants → final calibration, all on one `S`; patches passed from the committed tree; commit after every
green step; keep the ledger `ledger-scenariusze.md`; every number in a report with the command that produced it,
never from memory; no push, no other merge; report ≤ 15 lines (SHA, scenarios, coverage, calibration, mutants
N/N with the SUSPECT ones, the matrix file path, `luki`, merged rig-fix branches with their SHAs).
The matrix goes to `$K/.claude/tmp/refaktor/<k>/macierz.md`: `class → scenario ids`, one line per class.

## Template B — `brief-refaktor.md` and its goal

Turn limit `<TB>` = 40 + 3 × the number of routes (WDC: 27 routes used 120).

```
/goal Zadanie z pliku <abs brief-refaktor.md> zrobione: w tej rozmowie widać, dla obecnego HEAD i czystego drzewa,
(0) `git merge-base --is-ancestor main_dev HEAD` z kodem 0 (main_dev scalony PRZED punktami 1 i 2) oraz
`git merge-base --is-ancestor $(cat <abs plik S>) HEAD` z kodem 0 — S zawsze czytane z <abs plik S> w chwili sprawdzenia;
(1) `<rig> --plik=<file> --stary=<S z pliku> --nowy=HEAD --mutanty=<abs worktree>/tests/rownowaznosc/mutanty/<C>-po --etap=ref-<k>`
z „Werdykt: IDENTYCZNY”, kodem 0, bramką pokrycia „przechodzi” i kontrolą dodatnią N/N (N = liczba łatek w mutanty/<C>/);
(2) pełną suitę przez `<suite>` ze zbiorem czerwonych nazw równym <abs tlo.names> (pokaż `comm`; plik pisze orkiestrator w kroku 3);
(3) `git diff --stat <S z pliku>..HEAD -- tests/rownowaznosc ':!tests/rownowaznosc/mutanty/<C>-po'` pusty, a `comm -3` nazw plików
mutanty/<C> i mutanty/<C>-po pusty; (4) zapadkę standardu i PHPStan modułu na level max: 0 naruszeń, 0 błędów;
(5) `usuniete-symbole.sh <S z pliku> HEAD <file>` z oceną każdego trafienia (historia zostaje, stan bieżący poprawiony);
(6) wysłany SendMessage z raportem do „<orchestrator>”. Albo minęło <TB> tur — wtedy raport, czego brakuje.
```

Brief body: the Spec in full, then the target map (what moves where; the orchestrator's proposal from reading the
file, the session may change it with a reason); refactor first, then the rig; while iterating use fast checks (the
file's tests, a PHPUnit filter, the standard latch), the full rig and suite for the final check — the chain
„merge `main_dev` → commit → rig → suite” only after every fix and after the last `S` (a moved HEAD or `S` aborts
a running rig); on a difference fix the production code, never the measure; the measure arrives as „S=<sha>”
messages and is merged as it comes (`git merge --no-ff`), the session never edits it; a B-side uncovered range is
covered in code, or proposed in `uzasadnienia-po.json` with `z_klucza_A` (step 4 rule) — never added to the
measure by the session; **mutants after the refactor:** the old patches do not apply to the new code, so every
patch of `mutanty/<C>/` is re-made on the new code as the same bug in its new place, in `mutanty/<C>-po/` under
the same file name and with the same `# scenariusze:` and `# kanal:` preamble (mapping 1:1; the only allowed
change under `tests/rownowaznosc`; `mutanty/<C>/` itself stays untouched); when the measure's preamble changes,
the same change goes to `-po`; after a code fix check every `-po` patch with `git apply --check`; a mutant that
the new code cannot express (its code is gone) is a question to the orchestrator, never a dropped file;
existing tests only re-pointed (assertions unchanged); Spec §6 — tests of every new class with the extraction,
own fixtures, the registry latches (project commands) run when the module is extracted, not first in the full
suite; commits per project commands (09a/09b after `git add`, baseline after deleted code, quoted paths); a bug
in the OLD code → keep the old behaviour and create the issue (Spec §5); merge the blocking rig-fix branches the
brief lists (Step 1); commit after every green step; keep the ledger `ledger-refaktor.md`; every number in a
report with its command; no push, no other merge; report ≤ 15 lines (SHA, rig verdict, suite, standard and
PHPStan, `usuniete-symbole.sh` result, issues created, merged rig-fix branches with their SHAs, open questions).
