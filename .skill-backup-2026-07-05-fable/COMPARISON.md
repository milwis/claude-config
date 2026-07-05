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

## Jak porównać / jak wycofać

- Diff starej i nowej wersji:
  `git -C D:\Programowanie\claude-config diff -- plugins/milwis-coding-toolkit/skills`
  albo per plik: `fc .skill-backup-2026-07-05-fable\brainstorming.SKILL.md.bak plugins\milwis-coding-toolkit\skills\brainstorming\SKILL.md`
- Wycofanie pojedynczego skilla: skopiuj `.bak` z powrotem na miejsce `SKILL.md` (albo `git checkout -- <plik>`, bo zmiany są tylko w working tree — nic nie zostało scommitowane).
