# Porównanie A/B — regeneracja skilli 2026-07-05 (Fable 5)

Backup starych wersji (1:1, zweryfikowane hashem SHA256) leży obok tego pliku:
`brainstorming.SKILL.md.bak`, `writing-plans.SKILL.md.bak`, `executing-plans.SKILL.md.bak`.

Nowe wersje: `plugins\milwis-coding-toolkit\skills\{brainstorming,writingplans,executingplans}\SKILL.md`.

**Zasada regeneracji:** zero utraconych kontraktów, zero zmyślonych faktów. Każda zmiana poniżej to restrukturyzacja, doprecyzowanie albo dodatek ugruntowany w CLAUDE.md / realnych planach z `docs/plans/`. Frontmatter `name:` i `description:` — niezmienione co do znaku we wszystkich trzech.

---

## 1. brainstorming (5,6 KB → ~6,1 KB)

| Zmiana | Typ | Uzasadnienie |
|---|---|---|
| Variant Question i Regulated-Domain Gate przeniesione z końca pliku na początek jako **"Two Mandatory Gates"** (Gate A / Gate B), PRZED opisem procesów LIGHT/FULL | restrukturyzacja | W starej wersji oba guardy stały za sekcją "After the Design" — łatwo je było przeczytać za późno, już po wyborze kierunku. Teraz są jawnie związane z momentem "before any direction is chosen". |
| Regulated-Domain Gate obowiązuje jawnie w OBU tierach (stara wersja wiązała go tylko z "Phase 1", czyli FULL) | zaostrzenie | Zmiana LIGHT dotykająca VAT/progu prawnego też wymaga reguł ze źródeł w repo — spójne z regułą behawioralną w CLAUDE.md projektu (reguła prawna → wyłącznie z cytatem źródła). |
| Reguły dispatchu Explore wydzielone do wspólnej sekcji "Explore Dispatch Rules" (raz, zamiast dwa razy: w LIGHT i w FULL "same rules as...") | deduplikacja | Ten sam kontrakt (konkretne fakty, file:line, "Report ONLY what you found in code...") — zdanie końcowe zachowane co do znaku. |
| LIGHT krok 4: "multi-step → `writing-plans`; a 1-2 step change may be implemented directly" (stara wersja: zawsze writing-plans) | doprecyzowanie | Zgodne z drzewem decyzyjnym w CLAUDE.md projektu (LIGHT → implementacja; >3 kroków → writingplans). Stara wersja była w sprzeczności z CLAUDE.md. |
| Lista wariantów w Gate A uzupełniona o "single-vs-bulk" | dodatek | Pozycja obecna w liście Step 0.5 writing-plans i w CLAUDE.md ("pojedynczy-vs-zbiorczy") — brakująca tylko w brainstormingu; teraz listy są spójne. |
| Nowy red flag: "Regulated rule cited without a repo source → back to Gate B" | dodatek | Domyka pętlę Gate B na poziomie checklisty końcowej. |
| Zachowane bez zmian semantycznych | — | Tiery SKIP/LIGHT/FULL + eskalacja, HMW z polskim przykładem winiet, pytania wyostrzające, 4 soczewki wariantów, tabela Konwergencji (Wartość/Wykonalność/Spójność po polsku), one-pager 6 sekcji z "Not Doing", zapis do `docs/plans/YYYY-MM-DD-<topic>-design.md`, handoff do writing-plans, "jedno pytanie na raz / multiple choice", "Verify before asserting", YAGNI, wszystkie stare red flags. |

**Ryzyko regresji:** niskie — jedyna zmiana zachowania to LIGHT krok 4 (dopuszczona bezpośrednia implementacja przy 1-2 krokach) i rozszerzenie Gate B na LIGHT; obie przybliżają skill do CLAUDE.md projektu, a nie od niego oddalają.

---

## 2. writing-plans (11,9 KB → ~12,3 KB)

| Zmiana | Typ | Uzasadnienie |
|---|---|---|
| Numeracja kroków uporządkowana: Step 0 → Step 0.5 → **Step 1: Write the Plan** (header + struktura zadań + szablon) → **Step 2: Self-Audit** (zamiast enigmatycznego "Step N") → **Step 3: Execution Handoff** | restrukturyzacja | Stara wersja miała Step 0, Step 0.5, potem sekcje bez numerów i nagle "Step N" — nowa numeracja daje jednoznaczny pipeline. Kolejność treści bez zmian. |
| Plan Header: nowe pole **"Out of scope"** | dodatek | Ugruntowane w realnych planach (`2026-07-05-korekty-fx-kurs-198.md` — sekcja "Poza zakresem / odłożone"; `2026-07-05-cas-guardy-stanu-192.md` — "poza scope #192"). Praktyka już istnieje; skill ją teraz koduje. Pass 3 pkt 3 odsyła odrzucone findingi właśnie tam. |
| Drobne wygładzenia językowe (np. "Plans describe..." → "A plan describes...") | kosmetyka | Bez zmian semantycznych. |
| Zachowane bez zmian semantycznych | — | Step 0 (wszystkie 6 punktów, w tym ryzyka: `updated_at`, `$allowedResources`, `window.`, `views`/`group_views`; ścieżka flow docs), Step 0.5 z DOKŁADNYM promptem Explore + zapis Canon/Variants + uzasadnienie "defect lives between files", vertical slicing z przykładem ❌/✅, risk-first ordering, tabela sizing, max 5 plików / 3 kryteria, pełny Per-Task Template z sekcją **Invariants & Failure Semantics** (UNIQUE/FK/CHECK, TOCTOU, guarded UPDATE + affected-rows, lista WSZYSTKICH writerów + jedna kanoniczna metoda przejścia, UNKNOWN po timeout/5xx, write-ahead + reconcile-by-reference, zakaz wipe'owania payloadu, batch double-booking), commit `feat(moduł): opis po polsku`, zakaz pełnego kodu w planie + uzasadnienie tokenowe, wszystkie 8 red flags, Self-Audit Pass 1-4 (10-20 gapów, tabela 8 specjalistów, dispatch równoległy w jednej wiadomości, prompt read-only z zakazem generic advice, konsolidacja, ponowny Pass 1 przy zmianach strukturalnych, raport z jawnym flagowaniem zera findingów), komunikat handoffu, 4 companion skills. |

**Ryzyko regresji:** bardzo niskie — jedyny nowy element ("Out of scope" w headerze) formalizuje praktykę już obecną we wszystkich świeżych planach; reszta to przenumerowanie bez zmiany treści kontraktów.

---

## 3. executing-plans (7,2 KB → ~7,5 KB)

| Zmiana | Typ | Uzasadnienie |
|---|---|---|
| Format todo listy: przykład zmieniony z wywołania `TodoWrite([...])` w JS na czysty tekstowy listing etykiet + dopisek "(TodoWrite / the session's task tracker)" | uodpornienie | Nazwa narzędzia todo różni się między wersjami harnessu Claude Code; inwariantem jest FORMAT etykiety `[GROUP N|PARALLEL|SEQ] Task K: ... [AGENT: x]/[DIRECT]` — i ten jest zachowany co do znaku, wraz z regułą "todo list = pamięć po kompakcji". |
| Nowy akapit **"Plan vs reality mismatch"** w Step 2: kod przeczy planowi (przesunięta linia, zmieniona nazwa, fałszywe założenie) → ufaj kodowi, odnotuj odchyłkę; mismatch unieważniający podejście zadania → stop i uzgodnij, nie improwizuj nowego designu w trakcie | dodatek | Realny, częsty edge-case egzekucji, którego nie pokrywał ani Stop-the-Line (dotyczy failujących testów/buildów), ani "Concerns → raise before starting" (dotyczy momentu startu). Spójny z regułą projektu "NIE wprowadzaj pochopnych zmian — najpierw diagnoza". |
| Drobne wygładzenia (np. "A task can run in parallel with another ONLY if..." → "Tasks may run in parallel ONLY if ALL four hold") | kosmetyka | Bez zmian semantycznych. |
| Zachowane bez zmian semantycznych | — | DIRECT vs AGENT (pełne listy + "When unsure → AGENT. Quality beats speed."), 4 warunki równoległości, same-file rule ("ONE agent with all N tasks"), always-sequential (migracje przed query, commity, finalny code-reviewer+test-automator), "When in doubt → sequential", pseudokod pętli grup (ONE message z N Agent calls, wait ALL, verify, Stop-the-Line blokuje następną grupę), self-contained dispatch (task verbatim, pliki, AC tylko tego zadania, "do NOT touch file X"), **Canon hand-off** z cytatem "call it or mirror it; report any forced divergence back..." + "fix the prompt, not the agent", weryfikacja na granicach grup (php -l / node --check, testy, AC) jako brama `verification-before-completion` w granulacji grupy, finalna grupa sekwencyjna (test-automator + code-reviewer + commit; "final test pass IS the comprehensive coverage"), Trzy Reguły (Stop-the-Line z pipeline'em STOP→…→continue, Scope Discipline z "przy okazji" = #1 źródło regresji, Read Before Modifying bez wymuszonego preambułowego read), tabela wyboru agenta (10 wierszy), wszystkie 6 red flags, 3 companion skills. |

**Ryzyko regresji:** niskie — nowy akapit o rozjeździe plan↔kod jedynie dodaje brakującą ścieżkę decyzyjną; zmiana zapisu przykładu todo nie zmienia formatu etykiet, na których polega odtwarzanie stanu po kompakcji.

---

## 4. systematic-debugging — FUZJA z debugging-strategies (4,4 KB + 7,4 KB → ~8,3 KB)

Dogrywka na polecenie użytkownika: z dwóch skilli debugowania — `systematic-debugging` (claude-config, dyscyplina) i `debugging-strategies` (FakturyKonkret `.claude/skills/`, taktyka projektowa) — powstał jeden skill. Zapisany jako `systematic-debugging` w claude-config (nazwa zachowana, bo wskazują na nią cross-referencje: executing-plans, writing-plans, agenci `debugger` i `code-reviewer`). Oba źródła zbackupowane obok: `systematic-debugging.SKILL.md.bak`, `debugging-strategies.SKILL.md.bak`. **Repo FakturyKonkret nietknięte** — jego lokalny `debugging-strategies` dalej istnieje; jeśli ma zostać zastąpiony/usunięty, to osobna decyzja (CLAUDE.md projektu odwołuje się do `/debugging-strategies` w drzewie decyzyjnym).

| Zmiana | Typ | Uzasadnienie |
|---|---|---|
| Szkielet = 4 fazy z systematic-debugging (Iron Law, JEDNA hipoteza, reguła 3 prób, "no root cause" ~95%, Final Rule) — wszystko zachowane | baza | Silniejsza struktura dyscypliny; 6-Step Triage z debugging-strategies zmapowany do faz: REPRODUCE/LOCALIZE/REDUCE → Faza 1 (pkt 2/4/5), FIX ROOT CAUSE → Faza 4 pkt 2, GUARD → Faza 4 pkt 1, VERIFY → Faza 4 pkt 3. Nic z triage nie zginęło. |
| Nowy **Step 0: Logs First** przed fazami: early-warning (branch `log-reports`) → mapowanie symptom→log → grep/REQUEST_ID/format linii → `docs/troubleshooting.md` | fuzja + aktualizacja | Krok 0 z debugging-strategies, uzupełniony o system wczesnego ostrzegania z CLAUDE.md (2026-05-14), którego stary skill w ogóle nie znał. |
| Tabela symptom→log (10 wierszy) ZASTĄPIONA odesłaniem do CLAUDE.md sekcji DEBUGOWANIE | celowe usunięcie duplikatu | Tabela w starym skillu była przestarzałym podzbiorem tej w CLAUDE.md (brak mysql_watchdog, vignette_lv_scrape, Paysera, cron_runs). CLAUDE.md jest zawsze w kontekście projektu — duplikat w toolkicie = gwarantowany drift. |
| **Known Failure Patterns (FakturyKonkret)** — 5 wzorców (strict_types TypeError, bundle ReferenceError bez `window.`, N+1/SLOW API, 403/`$allowedResources`, ChangesTracker/`updated_at`) skondensowane do tabeli | przeniesione z debugging-strategies | Najcenniejsza projektowa treść źródła; fakty zweryfikowane (`$allowedResources` w `php/helpers.php` — troubleshooting.md; `updated_at`/`window.` — CLAUDE.md). Bez numeru linii `:201` (kruchy, wystarczy nazwa pliku). |
| Stop-the-Line (7-kroków) z debugging-strategies NIE powielony — zostaje sekcja **Never Rationalize** (3 racjonalizacje z `git stash` po polsku) + Integration wskazuje, że Stop-the-Line należy do executing-plans i przekazuje tutaj | deduplikacja | Kontrakt Stop-the-Line ma jednego właściciela (executing-plans); dublowanie pełnej procedury w dwóch skillach = drift. Esencja ("nigdy nie racjonalizuj") zachowana. |
| Toolbox i checklista "When Stuck" — scalone, skondensowane (php -l, phpunit --filter, EXPLAIN/SHOW PROCESSLIST, git bisect/blame, DevTools) | kondensacja | Usunięty tylko Xdebug trace (nieużywany w projekcie — brak śladów w CLAUDE.md/troubleshooting); git bisect przeniesiony do Fazy 1 pkt 3. |
| Kod przykładu testu regresyjnego (PHP, 10 linii) usunięty — zostały 3 twarde warunki (fail bez fixa / pass z fixem / opisuje scenariusz) | odchudzenie | Przykład był generyczny; kontrakt niesie 3 bullety. |
| Zachowane z systematic-debugging bez zmian | — | Podział ról skill vs agent `debugger`, Iron Law, Fazy 2-3 co do treści, reguła 3 prób z rozmową przed fixem #4, sekcja "no root cause", Integration (TDD RED, verification-before-completion, debugger, executing-plans), Final Rule. |

**Ryzyko regresji:** niskie — jedyne realne ryzyko to odesłanie do tabeli symptom→log w CLAUDE.md zamiast lokalnej kopii: skill użyty POZA FakturyKonkret nie ma mapowania (ale stara tabela i tak była projektowo-specyficzna), a w projekcie CLAUDE.md jest zawsze załadowany i świeższy.

---

## 5. Agent `debugger` — celowane uzupełnienia (nie rewrite)

Backup: `debugger.agent.md.bak`. Agent był dobry — dodane 4 rzeczy wyrównujące go ze zfuzowanym skillem `systematic-debugging`:

| Zmiana | Uzasadnienie |
|---|---|
| Step 0: raport wczesnego ostrzegania PRZED `[ERROR]` (FakturyKonkret: branch `log-reports`, HEALTH STATUS / ANOMALIES) | Agent nie znał systemu early-warning (CLAUDE.md 2026-05-14) — a to pierwszy krok ścieżki debugowania projektu. |
| Step 2: `git bisect` przy regresji + heurystyka "1 użytkownik vs reszta OK → dane, nie kod" | Obie techniki są w skillu i CLAUDE.md; agentowi brakowało. |
| Step 3: "Test ONE hypothesis at a time, one variable at a time — never stack speculative fixes" | Agent pozwalał listować 2-3 hipotezy bez dyscypliny testowania jednej naraz — rozjazd ze skillem (Faza 3). |
| Output Format: nowa pozycja **Ruled out** (wykluczone hipotezy + dowód wykluczenia) | Zapobiega ponownemu śledztwu po tych samych ścieżkach przy nawrotach buga. |

**Ryzyko regresji:** pomijalne — wyłącznie dodatki, zero usunięć; konwencja stampów aktualizacji zachowana.

---

## 6. Agent `backend-security-coder` — pełna regeneracja (9,0 KB → ~9,6 KB)

Backup: `backend-security-coder.agent.md.bak`.

| Zmiana | Typ | Uzasadnienie |
|---|---|---|
| Nowy "Discipline overlay": `verification-before-completion` — werdykt "secure"/"fixed" tylko z pokazanym dowodem | dodatek | Wzorzec już obecny u `code-reviewer`, `test-automator`, `debugger` — security-coder był jedynym bez overlayu; domyka spójność toolkitu. |
| ALWAYS: nowa reguła **Fail CLOSED** (guard z wyjątkiem/timeoutem/brakiem configu → DENY, nie pominięcie checku) | dodatek | Ugruntowane w audytach projektu (plan `2026-07-04-triage2-205-ddd-fail-open-gaps.md` — cała klasa fail-open) i skillu `insecure-defaults`. Powtarzalna klasa defektów, której tabela nie kodowała. |
| ALWAYS: nowa reguła **Timing-safe secret comparison** (`hash_equals()` / `crypto.timingSafeEqual()`) | dodatek | Wzorzec już produkcyjnie używany w projekcie (webhook deployu waliduje sekret przez `hash_equals` — CLAUDE.md §2a); agent go nie wymagał. |
| Common Vulnerabilities: nowy wiersz **CSRF** (token na każdym mutującym requeście, SameSite) | dodatek | Jedyna pozycja OWASP-owej klasyki nieobecna w tabeli, mimo że projekt ma dedykowany `csrf-interceptor.js`. |
| Checklist §5 Error Responses: dopisany fail-closed na ścieżce błędu | doprecyzowanie | Spójność z nową regułą ALWAYS. |
| Output Format: jawne "Every finding cites file:line and a concrete fix — no generic advice" | doprecyzowanie | Ten sam kontrakt co w promptach Pass 2 writing-plans. |
| Zachowane bez zmian | — | Frontmatter (name/description/model: sonnet), wszystkie 13 dotychczasowych reguł ALWAYS (w tym 3 lekcje audytowe: session regeneration na KAŻDEJ ścieżce logowania, permission consistency among neighbor routes, anonimizowane fixtures/GDPR), 8 pozycji ASK FIRST, wszystkie 14 zakazów NEVER (debug endpoints, tokeny w query stringu, composer/npm audit w CI, non-CSPRNG), 5-sekcyjny checklist ✅/❌, tabela podatności z aktualizacjami OWASP 2026 (SSRF→A01, Supply Chain A03, Mishandled Exceptions), format raportu z emoji-severity, cała sekcja AI & Agentic Security (statystyki Veracode/Sherlock, slopsquatting, OWASP Agentic 2026, MCP Top 10), historyczne komentarze aktualizacji. |

**Ryzyko regresji:** bardzo niskie — regeneracja jest addytywna (3 nowe reguły + 2 doprecyzowania), żadna dotychczasowa reguła nie została usunięta ani osłabiona.

---

## 7. systematic-debugging — UOGÓLNIENIE (wersja projektowa → uniwersalna)

Na polecenie użytkownika: skill odwiązany od KonkretnyTMS/FakturyKonkret, ma działać na najwyższym poziomie w każdym projekcie. Wersja sprzed uogólnienia jest w historii git (commit `8655787`); pierwotne źródła nadal w `.bak` obok.

**Zasada warstwowania (nowa, jawnie zapisana na górze skilla):** skill definiuje JAK debugować, projektowe CLAUDE.md/runbooki definiują GDZIE (lokalizacje logów, mapowania symptom→log, komendy testów). Gdy projekt dokumentuje własną ścieżkę debugowania, wykonuje się ją wewnątrz tego procesu.

| Co było (projektowe) | Co jest (uniwersalne) |
|---|---|
| Step 0: branch `log-reports`, CLAUDE.md sekcja DEBUGOWANIE, format logu FakturyKonkret | Early-warning signals dowolnego typu (health report, dashboard, alerting); mapowanie z dokumentacji projektu; "log line anatomy" do rozpoznania (timestamp/level/correlation ID/module/user); fallback grep + logi web-servera/kontenera |
| Tabela warstw: "PHP controller", "KSeF/GPS/WAPRO" | Warstwy generyczne: Frontend / API / Backend entry point / Service–data layer / Database / External service / The test itself |
| Weryfikacja: `vendor/bin/phpunit`, `npm run test:js:run`, `php -l` | Komendy projektu z przykładami multi-stack: phpunit/pytest/vitest; php -l / node --check / py_compile |
| "Known Failure Patterns (FakturyKonkret)" — 5 wzorców z `$allowedResources`, `window.`, `updated_at` | **"Universal Failure Patterns"** — 7 KLAS: type-boundary TypeError, dev-vs-prod-build symbol visibility, N+1/missing index, "jeszcze jeden rejestr uprawnień niż zarejestrowałeś", change-detection na nietkniętej kolumnie, environment drift (case-sensitivity/timezone/locale — lekcja PSR-4 z PR #155), pipeline-green-behavior-broken (fail-handler z exit 0 — lekcja `die()` w db_config). Instancje projektowe → troubleshooting doc projektu (Step 0.4). |
| Checklist/dokumentacja: `docs/troubleshooting.md`, `$allowedResources` | "Project's troubleshooting doc / closed issues", "every whitelist/registry/guard on the path" |
| git bisect z tagiem `v3.5.0` | `<last-good-tag>` |
| Zachowane bez zmian | Iron Law, 4 fazy, JEDNA hipoteza, reguła 3 prób, "no root cause" ~95%, Never Rationalize (polskie cytaty — głos użytkownika, nie coupling projektowy), Quick Reference — Phase exit criteria, Integration, Final Rule, podział skill vs agent `debugger` |

Dwie nowe klasy w Universal Failure Patterns (environment drift, swallowed exit code) NIE są zmyślone — to uogólnienia udokumentowanych incydentów projektu (PSR-4 case sensitivity Windows→Linux; `die()` zwracające exit 0 i zielone CI na zepsutej wersji — obie lekcje z CLAUDE.md §4b).

**Ryzyko regresji:** niskie — w projekcie FakturyKonkret specyfika (mapowanie logów, wzorce, komendy) i tak żyje w CLAUDE.md, które jest zawsze w kontekście; skill traci jedynie zdublowane odniesienia, zyskuje przenośność do pozostałych projektów użytkownika.

---

## Jak porównać / jak wycofać

- Diff starej i nowej wersji:
  `git -C D:\Programowanie\claude-config diff -- plugins/milwis-coding-toolkit/skills`
  albo per plik: `fc .skill-backup-2026-07-05-fable\brainstorming.SKILL.md.bak plugins\milwis-coding-toolkit\skills\brainstorming\SKILL.md`
- Wycofanie pojedynczego skilla: skopiuj `.bak` z powrotem na miejsce `SKILL.md` (albo `git checkout -- <plik>`, bo zmiany są tylko w working tree — nic nie zostało scommitowane).
