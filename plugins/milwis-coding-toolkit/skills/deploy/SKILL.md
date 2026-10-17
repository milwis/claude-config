---
name: deploy
description: "Owner-only: build and deploy the desktop app to production (KonkretnyTMS / FakturyKonkret) — pre-deploy gates, changelog approval, Version::APP bump, npm run build, USE_BUNDLE=true amend, ci-preflight on the final SHA, push, post-deploy status, restore USE_BUNDLE=false, worktree cleanup. Invoked only by the owner typing /deploy."
disable-model-invocation: true
---

# Deploy na serwer produkcyjny

**Core:** wywołanie `/deploy` przez właściciela JEST zgodą na deploy z CLAUDE.md §2 — wyłącznie na ten jeden deploy, w tej sesji. Skill nie powiela komend: prowadzi przez procedurę, której źródłem prawdy jest repo projektu, i dokłada punkty zatrzymania z właścicielem oraz pułapki zmierzone na nieudanych deployach.

**Announce at start:** „Używam skilla deploy.”

## 0. Wejście — czy to właściwy projekt

Przeczytaj w CAŁOŚCI, w tej kolejności, zanim wykonasz jakąkolwiek komendę:

1. `docs/claude-reference/procedury.md` §„Procedura: DEPLOY NA SERWER” (GATE 1–5) — **jedyna kolejność kroków**.
2. `docs/claude-reference/deploy-workflow.md` — preflight, bramka świeżości `dist/`, dobór segmentu wersji, checklista pre-build, changelog.
3. `docs/runbook/42-ci-preflight.md` i `docs/runbook/07-deploy-webhook.md` — tylko sekcje potrzebne przy czerwieni lub statusie innym niż `ok`.

Brak pliku z punktu 1 → **STOP**: „To repo nie ma procedury deployu, której ten skill oczekuje.” Nie improwizuj procedury z pamięci.

Gdy procedura w repo różni się od tego skilla — **wygrywa repo**. Rozjazd zgłoś w raporcie końcowym.

## 1. Punkty zatrzymania — tu czekasz na właściciela

| Moment | Co pokazujesz | Czego NIE robisz bez odpowiedzi |
|---|---|---|
| Przed GATE 1 | `git log --oneline origin/main..HEAD`, w tym osobno scalenia `--merges --grep '\[roadmapa\]'` (CLAUDE.md §2) | nie zakładasz, że „deploy” obejmuje pracę kolejki, której właściciel nie widział — wymień ją i zapytaj |
| GATE 2 | projekt wpisów `changelog.json` + proponowany bump (MINOR = nowa funkcja, PATCH = iteracja tej samej) | nie bumpujesz wersji i nie budujesz |
| Czerwień w dowolnej bramce | komenda, kod wyjścia, nazwy czerwonych testów | nie dopisujesz do `known-local-reds.txt` ani nie używasz `KTMS_SKIP_PREFLIGHT=1`, `PLAYWRIGHT_ALLOW_FLAKY` czy `--no-verify` |
| Po GATE 5 | status `ok` / `superseded` / `failed` z logu workflow `Deploy` | nie ogłaszasz „wdrożone” przy `superseded` |

## 2. Pułapki zmierzone na nieudanych deployach

- **Bramką jest CI, nie „tło”.** Zbiór nazw czerwonych testów porównany z porannym przebiegiem odpowiada na pytanie „czy moja praca coś zepsuła”, a nie „czy CI przejdzie”. Lokalnie decyduje `scripts/ci-parity-check.sh` na FINALNYM SHA, a ostatecznie `scripts/ci-preflight.sh`. Ostrzeżenia PHP przy `failOnWarning` dają exit 1 mimo „OK, but there were issues” — liczy się **kod wyjścia**.
- **Poza PHPUnit CI ma jeszcze inne joby.** Chodzi o `composer audit --no-dev --abandoned=fail` oraz WSZYSTKIE kroki jobu `migrations` z `.github/workflows/tests.yml` (idempotencja, `schema-collation`, `purchase-dup-key`), a nie tylko jeden. Zmiana SQL → lokalna replika `scripts/ci-local/run.sh` przed preflightem.
- **Każda zmiana po preflighcie to nowy SHA.** Dotyczy to merge'a `origin/main`, amenda i poprawki po czerwieni. Po merge'u z konfliktem w pliku czytanym przez zapadkę (`.claude/skills/**`, `docs/**`, `CLAUDE.md`) uruchom minimum `vendor/bin/phpunit tests/Config tests/Static tests/Hooks`, a potem nowy preflight.
- **`git commit -- index.php` bierze plik z drzewa roboczego, nie z indeksu.** Commit `USE_BUNDLE = true` rób bez pathspecu. Zaraz po nim sprawdź `git show HEAD:index.php | grep USE_BUNDLE`. Przywrócenie `false` po pushu zostaje NIEZACOMMITOWANE.
- **Bump `Version::APP` wymaga aktualizacji snapshotu w `tests/Config/VersionTest.php`** w tym samym commicie buildu.
- **`dist/` buduje wyłącznie sesja główna**, a nie podagent (#679; guard `bash-guard.sh` odrzuca build z podagenta). Pierwszy push po zmianach w `js/` bez świeżego `dist/` czerwieni job `build`.
- **Data deployu to wpis w `webhook/deploy.log`**, a nie commit „Build v”. Webhook odpala się po każdym zielonym pushu.

## 3. Raport końcowy

```
Wersja: vX.Y.Z (poprzednia: vA.B.C)       SHA: <finalny>
Preflight: <run URL> → success            Tests/Deploy na main: <wynik>, status webhooka: ok|superseded|failed
Changelog: <liczba wpisów>                USE_BUNDLE w drzewie: false (niezacommitowane)
Sprzątanie worktree: USUNIĘTE …/ZOSTAJE … (z powodem)
Rozjazdy procedura↔skill: <brak | lista>
```

Zakończ zdaniem: „Zdeployowano vX.Y.Z. Sprawdź, czy działa poprawnie.”
