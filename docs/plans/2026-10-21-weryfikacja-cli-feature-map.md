# Weryfikacja: CLI sterujące aplikacją + Feature Map + reprodukcja w triage — plan wdrożenia

> **For Claude:** execute with the `executingplans` skill.

**Goal:** dać weryfikatorom kolejki gotowe narzędzie (CLI `scripts/dev/app.mjs`) i mapę funkcji aplikacji
zamiast skryptów pisanych od zera, a triage kazać zostawić reprodukcję, która później staje się dyskryminatorem —
tak, żeby spadła liczba BLOCKED i koszt przygotowania weryfikacji.

**Architecture:** dwa repozytoria. KonkretnyTMS dostaje CLI (Node, ESM, importuje istniejące helpery
`tests/e2e/helpers/*`, sesja logowania trzymana w pliku stanu per port) i katalog `docs/features/`.
claude-config dostaje zmiany briefów: `verify-e2e` (CLI jako pierwszy wybór, zawężenie przeglądarki, limit wywołań),
`roadmapa/references/cykl-lidera.md` (doctor przed triage, reprodukcja w triage, BLOCKED → etykieta do ręcznego sprawdzenia).
Skill pozostaje ogólny: CLI i mapę wskazuje projekt w `docs/VERIFICATION_ENV.md` (sekcja `## CLI`).

**Tech Stack:** Node 22 (ESM, `playwright` z `node_modules` drzewa głównego), PHP 8.5 CLI (seed tożsamości),
MySQL dev (`127.0.0.1`, guard hosta jak w `db-query.js` / `seed_e2e_user.php`), vitest (`tests/js/`).

**Źródło:** artykuł „pstack part 1 — Verification is all you need” (`pstack_part1`): „Build the Lever” (CLI zamiast
markdownu), Feature Map (materialized memory), reprodukcja zgłoszeń. Świadomie NIE bierzemy: cloud agents /
równoległości (odrzucone 2026-09-24 pomiarem: konflikty przy drugim merge'u, wspólna baza dev), `/swarm`, codziennej
rutyny utrzymaniowej (wraca po pomiarze — patrz „Po wdrożeniu”).

## Pomiary wyjściowe (POMIAR, transkrypty podagentów KonkretnyTMS od 2026-09-22, cennik listowy = proporcje)

Skrypty: scratchpad sesji `v2.py`, `v3.py` (`rows2.json`).

| metryka | wartość |
|---|---|
| koszt wszystkich podagentów | $26 913 (sesje główne +$7 272) |
| weryfikatorzy (310) | $546 = 2,0% podagentów; mediana $0,95 |
| – z przeglądarką (74) | $119; 65 PASS / 3 BLOCKED / 0 FAIL / 6 bez werdyktu |
| – HTTP/CLI (236) | $427; 191 PASS / 6 BLOCKED / 3 FAIL / 36 bez werdyktu |
| udział kosztu weryfikatora PRZED pierwszym wykonaniem (curl/node/przeglądarka) | 39% (przeglądarka 32%, HTTP 41%) |
| tury z setupem (php -S, login, cookie, seed, USE_BUNDLE) | 18% kosztu weryfikatorów |
| weryfikatorzy BLOCKED lub bez werdyktu | 51 z 310, $191 = 35% kosztu weryfikacji |
| 5 najdroższych weryfikatorów | $78 (verify-1055 $21, verify-1048 $18, verify-1476 $15 …) |
| triage (200) | $1 726 = 6,4%; mediana $7,95 |
| L2 / review / build-fix | 43,3% / 22,0% / 14,4% |
| przyczyny BLOCKED w ledgerze | brak konta e2e po dumpie (#1046, #1504, #1203), brak tożsamości z wąskimi uprawnieniami (#1514, #1584), brak dyskryminatora (#1602, #1173), KSeF/SMSAPI zakazane w kolejce |

## Ocena wpływu na tokeny (WNIOSEK — do sprawdzenia po ~20 issue)

| zmiana | oszczędność | koszt |
|---|---|---|
| CLI: `serve`/`login`/`http`/`open` zamiast odkrywania i pisania od zera | setup + eksploracja 39% → ~20% kosztu weryfikatora ≈ −$100/mies. | jednorazowo zbudowanie CLI (~$40–80) |
| `doctor --fix` przed triage + `identity` | BLOCKED/bez werdyktu $191 → ~połowa ≈ −$60–90/mies. + mniej ręcznych sprawdzeń | ~1 wywołanie na issue (pomijalne) |
| limit wywołań weryfikatora | ogon >$10 ($78 w 5 przebiegach) ≈ −$40–60/mies. | ryzyko BLOCKED zamiast PASS na trudnych powierzchniach |
| reprodukcja w triage (tylko powierzchnia użytkownika, ≤ 10 wywołań) | weryfikator nie odkrywa dyskryminatora, mniej „brak dyskryminatora” | +10–15% triage dla issue z powierzchnią ≈ +$80–130/mies. |
| Feature Map | mniej eksploracji UI w weryfikatorze i L2 (wliczone w wiersz CLI) | jednorazowo ~$20–50; utrzymanie przy okazji zmian |

**Bilans tokenowy: w przybliżeniu neutralny** (−$200…−$280 vs +$80…+$130 miesięcznie przy łącznym ~$34k, czyli
±0,5–1%). Uzasadnieniem nie są tokeny, tylko jakość: mniej BLOCKED (= mniej zmian scalonych bez dowodu z powierzchni)
i dyskryminator gotowy przed budową. Duże dźwignie kosztowe (L2 43%, review 22%) są poza zakresem tego planu.

## Findings from code analysis

- Helpery już istnieją i są przetestowane: `tests/e2e/helpers/login.js:139` `loginAs(page, groupKey)` (grupy:
  administrator, ksiegowosc, dyspozytor, dyspozachod, testerzy; hasło z `TEST_PASSWORD`, login z `workerUsername()`),
  `base-url.js:85` `resolveBaseUrl`, `db-query.js:108` `dbRows` (host zahardkodowany na 127.0.0.1), `app-ready.js:90`
  `waitForAppReady`, `modal.js`. CLI ma je importować, nie duplikować.
- `scripts/dev/seed_e2e_user.php` — idempotentny seed `e2e_test` + `e2e_test_0..7`, guard hosta bazy, hasło w
  gitignorowanym `/.e2e-password`; tabele `users`, `groups`, `user_group_memberships`. Tożsamość z wąskim
  uprawnieniem wymaga dodatkowo `permissions_new` (+ `group_views`) — w #1514 weryfikator miał zakaz ruszania
  `permissions_new` dla istniejących grup, więc nowa tożsamość dostaje WŁASNĄ grupę z prefiksem `e2e_tmp_`.
- Serwowanie worktree: `php -S 127.0.0.1:<port> -t <worktree> <repo>/dev-server/router.php`; sesja NIE przechodzi
  między portami (`session_config.php:20,34,46`), logowanie osobno na każdym porcie; brak `.htaccess` w docroocie = 503.
- Pułapki UI zapisane prozą w `docs/VERIFICATION_ENV.md` (130 linii, 44 KB): dropdown „Katalogi” przed `data-view`,
  autofill-guard (`click()` przed `fill()`), `USE_BUNDLE=true` serwuje stary `dist/`, nakładka ładowania.
- Moduły najczęściej w kolejce (ledger): security 89, api 69, warsztat 67, ksef 41, zakupy 40, zlecenia 25, faktury 20, sms 18.
- Kolejka PRACUJE (tmux `kolejka`, issue #1718): drzewo główne KonkretnyTMS jest nietykalne (lider scala do `main`).
  Plugin trafia do sesji dopiero po `git push` claude-config (marketplace z GitHuba, autoUpdate) — lokalny commit
  nie zmienia zachowania biegnącej kolejki.
- Reguła środowiska: nigdy dwa przebiegi Playwright naraz na wspólnej bazie dev.

**Canon:** logowanie = `tests/e2e/helpers/login.js::loginAs`; odczyt bazy = `db-query.js::dbRows`; seed kont =
`scripts/dev/seed_e2e_user.php`; serwer worktree = przepis z `VERIFICATION_ENV.md` (router `dev-server/router.php`).
**Variants:** `tests/e2e/predeploy/helpers/login.js` (re-eksport canonu — bez zmian); jednorazowe `.claude/tmp/verify-*.mjs`
(70 sztuk — zastępowane przez CLI, nie migrowane); Chrome MCP (zostaje jako alternatywa, CLI nie jest od niego zależne).

**Out of scope:** cloud agents, `/swarm`, codzienna rutyna utrzymania mapy, zmiany dashboardu kolejki, sync
skilli do `KonkretnyTMS/.claude/skills`, push obu repo, scalenie gałęzi KonkretnyTMS (decyzja właściciela po zatrzymaniu kolejki),
wywołania KSeF/SMSAPI (nadal zakazane w kolejce — CLI tego nie zmienia).

## Zasady wykonania

- KonkretnyTMS: wyłącznie worktree `.claude/worktrees/verify-cli`, gałąź `agent/verify-cli` od `main`. Zero zmian w drzewie głównym.
- Właściciel wydał `kolejka.sh stop` (2026-10-21) — #1718 jest ostatnim issue. Testy na żywo dopiero po zatrzymaniu
  (`kolejka.sh status` / brak sesji tmux `kolejka`); do tego czasu wyłącznie testy jednostkowe.
- Testy na żywo (Playwright, serwer) tylko gdy `pgrep -f playwright` jest puste (kolejka nie weryfikuje), tylko odczyt
  albo zapisy na tożsamościach `e2e_tmp_*`; porty 8095–8099 (kolejka używa 8081–8094).
- claude-config: commity na `master`, bez push.

---

### Task 1: CLI — szkielet, `doctor`, `serve`, `stop` (KonkretnyTMS)

**Acceptance Criteria:**
- [ ] `node scripts/dev/app.mjs doctor` zwraca JSON `{ok, checks:[{name, ok, detail, fix}]}` dla: devserver :8080, `USE_BUNDLE` w `index.php`, konta e2e w bazie dev (+ zgodność hasła z `.e2e-password`), `playwright` rozwiązywalny, `.htaccess` w docroocie; `doctor --fix` uruchamia `seed_e2e_user.php`, gdy brakuje kont; kod wyjścia ≠ 0 przy niezdanym checku.
- [ ] `serve <worktree>` wybiera wolny port z 8095–8099 (lub `--port`), startuje `php -S` z routerem w tle, czeka na HTTP 200/302 z `login.php`, zapisuje pid/port w `.claude/tmp/app/servers.json` i zwraca `{port, pid, docroot}`; `stop <port|--all>` ubija tylko procesy z tego pliku.
- [ ] `--help` na każdym poziomie; błąd zawsze jako JSON `{error, hint}`, gdzie `hint` mówi, co zrobić; testy vitest dla parsowania argumentów, wyboru portu i formatu błędów.

**Files:**
- Create: `scripts/dev/app.mjs` (dispatcher + `doctor`, `serve`, `stop`)
- Create: `scripts/dev/app/lib.mjs` (JSON out, błędy z podpowiedzią, plik stanu, wybór portu)
- Test: `tests/js/dev-app-cli.test.js`

**Intent:** jedna komenda mówi weryfikatorowi, czy środowisko jest gotowe, i serwuje worktree bez ręcznego przepisu.

**Approach:**
- Podkomendy jako osobne moduły ładowane leniwie (stopniowe ujawnianie); stan wyłącznie w `.claude/tmp/app/` (gitignorowany).
- Guard hosta bazy jak w `db-query.js` (twardo 127.0.0.1) — `doctor` czyta bazę przez `dbRows`.
- Brak `cp`/`rm`/`mv` w ścieżkach poleceń (klasyfikator) — zapisy plików przez `fs`.

**Verification:** `npx vitest run tests/js/dev-app-cli.test.js` zielone; na żywo: `doctor`, `serve <worktree>` → `curl -sI` na zwrócony port, `stop`.

**Commit message:** `feat(dev): CLI app.mjs — doctor, serve, stop dla weryfikatorów`

### Task 2: CLI — `identity` (tożsamości testowe z wąskimi uprawnieniami) (KonkretnyTMS)

**Acceptance Criteria:**
- [ ] `identity create --tag <t> --groups <g1,g2>` tworzy `e2e_tmp_<t>` z członkostwem tylko w podanych grupach (pokrywa „konto z jedną wybieralną grupą”, #1584); hasło z `.e2e-password`.
- [ ] `identity create --tag <t> --base-group <g> --perm <zasób>:<view,add,edit,delete>` tworzy grupę `e2e_tmp_<t>` jako kopię uprawnień `<g>` (`permissions_new` + `group_views`) z nadpisanym jednym zasobem (pokrywa „tylko can_add”, #1514); istniejące grupy nietknięte — test to sprawdza (odcisk `permissionFingerprint` grupy bazowej przed/po).
- [ ] `identity cleanup --tag <t>|--all` usuwa wyłącznie użytkowników/grupy/wiersze z prefiksem `e2e_tmp_`; `--dry-run` drukuje plan zapisów bez wykonania; guard hosta = odmowa poza localhost.

**Files:**
- Create: `scripts/dev/seed_identity.php` (zapisy w transakcji, guard hosta jak `seed_e2e_user.php`)
- Create: `scripts/dev/app/identity.mjs`
- Modify: `scripts/dev/app.mjs` (rejestracja podkomendy)
- Test: `tests/Scripts/SeedIdentityTest.php` (PHPUnit na bazie dev, własne fixture `e2e_tmp_test*`, sprzątanie w tearDown)

**Intent:** zamknąć klasę BLOCKED „brak tożsamości o danych uprawnieniach” jedną komendą, bez dotykania istniejących grup.

**Approach:**
- Wzorzec seeda i guarda: `scripts/dev/seed_e2e_user.php` (latch: testy kont e2e, jeśli istnieją — `git grep -l seed_e2e_user tests/`); kopia dostaje własny test.
- Przed pisaniem: zmierzyć schemat `permissions_new`, `group_views`, `groups` (`SHOW CREATE TABLE`) i to, jak `login.php` wybiera grupę — builder cytuje wynik.
- Testy na żywej bazie asertują na wierszach, które same zapisały (reguła task-lifecycle E13); bez `markTestSkipped` zależnego od zawartości bazy.

**Invariants & Failure Semantics:**
- Prefiks `e2e_tmp_` jest jedynym kluczem kasowania — `cleanup` filtruje po nim w SQL (`LIKE 'e2e\_tmp\_%'`), nigdy po id z argumentu.
- Tworzenie w jednej transakcji; błąd w połowie = rollback, brak połowicznych grup.

**Verification:** PHPUnit `--filter SeedIdentityTest` zielony; mutacja (usunięcie filtra prefiksu w cleanup) → test czerwony.

**Commit message:** `feat(dev): app.mjs identity — tymczasowe tożsamości e2e z wąskimi uprawnieniami`

### Task 3: CLI — `login` + `http` (powierzchnia API, 76% weryfikacji) (KonkretnyTMS)

**Acceptance Criteria:**
- [ ] `login --port <p> [--user e2e_test|e2e_tmp_<t>] [--group <g>]` loguje przez Playwright (canon `loginAs` — rozszerzony o jawny login zamiast `workerUsername()`, gdy podany) i zapisuje storage state `.claude/tmp/app/state-<p>-<user>.json`; respektuje blokadę IP (`assertNotLockedOut`) i nie ponawia po odrzuceniu hasła.
- [ ] `http <action> --port <p> [--method POST] [--data <json|@plik>]` wysyła żądanie do `api.php?action=<action>` z ciastkiem i tokenem CSRF ze stanu sesji; zwraca `{status, headers, body}` (body jako JSON, gdy się parsuje).
- [ ] Brak sesji / wygasła sesja → błąd z `hint: "uruchom login --port <p>"`; testy jednostkowe budowania żądania i obsługi błędów.

**Files:**
- Create: `scripts/dev/app/session.mjs` (`login`, odczyt stanu)
- Create: `scripts/dev/app/http.mjs`
- Modify: `tests/e2e/helpers/login.js` (opcjonalny parametr jawnego loginu — bez zmiany domyślnego zachowania)
- Modify: `scripts/dev/app.mjs`
- Test: `tests/js/dev-app-cli.test.js` (rozszerzenie)

**Intent:** weryfikator HTTP przestaje pisać własne `login.sh` + cookie jar + CSRF; jedna komenda na żądanie.

**Approach:**
- Zmierzyć, skąd frontend bierze token CSRF (nagłówek / meta) — `git grep -n csrf js/core/` — i powtórzyć dokładnie ten mechanizm.
- Zmiana `login.js` wsteczna: istniejące spece (`git grep -l loginAs tests/e2e`) przechodzą bez zmian — uruchomić 1 spec z nich jako kontrolę.

**Verification:** vitest zielony; na żywo: `login --port 8080` → `http getCurrentUser` (lub równoważna akcja odczytu) zwraca 200 z nazwą użytkownika; bez loginu → błąd z podpowiedzią.

**Commit message:** `feat(dev): app.mjs login i http — sesja per port dla weryfikacji API`

### Task 4: CLI — `open`, `snapshot`, `screenshot`, `eval` + `ab` (dyskryminator) (KonkretnyTMS)

**Acceptance Criteria:**
- [ ] `open <view> --port <p>` przechodzi do widoku przez `window.showView(<view>)` po `waitForAppReady` (obsługuje widoki schowane pod dropdownem); `snapshot` zwraca drzewo dostępności widoku jako JSON; `screenshot <plik>` zapisuje PNG wyłącznie pod `.claude/tmp/`; `eval <js>` zwraca wynik serializowany.
- [ ] `ab --base <port> --branch <port> -- <podkomenda…>` (np. `ab --base 8080 --branch 8095 -- http getX`) wykonuje tę samą podkomendę na obu portach i zwraca `{base, branch, differs}`; `differs` liczone po znormalizowanym wyniku (bez timestampów/id sesji).
- [ ] Testy jednostkowe normalizacji i porównania w `ab`; jeden test kontrolny: `ab` dwa razy na tym samym porcie → `differs:false`.

**Files:**
- Create: `scripts/dev/app/browser.mjs` (open/snapshot/screenshot/eval na storage state z Task 3)
- Create: `scripts/dev/app/ab.mjs`
- Modify: `scripts/dev/app.mjs`
- Test: `tests/js/dev-app-cli.test.js`

**Intent:** dyskryminator „ta sama akcja na drzewie z poprawką i bez” jako jedna komenda — wymagany przez `verify-e2e`.

**Approach:**
- Każda komenda = osobny proces z `storageState`; bez trzymania przeglądarki w tle (prostsze sprzątanie, brak osieroconych procesów).
- Lista kluczy widoków brana w runtime (POMIAR, Task 4): rejestr to tabela DB `views` filtrowana per grupa (`php/services/NavigationService.php:82`), nie `views/navigation-dynamic.php`; dla administratora 49 kluczy (`eval` na `nav [data-view]` + `window.USER_VIEWS`). `open` z nieznanym kluczem zwraca listę dostępnych.

**Verification:** vitest zielony; na żywo: `open orders --port 8080` + `snapshot` (tylko odczyt), `ab` na 8080 vs 8080 → `differs:false`.

**Commit message:** `feat(dev): app.mjs open/snapshot/screenshot/eval i ab jako dyskryminator`

### Task 5: Feature Map + sekcja `## CLI` w VERIFICATION_ENV (KonkretnyTMS)

**Acceptance Criteria:**
- [ ] `docs/features/README.md` — indeks wszystkich widoków z rejestru nawigacji (klucz `open`, nazwa w menu, grupy z dostępem, link do pliku obszaru); liczba widoków w indeksie = liczba kluczy w rejestrze (polecenie liczące zacytowane w commicie).
- [ ] Pliki obszarów dla 6 modułów najczęstszych w kolejce (warsztat, zakupy, ksef, zlecenia, faktury, sms): podfunkcje, jak dojść (perspektywa użytkownika), komendy `app.mjs`, pułapki, wymagane konto/uprawnienia, czego kolejka nie może wywołać (KSeF/SMSAPI).
- [ ] `docs/VERIFICATION_ENV.md` dostaje sekcję `## CLI` (ścieżka, `--help`, mapa) na początku; pułapki UI przeniesione do plików obszarów zostają w VERIFICATION_ENV jako jednolinijkowe odsyłacze (bez utraty treści).

**Files:**
- Create: `docs/features/README.md`, `docs/features/{warsztat,zakupy,ksef,zlecenia,faktury,sms}.md` (6 plików — wyjątek od limitu 5, same dokumenty)
- Modify: `docs/VERIFICATION_ENV.md`

**Intent:** weryfikator i L2 znajdują drogę do funkcji z mapy, a nie z eksploracji kodu i prozy.

**Approach:**
- Generuje agent przechodzący po rejestrze nawigacji i `views/` (Explore/sonnet); każdy wpis „jak dojść” sprawdzony przez `app.mjs open` (tylko odczyt).
- Wpisy mapy to WNIOSEK — w briefach nadal wymagany pomiar z bieżącej tury, ale jest nim jedna komenda `open`.
- Jeśli projekt ma latch budżetu/struktury dokumentów (`scripts/check_doc_structure.php`), uruchomić go.

**Verification:** `check_doc_structure.php` (jeśli dotyczy) zielony; wyrywkowo 3 wpisy: komenda z mapy → `snapshot` pokazuje opisany element.

**Commit message:** `docs(features): Feature Map aplikacji i sekcja CLI w VERIFICATION_ENV`

### Task 6: `verify-e2e` — CLI jako pierwszy wybór, zawężenie przeglądarki, limit wywołań (claude-config)

**Acceptance Criteria:**
- [ ] Step 2: gdy `VERIFICATION_ENV.md` ma `## CLI` — `doctor` zastępuje sondę połączenia, wpis mapy + `open`/`http` zastępuje grep punktu wejścia, `ab` jest domyślnym dyskryminatorem; bez CLI dotychczasowa procedura bez zmian.
- [ ] Wybór powierzchni: przeglądarka tylko gdy diff dotyka plików frontu (`js/`, `views/`, szablony) albo gdy żadna powierzchnia HTTP/CLI nie rozróżnia drzew — inaczej HTTP (`git diff --stat` decyduje, komenda w briefie).
- [ ] Szablon briefu: nowe linie `Control CLI`, `Feature map entry`, `Repro from triage` oraz limit „≤ 60 wywołań narzędzi; na limicie BLOCKED ze stanem, nie dalsze próby”.

**Files:**
- Modify: `plugins/milwis-coding-toolkit/skills/verify-e2e/SKILL.md`
- Modify: `plugins/milwis-coding-toolkit/skills/verify-e2e/references/evidence.md` (nowy wpis E z pomiarami z tego planu)

**Intent:** reguły trafiają do weryfikatora przez brief (jedyny kanał — E5), nie przez odwołanie do skilla.

**Approach:** zmiany wkomponowane w istniejące punkty Step 2/3, bez dublowania; skill pozostaje projektowo-neutralny (nazwy z `VERIFICATION_ENV.md`).

**Verification:** przeczytanie Step 2–3 jako weryfikator: każda nowa linia szablonu ma regułę wypełnienia lub `skipped: <reason>`; `git diff --stat` ≤ ~40 linii netto.

**Commit message:** `feat(verify-e2e): CLI projektu jako pierwszy wybór, przeglądarka tylko dla frontu, limit wywołań`

### Task 7: `roadmapa` — doctor przed triage, reprodukcja w triage, BLOCKED → ręczne sprawdzenie (claude-config)

**Acceptance Criteria:**
- [ ] Cykl lidera: przed triage `doctor --fix` (gdy projekt ma CLI), wynik w `$K/doctor-<N>.json`. **Odstępstwo przy wykonaniu:** niezdany check NIE odkłada issue (devserver w dół nie przeszkadza w bugu backendu) — plik idzie do triage/L2 i do briefu weryfikacji jako stan środowiska.
- [ ] Brief triage: przy `user-facing surface: yes` sekcja `## Repro` — komenda CLI (lub curl), która na HEAD pokazuje defekt, zapisana w `$K/repro-<N>.sh`, ≤ 10 wywołań; nieosiągalna → `n/a: <powód>`. Brief L2 przekazuje ją do weryfikatora jako `Repro from triage` / dyskryminator.
- [ ] Verify BLOCKED: lider dodaje do zamykanego issue etykietę `weryfikacja:reczna` (tworzy ją, gdy brak) i jednolinijkowy komentarz, co kliknąć; `kolejka.sh status` wypisuje otwarte pozycje do ręcznego sprawdzenia.

**Files:**
- Modify: `plugins/milwis-coding-toolkit/skills/roadmapa/references/cykl-lidera.md`
- Modify: `plugins/milwis-coding-toolkit/skills/roadmapa/scripts/kolejka.sh` (status)
- Modify: `plugins/milwis-coding-toolkit/skills/roadmapa/SKILL.md` (jedna linia w Owner/Afterwards)

**Intent:** BLOCKED przestaje znikać w ledgerze — trafia do właściciela jako konkretna lista; dyskryminator powstaje przed budową.

**Approach:** limit triage pilnuje kosztu (+10–15% tylko dla issue z powierzchnią); bez CLI w projekcie kroki są pomijane z `skipped: brak CLI`.

**Verification:** `bash -n kolejka.sh`; `kolejka.sh status` na repo z etykietą testową pokazuje listę (gh, tylko odczyt); przeczytanie briefów: każda nowa reguła jest linią briefu.

**Commit message:** `feat(roadmapa): doctor przed triage, reprodukcja w triage, BLOCKED do ręcznego sprawdzenia`

### Task 8: Wydanie pluginu (claude-config)

**Acceptance Criteria:**
- [ ] `plugin.json` → `1.5.49`; wpis w `UPDATE_LOG.md` z pomiarami wyjściowymi i celami (niżej).
- [ ] Bez push — push i sync do KonkretnyTMS po scaleniu `agent/verify-cli` przez właściciela (inaczej kolejka dostałaby briefy wskazujące CLI, którego nie ma na `main`; reguła „bez CLI = skipped” to łagodzi, ale kolejność jest bezpieczniejsza).

**Files:** `plugins/milwis-coding-toolkit/.claude-plugin/plugin.json`, `plugins/milwis-coding-toolkit/UPDATE_LOG.md`

**Commit message:** `feat(weryfikacja): CLI projektu, Feature Map i reprodukcja w triage (v1.5.49)`

## Po wdrożeniu — pomiar po ~20 issue (cele)

- udział kosztu weryfikatora przed pierwszym wykonaniem: 39% → ≤ 25%
- weryfikatorzy BLOCKED/bez werdyktu: 16% (51/310) → ≤ 8%
- mediana triage: $7,95 → ≤ $9,00
- mediana weryfikatora: $0,95 → ≤ $0,80; brak przebiegów > $10
- gdy cele osiągnięte: rozważyć rutynę utrzymania mapy w stanie `pusto` kolejki.

## Self-audit (writingplans Step 2)

Pass 1 — znalezione i poprawione w planie:
1. Kolejka pracuje na `main` KonkretnyTMS → dodane „Zasady wykonania” (worktree, porty 8095–8099, Playwright tylko gdy kolejka nie weryfikuje).
2. `loginAs` używa `workerUsername()` (sufiks per worker) → Task 3 rozszerza helper wstecznie zgodnie, z kontrolą istniejącego speca.
3. `identity --perm` mogłoby zmienić uprawnienia istniejącej grupy (zakaz z #1514) → osobna grupa `e2e_tmp_`, odcisk grupy bazowej przed/po w teście.
4. Cleanup po id z argumentu = ryzyko skasowania prawdziwych kont → kasowanie wyłącznie po prefiksie w SQL + mutacja w weryfikacji.
5. Kolejność wydania pluginu względem scalenia KonkretnyTMS → Task 8 bez push; skille z regułą „bez CLI = skipped”.
6. Task 5 ma 7 plików (dokumenty) — świadomy wyjątek, bez kodu.

Pass 2 (specjaliści) pominięty: 8 zadań, ale bez pieniędzy/VAT/danych regulowanych; uprawnienia dotyczą tylko tożsamości testowych na dev, a Task 2 i tak przejdzie review + security w task-lifecycle.

## Postęp wykonania (ledger tej pracy)

| data | zadanie | stan | dowód |
|---|---|---|---|
| 2026-10-21 | worktree KonkretnyTMS | `.claude/worktrees/verify-cli`, `agent/verify-cli` od `f6cf54256` | `git worktree add` |
| 2026-10-21 | Task 1 | zrobione, `a0ce20c99` | POMIAR: vitest dev-app-cli → 22 passed; `doctor --root WT` → ok:true (6/6) |
| 2026-10-21 | Task 3 | zrobione, `b46290ae1` | POMIAR: vitest dev-app-session + dev-app-cli → 39 passed; live (reported): login :8080 + http permissions-get-current-user → 200 |
| 2026-10-21 | Task 2 | zrobione, `5342eb914` | POMIAR: phpunit `SeedIdentityTest` + latche SAPI/StrictTypes/PhpunitCollection/PhpstanScope → OK (23 tests, 703 assertions); eslint `scripts/dev/app*` rc=0; mutanty 4/4 RED (reported); odchylenie: guard SAPI w kształcie kanonu (`http_response_code(403); exit(1)`), bo latch zabrania STD* |
| 2026-10-21 | Task 4 | zrobione, `a084b1b86` | POMIAR: vitest dev-app-browser → 18 passed; `smoke.png` istnieje; live A/B 8080↔8080 differs:false (reported) |
| 2026-10-21 | Task 5 | zrobione, `faee2f10f` | POMIAR: awk lidera na `VERIFICATION_ENV.md` → `scripts/dev/app.mjs`; tabela README = 49 wierszy (= `eval` .length = `SELECT COUNT(*) FROM views`, reported); live open/snapshot zlecenia/warsztat/zakupy (reported); KSeF nie ma własnego klucza widoku |
| 2026-10-21 | Task 8 | zrobione, `0f9b77e` (v1.5.49) | — |
| 2026-10-21 | review (opus) | 0 blocker, 6 major, 5 minor; 4 potwierdzone sondami (ab maskuje `session.role`, `decideKill` z portem-stringiem 8080, `isPortFree` przy 0.0.0.0, guard tylko hosta) | poprawki: `fix-cli` → `688987ddf` |
| 2026-10-21 | poprawki z review | zrobione, `688987ddf` (11/11) + docs CLI `5f2458543` | POMIAR: vitest dev-app-* → 88 passed; phpunit SeedIdentity+latche → OK (27 tests, 736 assertions); 4 sondy po poprawce: ab → `["body.session.role"]`, decideKill str 8080 → kill:false, isPortFree 0.0.0.0 → false; awk lidera → `scripts/dev/app.mjs` |
| 2026-10-21 | kolejka | zatrzymana 20:14:15 po #1718 (`watcher.log`) | — |
| 2026-10-21 | verify CLI na żywo (`verify-cli-live`) | PASS, 22 wywołania | reported: doctor 6/6, sesja przeżywa 10 s, ab kontrola differs:false, ab admin vs ksiegowosc differs:true (163 ścieżki), 5/5 barier odmawia; POMIAR po: 0 wierszy `e2e_tmp_`, brak serwerów 8095–8099 |
| 2026-10-21 | luki z weryfikacji | zrobione, `60b77a43e` + `18f4950eb` + `d74c0cae2` | `ab --base-user/--branch-user`, `http --body-only`, `snapshot --max-nodes` (domyślnie 100), jawna odmowa `stop 8080`; POMIAR: vitest dev-app-* → 98 passed; snapshot orders: bez limitu ≈754 kB (reported), 400 → 78135 B, 100 → 11958 B z 11 przyciskami |
| 2026-10-21 | Task 6 | zrobione, `2b23d6f` | — |
| 2026-10-21 | Task 7 | zrobione, `15fcfef`; POMIAR: `ROADMAPA_SKILL_DIR=<claude-config>/…/roadmapa phpunit --filter RoadmapaSkillLatchTest` → OK (5 tests, 102 assertions); `bash -n kolejka.sh` OK | — |

| 2026-10-21 | pełna suita w WT | vitest 428 plików / 6862 passed; PHPUnit 25627 testów: 59 E + 86 F | POMIAR: 141 z 143 nazw testów czerwonych także na `main` (`kolejka/fullsuite-20261021-183658.log`: 59 E + 84 F; DDD, RepairOrder*LiveDb, Paysera… — stan bazy dev, nie ta gałąź); 2 tylko na gałęzi (`JsonResponseSeamBudgetLatchTest` 233≠231, `EnvExampleSyncTest`) → naprawione `fde4e78eb`, filtr 34 tests OK, PHPStan OK |

Zostało (właściciel): scalenie `agent/verify-cli` do `main` KonkretnyTMS, push claude-config (v1.5.49) + sync toolkitu, obserwacja pierwszego cyklu kolejki (`doctor --fix` vs klasyfikator auto-mode). (review, pełna suita, verify CLI), Task 8.
Miny: **zmiana User-Agenta niszczy sesję** (`SecurityService.php:111-116`, `:216-237`) — `http` wysyła UA z logowania; do Feature Map/VERIFICATION_ENV (Task 5). Ścieżka `dev-server/router.php` może być tylko w drzewie głównym; klasyfikator auto-mode może odrzucić `doctor --fix` w sesji lidera (w #1046 odrzucił seed) — pierwszy cykl kolejki obserwowany; agentów pluginu (`javascript-pro`, `php-pro`) nie ma w rejestrze tej sesji → `general-purpose` + rola w briefie.
