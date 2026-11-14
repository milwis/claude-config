# Project commands — KonkretnyTMS

Read by the `refaktor` orchestrator at step 0 and copied into both briefs where they name a command.
`K=~/Programowanie/KonkretnyTMS`. Another project gets its own `references/projekt-<name>.md` with the same items.

- rig (`<rig>` in the templates): `$K/.claude/tmp/stanowisko-slot.sh <abs tree> --wzorzec=<abs template from the
  ledger> --plik=<file> --stary=<ref> --nowy=<ref> --etap=<name>` — `--wzorzec` on EVERY run of this skill (the
  default `baza.sql` may lack migrations; the secondary templates are found by name next to it)
  (calibration: `--stary=<S> --nowy=<S> --kalibracja`; code 7 = template DB lacks migrations → rebuild it with
  `tests/rownowaznosc/przygotuj-wzorzec.sh`). One run at a time; the slot queues. The result is the run's
  report directory: `meta.json` (`kod_wyjscia`, `kontrola_dodatnia`, `stanowisko_sha`, `samotest`,
  `mutant_b`, `wzorzec_sha256`) and `raport.md` (every difference: scenario, path, A, B) — read those, not the
  log tail. Time a run from outside (`date +%s` before and after) when you estimate a batch; until
  claude-config #80 the log's „czas całkowity” is not the wall time of the whole run.
- template DB fresh (step 1; empty = fresh, positive control: the 2026-11-03 `baza.sql` lists 23):
  `comm -23 <(git -C $K ls-tree --name-only main_dev sql/migrations/ | grep '\.sql$' | xargs -n1 basename | sort) <(grep -a '^INSERT INTO `schema_migrations`' <template.sql> | grep -o "'[^']*\.sql'" | tr -d "'" | sort -u)`.
  Rebuild with `przygotuj-wzorzec.sh --plik=baza-<date>.sql`, then a separate call `przygotuj-wzorzec.sh --wtorna=<db>`
  for every `bazy_wtorne` entry (the two flags exit 1 together), both from the same dev state; the main template's
  absolute path and every `sha256` go to the ledger.
- class mutants on the OLD code (A=S, B=S+patch), one run per patch — the rig refuses `--stary` = `--nowy`
  without `--kalibracja`/`--mutant-b` (L6c) and skips the positive control under `--kalibracja`:
  `<rig> --plik=<file> --stary=<S> --nowy=<S> --mutant-b=<abs patch> --tylko=<the patch's preamble regex>
  --bez-pokrycia --etap=mut-<k>-<n>` → exit **2** and the difference in the patch's channel (Completeness §2,
  detection rule). Batches of ~10 patches under one slot lock instead of one slot request per patch (WDC:
  ~1300 s per patch through the queue, ~53 s in a batch); claude-config #76 replaces this with one run.
- class mutants on the NEW code: the proof run takes `--mutanty=<abs dir>` (default `tests/rownowaznosc/mutanty/`
  holds the Gutschrift patches — never the proof for another class). Result: `<report>/kontrola-dodatnia.json`,
  `mutantow` = N, `bledow` = 0. A patch starts with `# scenariusze: <regex>` (the whole action family with its
  preparation) and `# kanal: <regex of the difference path>` (the channel the patch changes); a patch that does
  not apply is red (L13), not skipped.
- synthetic data: a scenario's `dane` (request payload), `przygotuj_sql` (state before the request) and
  `naglowki` (request headers, e.g. `X-Mobile-Token`), or the class's seed `tests/rownowaznosc/wzorzec/<Class>.sql`
  (fixed timestamps, no `NOW()`; accounts and groups looked up by login/name, never by id — template ids shift).
- suite: `$K/.claude/tmp/phpunit-slot.sh <abs tree>` → prints `names=<file>` (red test names).
- standard (Spec §1): `php vendor/bin/phpunit --filter GutschriftModuleStandardLatchTest` and
  `php -d register_argc_argv=On vendor/bin/phpstan analyse -c phpstan-modul-<module>.neon --memory-limit=1G`.
- stale references: `$K/.claude/skills/refaktor/scripts/usuniete-symbole.sh <S> <F> <file>` (from the repo root)
  → every hit on a method removed or moved out of the file, in `docs tests php` (history folders excluded), with
  a positive control on S; each hit is judged „history” (stays) or „current state” (fix). Exit 1 = hits listed.
- registry latches a module extraction touches (Spec §6): `tests/Static/ServicesDirectTimeReadRatchetLatchTest.php`
  (a moved `new \DateTime()`/`time()` is a new read → inject `Psr\Clock\ClockInterface`, never grow the
  allow-list), `tests/Static/UntestedClassesInventoryFreshnessLatchTest.php` (pin of classes without tests → test
  the new classes, never raise the pin), `tests/Static/TestSuiteVolumeRatchetLatchTest.php` (`PDO_CONSTRUCTIONS`),
  `tests/Static/GenericThrowRatchetLatchTest.php`, `tests/Config/IncidentLessonsSplitCompletenessTest.php` (adding
  the module's incident file is registration), `GutschriftModuleStandardLatchTest` `MODULES`/`MODULES_FLOOR`.
- commits: regenerate `09a`/`09b` (`php scripts/measure-untested-classes.php`, `php scripts/measure-god-objects.php`)
  after `git add` — 09a counts tracked files only; after deleting code drop its `phpstan-baseline.neon` entries
  (`ignore.unmatched` fails the hook); quote paths with spaces (`docs/dokumentacja programu/…`). A failed commit
  costs a full hook (>120 s). In scripts: no `\b` in `git grep -E` (macOS gives a false zero); keep a JSON file's
  format when a script rewrites it.
- the rig's files per class: `tests/rownowaznosc/{karta,inwentarz,scenariusze,maska}/<Class>.json`,
  `tests/rownowaznosc/mutanty/<Class>/` (old code) and `tests/rownowaznosc/mutanty/<Class>-po/` (new code);
  the worked examples are `GutschriftDocumentController` and `WarsztatDocumentController` (second database,
  mobile token, ledgers in `$K/.claude/tmp/refaktor/warsztatdocumentcontroller/`).
- karta fields used by this skill (besides `plik`, `pliki_zapisu`, `pliki_modulu`, `prog_pokrycia_efektywnego`,
  `poza_pomiarem`, `uslugi_zewnetrzne`):
  - `mutanty` — the class's mutant directory relative to `tests/rownowaznosc` (`mutanty/<Class>`);
  - `bazy_wtorne` — every database the class uses besides the main one (names or `{nazwa, zmienna_env?, zrodlo?}`);
    a non-empty list switches the rig to one mysqld instance per side, each with that database loaded from its
    own template, and the SQL sequence and binlog delta cover both schemas;
  - `luki` — known measurement gaps approved in step 3 (section **Completeness**); the rig does not read it.
  - `poza_pomiarem` from the start holds `phpstan-modul-<module>.neon` and `phpstan-baseline.neon` (the module
    name comes from the target map); a missing entry makes the refactor run INVALID (code 9).
- launch a session (CLAUDE.md rule — every agent session through `hc run`):

  ```bash
  hc run --bg --outlive-parent --no-notify --name <n> --cwd <worktree> \
    env ENABLE_CLAUDEAI_MCP_SERVERS=false caffeinate -ims \
    claude --permission-mode auto --model opus --effort high -n "<n>" --remote-control "<n>" "<first prompt>"
  ```
