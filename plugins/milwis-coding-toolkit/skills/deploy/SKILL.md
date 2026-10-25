---
name: deploy
description: "Owner-only: build and deploy the desktop app to production (KonkretnyTMS / FakturyKonkret) — manual production steps plan (GATE 0) with one-command-at-a-time operator guidance, pre-deploy gates, full local test run plus analysis of the last 10 failed CI runs before push, changelog approval, Version::APP bump, npm run build, USE_BUNDLE=true amend, ci-preflight on the final SHA, push, post-deploy status, restore USE_BUNDLE=false, worktree cleanup. Invoked only by the owner typing /deploy."
disable-model-invocation: true
---

# Deploy na serwer produkcyjny

**Core:** wywołanie `/deploy` przez właściciela JEST zgodą na deploy z CLAUDE.md §2 — wyłącznie na ten jeden deploy, w tej sesji. Skill nie powiela komend: prowadzi przez procedurę, której źródłem prawdy jest repo projektu, i dokłada punkty zatrzymania z właścicielem oraz pułapki zmierzone na nieudanych deployach.

**Announce at start:** „Używam skilla deploy.”

## 0. Wejście — czy to właściwy projekt

Przeczytaj w CAŁOŚCI, w tej kolejności, zanim wykonasz jakąkolwiek komendę:

1. `docs/claude-reference/procedury.md` §„Procedura: DEPLOY NA SERWER” — **wszystkie GATE od najniższego numeru (dziś GATE 0) do ostatniego**. To **jedyna kolejność kroków**.
2. **Kroki ręczne na produkcji**, czyli plik albo katalog, który wskazuje GATE 0 procedury. Dziś to `docs/runbook/21-kroki-reczne-najblizszy-deploy.md`: sekcja „Prowadzenie operatora krok po kroku” plus CAŁA sekcja „Do wykonania”. Jeśli istnieje `docs/runbook/kroki-prod/`, czytaj jego `README.md` i wszystkie pliki z `oczekujace/`.
3. `docs/claude-reference/deploy-workflow.md` — preflight, bramka świeżości `dist/`, dobór segmentu wersji, checklista pre-build, changelog.
4. `docs/runbook/42-ci-preflight.md` i `docs/runbook/07-deploy-webhook.md` — tylko sekcje potrzebne przy czerwieni lub statusie innym niż `ok`.

Brak pliku z punktu 1 → **STOP**: „To repo nie ma procedury deployu, której ten skill oczekuje.” Nie improwizuj procedury z pamięci.

Właściciel nie musi niczego dopisywać do `/deploy`. Samo wywołanie oznacza: zaczynasz od planu kroków ręcznych (GATE 0), a nie od buildu.

Gdy procedura w repo różni się od tego skilla — **wygrywa repo**. Rozjazd zgłoś w raporcie końcowym.

## 1. Punkty zatrzymania — tu czekasz na właściciela

| Moment | Co pokazujesz | Czego NIE robisz bez odpowiedzi |
|---|---|---|
| Przed GATE 1 | `git log --oneline origin/main..HEAD`, w tym osobno scalenia `--merges --grep '\[roadmapa\]'` (CLAUDE.md §2) | nie zakładasz, że „deploy” obejmuje pracę kolejki, której właściciel nie widział — wymień ją i zapytaj |
| GATE 0 — plan | kroki ręczne w czterech grupach: **A** przed pushem, **B** po statusie `ok`, **C** następnego dnia, **D** nie przy tym deployu. Wpis, którego commity są już przodkami ostatnio wdrożonego SHA, oznacz jako „zaległy — czy zrobione?” | nie budujesz, dopóki właściciel nie zaakceptuje planu |
| Faza A — przed pushem (GATE 4) | **jedna komenda na raz** (patrz §1a) | nie pushujesz, dopóki każdy krok A nie dał oczekiwanego wyniku |
| Faza B — po statusie `ok` | jak faza A, jedna komenda na raz | nie startujesz przy `superseded` ani `failed` |
| GATE 2 | projekt wpisów `changelog.json` + proponowany bump (MINOR = nowa funkcja, PATCH = iteracja tej samej) | nie bumpujesz wersji i nie budujesz |
| GATE 4, przed preflightem | wyniki lokalnych testów + tabela 10 ostatnich porażek CI z ponowną kontrolą (§1b) | nie uruchamiasz preflightu i nie pushujesz |
| Czerwień w dowolnej bramce | komenda, kod wyjścia, nazwy czerwonych testów | nie dopisujesz do `known-local-reds.txt` ani nie używasz `KTMS_SKIP_PREFLIGHT=1`, `PLAYWRIGHT_ALLOW_FLAKY` czy `--no-verify` |
| Po GATE 5 | status `ok` / `superseded` / `failed` z logu workflow `Deploy` | nie ogłaszasz „wdrożone” przy `superseded` |

## 1a. Prowadzenie właściciela przez kroki ręczne

Kroki na serwerze (RDP, PowerShell jako administrator, phpMyAdmin, panele zewnętrzne) wykonuje właściciel. Ty nie masz tam dostępu i nie zgadujesz wyników.

- **Jedna komenda na raz.** Dla każdej podajesz: gdzie ją wykonać (okno, konto, baza), samą komendę w bloku kodu i oczekiwany wynik. Potem czekasz, aż właściciel wklei wynik, porównujesz go z oczekiwanym i dopiero wtedy podajesz następną. Nigdy nie wysyłasz listy kilku komend naraz.
- **Wynik inny niż oczekiwany = stop.** Nie improwizujesz obejścia. Wracasz do wpisu (warunki przerwania, „Skutek pominięcia”) i rozstrzygasz z właścicielem.
- **Sekrety:** nigdy nie prosisz o hasło, token ani wartość z `.env`. Komendy piszesz tak, żeby ich wynik tego nie wypisywał.
- **Faza C:** zapisujesz właścicielowi krótką listę z datą i dokładnymi komendami.
- **Po wykonaniu:** wpis przenosisz do „Wykonane” (albo do `kroki-prod/wykonane/`) z datą, wersją i wynikiem liczbowym z komend, a nie samym „OK”. Potem robisz commit `chore(api): …`, który pójdzie z najbliższym pushem.

## 1b. Bramka przed pushem — wszystkie testy lokalnie + lekcja z ostatnich 10 porażek CI

Cel: push `main` ma przejść `Tests` **za pierwszym razem**. Przy wielu commitach naraz typowe było zielone CI dopiero przy trzeciej lub czwartej próbie. Ten krok wykonujesz w GATE 4, na FINALNYM SHA (po commicie `dist/` + `USE_BUNDLE=true`), PRZED `scripts/ci-preflight.sh`. Każda poprawka po nim daje nowy SHA i powtórkę kroków 1 i 3.

1. **Wszystkie testy lokalnie, nie celowane:**
   - pełna suita PHPUnit przez slot (`.claude/tmp/phpunit-slot.sh`, jeśli istnieje; inaczej jak w `deploy-workflow.md`) → `scripts/ci-parity-check.sh <plik .names>` = exit 0;
   - Vitest (`npm run test:js:run` pod node@22) i ESLint (`npm run lint`);
   - PHPStan jak w CI (`php -d register_argc_argv=On vendor/bin/phpstan analyse --memory-limit=1G`);
   - `composer audit --no-dev --abandoned=fail`;
   - jeśli zakres pushu dotyka `sql/` albo `database/`: `scripts/ci-local/run.sh`, czyli MariaDB 10.4 i kroki jobu `migrations`;
   - jeśli dotyka `js/`: `node scripts/verify-dist-freshness.js`.
   Liczy się **kod wyjścia** każdej komendy, nie „OK” w wyjściu.
2. **Ostatnie 10 porażek CI:**
   ```bash
   gh run list --workflow Tests --status failure --limit 10 --json databaseId,headSha,createdAt,displayTitle
   gh run view <databaseId> --log-failed     # dla KAŻDEGO z 10, nie dla próbki
   ```
   Z każdego logu wypisz job (`php`, `js`, `build`, `money-parity`, `migrations`, `php-budget`, `phpstan-scope-e2e`…), krok i pierwszą realną przyczynę (nazwa testu i asercja, plik i reguła lintera, błąd SQL). Pogrupuj w klasy i policz. W tabeli pokaż właścicielowi: klasa / ile razy z 10 / przykładowy run / czy nasz lokalny krok z punktu 1 ją pokrywa.
3. **Ponowna kontrola najczęstszych klas na finalnym SHA.** Dla każdej klasy, która wystąpiła ≥2 razy, oraz każdej, której punkt 1 NIE pokrywa (np. zależność od Linuxa, `TMPDIR`, kolacja MariaDB, brak bazy w CI, świeżość `dist/`, stała korpusu zapadki podniesiona tylko w jednym miejscu), wykonaj pomiar, który by ją złapał na TYM SHA, i podaj komendę oraz wynik. Pytanie brzmi: „czy ten push ma tę przyczynę, czy nie, i co to rozstrzyga”, a nie „sprawdź, czy jest dobrze”. Klasa nie do zmierzenia lokalnie → wpisz to jawnie jako ryzyko, nie jako „OK”.
4. Dopiero potem `scripts/ci-preflight.sh`. Czerwony preflight → odczytaj `--log-failed`, dopisz przyczynę do tabeli z punktu 2 i wróć do punktu 1 dla nowego SHA.

Punkt zatrzymania: tabela z punktu 2 i wyniki z punktu 3 idą do właściciela przed preflightem. Bez tego nie pushujesz.

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
Lokalnie: PHPUnit/parity, Vitest, ESLint, PHPStan, audit, [migrations], [dist] → exit 0
Porażki CI (10 ostatnich): <top klasy z liczbą> → sprawdzone na tym SHA: <tak/ryzyko>
Preflight: <run URL> → success            Tests/Deploy na main: <wynik>, status webhooka: ok|superseded|failed
Changelog: <liczba wpisów>                USE_BUNDLE w drzewie: false (niezacommitowane)
Kroki ręczne: A <n>/<n> ✓, B <n>/<n> ✓, C do zrobienia <data>: <lista>, D: <lista>, zaległe bez odpowiedzi: <lista>

Sprzątanie worktree: USUNIĘTE …/ZOSTAJE … (z powodem)
Rozjazdy procedura↔skill: <brak | lista>
```

Zakończ zdaniem: „Zdeployowano vX.Y.Z. Sprawdź, czy działa poprawnie.”
