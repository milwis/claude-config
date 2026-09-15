# Update Log

> **MAINTENANCE POLICY (obowiązuje rutynę miesięczną — od 2026-08-19):**
> 1. **Nie zmieniaj frontmatter `model:`** — podział jest celowy: `sonnet` dla agentów piszących, `opus` dla code-reviewer / backend-security-coder / refactoring-orchestrator. Audyty (audit-360) i tak spawnują specjalistów z override `model: opus` — patrz SKILL.md §1.
> 2. **Nie dodawaj sekcji „newsowych"** (wydania PostgreSQL/MySQL/Node/Safari, listy narzędzi, statystyki branżowe z datami). Zostały celowo usunięte 2026-08-19 — starzeją się co miesiąc, nie zmieniają decyzji przy pisaniu kodu i zżerają tokeny przy każdym wywołaniu agenta. Aktualizuj wyłącznie REGUŁY (co wolno / czego nie wolno / jak zweryfikować).
> 3. **Nie przywracaj sekcji frameworkowych do php-pro** (Laravel/Symfony) ani katalogów narzędzi do test-automator.
> 4. Stopka pliku agenta: jeden komentarz `<!-- Updated: ... -->` + `Last updated:`; historia żyje w tym pliku, nie w agentach.

## Run: 2026-09-15 (8) — Poprawki po samoocenie v1.5.11: kontrakt raportu vs werdykt na końcu, plan ryzyk poza raportem, martwe odwołanie do RUN_META (v1.5.12)

Źródło: ocena własnych zmian z (7) — dwa konflikty z `task-lifecycle` hard rule 8 i jedno martwe odwołanie (klasa „dead documentation reference", którą recenzent sam ma wyłapywać). Bez `POMIAR` — to naprawa spójności, nie nowa reguła. Decyzja odłożona: rozbicie recenzenta na `code-reviewer-S` / `-L` (wybór po stronie zlecającego) — NIE: różnica między tierami to ~6 KB z 28 KB (plan, jednostki L, tabela plików), reszta (overlay, 7 osi, tabela AI, zasady) obowiązuje w każdym tierze, a dwa pliki z tą samą treścią dryfują (polityka utrzymania walczy z dryfem już teraz); koszt stałej nadwyżki ~1,8 k tokenów na wywołanie przy cenie cache-read wobec 138–157 k za recenzję (partia 2.4) to ~1 % — poniżej progu opłacalności rozdwojenia. Do rewizji, jeśli `retro` pokaże, że większość recenzji w fali to tier S.

- `agents/code-reviewer.md`: Output Format — pierwsza linia raportu = token terminalny (`No issues.` albo linia werdyktu) zgodnie z hard rule 8(a) task-lifecycle, pełny werdykt z uzasadnieniem zamyka podsumowanie; decyzja zapada w rozumowaniu po ostatnim pomiarze, raport ją tylko zapisuje (argument OCR o kolejności pól dotyczy outputu, nie rozszerzonego myślenia — zapisane wprost). §2 — plan ryzyk jest materiałem roboczym i nie trafia do raportu (8(d): zakaz łańcuchów strzałek w prozie); do raportu trafiają wyniki pomiarów jako `path:line` + komenda.
- `skills/audit-360/SKILL.md`: STEP 1 pkt 13 — usunięte odwołanie do RUN_META audytu 2026-08-19 (`KonkretnyTMS/audit/` nie ma takiego pliku; mechanizm powstał później); liczba 150–250 k oznaczona jako ZAŁOŻENIE do zastąpienia pierwszym zmierzonym RUN_META.

## Run: 2026-09-15 (7) — Adaptacje z przeglądu repo alibaba/open-code-review: tiery recenzji S/M/L, plan ryzyk z pomiarem obalającym, ledger pokrycia, dyscyplina odrzucania w audit-360 (v1.5.11)

Źródło: przegląd całego repo `github.com/alibaba/open-code-review` (Go CLI; wewnętrzny reviewer Alibaby, benchmark AACR-Bench: wyższa precyzja i F1 od Claude Code przy ~1/9 tokenów, niższy recall — świadomy trade-off). Przejęto MECHANIKĘ promptów i gwarancje procesu, nie narzędzie (własny endpoint LLM, diff-only, wyklucza testy z recenzji — sprzeczne z naszym tests-first). Zasada doboru: najlepszy stosunek jakości do tokenów — recenzent bywa wołany na diff 10-liniowy, więc każdy dodatek ma bramkę rozmiaru. NIE przejęto: `ocr delegate` jako zależność npm (deterministyczny wybór plików — ledger pokrycia w prozie robi to samo bez instalacji), grupowania plików przez LLM (u nas tylko przy tierze L, ręcznie), wykluczania testów z recenzji, cichego kasowania znalezisk `low`. Odłożone: pomiar precyzji/recallu recenzenta na AACR-Bench (wskaźnik w README), szablon `ASSURANCE_CASE.md` dla `backend-security-coder`.

- `agents/code-reviewer.md`: **Effort tier** — `git diff --stat` decyduje: **S** (≤3 pliki, <100 linii) = 7 osi, bez planu, jedno przejście, pokrycie jedną linią, Strengths jedną linią; **M** (≤10 plików, ≤400 linii) = plan ryzyk + tabela pokrycia; **L** = jednostki recenzji ≤10 plików (producent↔konsument, interfejs+implementacja, warianty i18n/config) + drugie przejście per jednostka BEZ planu („plan z przejścia 1 jest sufitem pokrycia"), stop gdy nic nowego; ścieżka wrażliwa (pieniądze/VAT/auth, migracje, CI, manifesty) podnosi tier o jeden. **§2 Risk plan** (M/L): `[high|medium|low] gdzie — co — skutek → komenda — co potwierdza/obala`; ryzyko bez wykonanego pomiaru zostaje PLAUSIBLE; `(none)` legalne; plan to podłoga, nie sufit. **§6**: każde znalezisko cytuje verbatim linię `+` z diffu (numery linii dryfują, cytat nie) + etykietę CONFIRMED/PLAUSIBLE/LATENT; **ledger pokrycia** — każdy plik ze stat kończy jako `reviewed` lub `skipped(<powód>)` (generated/vendored/binary/secret-bearing; plik z sekretami nigdy nie cytowany), implementacja nie pokrywa interfejsu/configu/szablonu/testu, „mniejszy plik w grupie" to nie powód. **By file type** — tabela dla `.github/workflows` (`pull_request_target`+checkout PR head, `${{ github.event.* }}` w `run:`, akcje bez SHA, brak `permissions:`, brak timeoutu), `composer.json` (`allow-plugins` wildcard, klasa prod tylko w `autoload-dev`, `config.platform` maskujące niezgodność, `secure-http`, `*`/`dev-*` bez locka, brak `ext-*`), `package.json` (narzędzie w `scripts` bez `devDependencies`, `latest`, duplikat dep/devDep, `postinstall`), PHP (`isset` vs `array_key_exists`, `foreach` by-ref bez `unset`, `@`, transakcja z wczesnym `return`, blokada sesji przez wolne I/O, identyfikatory `ORDER BY` → allowlist, `.phtml` — potwierdź czy helper już escapuje). **Output**: werdykt jako OSTATNIA linia (pole decyzji przed polem uzasadnienia = model pisze „nie powinienem tego usuwać" w uzasadnieniu, a id zostaje w decyzji — zmierzone przez OCR na jego filtrze), sekcja `### Coverage`, tier w Scope. **Principles**: nie raportuj tego, co PHPStan/Psalm/ESLint/tsc/formatter już raportują, chyba że diff pokazuje skutek, którego narzędzie nie wyraża; znalezisko bezpieczeństwa wymaga ustalenia kontroli atakującego ORAZ kontekstu wyjścia przed wpisaniem.
- `skills/task-lifecycle/SKILL.md`: Step 2.1 — brief przekazuje `git diff --stat`, nie tier; recenzent sam się wymiaruje; nie prosić diffu S o „thorough review".
- `skills/audit-360/SKILL.md` (skill v1.2): §4 reguła 6 — przekroczenie budżetu 50 wywołań kończy plik `## Checkpoint` w pięciu sekcjach (Identified issues / Tool-call conclusions / Completed / Pending / Current focus) zamiast listy nieodwiedzonych obszarów — wnioski z narzędzi przeżywają, wznowiony specjalista nie grepuje drugi raz; budżet = obcięcie pokrycia, nie porażka. STEP 4 — **dyscyplina odrzucania**: konsolidator usuwa znalezisko tylko na gruncie A (kod nieobecny w cytowanym pliku, sprawdzone Readem) lub B (jedna linia kodu literalnie zaprzecza tezie, bez łańcucha wnioskowania); „nieweryfikowalne / niska wartość / wygląda ok" to NIE grunt; tematy chronione (współbieżność/TOCTOU, pieniądze/VAT, granice auth, zmiana kształtu trwałego/zachowania, utrata danych) nigdy nie odrzucane; każde odrzucenie = wiersz `audit/DROPPED.md` (`id | grunt | linia obalająca`). STEP 1 pkt 13 — szacunek kosztu przed dispatchem (liczba specjalistów × ~50 wywołań × ~150–250k na Opusa przy 20–40k LOC), ostrzeżenie PRZED STEP 2 gdy quota nie uniesie. STEP 7 — `RUN_META.md` z tabelą stanów per specjalista (`completed` / `truncated(budget)` / `failed(<klasa>)` / `reused`), stan końcowy audytu wyprowadzony z tabeli, delta wobec szacunku = szacunek następnego audytu. STEP 6 + best practice 11a — self-review uzgadnia zbiory id (findings = REPORT ∪ DROPPED). Załączniki: DROPPED.md, RUN_META.md.
- `skills/audit-360/prompts/10-consolidator.md`: STEP 2b — grunty A/B, tematy chronione, uzasadnienie PRZED decyzją, format DROPPED.md.
- `skills/audit-360/prompts/12-self-review.md`: check (h) — rekoncyliacja id, weryfikacja każdego wiersza DROPPED (`sed -n`), przywrócenie odrzuconego tematu chronionego; (h) w kryteriach FAIL.
- `skills/audit-360/prompts/02-php-pro.md`: kategoria G2 — semantyka poza zasięgiem kompilatora/PHPStan (isset/array_key_exists, foreach by-ref, `@`, otwarta transakcja, blokada sesji, identyfikatory SQL, brak timeoutu curl); zakaz duplikowania wyjścia phpstan/psalm bez pokazanego skutku; escaping tylko po potwierdzeniu kontroli atakującego i kontekstu.
- `skills/audit-360/prompts/09-deps-docs.md`: A.7a — semantyka manifestów i CI (composer.json / package.json / workflows) jak w tabeli recenzenta.
- `README.md`: akapit o AACR-Bench jako zbiorze referencyjnym do pomiaru precyzji/recallu recenzenta — reguła podnosząca tokeny bez ruchu precyzji nie zostaje.

## Run: 2026-09-15 (6b) — Partia 2.5 roadmapy KonkretnyTMS: wartości redagowane jako placeholdery, kontrola pozytywna przed zerem, kotwice jako komenda+wyjście, wzorce grep jako literały (v1.5.10)

Źródło: `POMIAR` z partii 2.5 (#620, #716). Wpis dopisany po fakcie przy pushu v1.5.11 — zmiany były w drzewie roboczym bez wpisu w logu.

- `agents/*.md` (10 agentów piszących + code-reviewer): reguła 5 procedury falsyfikacji — wartości, które zadanie redaguje/usuwa (hosty, skrzynki, ścieżki udziałów, klucze), w raporcie WYŁĄCZNIE jako `<host>`/`<mailbox>`/`<path>`; raport jest kopiowany do ledgera, issue i commita, więc każde cytowanie ponownie wycieka wartość. `POMIAR` (#620): builder redagujący `.env.example` wpisał do raportu prawdziwą skrzynkę i host mimo zakazu w briefie.
- `agents/code-reviewer.md`: `0 hits` jest pomiarem dopiero po kontroli pozytywnej (ten sam wzorzec na linii, która NA PEWNO pasuje); kontrola też zwracająca 0 = zepsute narzędzie, nie czysty kod.
- `skills/roadmapa/SKILL.md`: kotwica w roadmapie = komenda + surowe wyjście, nigdy liczba będąca już wnioskiem; ZERO wchodzi dopiero po drugim wzorcu (synonim/alias/wywołanie funkcji) — `POMIAR` (#716): `grep -c PHP_SAPI → 0` w trzech plikach, dwa z nich strzeżone przez `php_sapi_name()`. §7: wzorce przekazywane podagentowi to literały (`git grep -nF -f <plik>`), nie ręczne regexy z `\b`/`$FILES` — na macOS/zsh zepsuty wzorzec zwraca to samo `0` co czysty plik.
- `skills/task-lifecycle/SKILL.md`: wyjątek trivial fix-up rozszerzony na docs-only (dowód jedną komendą: `ls`/`git grep -nF` pokazujące poprawioną referencję).

## Run: 2026-09-15 (6) — Partia 2.4 roadmapy KonkretnyTMS: poprawki M, N, O, Q, R (v1.5.9)

Źródło: aneks analizy workflow w ledgerze partii 2.4 (3 issues, w tym #579, #580). `POMIAR`: ≈905 k tokenów / 6 podagentów (2.2 przy tych samych 3 buildach: 1,86 M → −51 %); okno G1 14 % → 26 %, bez kompakcji i handoffu; zero podagentów triage/verify (issues test-only były same pomiarem); oba znaleziska zmieniające kod pochodziły z mutantów kontrolnych recenzenta — recenzje opus (157 k / 138 k) zasadne. Poprawki A–L z v1.5.6 potwierdzone pomiarem. **P** (tryb `scripts/mutation-probe.sh` dla plików testowych — 3 agentów odtworzyło obejście, ~15 wywołań) zostaje po stronie repo KonkretnyTMS, nie toolkitu.

- `skills/task-lifecycle/SKILL.md`: **M** — Step 1 + hard rule 8(b): raport buildera przechodzi po numerowanych punktach zlecenia jako `DONE <path:line>` / `SKIPPED <powód>`; punkt nieobecny = SKIPPED, SKIPPED bez powodu = raport wraca (#580: sondy pominięte po cichu, złapane grepem orkiestratora, nie recenzją; w #579 wymóg w briefie zadziałał). **N** — Step 1 prompt buildera: każde „skopiuj wzorzec X" nazywa ZAPADKĘ wzorca i wymaga własnej zapadki dla kopii (#580: mechanizm skopiowany bez testu per drzewo → P1 + runda). **O** — Step 2 wyjątek „Trivial fix-up inline": test-only, ≤40 linii, kopia sąsiedniego wzorca, dowód jedną sondą mutacyjną → orkiestrator edytuje DIRECT z zacytowaną linią RED/GREEN; poza tymi czterema granicami → świeży fixer; wznowienie buildera nadal zakazane (hard rule 6). `POMIAR`: 3 fix-upy inline ≈25 k vs ≥300 k przez świeże fixery. **Q** — Step 2.5: mutant kontrolny recenzenta na kroku NIETKNIĘTYM przez diff (sąsiednia gałąź / drzewo / noga tego samego guardu).
- `agents/code-reviewer.md`: **Q** — overlay: mutant kontrolny na nietkniętym kroku jako stały wymóg, nie opcja.
- `skills/writingplans/SKILL.md`: **N** — Per-Task Template „Approach": wzorzec do skopiowania + jego zapadka; kopia dostaje własną zapadkę w tym samym zadaniu.
- `skills/roadmapa/SKILL.md`: **R** — blok odroczenia: komentarz przez `--body-file`; nota owner-at-keyboard: mechanika zamknięcia `gh issue comment --body-file` + `gh issue close --reason completed`, nigdy inline `--comment "<markdown>"` (zsh parse error, zamknięcie nie nastąpiło). Fraza zapadki `What the chain must not do` i blok wykonywalny bez `git merge` — bez zmian.
- `skills/issue-pipeline/SKILL.md`: **R** — Step 1 ALREADY-FIXED: ta sama forma `gh`.

## Run: 2026-09-15 (5) — Adaptacje z przeglądu repo mattpocock/skills: `retro`, `resolving-merge-conflicts`, pętla sprzężenia w debugowaniu, test tautologiczny, scope creep (v1.5.8)

Źródło: przegląd całego repo `github.com/mattpocock/skills` (skille `retro`, `resolving-merge-conflicts`, `diagnosing-bugs`, `tdd`, `code-review`, `codebase-design`, `writing-for-agents`). Wybrane dwa zestawy: „post-wave" (zero tokenów w fali) i „discipline upgrades" (+~1 KB w `systematic-debugging` przy wyzwoleniu). NIE przejęto: `to-spec`/`to-tickets`/`AGENT-BRIEF` (reguła „bez ścieżek plików" sprzeczna ze zmierzoną regułą K roadmapy), dwuagentowego `code-review` (2× spawn), `DESIGN-IT-TWICE` (3× spawn), `handoff` (roadmapa §5 jest nadzbiorem), listy smelli Fowlera (tokeny na agencie opus przy niskiej wydajności na naszych znaleziskach). Odłożone do osobnej decyzji: `brainstorming` → rundy frontier z rekomendowaną odpowiedzią; `domain-modeling` + `CONTEXT.md` (próba z pomiarem w KonkretnyTMS); hook `git-guardrails` na poziomie projektu.

- `skills/retro/SKILL.md` (**nowy**, user-invoked): retrospektywa fali/partii/sesji — ledger + transkrypty podagentów (tabela z `~/.claude/projects/<slug>/*.jsonl` przez skrypt do `.claude/tmp/retro-<data>.tsv`, nie do kontekstu) → siedem kategorii (nawigacja, kontrole automatyczne, standardy → recenzent nie builder, ekonomia narzędzi, no-opy i sedyment, dostęp do informacji, mechanika relay) → ranking kandydatów, każdy z POMIAR + plik + gotowa treść reguły; polityka UPDATE_LOG wbudowana (bez `model:`, bez newsów); nie aplikuje niczego sam.
- `skills/resolving-merge-conflicts/SKILL.md` (**nowy**): hunk po hunku wg intencji z pierwotnych źródeł (commit, issue, wiersz ledgera), oba zamiary zachowane gdy dotyczą różnych spraw, trade-off zapisany gdy sprzeczne; bez `--abort`, bez `checkout --ours/--theirs` na cały plik; pliki lock regenerowane, nie łączone ręcznie; kontrole projektu w kolejności z `CLAUDE.md`, pełna suita pod slotem w tle; konwencja komunikatu merge (marker `[roadmapa]`); bez push.
- `skills/systematic-debugging/SKILL.md`: Faza 1 krok 2 = **pętla sprzężenia** — drabinka 9 sposobów + HITL jako ostatni; kryterium ukończenia: JEDNA komenda już uruchomiona, red-capable / deterministyczna / szybka / uruchamialna przez agenta; brak pętli → stop i prośba o środowisko/artefakt; **minimalizacja** do elementów nośnych. Faza 3: 3–5 rankowanych falsyfikowalnych hipotez (predykcja każda), pokazane użytkownikowi gdy obecny, testowane po jednej z disproof-first (bez zmiany). Faza 4: test regresji z minimalnego repro na seamie odtwarzającym prawdziwy wzorzec błędu; brak poprawnego seamu = znalezisko; logi debug z tagiem `[DEBUG-xxxx]` i sprzątanie przez grep; re-run pętli na oryginalnym scenariuszu; potwierdzona hipoteza w commit message. Checklist + tabela wyjścia z fazy zaktualizowane. `scripts/hitl-loop.template.sh` (nowy).
- `skills/test-driven-development/SKILL.md`: wiersz „Independent" w tabeli dobrych testów — **test tautologiczny** (oczekiwana wartość policzona tak jak kod, snapshot tą samą ścieżką, stała vs stała) zostaje GREEN pod każdym mutantem; „vertical, not horizontal" — jeden test → jedna implementacja, nie wszystkie testy z góry.
- `agents/code-reviewer.md`: test tautologiczny → CRITICAL (= brak testu, łamie regułę mutantów z overlayu); oś G nowy wiersz **Scope creep** — zachowanie, o które nikt nie prosił, i wymagania brakujące/częściowe, z cytatem linii specu.
- `agents/refactoring-orchestrator.md`: faza mapowania — **deletion test** (usunięcie modułu: złożoność znika = indirection, złożoność wraca u N wywołujących = moduł zarabia na siebie); jeden adapter za seamem = seam hipotetyczny, dwa = realny.
- `README.md`: wiersze `/retro`, `resolving-merge-conflicts`; opis `systematic-debugging` zaktualizowany.

## Run: 2026-09-15 (4) — Adaptacje z przeglądu repo JuliusBrussee/caveman: skill `migration`, drabinka reuse, warunki Entry/Stop, kontrakt raportów podagentów (v1.5.7)

Źródło: przegląd całego repo `github.com/JuliusBrussee/caveman` (skille `migration`, `native-core.md`, `lean-build`, `cavecrew-builder`/`-reviewer`, `registry.json`) pod kątem luk w toolkicie. Zestaw „core" — zero zmian w mechanice `roadmapa` (zapadka `RoadmapaSkillLatchTest` nietknięta), zero zmian `model:`, tokeny neutralne (+~300 przy wyzwoleniu `migration`, +~40 na skill dyscypliny). NIE przejęto: trybu `/caveman` (koszt fali to cache-read kontekstu podagentów, nie output — `POMIAR` task-lifecycle reguła 6: 503 M cache-read; JetBrains: 8,5 % outputu w kodowaniu agentowym, brak opublikowanego kosztu netto), `cavecrew-reviewer` (brak bramek disproof-before-verdict i mutantów), kompresji `roadmapa/SKILL.md` (uzasadnienia `POMIAR` są nośne). Odłożone do osobnej decyzji: agent `locator` (haiku, kontrakt cytowań), pomiar `subagent-tax` (prefiks schematów MCP per spawn), skill `commit-message`.

- `skills/migration/SKILL.md` (**nowy**): mapa czytelników/pisarzy z `file:line` przed edycją, kształt danych z dowodu fizycznego, okno kompatybilności; ścieżka w przód (idempotentna) i rollback (przećwiczony na kopii); expand → migrate → verify → contract, Contract wyłącznie jako osobno zlecony etap, kroki destrukcyjne autoryzowane osobno; Entry/Stop w nagłówku.
- `agents/code-reviewer.md`: overlay — CRITICAL za zmianę kształtu trwałego/publicznego bez nazwanej ścieżki rollbacku lub z niezleconym krokiem Contract (`DROP`, usunięcie kolumny/pola, kasowanie danych).
- `skills/executingplans/SKILL.md`: „Reuse ladder" przed wyborem DIRECT/AGENT — 1) zachowanie istnieje (Canon) → użyj; 2) odpowiedzialna warstwa/helper → rozszerz tam; 3) stdlib/framework/DB/zależność → użyj; 4) mała nowa implementacja przy niezmienniku; 5) struktura blokuje własność → refactor jako osobne zadanie przed feature'em. Pytania do użytkownika tylko o wybory publiczne/bezpieczeństwa/danych/rozliczeń/trudno odwracalne.
- `skills/test-driven-development`, `systematic-debugging`, `verification-before-completion`, `verify-e2e`: linie **Entry** / **Stop** pod „Announce at start" (wzorzec `entry_condition`/`stop_condition` z `registry.json` caveman) — sprawdzalne wyjście per etap dla orkiestratora.
- `skills/task-lifecycle/SKILL.md`: hard rule 8 — kontrakt raportu podagenta: pierwsza linia = token terminalny (builder `done.` / `too-big.` / `ambiguous.` / `needs-confirm.` / `regressed.`; recenzent `No issues.` lub werdykt; weryfikator `VERDICT:`), znaleziska `path:line` z etykietą MEASURED/INFERRED, bez narracji wywołań, bez wymyślonych skrótów (`cfg`/`impl`/`req`) i łańcuchów strzałek — tokenizer dzieli je jak pełne słowo, zero oszczędności. Step 1: builder raportuje w tym kontrakcie; `migration` na liście skilli dyscypliny buildera.
- `skills/issue-pipeline/SKILL.md`: monitor-by-exception czyta pierwszą linię raportu — eskalacja tylko przy `ambiguous.` / `needs-confirm.` / `BLOCKED`.
- `agents/refactoring-orchestrator.md`: „Return report format" briefu — token terminalny, `file:line` najpierw, bez narracji.
- `README.md`: wiersz `migration` w tabeli skilli dyscypliny, reguła 3a, zdanie o Entry/Stop.

## Run: 2026-09-15 (3) — Analiza tokenów partii 2.2/2.3 roadmapy: dwanaście poprawek A–L (v1.5.6)

Źródło: aneksy analizy workflow w ledgerach KonkretnyTMS `docs/plans/zrealizowane/2026-09-15-roadmapa-partia-2-2-ledger.md` (A–F) i `…-partia-2-3-ledger.md` (G–L). `POMIAR`: partia 2.2 = ~1,86 M tokenów / 16 podagentów na 3 issues; partia 2.3 = ~483 k / 4 podagenty na 3 issues (triage #511 sonnet 75 k za jedno zdanie; pełna suita w tle 0 tokenów podagenta wobec 60–100 k per przebieg w 2.2). Wszystkie zmiany to REGUŁY z pomiarem w treści, żadna nie zmienia `model:` ani nie dodaje sekcji newsowych.

- `skills/roadmapa/SKILL.md`: **K** — §3 każdy „gotowy" artefakt w `Zrobione`/`Zostało` niesie ścieżkę w repo albo etykietę `NIE zmaterializowane` (#698: fikstury „już napisane" istniały tylko w raporcie podagenta); **E** — §4 triage G1: issue ≤3 komend lub będące samo pomiarem robi G1 inline, jeden `Explore` na 2–3 proste issues, dedykowany podagent tylko dla śladu po korpusie; **L** — §4 sondy HTTP na produkcję wyłącznie na udokumentowaną domenę, nieoczekiwane `200` potwierdzone ciałem odpowiedzi (`192.168.3.2` serwuje inną aplikację z catch-all 200); **H** — §4 pełna suita: forma preferowana `run_in_background` + stdout do pliku + odczyt tylko `grep -E "NAZWY|Configuration:|^Tests:|^OK"` + `comm -3` + `ci-parity-check.sh`, podagent tylko gdy tło niedostępne; akapit „deliberately NOT on this list" dostosowany; **F** — §4b nota „owner-at-keyboard": jawne polecenie właściciela w sesji G1 autoryzuje merge z markerem `[roadmapa]` i `gh issue close` dla TEJ partii — to instrukcja, nie tryb; nie deklaruje się w roadmapie, nie przechodzi na G2+. Proza bez `git merge` w bloku wykonywalnym — zapadka `RoadmapaSkillLatchTest` zielona.
- `skills/task-lifecycle/SKILL.md`: **I** — Step 0 Trivial obejmuje diff test-only ≤10 linii z jednokomendową sondą mutacyjną (edycja DIRECT legalna tylko z zacytowaną linią RED/GREEN); **A** — Small test-only / prod ≤10 linii poza modułami wrażliwymi pomija Step 4 (self-audit + run celowany = weryfikacja); **D** — Step 2 prompt fix-upu: znaleziska verbatim + proponowany diff recenzenta + wymagany dowód + zakaz czytania poza znaleziskami i re-recenzji reszty; **J** — Step 2.5 diff test-only: recenzent powtarza ≥1 mutant buildera + ≥1 mutant KONTROLNY na własnej kopii, raport zastępuje Step 4.
- `agents/code-reviewer.md`: **J** — overlay: przy diffie test-only recenzent sam odtwarza mutanty (kopia, nie plik śledzony; `sed` bez zmiany = no-op, GREEN nic nie dowodzi); **B** — każda liczba w znalezisku cytuje komendę, inaczej INFERRED bez prawa do CONFIRMED.
- `agents/php-pro.md`: **C** — Context economy pkt 5: porównanie z `main` przez `git show main:<ścieżka>` / `git diff main..HEAD`, nigdy worktree ani kopia pliku.
- Po stronie repo KonkretnyTMS (nie w toolkicie): `scripts/mutation-probe.sh` (**G**), notatka w `.claude/rules/test-rules.md`, wyjątek Trivial w `CLAUDE.md` §4c (**I**).

## Run: 2026-09-15 (2) — `skills/roadmapa/SKILL.md` po angielsku, spójny z tor-orkiestratora.md (v1.5.5)

Źródło: `KonkretnyTMS@5056634c1` (2026-09-13, tłumaczenie skilla na angielski + zapadka `tests/Config/RoadmapaSkillLatchTest.php` przepięta na frazę `What the chain must not do`). Plik NIE poszedł z v1.5.4, bo w chwili przenoszenia repo projektu miało już wersję polską z syncu `f1b8da338` (konflikt merge rozwiązany `--theirs`). Skutek: zapadka czerwona w CI na deployu v3.78.0 (Tests #34952880368). Wersja angielska jest NADZBIOREM polskiej z `5b6479f` — zawiera opis frontmatter z upstreamu i akapit o delegowaniu pełnej suity podagentowi (§4 „You do NOT run the full suite yourself"). `POMIAR`: `git diff --stat 74a1d5343 f1b8da338 -- SKILL.md` → 9 insercji, obie zmiany obecne w wersji angielskiej.

- `skills/roadmapa/SKILL.md`: treść angielska 1:1 z `KonkretnyTMS@add0b67fb`; `references/tor-orkiestratora.md` (już angielski od v1.5.4) bez zmian.

## Run: 2026-09-15 — Przeniesienie lokalnych adaptacji cykli z KonkretnyTMS (v1.5.4)

Źródło: sync `sync-claude-toolkit` z 2026-09-15 (`99c42ce30` w KonkretnyTMS) nadpisał `cp -rf` osiem plików, których ulepszenia żyły wyłącznie w repo projektu (commity `4c8373aef`, `1475a20ca`, `e947c6c58`, `518f37415`, `5056634c1`) — każdy kolejny sync zdejmowałby je ponownie. Przeniesione 1:1 z `KonkretnyTMS@ece8354fe`:

- `agents/php-pro.md`, `python-pro.md`, `nextjs-pro.md`: `tools:` + `SendMessage, Skill` (raport końcowy przez SendMessage do orkiestratora, wywołanie skilla z ograniczoną listą narzędzi); `refactoring-orchestrator.md`: + `SendMessage`.
- `skills/issue-pipeline/SKILL.md`: równoległość ⇒ worktree (zawsze), reguła zasobów współdzielonych (slot pełnej suity, port per worktree z dyskryminatorem, Chrome vs Playwright), jeden agent na jednostkę pracy + raport przez SendMessage + zakaz pollingu orkiestratorów, `model:` orkiestratora wg polityki projektu (domyślnie opus), „jeden lifecycle = jedno issue" z jedynym wyjątkiem bundle, kolumna Tip SHA i done-label w tabeli, odsyłacz do dokumentu lokalnych adaptacji projektu.
- `skills/task-lifecycle/SKILL.md`: hard rule 6 (fix-upy do ŚWIEŻEGO agenta, nigdy wznowienie), raport przez SendMessage, worktree.
- `skills/verify-e2e/SKILL.md`: „które drzewo weryfikujesz" — dyskryminator docroot przy pracy w worktree.
- `skills/roadmapa/references/tor-orkiestratora.md`: wersja angielska (mniej tokenów), spójna z SKILL.md roadmapy.

---

## Run: 2026-09-14 (2) — roadmapa: jedno issue = jeden task-lifecycle, plan tylko dla klasy Large (v1.5.3)

Źródło: decyzja właściciela po pomiarze kosztów (fala L: ~68 $/issue; partia issue-pipeline: ~70 $/issue — struktura kosztu identyczna) i dźwignia E planu kosztowego KonkretnyTMS (`docs/plans/zrealizowane/2026-09-11-koszt-tokenow-lancucha-roadmapy.md` §3: dwóch specjalistów na Opusie audytowało plan 20-liniowej zmiany; szacunek −40 % na takim issue).

### Updated
- **roadmapa §4:** faza `plan` = intake wg `task-lifecycle` Step 0 — generacja klasyfikuje issue (Trivial/Small/Standard/Large) ze świeżych kotwic i pisze blok kontekstu; `/writingplans` + Pass 2 WYŁĄCZNIE dla Large (kryteria Step 0 + drzewo decyzyjne projektu: >3 kroków, domena regulowana); pozostałe klasy przechodzą do `exec` w tej samej generacji. `exec` = Steps 1-3 (builder, pętla review z capami — Small: jedno przejście albo self-audit wg progu projektu — security, bramka pre-commit). `verify` = Steps 4-5, obowiązkowa dla KAŻDEJ klasy. Generacja jest orkiestratorem task-lifecycle (nie pisze kodu, świeży nazwany podagent na jednostkę pracy, `SendMessage` po nazwie).
- **roadmapa §2:** faza atomowa `writingplans` istnieje tylko dla Large.
- **roadmapa §3:** roadmapa niesie podpowiedź klasy z triage'u G1 (decyzja finalna przy intake); wiersz ledgera dostaje pole `Klasa:`.
- **task-lifecycle Step 0:** klasa Large rozszerzona o „projektowe drzewo decyzyjne kieruje do planu" (np. >3 kroków implementacji), żeby roadmapa i pipeline klasyfikowały tym samym kryterium.
- **roadmapa — krawędzie tokenowe (druga tura tego samego dnia):** (a) klasyfikacja przy intake to decyzja na kotwicach, nie eksploracja — w razie wątpliwości klasa tańsza, eskalacja do Large wyłącznie z pomiaru buildera (adnotacja `Reklasyfikacja:` w ledgerze); (b) Trivial zachowuje wyjątek DIRECT edit z task-lifecycle, verify świeżym podagentem tylko przy powierzchni użytkownika; (c) `exec` ma jeden bezpieczny punkt cięcia — po commicie buildera, przed recenzentem — z formatem wiersza `faza exec (CZĘŚCIOWA — …)`; (d) koszty faz z pomiaru fali L: plan z Pass 2 = 12-16 pp, exec = 5-6 pp, verify = 2-3 pp; (e) pole `Okno:` w wierszu ledgera z komendą mierzącą zużycie funkcją hooka (`relay_measure`), warunek 2 reguły końca fazy liczony z pomiaru; (f) pełna suita zdjęta z listy wykluczeń (biegnie w podagencie pod slotem; zajęty slot to warunek stopu §6, nie powód handoffu); (g) G1 deleguje sprawdzenie kodu przy triage'u do `Explore`/sonnet `triage-<nr>` (prompt z issue-pipeline Step 1) zamiast czytać kod we własnym oknie.

### Issues
- Nazwy faz `plan|exec|verify` zostają — istniejące ledgery i zapadka `tests/Config/RoadmapaSkillLatchTest.php` (KonkretnyTMS) grepują po nich. Zvendorowane ręcznie do KonkretnyTMS/.claude tego samego dnia.

---

## Run: 2026-09-14 — issue-pipeline / task-lifecycle: równoległość, zasoby współdzielone, kadencja (v1.5.2)

Źródło: przegląd obu skilli przed falą naprawy issues w KonkretnyTMS (141 otwartych). Sprzeczności wewnętrzne i luki zmierzone na tekście skilli + incydenty z pamięci sesji (checkout jednej gałęzi skasował niezacommitowaną pracę drugiego agenta; worktree bez `.env` dał fałszywy baseline; port :8080 serwował drzewo GŁÓWNE podczas weryfikacji gałęzi).

### Updated
- **issue-pipeline:** (1) „równoległość ⇒ worktree, zawsze" — warunek „jeśli builderzy kolidowaliby w jednym drzewie" był logicznie pusty, bo gałąź per issue nie może dzielić drzewa z inną gałęzią; (2) reguła zasobów współdzielonych poza plikami (baza dev, port aplikacji serwujący drzewo główne, jeden sterowany Chrome, budżet CI) z decyzją per zasób: slot / własna instancja / sekwencyjnie; (3) kadencja: jeden przebieg = jedna partia ≤3 issues, kolejna partia = nowe wywołanie z nowym „go" (usunięta sprzeczność „tylko wyjątki" vs „check-in po 3" vs „kolejna partia po raporcie"); (4) triage: `Explore`, `model: sonnet`, `name: triage-<n>`, pytanie o listę plików + flagi (baza / GUI / plik wspólny z inną issue); (5) orkiestrator per issue: `general-purpose`, `name: orch-<n>`, `model:` wg polityki projektu — domyślnie `opus` (Sonnet-orkiestrator to dźwignia F z planu kosztowego, dopuszczalna dopiero po teście A/B), szablon promptu z worktree, zasobami współdzielonymi, odsyłaczem do lokalnych adaptacji projektu, done-label zamiast zamykania issue, „procedura W CAŁOŚCI"; (6) sekcja „Jedno lifecycle = jedno issue" z jedynym wyjątkiem (bundle: ten sam plik + każde Trivial/Small + wspólna powierzchnia; liczy się jako N do capu); (7) tabela statusów z kolumną Tip SHA i listą pozostawionych worktree; (8) odsyłacz `executing-plans` → `executingplans` (skill nazywa się bez myślnika).
- **task-lifecycle:** (1) cap pętli review-fix ujednolicony: 2 Standard / 3 Large, sufit 3 (krok 2.3 mówił „2", hard rule 2 „3"); (2) reguła 7 / krok 1: `SendMessage` po nazwie tylko, gdy orkiestrator jest nazwanym podagentem — sesja główna dostaje task-notifications i nie ma nazwy; (3) jawny `model:` przy każdym spawnie (rejestr agentów bywa nieświeży); (4) klasa Small: próg recenzji z CLAUDE.md projektu wygrywa (self-audit zamiast reviewera); (5) strategia gałęzi: równoległe lifecycle → własny worktree, ścieżki absolutne, checklista worktree projektu przed pierwszym testem; (6) pełna suita = zasób współdzielony (slot, czytaj SWÓJ log); (7) verify: powierzchnia serwowana Z worktree + dyskryminator; (8) raport: tip SHA, done-label jako jedyny zapis do trackera; (9) odsyłacze `executingplans`.
- **verify-e2e:** akapit „które drzewo weryfikujesz" (docroot = worktree + dyskryminator); odsyłacz `executingplans`.

### Issues
- Zvendorowane ręcznie do KonkretnyTMS/.claude tego samego dnia; tam dodatkowo `docs/claude-reference/lokalne-adaptacje-cykli.md` (checklista worktree, zasoby współdzielone, modele, etykieta `status:do-scalenia`, wytyczne 1 issue = 1 lifecycle) i tabela macOS w `docs/VERIFICATION_ENV.md`.

---

## Run: 2026-08-30 — Klasa błędu „pomiar ≠ wniosek": procedura falsyfikacji u agentów piszących (v1.5.1)

Źródło: diagnoza agenta po fali 11 issues w KonkretnyTMS (2026-08-29/30). Sześciu agentów piszących popełniło ten sam błąd (jeden trzykrotnie): dwie prawdziwe przesłanki zmierzone, trzecia niezmierzona, wniosek fałszywy (403 CSRF vs globalny interceptor; `--exclude-group` vs plik w ogóle niezbierany przez suitę; „sieroty" vs `FK ON DELETE SET NULL`; „zdarzenia przepadają" vs logger łapiący `PDOException` piętro niżej). Reguły kodowały WNIOSKI z incydentów, nie PROCEDURĘ; jedyne miejsce łapiące klasę systematycznie to wymóg dowodu mutacyjnego (procedura, nie przestroga). code-reviewer (krok weryfikacyjny w definicji) wyłapał 5/6 — brakowało odpowiednika u piszących.

### Updated
- **Wszyscy agenci piszący** (php-pro, javascript-pro, test-automator, sql-pro, database-optimizer, mobile-pwa-developer, nextjs-pro, python-pro, backend-security-coder, debugger): wspólna sekcja „Discipline overlay — measurement vs. conclusion" — nazwana klasa, 4-krokowa procedura (teza → pomiar OBALAJĄCY → wykonaj → etykiety MEASURED/INFERRED w raporcie), zasada zleceń dwustronnych („ustal, czy X czy nie-X, i podaj, co rozstrzyga", nigdy „sprawdź, czy X"). debugger dodatkowo: krok 3/4 — zapisz obalenie przed uruchomieniem, root cause tylko po przeżytym obaleniu.
- **code-reviewer:** zasada „Disproof before verdict" — CONFIRMED tylko z pokazanym pomiarem obalającym; znalezisko od agenta piszącego bez etykiet MEASURED/INFERRED lub z niezmierzonym ogniwem → degradacja do PLAUSIBLE.
- **Skille (minimalnie, tylko formułowanie zleceń):** task-lifecycle — zlecenia weryfikacyjne dwustronne, PLAUSIBLE od recenzenta wraca jako zlecenie dwustronne, nie jako fix; issue-pipeline — triage „ustal, czy istnieje czy NIE" + nowy werdykt NOT-A-BUG z pomiarem obalającym; systematic-debugging — Faza 3 krok „najpierw obalenie", raport MEASURED/INFERRED.
- Nie ruszono: refactoring-orchestrator (ma już wymóg dowodu przeciwnego), workflow i reszta skilli (nie były przyczyną ani razu w fali).

### Issues
- Zvendorowane ręcznie do KonkretnyTMS/.claude tego samego dnia; tam dodatkowo nagłówek klasy w `.claude/rules/incident-lessons.md`, jednoliniówka w CLAUDE.md §4 i overlay w `skryba.md`.

---

## Run: 2026-08-19 — Audit-360 feedback loop (KonkretnyTMS) + token economy (v1.5.0)

> **SUPERSEDES wpis „2026-08-17 — stay uniformly on Opus".** Tamta analiza liczyła koszt po cenniku API (luka Opus/Sonnet ~1,7×) i na tej podstawie odrzuciła podział dwupoziomowy. Użytkownik pracuje jednak na **subskrypcji Max (limit kwotowy)**, gdzie zużycie liczone jest wg wagi modelu, a nie cennika API — Opus wypala limit wielokrotnie szybciej niż Sonnet — i decyzją użytkownika (19.08, po wypaleniu limitu Max20 w 2-3 dni) agenci piszący przechodzą na Sonneta. Ryzyko jakościowe adresują: review na Opusie (code-reviewer, backend-security-coder, refactoring-orchestrator), override `model: opus` dla WSZYSTKICH specjalistów w audit-360 oraz metryka z tamtego wpisu (liczba iteracji review w task-lifecycle — jeśli zadania zaczną wymagać 2-3 rund zamiast 1, wracamy do rozmowy z danymi).

### Updated
- **Modele:** agenci piszący → `sonnet` (php-pro, sql-pro, javascript-pro, test-automator, debugger, database-optimizer, nextjs-pro, python-pro, mobile-pwa-developer); `opus` zostaje: code-reviewer, backend-security-coder, refactoring-orchestrator. Skill audit-360 spawnuje specjalistów z jawnym override `model: opus` (polityka w SKILL.md §1).
- **Nowe reguły z audytu 360° KonkretnyTMS 19.08.2026 (AGENT_UPDATES.md, wzorce 1-9):** kanon Money/VAT + reguła kierunku dokumentu (php-pro, javascript-pro); trigger-scope + grep-all-writers przy rekordach finalnych oraz seeding z autorytatywnego słownika / legacy twins (sql-pro); raportowanie ZAKRESU narzędzia + liczniki SKIPPED zamiast gołego „zielono" (code-reviewer krok 6, test-automator, php-pro, javascript-pro, debugger); reguły dopasowania w configach — sonda 403-vs-404 zamiast czytania, allowlista katalogów (backend-security-coder, code-reviewer, php-pro); guard `PHP_SAPI` + zakaz inline poświadczeń w skryptach operatorskich (php-pro, backend-security-coder); autoloader przed pierwszym `exit` w cronach (php-pro, debugger); antywzorce testowe + próba mutacyjna (php-pro); martwe odwołania w dokumentacji (code-reviewer, projektowy skryba).
- **Ekonomia testów:** testy celowane w iteracji, pełna suita RAZ na bramce z raportem passed+skipped (php-pro, test-automator, task-lifecycle).
- **Skille:** task-lifecycle — klasa Small (diff <30 linii → 1 review pass), cap pętli 3→2, obowiązkowy Task-context block dla subagentów; verify-e2e — polityka dowodów (1 screenshot przy PASS, komplet przy FAIL, GIF na życzenie, API = dump tekstowy); issue-pipeline — cap 10→3 issues na przebieg; writingplans — Pass 2 warunkowy (>5 zadań lub domena regulowana, max 2 specjalistów); audit-360 — polityka modeli, `audit/RUN_META.md` (koszt/czas/utracone przebiegi), CHECK B mechaniczny (wszystkie symbole + sygnatury + weryfikacja file:line), path fidelity konsolidatora + addenda w prompts/10 i prompts/12.

### Removed (token economy)
- php-pro: sekcje Laravel/Symfony i zdublowany „Modern PHP Quick Reference" (~150 linii); sql-pro + database-optimizer: bloki newsów wersji baz (~80 linii); test-automator: katalogi narzędzi AI/API/perf (~25 linii); wszyscy: skumulowane stopki changelogowe.

### Issues
- Zmiany zvendorowane ręcznie do KonkretnyTMS/.claude tego samego dnia (kopie identyczne z pluginem).

---

## Run: 2026-08-17 — Model-class decision: stay uniformly on Opus; doc drift fixed

### Decided
- **Two-tier split (Sonnet producers / Opus gates) was evaluated and rejected.** All 12 agents stay on `model: opus`. No agent frontmatter changed in this run.

### Updated
- **skills/audit-360/SKILL.md**: the specialist table's Model column had drifted to a mix of `inherit` / `sonnet` / `opus` that stopped describing what actually ran once the 2026-08-01 run forced every agent to opus. Column corrected to the real value (`opus` throughout), with a note that the uniformity is deliberate and that any future row reading otherwise is a change someone made on purpose. Best-practice #8 reworded accordingly.
- **skills/lang-guidelines/SKILL.md + references/agent-template.md**: resolved a standing contradiction — SKILL.md required `model: inherit` in generated agents while its own template wrote `model: opus`. Both now say `model: opus` and point at the README rationale, so newly generated language experts land in the right class.
- **README.md**: new "Model class" section recording the decision and the reasoning behind it.
- **plugin.json / marketplace.json**: 1.4.3 → 1.4.4.

### Rationale
The question was whether to cut token cost by moving rule-driven producers to Sonnet ahead of the weekly-limit promotion ending. Three findings killed it:

1. **The price gap is much smaller than the previous Opus generation's.** At list pricing Opus 5 is $5/$25 per MTok against Sonnet 5's $3/$15 — about 1.7x, not the ~5x that made this trade obviously worthwhile in the past. (Sonnet 5 introductory pricing of $2/$10 runs through 2026-08-31, so the gap is temporarily ~2.5x.)
2. **The agents that must stay on Opus are most of the roster.** Anything whose mistakes are silent — `code-reviewer`, `backend-security-coder`, `debugger`, `refactoring-orchestrator` — plus anything whose output is irreversible once it runs — `sql-pro`, `database-optimizer` — cannot move. That is 6 of 12 before considering the risky cases, leaving roughly 15-20% total saving.
3. **The remaining candidates have no principled boundary.** `php-pro`, `python-pro`, `javascript-pro` and `nextjs-pro` all produce backend code; there is no rule that puts one on Sonnet and keeps another on Opus, so the choice is all-or-nothing rather than per-agent.

15-20% is not worth a quality question mark over backend code, migrations, and security-sensitive paths.

### If this is revisited
Revisit with data, not intuition. `task-lifecycle` Step 2 already reports review iterations per task, so a tier change is measurable: work that used to pass review in one round starting to need two or three is the signal that the smaller model is not carrying the task. Re-check the price gap first — this analysis is only valid while it stays near 1.7x.

### Issues
- None

---

## Run: 2026-08-01 — Set all toolkit agents to opus model class

### Updated
- **All agent frontmatter**: `model:` set to `opus` across every toolkit agent (was a mix of `inherit`/unset), so agents run on the Opus class regardless of the session model.
- **plugin.json / marketplace.json**: 1.4.1 → 1.4.2.

### Issues
- None

---

## Run: 2026-08-01 — Generalize nextjs-pro to be project-agnostic

### Updated
- **agents/nextjs-pro.md**: removed all assumptions inherited from the project it was created on (`aplikacja_portfel_inwestycyjny`): fixed stack list in the intro (Tailwind/Serwist/Zod/Vitest/Netlify/local JSON) replaced with a "discover the stack from `package.json` / `tsconfig.json` / `next.config.*` first" instruction plus a new Core Philosophy bullet ("The repository is the source of truth"); "this project's data layer is local JSON" → serverless-filesystem guidance for any host (Netlify/Vercel/Lambda as examples); hardcoded path aliases (`@config/*`, `@data/*`) → "check `tsconfig.json` paths"; "tsconfig here already runs strict…" → recommended baseline to verify; project CSP claims → general security-header guidance; "Vitest 4 + RTL" → "use the repo's existing runner"; domain-specific coverage list (rates, inflation, indicators) → generic (calculations, parsing, validation); Tailwind/Serwist/Netlify ecosystem notes gated behind "only when `package.json` shows the project uses it"; checklist items reworded (fs writes conditional on serverless target, scripts read from `package.json`).
- **plugin.json / marketplace.json**: 1.4.0 → 1.4.1.

### Rationale
The agent was generated during an audit of a specific Next.js project and carried that project's stack as hard facts ("this project", "this repo"). As a marketplace plugin agent it runs against arbitrary repositories — stated assumptions that are false in a given repo (e.g. "your data layer is local JSON") are worse than no assumption. Same generalization pass previously applied to systematic-debugging (4aa5edf).

### Issues
- None

---

## Run: 2026-08-01 — New language expert: nextjs-pro

### Added
- **agents/nextjs-pro.md**: Next.js 15.5+ / React 19.2 / TypeScript 5 expert (App Router, Server Components, Server Actions), generated via `/lang-guidelines` with web research. 15 documented AI failure modes with ❌/✅ examples, each grounded in a source: Pages Router APIs smuggled into App Router (`getServerSideProps`, `next/router`, `next/head`); synchronous `cookies()`/`headers()`/`params`/`searchParams` (async since Next 15); assuming `fetch` and GET Route Handlers are still cached by default (they are not); Server Actions treated as trusted instead of public HTTP endpoints; middleware as the sole auth layer (CVE-2025-29927); server data leaking into Client Components via props; `"use client"` at page/layout level instead of leaves; `forwardRef` in React 19; `useEffect` for initial data; hydration mismatches from nondeterministic render; mutations without `revalidatePath`/`revalidateTag`; hallucinated imports; `redirect()`/`notFound()` swallowed by try/catch; `.parse()` at the boundary with `any` behind it; filesystem writes on serverless. Ecosystem notes cover Tailwind 4, Serwist/PWA caching pitfalls, Zod 4, Netlify deployment.

### Updated
- **README.md**: nextjs-pro added to the Language Experts table.
- **plugin.json / marketplace.json**: 1.3.0 → 1.4.0.

### Rationale
Toolkit had no specialist for the JS meta-framework stack. `javascript-pro` covers language-level JS/TS but not framework semantics — and Next 15 / React 19 are exactly where LLM training data actively fights correct code (years of Pages Router and Next 13/14 content dominate), so a dedicated agent carries the most weight per token.

### Origin
Created during an `/audit-360` run on the `aplikacja_portfel_inwestycyjny` project (Next.js 15.5.22 + React 19.2.4 + Serwist PWA on Netlify), where the specialist-selection step found no matching language expert.

### Issues
- None

---

## Run: 2026-08-01 — Monthly maintenance sweep

### Updated
- **agents/python-pro.md** (411→415 lines): Corrected version status (Python 3.14 stable / 3.15 beta, RC1 due 2026-08-04, final 2026-10-01 per PEP 790; 3.10 EOL Oct 2026). Added CVE-2026-5713 (profiling/asyncio-introspection privilege escalation) and CVE-2026-4786/6100 (CERT-FR CPython RCE advisory). Noted incomplete-mitigation follow-ups for CVE-2026-4519 and CVE-2026-0672. Added slopsquatting persistence note and an architecture-persona tip for AI-generated modules.
- **agents/sql-pro.md** (500→528 lines): Added new PART 2.5 "Common AI-Generated SQL Failure Patterns" (fan-out aggregation, hallucinated schema, WHERE-scope drift on iteration, ~78% zero-shot text-to-SQL accuracy benchmark). Confirmed PostgreSQL 19 Beta 2 (July 16, 2026) feature list. Confirmed MySQL 9.6 (Innovation) and 9.7 LTS (first LTS since 8.4) feature detail. Added 2026 CVE precedents (CVE-2026-44381 MISP, CVE-2026-42208 LiteLLM) to injection guidance.
- **agents/database-optimizer.md** (246→268 lines): Updated PostgreSQL 19 to confirmed Beta 2 with full feature list (pg_plan_advice, native REPACK, parallel autovacuum, logical replication of sequences, SQL/PGQ, GROUP BY ALL). Added MySQL 9.7 LTS (Hypergraph Optimizer now in Community Edition, cpuset cgroup support, HA telemetry now free). Added vector (HNSW/IVF) index row. Added "Redis-compatible alternatives" section (Valkey, Dragonfly, Garnet, Kvrocks).
- **agents/mobile-pwa-developer.md** (105→110 lines): Added Declarative Web Push (Safari 18.4+/18.5+, no service worker required). Documented Safari's 7-day inactivity data-eviction gotcha (Home Screen installs exempt). Added common AI-generated Service Worker scope/stale-HTML pitfall plus fix, and two corresponding Quality Checklist items.
- **agents/test-automator.md** (200→217 lines): Refreshed Vitest to 4.1+ (AST-based coverage remapping, shared vite.config) and noted Playwright overtaking Cypress as 2026 default. Added new "AI-Powered Test Generation & Execution Tools" section (Gartner's first AI-testing Magic Quadrant, autonomous generation, self-healing execution, visual validation, AI failure triage). Added "just click accept" anti-pattern for AI-suggested test fixes.
- **skills/new-project/SKILL.md** (477→486 lines): Added SBOM generation (CycloneDX/SPDX), automated dependency updates (Dependabot/Renovate) with lockfile pinning, named secret-scanning tools (gitleaks/trufflehog/detect-secrets), vulnerability scanning (Trivy/Grype/pip-audit) as a CI gate, MFA-on-publish-rights rule, and a postgres:18+ Docker volume-path gotcha.

### Skipped (up to date, < 30 days)
- **backend-security-coder.md**: Last updated 2026-07-05 (27 days)
- **code-reviewer.md**: Last updated 2026-07-07 (25 days)
- **debugger.md**: Last updated 2026-07-05 (27 days)
- **javascript-pro.md**: Last updated 2026-07-05 (27 days)
- **php-pro.md**: Last updated 2026-07-05 (27 days)
- **refactoring-orchestrator.md**: Last updated 2026-07-07 (25 days)

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- audit-360/SKILL.md
- issue-pipeline/SKILL.md
- systematic-debugging/SKILL.md
- task-lifecycle/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md
- verify-e2e/SKILL.md
- lang-guidelines/SKILL.md — meta-skill describing how to research/generate other agents; no "Last updated" of its own and no external technology domain to research (process definition, same category as brainstorming/writingplans/executingplans)

### Deferred to next run
- None — all 6 evolving files processed within the 10-file cap

### Issues
- None — all WebSearch queries returned useful results, no rephrasing needed, no git conflicts, all diffs self-reviewed clean (frontmatter intact, no deletions, line counts grew)

### Next run priorities
- backend-security-coder.md, debugger.md, javascript-pro.md, php-pro.md (last updated 2026-07-05 — will be ~57 days by next run)
- code-reviewer.md, refactoring-orchestrator.md (last updated 2026-07-07 — will be ~55 days by next run)

---

## Run: 2026-07-17 — Autonomy layer: task-lifecycle, issue-pipeline, verify-e2e

### Added
- **skills/verify-e2e**: Surface-level verification in a fresh adversarial subagent (GUI → browser + screenshots, API → real HTTP, CLI/cron → execution). Evidence artifacts mandatory; BLOCKED protocol appends missing prerequisites to project `docs/VERIFICATION_ENV.md` so the verification environment compounds. Rationale: smarter models fake completion more convincingly (Fable 5 system card) — isolation + adversarial prompt is the countermeasure.
- **skills/task-lifecycle**: Orchestrated end-to-end cycle for one task: build (specialist subagent) → code-review loop with auto-fix of CRITICAL/HIGH/MEDIUM (cap 3) → conditional security pass (backend-security-coder) → verify-e2e in fresh subagent (cap 3) → report package. Main session never writes code; feature-branch policy for deploy-from-main projects; merge/push/deploy always the user's decision.
- **skills/issue-pipeline**: Batch remediation: collect (gh issues / audit-360 findings / list) → mandatory triage on HEAD (stale-finding kill + fresh file:line anchors, per KNOWLEDGE lesson "audit older than commit delta") → file-disjoint batching (2-3 wide, executing-plans 4 conditions, DB issues never parallel) → one task-lifecycle orchestrator per issue on `agent/issue-<n>` → monitor by exception → status table. Cap 10 issues/run. Automates the previously manual audit → issues → orchestrators flow.

### Updated
- **verification-before-completion**: claim table row + integration note — verify-e2e is the OUTER gate (user surface), this skill the inner (commands/tests).
- **executingplans**: final group now includes verify-e2e for user-facing changes; companion-skills list extended (verify-e2e, task-lifecycle).
- **audit-360**: Quick-start step 13 — optional remediation handoff: P0/P1 → `gh issue create` → issue-pipeline.
- **README.md**: new skills documented + "Autonomy Layer" section (orchestration diagram, hard caps, BLOCKED-as-first-class, audit→issues→pipeline loop).
- **plugin.json**: 1.2.0 → 1.3.0; marketplace.json plugin entry aligned to 1.3.0 (was stale at 1.1.0).

### Source
- Boris (Claude Code) "steps of AI adoption" levels 1-4, via analyzed video transcript (2026-07-17): self-verification loop on the user surface, isolated verifier subagents, severity-gated auto-fix review loops with caps, orchestrator-not-builder main session, verification-environment investment, monitor-by-exception.

### Issues
- None

---

## Run: 2026-07-07 — Manual restructure: refactoring-specialist → refactoring-orchestrator

### Replaced
- **refactoring-specialist.md → refactoring-orchestrator.md**: Role changed from hands-on refactoring executor to end-to-end orchestrator (per user-authored prompt). Runs phases 0–6: mandatory backup with manifest, behavioral baseline (tests + static analysis), audit, plan with uncertainty gate, delegated execution (never codes itself — spawns php-pro/javascript-pro/sql-pro/test-automator via nested Agent tool, supported since Claude Code v2.1.172), equivalence verification (baseline diff + before/after regression + 7-axis code-reviewer pass), sign-off with user-confirmed backup release. Carried over from the old agent as "briefing knowledge" injected into subagent assignments: AST-or-nothing bulk transformation rules (incl. 2026-05-15 sed incident), PHP/JS refactoring pitfalls, large-file split patterns (Extract Class / Strangler Fig / Branch by Abstraction), smell table, refactoring catalog, metrics. Added read-only audit mode for audit-360 compatibility. No `Edit` tool by design.
- **audit-360**: `prompts/06-refactoring-specialist.md` renamed to `prompts/06-refactoring-orchestrator.md` (subagent_type updated, READ-ONLY audit mode noted); SKILL.md references updated.
- **executingplans / new-project / README**: agent routing references updated to `refactoring-orchestrator`.
- **plugin.json**: version 1.1.0 → 1.2.0.

### Issues
- None

---

## Run: 2026-07-01

### Updated
- **javascript-pro.md**: Updated Node.js LTS to v24+ (V8 13.6, Explicit Resource Management `using`/`await using`, `RegExp.escape()`, `Error.isError()`, built-in SQLite, npm 11). Added TypeScript 6.0 (March 2026: `strict` default, ES5 target removed, final JS compiler; TS 7.0 Go rewrite in development). Added `using`/`await using` pattern section.
- **mobile-pwa-developer.md**: Updated platform support — iOS Safari 26+ (WebGPU enabled by default, `<model>` 3D, Digital Credentials, Trusted Types, File System WritableStream, Home Screen default to web app mode), Safari 27 beta (Grid Lanes/CSS masonry, Customizable Select), Chrome 148+ (Prompt API stable, PWA origin migration, WebMCP origin trial). WebGPU reached Baseline status (January 2026, ~77% global coverage). WebNN updated CR but not production-ready (estimated 2027). Added Service Worker Static Routing API.
- **sql-pro.md**: Added PostgreSQL 19 Beta 1 (June 2026, GA expected September 2026). Added MySQL 9.6/9.7 quarterly innovation releases. Updated Modern Systems — CockroachDB 25.2 (distributed vector indexing), TiDB X (unified vector/graph/JSON/SQL engine + MCP integrations), Neon/Databricks Lakebase.
- **code-reviewer.md**: Added ProjectDiscovery 2026 stat (AI code 1.88× more likely to introduce vulnerabilities). Added specific slopsquatting incidents — `unused-imports` npm (~233 weekly downloads), `huggingface-cli` (30K+ downloads, Alibaba incident), CSA April 2026 autonomous agent risk. Added iterative refinement degradation anti-pattern (Arxiv 2506.11022).
- **database-optimizer.md**: Added PostgreSQL 19 Beta 1 (June 2026, GA expected September 2026).

### Skipped (up to date, < 30 days)
- **backend-security-coder.md**: Last updated 2026-06-01 (30 days)
- **debugger.md**: Last updated 2026-06-01 (30 days)
- **php-pro.md**: Last updated 2026-06-01 (30 days)
- **python-pro.md**: Last updated 2026-06-01 (30 days)

### Skipped (no significant new findings)
- **refactoring-specialist.md**: Last updated 2026-05-15 (47 days) — no significant new refactoring tools or patterns found in research
- **test-automator.md**: Last updated 2026-05-15 (47 days) — Vitest 4, Jest 30, Playwright already covered; no major new testing tool releases found
- **new-project/SKILL.md**: Last updated 2026-05-01 (61 days) — Docker images still current (PG 19 still beta, not GA), no significant changes needed

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md
- audit-360/SKILL.md

### Skipped (template/orchestration)
- lang-guidelines/SKILL.md (meta-skill for generating agents, stable process)

### Deferred to next run
- None — all files processed within the 10-file limit

### Issues
- None

### Next run priorities
- refactoring-specialist.md (will be 77 days by next run — consider adding new AST tooling or patterns)
- test-automator.md (will be 77 days by next run)
- new-project/SKILL.md (will be 91 days by next run — update Docker images when PG 19 reaches GA)
- backend-security-coder.md (will be 60 days by next run)
- debugger.md (will be 60 days by next run)
- php-pro.md (will be 60 days by next run)
- python-pro.md (will be 60 days by next run)

---

## Run: 2026-06-01

### Updated
- **python-pro.md**: Added Python 3.14 stable features — PEP 649 (deferred annotation evaluation), PEP 734 (multiple interpreters), PEP 758 (except without parens), PEP 779 (free-threaded Python officially supported), PEP 784 (compression.zstd), uuid7(), JIT compiler. Added 2026 CVEs: CVE-2026-3298 (asyncio buffer overflow), CVE-2026-4519 (webbrowser.open() injection), CVE-2026-0672 (cookies bypass). Added remote debugging security note. Updated description to 3.14+/3.15.
- **backend-security-coder.md**: Added OWASP Top 10 2026 new categories — A03 Software Supply Chain Failures and Mishandled Exceptions. Updated SSRF entry to note merger into Broken Access Control A01. Updated AI vulnerability stats: 92% of AI codebases have critical vuln (Sherlock Forensics 2026), 35 CVEs/month attributed to AI-generated code.
- **debugger.md**: Added 4 new AI-generated bug patterns — hallucinated APIs, incomplete-context conflicts (43% need production debugging per Lightrun 2026), performance anti-patterns, semantic error dominance (>60% of AI faults).
- **php-pro.md**: Added PHP 8.5 URI extension (Uri\Rfc3986\Uri, Uri\WhatWg\Url replacing parse_url()), closures in constant expressions.

### Skipped (up to date)
- **code-reviewer.md**: Last updated 2026-05-15 (17 days)
- **javascript-pro.md**: Last updated 2026-05-15 (17 days)
- **refactoring-specialist.md**: Last updated 2026-05-15 (17 days)
- **test-automator.md**: Last updated 2026-05-15 (17 days)
- **database-optimizer.md**: Last updated 2026-05-01 (31 days) — PG 18.4 point release is maintenance/security only, no new optimization patterns
- **mobile-pwa-developer.md**: Last updated 2026-05-01 (31 days) — no new PWA APIs or browser features since May update
- **sql-pro.md**: Last updated 2026-05-01 (31 days) — PG 18 and MySQL 9 features already comprehensive, no new dialect features
- **new-project/SKILL.md**: Last updated 2026-05-01 (31 days) — process skill with current tech references, no significant changes needed

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md

### Skipped (template/orchestration)
- lang-guidelines/SKILL.md (meta-skill for generating agents)
- audit-360/SKILL.md (orchestration process)

### Deferred to next run
- None — all 8 evolving files were processed

### Issues
- None

### Next run priorities
- database-optimizer.md (will be 61 days by next run)
- mobile-pwa-developer.md (will be 61 days by next run)
- sql-pro.md (will be 61 days by next run)
- new-project/SKILL.md (will be 61 days by next run)
- code-reviewer.md (will be 47 days by next run)
- javascript-pro.md (will be 47 days by next run)
- refactoring-specialist.md (will be 47 days by next run)
- test-automator.md (will be 47 days by next run)

---

## Run: 2026-05-15 — Post-Audit Incident Updates

Driven by 2026-05-15 incident (bulk `sed` on `catch (e) {` destroyed 13 JS files) and PR #155 / `ksef_daemon` orphan-test incident (7 tests passing CI against deleted code).

### Updated
- **javascript-pro.md**: New sections — Vite/bundler scope isolation checklist (cross-file `window.X`, eslint globals sync, implicit globals → `ReferenceError` in bundles); ES2019 catch binding rule with explicit ban on sed/regex bulk transforms (incident 2026-05-15); `Object.prototype.hasOwnProperty.call` rule.
- **code-reviewer.md**: Added 6th review axis — **Test-Production Contract**: orphan-test scan for DELETE/RENAME/signature/exception changes (`scripts/check_orphan_tests.sh <symbol>`, `grep tests/` patterns). Description and review-process headers updated 5→6 axes.
- **test-automator.md**: New **Pre-Flight** section — before editing tests or after a production change, run (1) orphan scan, (2) filtered sanity check, (3) MANDATORY full suite run (because `failOnWarning`/`failOnRisky` and orphan tests only surface in a full run, never in `--filter`).
- **refactoring-specialist.md**: Added safety rule #6 and new **Bulk Transformations — AST or Not at All** section. Explicit ban on `sed`/`awk`/`perl -pi` for catch bindings, signatures, declarations; allowed list (eslint --fix, jscodeshift, ts-morph, Rector, LibCST). Added Last-updated footer (previously missing).
- **sharp-edges (backup-skills)**: New category 7 — **Tooling Footguns: Bulk Regex/Sed on Source Code**. Codifies the 2026-05-15 catch-binding incident as a sharp-edge anti-pattern.

### Considered but skipped
- **eslint-cleanup skill (new, optional)**: content overlapped with new javascript-pro and refactoring-specialist sections; project-specific (CI free-tier, `sync_eslint_globals.sh`). Can be added later if a dedicated workflow checklist is wanted.

### Issues
- None — all edits are additive guidance, no breaking changes to existing structure.

---

## Run: 2026-05-01

### Updated
- **php-pro.md**: Added PHP 8.4 features (property hooks, asymmetric visibility, PDO driver subclasses, array_find/any/all, new-without-parens), PHP 8.5 features (pipe operator, clone with, array_first/last, #[\NoDiscard]), code examples; updated vulnerability stats to Veracode 2026 (~45%); updated description from 8.3+ to 8.4+/8.5
- **javascript-pro.md**: Updated Node.js LTS from v20+ to v22+ (WebSocket, watch mode, .ts execution, HTTP/3 QUIC); added TypeScript 5.8 features (erasableSyntaxOnly, rewriteRelativeImportExtensions); added ESLint 10 flat config (eslintrc removed Feb 2026); updated Vitest to 4+ (stable browser mode); updated AI vulnerability stats to Veracode 2026
- **backend-security-coder.md**: Added new AI & Agentic Security section covering OWASP Top 10 for Agentic Applications 2026, slopsquatting supply chain attacks, OWASP MCP Top 10, updated vulnerability stats
- **sql-pro.md**: Added PostgreSQL 18 features (async I/O, skip scan, uuidv7, virtual generated columns, temporal constraints, OAuth); added MySQL 9 features (vector data type, enhanced EXPLAIN, WebAuthn)
- **database-optimizer.md**: Added PostgreSQL 18 performance features (async I/O with 3x improvement, skip scan, virtual generated columns, uuidv7)
- **code-reviewer.md**: Added slopsquatting and deprecated config format checks to AI-generated code review table; updated vulnerability stats to Veracode 2026
- **test-automator.md**: Updated Vitest to 4+ (stable browser mode, visual regression testing), Jest to 30, added Playwright component testing
- **mobile-pwa-developer.md**: Updated iOS Safari to 16.4+, added Firefox 143+ PWA support, Workbox 7, manifest-only install prompts, WebGPU/WebNN on-device AI capabilities
- **new-project/SKILL.md**: Updated Docker images (postgres:18, mongo:8, rabbitmq:4), added PostgreSQL 18 feature notes
- **debugger.md**: Added slopsquatting and AI tool supply chain compromise to debugging patterns

### Skipped (up to date)
- **python-pro.md**: Last updated 2026-04-14 (17 days ago, within 30-day threshold)

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md

### Deferred to next run
- **refactoring-specialist.md**: Hit 10-file limit; refactoring patterns are relatively stable
- **audit-360/SKILL.md**: Hit 10-file limit; orchestration process, lower priority
- **lang-guidelines/SKILL.md**: Hit 10-file limit; meta-skill for creating agents

### Issues
- None

### Next run priorities
- refactoring-specialist.md (no "Last updated" date, deferred this run)
- audit-360/SKILL.md (no "Last updated" date, deferred this run)
- lang-guidelines/SKILL.md (no "Last updated" date, deferred this run)
- python-pro.md (will be 47+ days old by next monthly run)
