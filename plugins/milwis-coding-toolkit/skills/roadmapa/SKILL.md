---
name: roadmapa
description: "Use when a BATCH of issues must be resolved with the owner away from the keyboard — a chain of sessions that hand work to each other. Generation 1 triages issues on HEAD and writes a roadmap; every later generation works through phases (plan / execute / verify) and keeps taking the next unclosed one while its context stays below the warn threshold, spawning its own successor via `claude --bg` and stopping only when a threshold fires or the next phase is excluded. In `ciągły` mode the chain does not end with the roadmap: the last generation spawns a curator that triages the next batch from the backlog by priority, skipping issues the repo defers, and the run stops on a STOP file or a wave cap. With `merge-lokalny` the generation closing verify merges the branch into local `main` under a five-condition gate — never a push. Durable state lives in a committed roadmap + append-only ledger, never in a session's context. Input: issue numbers or a backlog. Output: branches, ledger rows with evidence, and a status table."
---

# Roadmapa (łańcuch sesji rozwiązujący partię issues bez obecności właściciela)

> **Źródłem prawdy tego pliku jest `milwis/claude-config`** (`plugins/milwis-coding-toolkit/skills/roadmapa/`).
> Workflow `sync-claude-toolkit` kopiuje go stamtąd co poniedziałek przez `cp -rf`, więc **edycja kopii
> w `.claude/skills/` zostanie cicho nadpisana** — zmiany wprowadzaj upstream. Sync przenosi wyłącznie
> `agents/` i `skills/`: hooki sztafety (`~/.claude/hooks/relay-*.sh`), na których stoją progi z §1, **nie
> jadą z nim** i w nowym repo trzeba je wpiąć osobno.

**Rdzeń:** kontekst jest zasobem zużywalnym, a jakość pracy spada, zanim okno się zapełni. Zamiast jednej sesji dobijającej do ściany — **łańcuch sesji, z których każda robi JEDNĄ fazę i przekazuje pracę następnej**, którą sama rodzi. Właściciela nie ma przy komputerze; wszystko, co ma przetrwać, musi być w repo, nie w kontekście.

**Zapowiedz na starcie:** „Używam skilla roadmapa, pokolenie N."

**Pierwszy wiersz ledgera zawiera ZMIERZONE progi**, nie założone:
```bash
bash -c 'source ~/.claude/hooks/relay-lib.sh; echo "WARN=$RELAY_WARN HANDOFF=$RELAY_HANDOFF CEILING=$RELAY_CEILING HARD=$RELAY_HARD_CAP"'
```
Wpięty hook z progami innymi niż zakładasz wygląda identycznie jak działający mechanizm i **milczy przez cały przebieg** — to próżniowo zielona ochrona. Zmierz i zapisz.

**Wymaga wpiętych hooków sztafety** (`~/.claude/hooks/relay-{lib,post,pre}.sh` w `settings.json`). Bez nich progi nie zadziałają i łańcuch nie ruszy sam z siebie — sprawdź `jq '.hooks' ~/.claude/settings.json` i przerwij, jeśli `null`.

---

## 1. Progi i to, co przy nich robisz

| % okna | Co się dzieje | Egzekwuje |
|---|---|---|
| 35 | uzupełnij handoff w ledgerze; nowe wątki tylko domykalne | wtrysk `PostToolUse` |
| 40 | koniec brania nowych wątków; `Agent` zablokowany; zrodź następcę | `deny` + wtrysk |
| 60 | odcięte wszystko poza `Bash`, `Write`, `SendMessage`, `TodoWrite`, `ListAgents` — w tym `Read`, `Grep`, `Glob`, `Edit` | `deny` |
| 80 | twardy sufit — `hold` go NIE znosi | `deny` |

**Progi są SIATKĄ BEZPIECZEŃSTWA, nie harmonogramem.** Zmierzone w przebiegu 1 (pięć przekazań):
4 z 5 nastąpiły z powodu **granicy fazy z §4**, przy 31,5% / 38,6% / 26,8% / 37,0% — czyli PONIŻEJ
progu 40, który nie zapalił się wcale. Tylko piąte (44,4%) prowadził próg. Nie planuj więc pracy „do
progu": przekazuj na granicy fazy, a progi traktuj jako to, co Cię złapie, gdy faza okaże się dłuższa,
niż zakładałeś.

Liczba jest o turę spóźniona i liczona wobec limitu **wyprowadzonego z modelu** (§1b).
Opóźnienie zmierzone: **jedna runda narzędziowa (~27 s)** — hook po PIERWSZYM narzędziu ponad progiem
czyta jeszcze zużycie POPRZEDNIEJ tury, więc wtrysk dociera ok. 0,5 pp za progiem (G2: przekroczenie
35% przy 352 880, wtrysk przy 355 042). `RELAY_LIMIT` NIE ma wartości domyślnej — jest awaryjnym nadpisaniem; domyślne 1e6 pochodzi z `RELAY_LIMIT_DEFAULT`. Ustawienie `RELAY_LIMIT` na wartość niebędącą dodatnią liczbą jest odrzucane z ostrzeżeniem, nie po cichu. Świeża sesja w tym repo startuje z ok. 14% (`CLAUDE.md` + `incident-lessons.md`; zmierzone: G2 = 143 729,
G3 = 143 860, G6 = ok. 144 000 — wartość jest stabilna).

`POMIAR`: punkty przekazania w przebiegu 1 wypadły na 31,5% / 38,6% / 26,8% / 37,0% / 44,4%, średnio
33,5%, a różnica między kolejnymi przekazaniami to ok. 19 punktów. `WNIOSEK` (skorygowany 2026-09-05):
ta liczba **nie mierzy pojemności okna** — mierzy skutek reguły „jedna faza na pokolenie" z
ówczesnego §4, która kazała przekazywać na granicy fazy niezależnie od zużycia. Trzecia przesłanka
(„czy pokolenie mogło pracować dalej") nie była zmierzona, więc etykieta „realne pasmo" była
fałszywym uogólnieniem — instancja `§Klasa nadrzędna` z `incident-lessons.md` (dwie przesłanki
zmierzone, trzecia nie, wniosek fałszywy). §4 usuwa to sprzężenie: pokolenie z zużyciem poniżej
`RELAY_WARN` bierze kolejną niedomkniętą fazę zamiast przekazywać automatycznie na granicy fazy, więc
„19 punktów" przestaje być podstawą do krojenia etapów roadmapy na ~19-punktowe kawałki.

## 1a. Podagenci mają własne progi

Podagent nie jest małą sesją — **nie może nikomu przekazać pracy**, jego jedynym wyjściem jest oddanie raportu rodzicowi. Ma za to własne okno i własny transkrypt (`<projekt>/<session-id>/subagents/agent-<agent_id>.jsonl`), więc hooki mierzą go osobno:

| % własnego okna | Co się dzieje |
|---|---|
| 45 | „zwijaj się, domknij wątek, oddaj raport" |
| 65 | **każde** narzędzie dostaje `deny` — zostaje wyłącznie napisanie raportu |

Odcięcie narzędzi jest tu mechanizmem wymuszającym, nie karą: podagent bez narzędzi musi odpowiedzieć.

Ta sama zasada rządzi sufitem sesji: od 60% odcięte jest **czytanie** (`Read`, `Grep`, `Glob`, `Edit`), bo to cztery największe konsumenty okna — sufit, który je przepuszcza, nie chroni przed niczym. `Bash` zostaje otwarty, bo bez niego nie zrobisz `git` ani `claude --bg`; **sufit odcina narzędzia, nie zamiary**, więc to na Tobie leży, żeby nie czytać plików przez `cat`. Niepełny raport jest użyteczny, przerwany podagent bez raportu nie jest.

Wnioski dla zlecającego: **deleguj wąsko**. Zadanie w rodzaju „przejrzyj cały moduł" zjada okno podagenta, zanim cokolwiek zaraportuje. Zleceń weryfikacyjnych udzielaj dwustronnie („ustal, czy X czy nie-X, i podaj, co rozstrzyga") — i tak jest to wymóg `CLAUDE.md`, a przy okazji ogranicza zbieranie materiału.

**Podagent nigdy nie przekazuje pracy w bok.** Nie rodzi drugiego podagenta (większość definicji nie ma narzędzia `Agent` — `php-pro` to `Read, Write, Edit, Bash, Glob, Grep`) i nie zakłada sesji przez `claude --bg` z Basha.

Hook blokuje typowe formy tego wywołania, ale to **obrona w głąb, nie zapadka** — i trzeba to wiedzieć, zanim się na niej oprzesz. Czarna lista komend jest z definicji niepełna: `sudo claude`, `nohup claude`, `timeout 600 claude`, `bash -c 'claude …'` oraz nazwa binarki podana zmienną **przechodzą** (zmierzone). Pierwsza wersja guarda przepuszczała nawet `KTMS_RELAY_GEN=2 claude --bg …`, czyli dosłownie formę, której uczy §5 tego skilla i którą hook sam wstrzykuje w kontekst — zakaz dawał się pokonać skopiowaniem instrukcji, którą podagent dostał od tego samego mechanizmu. Domknięte, ale reszta luk zostaje: realnie trzyma tu treść wstrzykniętego polecenia, nie regex.

**Dlaczego NIE ma tu reguły `permissions.deny` z `Bash(claude:*)`** — rozważone i odrzucone 2026-09-05 po pomiarze, nie z przeoczenia. Reguła jest mocniejsza od regexa: `POMIAR` (`claude -p --disallowedTools "Bash(claude:*)"`) pokazał, że blokuje `nohup claude …` i `C=claude; $C …`, czyli warianty, których regexem złapać się nie da, i **nie ma fałszywych trafień** na komendach jedynie cytujących `claude` (`echo`, `grep`, `git log --grep`). Wspólną dziurą obu jest `bash -c '…'`.

Blokerem jest **zasięg**: reguły z `settings.json` obowiązują SESJĘ, a nie wybiórczo jej podagentów. Wpisanie tam `Bash(claude:*)` odcięłoby `claude --bg` także orkiestratorowi — czyli zabiłoby mechanizm, na którym stoi cała sztafeta (§5 krok 4). Nie ma zakresu „tylko podagent", a `.claude/agents/*.md` jest nadpisywane przez workflow `sync-claude-toolkit` (`cp -f "${SRC}/agents/"*.md`), więc frontmatter agenta też nie jest trwałym nośnikiem. Zostaje regex w hooku jako obrona w głąb — świadomie słabsza, bo mocniejsza wersja kosztowałaby więcej, niż daje. Ciągłość ma wyłącznie lead: raport wraca do niego, a on decyduje, czy zlecić resztę świeżemu podagentowi z węższym zadaniem. Raport jest przy okazji **punktem kompresji** — 200k eksploracji zamienia się w 2k ustaleń; przekazywanie kontekstu bezpośrednio między podagentami przenosiłoby balast zamiast go ścinać.

Koszt, o którym trzeba pamiętać: raport ląduje w oknie **leada**. Każda runda podagenta go pogrubia, więc podagent ucięty na sufcie przyspiesza zmianę pokolenia u rodzica. Progi stroisz przez `RELAY_SUB_WARN` / `RELAY_SUB_CAP`.

## 1b. Skąd bierze się mianownik — limit wyprowadzany z modelu

Procent nie ma sensu bez okna, a okno **zależy od modelu, nie od stałej**. Hook czyta `.message.model` z mierzonego transkryptu i dobiera limit: `haiku` → 200 000, każdy inny model → 1 000 000 (rozstrzygnięcie właściciela, 2026-09-05). Nadpiszesz przez `RELAY_LIMIT_HAIKU` / `RELAY_LIMIT_DEFAULT`, a awaryjnie przez `RELAY_LIMIT` (wymusza wartość niezależnie od modelu).

**Dlaczego to jest osobna sekcja, a nie szczegół implementacyjny:** zły mianownik psuje mechanizm w OBIE strony i za każdym razem po cichu. Za duży — próg nie odpala się nigdy, ochrona jest próżniowo zielona (dokładnie ten stan, w którym podagent dobija do 800k). Za mały — narzędzia zostają odcięte przy ułamku realnego okna i **niszczą poprawną pracę**. To drugie zdarzyło się naprawdę 2026-09-05: przyjęty z obciętej próbki (`find -size +200k | head -40`) limit 200k dla sonneta uciął żywego podagenta przy 459 849 tokenach, w połowie zadania.

Pomiar rozstrzygający, na **pełnym** zbiorze 975 transkryptów podagentów — maksymalny zaobserwowany kontekst per model:

| model | max zaobserwowany | co to dowodzi |
|---|---|---|
| claude-sonnet-5 | 981 531 | okno ≥ 1M |
| claude-opus-5 | 503 833 | okno ≥ 504k |
| claude-opus-4-7 | 273 157 | okno ≥ 273k |
| claude-sonnet-4-6 | 125 583 | nic ponad 126k |
| claude-haiku-4-5 | 88 458 | nic ponad 89k |

To są **dolne ograniczenia**, nie rozmiary okien — „max zaobserwowany" nigdy nie dowodzi, gdzie kończy się okno. Dlatego obok procentu stoją progi **absolutne** (`RELAY_SUB_WARN_ABS` 500k, `RELAY_SUB_CAP_ABS` 700k, `RELAY_HANDOFF_ABS` 450k, `RELAY_CEILING_ABS` 650k): odpala się to, co wypadnie **wcześniej**. Przy oknie 1M procent zawsze wyprzedza, więc progi absolutne są niewidoczne — ujawniają się dopiero wtedy, gdy limit modelu zgadliśmy za wysoko, i wtedy ratują przed runawayem. Dodając nowy model, nie zgaduj okna: zostaw domyślne 1M i pozwól pracować siatce absolutnej.

**Liczba, którą widzisz w TUI przy działającym podagencie („↓ 456.5k tokens"), to TA SAMA wielkość, którą mierzy hook** — zmierzone: 459 396 wobec 456.5k. To NIE jest suma kumulatywna (ta dla tego samego podagenta wynosiła 54,6 mln, czyli 119×). Możesz więc kalibrować progi po tym, co widzisz na ekranie.

## 2. Fazy atomowe — `hold`

Niektórych faz **nie wolno** przekazać w połowie: plan dopisany do połowy jest gorszy niż plan dokończony o dziesięć punktów drożej, a sonda mutacyjna porzucona w locie zostawia zmutowany plik w drzewie.

**Faza nieatomowa `hold`-a NIE zakłada** — nie wywnioskowuj tego a contrario z listy poniżej. Commit odpalający sześć guardów pre-commit trwa długo i wygląda jak zawieszenie, ale nie jest fazą atomową. Zapomniany `rm -f $SID.hold` znosi progi 40 i 60 do końca życia sesji, więc `hold` zakładany „na wszelki wypadek" jest gorszy niż niezakładany.

Fazy atomowe:
- pisanie planu przez `/writingplans` **razem z audytem specjalistów (Pass 2)** — plan bez Pass 2 nie jest planem;
- sonda mutacyjna w toku (plik zmutowany, jeszcze nieprzywrócony);
- runda review→fix w locie (recenzent oddał findingi, fix niezacommitowany).

Własny `session-id` bierz ze środowiska — **nie wyprowadzaj go z nazwy sesji**:
```bash
SID="$CLAUDE_CODE_SESSION_ID"
mkdir -p ~/.claude/relay-state
```
Wariant przez `claude agents --json | jq 'select(.name==…)'` ma dwa ciche tryby zaniku, oba zmierzone: nazwy `<slug>-g<n>` są generowane deterministycznie, więc powtórzone pokolenie daje dwie sesje o tej samej nazwie, `$SID` staje się dwuliniowy i plik `hold` powstaje pod nazwą ze znakiem nowej linii; a pokolenie 1 nie ma nazwy w ogóle, więc `$SID` jest pusty i powstaje `~/.claude/relay-state/.hold`, którego hook nigdy nie znajdzie. W obu przypadkach `hold` **nie działa i nic o tym nie mówi** — faza atomowa zostaje przerwana progiem, czyli dokładnie ta szkoda, przed którą ta sekcja powstała.

Wejście i wyjście:
```bash
echo "writingplans #<nr>" > ~/.claude/relay-state/$SID.hold   # wejście
rm -f ~/.claude/relay-state/$SID.hold                        # wyjście — OBOWIĄZKOWE
```
`hold` zawiesza progi 40 i 60 (razem z ich wariantami absolutnymi), **nie zawiesza twardego sufitu — ani procentowego (80%), ani absolutnego (`RELAY_HARD_CAP_ABS`, domyślnie 850 000)**. Do 2026-09-05 sufit absolutny w ogóle nie istniał, a `hold` gasił całą siatkę ABS — czyli dokładnie w scenariuszu, dla którego ta siatka powstała (okno zgadnięte za wysoko), faza atomowa zostawała bez jakiegokolwiek sufitu. Furtka bez limitu przestaje być furtką i staje się obejściem mechanizmu. Po dojściu do twardego sufitu w trakcie fazy atomowej: zapisz, co masz, oznacz w ledgerze fazę jako `PRZERWANA` z dokładnym punktem przerwania i przekaż — następca **wznawia fazę od początku**, nie od środka.

## 3. Trwały stan — roadmapa i ledger

Kontekst ginie razem z sesją; repo nie. Dwa pliki, oba **commitowane**:

Roadmapa nie musi być listą issues — może być listą faz dowolnego zadania. Wtedy `issue #<nr>` w nagłówku wiersza ledgera zastąp `etap N`, a pola o gałęzi `agent/issue-<nr>` i triage'u na HEAD pomiń.

**Artefakt narastający przez wiele pokoleń** (raport, inwentarz, plik zbiorczy) dopisuj wyłącznie przez `cat >>` albo `Edit` — `cat >` skasuje pracę poprzednika, a zapis wygląda na w pełni udany. Sprawdź po zapisie `git status --short -- <plik>`: ` M` znaczy dopisane, `??` znaczy, że właśnie stworzyłeś plik na nowo.

**Roadmapa** — `docs/plans/<data>-roadmapa-<slug>.md`, pisze ją pokolenie 1, potem tylko do odczytu:
- lista issues po triage'u, każdy z jednozdaniowym zakresem, szacunkiem faz i etykietą `cloud-safe`/`local-only` (kryterium w §4a);
- kolejność (najpierw to, co odblokowuje resztę; nigdy dwa issues dotykające tej samej tabeli obok siebie);
- **tor realizacji** — sztafeta (domyślny) / orkiestrator / chmura, wybrany wg kryterium z §4a i uzasadniony JEDNYM zdaniem;
- **tryb zakończenia issue** — `gałąź` (domyślny) albo `merge-lokalny` (§4b);
- **tryb łańcucha** — `partia` (domyślny: łańcuch kończy się razem z roadmapą) albo `ciągły`
  (po wyczerpaniu roadmapy powstaje kurator kolejnej fali) — §4c;
- czego łańcuchowi nie wolno: push na `origin`, deploy, `gh issue close`, wysyłka do KSeF.

**Ledger** — `docs/plans/<ten-sam-slug>-ledger.md`, **append-only**, jeden wiersz na zakończoną fazę.

Jedyny wyjątek od append-only to **tabela kolejki faz** w nagłówku (jeśli ją prowadzisz): jej kolumna
`status` z definicji wymaga edycji w miejscu i wolno ją nadpisywać. Wszystko poniżej nagłówka jest
dopisywane i nietykalne. Zmierzone w przebiegu 1: commit ledgera G2 to 47 wstawek i **2 skasowane
linie** — obie w tej tabeli; G2 musiał sam rozstrzygnąć, że to wolno, bo poprzednia wersja tej sekcji
mówiła tylko „append-only" i nie przewidywała tabeli w ogóle. Wiersz fazy, raz dopisany, nie jest
poprawiany — nowe ustalenia idą jako aneks z własnym nagłówkiem.

Format wiersza:

```
## G<gen> · issue #<nr> · faza <triage|plan|exec|verify> · <data godzina>
- Gałąź: agent/issue-<nr>
- Zrobione: <co realnie weszło, z commitami>
- POMIAR: <komenda → wynik; to, co zmierzone>
- WNIOSEK: <to, co wywnioskowane — osobno, nigdy zmieszane z POMIAREM>
- Zostało: <następny krok, konkretnie>
- Miny: <czego następca ma NIE robić i dlaczego>
```

Ledger jest prawdziwym przekazaniem. Prompt startowy następcy to tylko wskaźnik na niego — dzięki temu jakość przekazania nie zależy od tego, ile kontekstu zostało poprzednikowi.

## 4. Role pokoleń

**G1 — kurator.** Wybiera 5-6 issues i pisze roadmapę.

**Tryby bierze z polecenia właściciela, nigdy z wnioskowania.** Domyślnie `tor: sztafeta`, `tryb zakończenia issue: gałąź`, `tryb łańcucha: partia`. `ciągły` i `merge-lokalny` włączasz **wyłącznie na wyraźne żądanie** — kształt zadania („dużo issues", „nie będzie mnie") żądaniem NIE jest. Domysł idzie tu w jedną stronę nieodwracalnie: łańcuch, który sam sobie włączył tryb ciągły, pracuje przez noc nad issues, których właściciel mu nie dał.

**Gdy właściciel NIE podał zestawu issues — zapytaj, zanim cokolwiek wybierzesz.** Pytanie brzmi: czy kurator ma dobrać issues autonomicznie (i w jakim trybie łańcucha), czy właściciel poda listę. To JEDYNY moment, w którym wolno stanąć pytaniem — właściciel dopiero co wydał polecenie, więc jest przy komputerze; od chwili powstania G2 obowiązuje **zakaz zatrzymania pytaniem** z §6 bez wyjątków. Nie odpalaj łańcucha „na próbę" z domyślnym zestawem: pierwsza faza zdąży założyć gałąź i commit, zanim właściciel zobaczy, co wybrałeś. Obowiązkowo **triage na HEAD**: otwarte issue nie znaczy niezrobione (zmierzone: dwa z pięciu były już w `main`). Dla każdego: `git log --oneline --all --grep "#<nr>"`, `gh issue view <nr>`, sprawdzenie, czy opisany defekt nadal istnieje w kodzie. Issue już zrobione → wiersz ledgera `ZAMKNIĘTE NA HEAD` z dowodem, bez wchodzenia w implementację. G1 **nie pisze planów ani kodu** — przy 40% rodzi G2.

**G2..Gn — wykonawcy faz.** Roadmapę i ledger czytaj **jedną komendą** (`cat <roadmapa> <ledger>`), nie dwoma — przy ciasnym paśmie każde wywołanie narzędzia się liczy. Każde pokolenie bierze z ledgera pierwszą niedomkniętą fazę i robi **tylko ją**:
- `plan` → `/writingplans` (faza atomowa, `hold`) → commit planu → przekazanie;
- `exec` → `/executingplans` na `agent/issue-<nr>`, pre-commit gate wg `CLAUDE.md` §4a → przekazanie;
- `verify` → `/verify-e2e` na powierzchni użytkownika → wiersz ledgera z dowodem.

Jedno issue wymagające trzech-czterech pokoleń jest **normalne**, nie awarią.

**Reguła końca fazy (deterministyczna, bez pytania właściciela).** Po dopisaniu wiersza ledgera i
jego commicie przeczytaj ledger ponownie. Weź kolejną fazę **w tej samej sesji**, jeśli WSZYSTKIE
trzy warunki zachodzą naraz:
1. istnieje kolejna niedomknięta faza w roadmapie;
2. bieżące zużycie okna jest poniżej `RELAY_WARN`;
3. kolejna faza nie jest na liście wykluczeń poniżej.

Zrodzenie następcy (§5) jest zarezerwowane dla przypadku, w którym którykolwiek z tych trzech
warunków nie zachodzi — nie dla samego faktu domknięcia fazy. Domyślnym ruchem pokolenia z zapasem
okna jest **wziąć kolejną fazę**, nie przekazać ją dalej.

**Lista wykluczeń** — kolejnej fazy NIE bierz w tej samej sesji, tylko zródź następcę:
- faza wymaga wyłącznego slotu na pełną suitę;
- faza dotyka tego samego pliku co faza właśnie domknięta, a recenzent ma ją oceniać niezależnie;
- faza jest atomowa (§2, `hold`) i nie mieści się w rezerwie do `RELAY_WARN`;
- faza wymaga innego worktree niż bieżący.

`POMIAR` (zdarzenie 2026-09-05): pokolenie domknęło fazę `verify`, zużyło ~0,05% okna, nie
przekroczyło żadnego progu — i mimo to zatrzymało się, pytając właściciela, czy wziąć następną fazę.
Poprzednia wersja tej sekcji nakazywała wyłącznie „zrób TYLKO ją" i nie opisywała żadnego ruchu dla
stanu „faza domknięta, próg niezapalony, roadmapa niewyczerpana". `WNIOSEK`: zachowanie pokolenia
było zgodne z ówczesnym skillem — wada była w skillu, nie w agencie; reguła wyżej ją zamyka.

**Pod torem orkiestratora role pokoleń z tabeli wyżej nie obowiązują** — nie ma kolejnych pokoleń, tylko jedna długowieczna sesja-lead (nie czyta plików, nie pisze kodu) i subagenci per faza z `isolation: worktree`. Mechanika, format `/goal` i to, czego lead nie robi → `references/tor-orkiestratora.md`.

## 4a. Wybór toru

Trzy tory, wybór na G1, zapisany w roadmapie (§3) i uzasadniony JEDNYM zdaniem:

| Tor | Kiedy | Kto pracuje |
|---|---|---|
| **Sztafeta** (domyślny, §1-§7 niżej) | wszystko poza dwoma wierszami niżej — w tym fazy długie/atomowe (§2, `hold`) i partie, gdzie fazy nachodzą na te same pliki | kolejne sesje, jedna na raz |
| **Orkiestrator** | fazy KRÓTKIE i ROZŁĄCZNE PLIKOWO — subagenci mogą biec równolegle w osobnych worktree bez kolizji | jedna sesja-lead + subagenci (`isolation: worktree`) |
| **Chmura** | partia oznaczona `cloud-safe` | `claude --cloud`, jedna sesja na issue |

Zmierzona zaleta sztafety u właściciela: pozwala domknąć kilka issues bez podchodzenia do komputera i zużywa wyraźnie mniej tokenów niż poprzedni układ — dlatego zostaje domyślna, a dwa pozostałe tory są wyjątkiem dla konkretnego kształtu partii, nie równorzędną alternatywą wybieraną swobodnie.

**Triage G1 etykietuje KAŻDE issue `cloud-safe` albo `local-only`.** `local-only` to co najmniej: zależność od lokalnej bazy MySQL, od dev servera (`localhost:8080`), od sandboxa KSeF, od plików spoza repo (udziały sieciowe, `Z:\`, `Y:\`). Issue etykietowalne `cloud-safe` może iść torem chmurowym niezależnie od tego, którym torem idzie reszta partii — etykieta jest per issue, tor bazowy jest per partia.

> **Pułapka zmierzona suchą próbą (2026-09-05):** worktree subagenta odgałęzia się od `origin/<gałąź domyślna>`, **nie** od lokalnego HEAD leada — praca leada sprzed pusha jest dla subagenta niewidoczna, a jego raport i tak wygląda poprawnie. W worktree nie ma też `.env`, więc „testy zielone" jako kryterium odbioru da SKIP zamiast wyniku. Szczegóły i pozostałe pomiary → `references/tor-orkiestratora.md`.

Mechanika toru orkiestratora (co robi lead, co robi subagent, warunek domknięcia, jak wpisywać wiersze ledgera, czego lead NIE robi) → `references/tor-orkiestratora.md`. §1-§7 tego skilla opisują tor sztafety. Pod torem orkiestratora **nie stosuje się WYŁĄCZNIE tego, co dotyczy przekazania pracy między sesjami** — czyli mechaniki rodzenia następcy z §5, podziału fali na dwie równoległe sztafety z §6a **oraz trybu
`ciągły` z §4c** (rodzenie kuratora JEST rodzeniem następcy, a pod tym torem kolejnych pokoleń nie ma —
nową falę otwiera właściciel). **`merge-lokalny` (§4b) obowiązuje pod torem orkiestratora bez zmian**,
z jedną poprawką aktora: scala lead po odebraniu dowodu z fazy `verify`, nie „pokolenie". **Pod torem
chmurowym `merge-lokalny` jest ZAKAZANY** — sesja `claude --cloud` nie ma lokalnego `main` właściciela,
a jej jedynym wyjściem jest push, czyli dokładnie ta akcja, której §4b zabrania. Wszystko inne obowiązuje bez zmian, a w szczególności dwie rzeczy, które łatwo uznać za nieaktualne, a nie są:

- **Rozłączność plikowa z §6a obowiązuje TAK SAMO.** Subagenci mają własne worktree, ale lead pisze roadmapę i ledger w drzewie WSPÓLNYM — więc rozłączne slugi, osobne pliki ledgera i zakaz dwóch równoległych zapisów do tego samego pliku zostają w mocy.
- **Właściciela powiadamiaj przez `PushNotification`, nigdy wiadomością do agenta** (§5). To reguła o kanale do CZŁOWIEKA, nie o sekwencyjności — pod tym torem jest tak samo wiążąca.

## 4b. Tryb zakończenia issue — `gałąź` i `merge-lokalny`

Roadmapa deklaruje w §3 jeden z dwóch trybów. `gałąź` (domyślny) znaczy: łańcuch kończy pracę nad issue na `agent/issue-<nr>` i nie dotyka `main` — dokładnie tak działa `CLAUDE.md` §4c. `merge-lokalny` znaczy: pokolenie domykające fazę `verify` scala gałąź do **lokalnego** `main`. Zakaz pusha na `origin` zostaje w mocy bez zmian — scalenie jest lokalne i odwracalne, push nie jest.

**Scala pokolenie domykające `verify`, nie osobna faza.** Scalenie bez świeżego dowodu z powierzchni użytkownika byłoby scaleniem na słowo; pokolenie, które ten dowód właśnie zebrało, jest jedynym, które go ma w kontekście.

**Bramka — wszystkie pięć warunków naraz, każdy zmierzony PRZED `git merge`:**

1. `verify` zielone — dowód na powierzchni użytkownika, nie „testy przechodzą".
2. Pre-commit gate przeszedł (`CLAUDE.md` §4a): testy celowane, `php -l`, `code-reviewer` wg progów
   z **`CLAUDE.md` §4** (nie §4 tego skilla — tam są role pokoleń). Dowód: **w ledgerze istnieje wiersz
   fazy `exec` tego issue z polem `POMIAR` niosącym wynik gate'u**. Pokolenie scalające nie ma tego
   zdarzenia we własnym kontekście, więc bez wiersza ledgera warunek jest niesprawdzalny — a warunek
   niesprawdzalny domyślnie NIE jest spełniony.
3. Recenzent bez findingów **`CRITICAL` ani `REQUIRED`** — to słownik, którym `code-reviewer` realnie
   kończy raport (`.claude/agents/code-reviewer.md` §Output Format). **Nie pisz tu „P0/P1"**: `P0`..`P3` to
   etykiety GitHuba, warstwa bez związku z wyjściem recenzenta, a warunek zapisany tym słownikiem jest
   spełniony przez raport „❌ CHANGES REQUIRED, 3 × CRITICAL" — czyli bramka strzegąca `main` staje się
   próżniowo zielona. Finding `PLAUSIBLE` nie jest tu rozstrzygany: zatrzymuje CAŁY łańcuch wg §6,
   więc do pytania o merge w ogóle nie dochodzi.
4. Drzewo czyste i wyłączne. Czyste: `git status --porcelain --untracked-files=no` puste **oraz**
   `git stash list` puste. `POMIAR` (2026-09-06): samo `git status --porcelain` daje w tym repo **16 linii**
   trwałych `??` (`dev-server/`, `.claude/worktrees/`, `report/`, `docs/hansetank/`) — warunek bez
   `--untracked-files=no` wypada ZAWSZE i cicho degraduje `merge-lokalny` do trybu `gałąź`. Nieśledzone
   pliki na merge nie wpływają. Wyłączne: żadna inna sesja/fala nie pisze w tym drzewie — mierz **mtime
   transkryptów pokoleń oraz katalogu `<sesja>/subagents/`** wg §6; `status` z `claude agents` kłamie
   (zmierzone tam). Scalenie przy cudzej niezastage'owanej pracy to klasa szkód z §5.
5. Gałąź zawiera aktualny `main`: `git merge-base --is-ancestor main agent/issue-<nr>` → `0`. Jeśli `1` — najpierw `git merge main` **w gałęzi**, dopiero potem scalaj w drugą stronę.
   **Konflikt przy TYM scaleniu również kończy się `git merge --abort`** — łańcuch nie rozstrzyga
   konfliktów w żadnym kierunku, bo szkoda z akapitu „Konflikt" niżej jest identyczna niezależnie od
   kierunku.

Którykolwiek warunek niespełniony → **nie scalaj**, zostaw gałąź, wpisz do ledgera pole „Zostało: merge
zablokowany — <który warunek, z pomiarem>". Zablokowany merge sam w sobie **nie** zatrzymuje łańcucha —
z jednym wyjątkiem: gdy blokadą jest finding `PLAUSIBLE`, pierwszeństwo ma §6 i łańcuch **staje**.

**Procedura (wszystkie warunki spełnione):**

```bash
git merge --no-ff agent/issue-<nr> -m "fix(<moduł>): <opis po polsku> (#<nr>) [roadmapa]"
```

`--no-ff` jest obowiązkowe: fast-forward gubi granicę issue w historii, a to jedyny ślad, po którym da się potem cofnąć jedno issue bez ruszania reszty fali.

**Konflikt → `git merge --abort`, koniec.** Nie rozstrzygaj go w łańcuchu. Zmierzone: przy konflikcie w `docs/` odruch „weź moją wersję" (`--ours`/`--theirs`) cicho zjada cudzy akapit, a dokumentacja nie ma zapadki, która by to złapała. Po `--abort`: wiersz ledgera „merge zablokowany — konflikt w <pliki>", `PushNotification` do właściciela, następna faza.

**Po udanym scaleniu, w tej samej turze:**

```bash
php -l <zmienione pliki>            # sanity po scaleniu, nie zamiast pkt 2
gh issue edit <nr> --add-label "status:zrobione-lokalnie"
```

Etykieta `status:zrobione-lokalnie` („Zaimplementowane + merge do lokalnego main, jeszcze NIE wdrozone na serwer") jest **jedynym sygnałem, po którym kurator późniejszej fali rozpozna, że issue jest zrobione** — `gh issue list --state open` nadal je pokaże, bo łańcuchowi nie wolno zamykać issues. Pominięcie etykiety kosztuje pełny triage tego samego issue w kolejnej fali.

**Znacznik `[roadmapa]` w komunikacie scalenia jest obowiązkowy i ma jednego odbiorcę: krok PRZED
pushem.** `POMIAR` (2026-09-06): `tests.yml` odpala się na push do `main`, `deploy.yml` na `workflow_run`
z `conclusion == success` → webhook serwera; `CLAUDE.md` §2 autoryzuje push na GitHub z góry, bez pytania;
`git log origin/main..main` → 18 commitów, czyli batchowanie pushy jest tu praktyką; `.git/hooks` pusto.
`WNIOSEK`: scalenie jest odwracalne w drzewie, ale NIE w skutkach — zmienia to, co zrobi następny
rutynowy push. Dlatego `CLAUDE.md` §2 wymaga sprawdzenia
`git log origin/main..main --merges --grep '\[roadmapa\]'` przed pushem `main`, a niepusty wynik znosi
zgodę udzieloną z góry. Znacznik pominięty = praca łańcucha nieodróżnialna od własnych commitów
właściciela.

Czego przy `merge-lokalny` nadal **nie wolno**: `git push`, `gh issue close`, deploy, `npm run build`, zmiana `USE_BUNDLE`. Scalone do lokalnego `main` znaczy „gotowe do przejrzenia przez właściciela", nie „wdrożone".

## 4c. Tryb łańcucha — `partia` i `ciągły`

Roadmapa deklaruje też, co się dzieje po wyczerpaniu listy issues:

- **`partia`** (domyślny) — łańcuch kończy się razem z roadmapą, wg §6.
- **`ciągły`** — pokolenie domykające ostatnią fazę nie kończy łańcucha, tylko rodzi następcę z rolą **kuratora**: nowa fala, nowa roadmapa, nowy ledger, ten sam łańcuch.

Tryb ciągły wprowadza jedną zmianę nazewniczą, bez której fale nie dają się policzyć: slug ma postać `<baza>-w<k>`, a pliki to `docs/plans/<data>-roadmapa-<baza>-w<k>.md` i `…-w<k>-ledger.md`. Numer fali **wyprowadzasz z historii gita**, nigdy z pamięci, z promptu ani z listingu katalogu:

```bash
k=$(( $(git log --diff-filter=A --name-only --pretty=format: -- 'docs/plans/*-roadmapa-<baza>-w[0-9]*.md' \
        | grep -v -- '-ledger\.md$' | grep -c . ) + 1 ))
```

Dwie pułapki, obie zmierzone 2026-09-06, obie dające liczbę wyglądającą na poprawną:

- **Glob łapie ledger.** Fala zostawia `…-w1.md` **i** `…-w1-ledger.md`, więc `ls | wc -l` liczy każdą falę dwa razy: po pierwszej fali `k=3` zamiast `2`, po drugiej `k=5` zamiast `3`. Numery w nazwach plików kłamią (w1, w3, w5…), a cap „30 fal" odpala po szesnastu. Stąd `grep -v -- '-ledger\.md$'`.
- **`-w*` łapie zwykłe słowa.** `POMIAR`: wzorzec `*-roadmapa-*-w*.md` zwraca w tym repo
  `2026-09-05-roadmapa-fala-**w**rzesniowa.md` — falę z trybu `partia`, która numeru nie ma. Stąd
  `-w[0-9]*`, zweryfikowane dwoma narzędziami (`git log` i `ls | grep -E`): oba dają dziś `0`.
- **Listing katalogu gubi zarchiwizowane.** `POMIAR`: `docs/plans/zrealizowane/` ma 273 pliki — przenoszenie domkniętych planów jest tu ustaloną praktyką. Glob nie schodzi rekurencyjnie, więc archiwizacja **obniża `k`**: cap odsuwa się w nieskończoność, a nowa fala dostaje numer już użyty. Historia gita przenoszenia nie gubi.

Licznik trzymany w kontekście albo w `relay-state/` ginie razem z sesją i wygląda przy tym na działający — a to jest dokładnie ten stan, w którym cap na fale przestaje odpalać po cichu. Policz `k` **dwoma różnymi narzędziami**, zanim nazwiesz pliki fali.

### Dobór partii przez kuratora

Kurator nowej fali robi triage na HEAD wg §4 (to obowiązuje bez zmian) i dobiera 5-6 issues, w tej kolejności kroków:

1. **Warunki stopu PRZED doborem** — sprawdź je, zanim cokolwiek policzysz (§6).
2. **Zbiór kandydatów:** `gh issue list --state open` **minus** wszystko z etykietą
   `status:zrobione-lokalnie` (scalone przez wcześniejsze fale, wciąż otwarte, bo łańcuchowi nie wolno
   zamykać issues), `status:odlozone`, `tor:remediacja-danych` — **minus klasa pomysłów, wg sekcji niżej**.
3. **Kolejność wg priorytetu:** `P0` → `P1` → `P2` → `P3`, z przestarzałymi odpowiednikami
   (`priorytet:krytyczny|wysoki|sredni|niski`) traktowanymi na równi; na końcu issues **bez** etykiety
   priorytetu — nigdy jako domysł „pewnie średni". `POMIAR` (2026-09-06): 13 ze 148 otwartych nie ma
   priorytetu, a `P0`..`P3` i `priorytet:*` nie współwystępują ani na jednym issue z 625, więc mapowanie
   jest jednoznaczne.
4. **Odsiej odłożone:** `--label status:odlozone` wypada ze zbioru kandydatów. Dla reszty — kontrola
   odłożenia per issue wg dwóch sekcji niżej; to najdroższy krok tego skilla do pominięcia.
5. **Rozłączność plikowa w partii** wg §3: nigdy dwa issues dotykające tej samej tabeli ani tego samego pliku obok siebie.

### Autonomicznie WYŁĄCZNIE naprawy — o nowej funkcjonalności decyduje właściciel

Kurator dobiera samodzielnie tylko issues opisujące **defekt, dług albo regresję**: błąd, znalezisko audytowe, martwy kod, brakująca zapadka, niezastosowana migracja, podatność. **Pomysł na nową funkcjonalność jest decyzją właściciela** i nie wchodzi do żadnej fali dobranej autonomicznie — nawet oznaczony `P1`, nawet gdy stoi na szczycie listy priorytetów. Właściciel może go wskazać wprost; kurator nie może go wybrać za niego.

Odsiew idzie w dwóch krokach, bo etykiety same nie wystarczą:

1. **Po etykiecie — wyklucz bezwarunkowo:** `typ:pomysl` oraz jego przestarzałe odpowiedniki na starych
   issues (`enhancement`, `new_idea`, `request`), a także `typ:analysis` („analiza/decyzja, bez zmian
   kodu" — z definicji rozstrzygnięcie człowieka).

   Etykiety w tym repo mają od 2026-09-06 trzy osie i **nowe** issue nosi po jednej z każdej:
   `modul:*` (czego dotyczy), `P0`..`P3` (priorytet), `typ:*` (`typ:bug`, `typ:point-fix`,
   `typ:structural`, `typ:test`, `typ:analysis`, `typ:pomysl`). Stare issues zostały jak były, więc
   kurator musi rozumieć OBA słowniki: `bug` ≈ `typ:bug`, `enhancement`/`new_idea`/`request` ≈
   `typ:pomysl`, `priorytet:krytyczny|wysoki|sredni|niski` ≈ `P0`..`P3`. Przestarzałe warianty mają to
   wpisane we własny opis (`gh label list`) — nie zgaduj mapowania z nazwy.
2. **Po treści — przeczytaj resztę.** `POMIAR` (2026-09-06): ze 148 otwartych issues **89 nie ma żadnej etykiety typu** (i 105 nie ma `modul:*`); klasa naprawy oznaczona etykietą to 51, klasa pomysłu — 1, `typ:analysis` — 8. Próbka tych 89 to niemal wyłącznie znaleziska audytowe i dług (`[ARCH-*]`, `[DEP-*]`, `[TEST-*]`, martwy kod, niezastosowana migracja). `WNIOSEK`: reguła „bierz tylko oznaczone jako bug" wycięłaby ~60% realnej pracy naprawczej, więc brak etykiety **nie** wyklucza — wyklucza dopiero treść.

**Błąd odsiewu jest niesymetryczny i to on ustala domyślną odpowiedź przy wątpliwości.** Wzięcie pomysłu = łańcuch buduje przez noc funkcjonalność, której nikt nie zamawiał, i scala ją do lokalnego `main`. Pominięcie naprawy = czeka jedną falę. Przy genuinie niejasnej treści **wyklucz** i wpisz issue do roadmapy w sekcji „do decyzji właściciela".

Każde wykluczenie po treści **oznacz etykietą** (`enhancement` dla pomysłu) razem z krótkim komentarzem. Bez tego następna fala przeczyta to samo issue od nowa, a któraś w końcu przeczyta je pobieżnie.

### Kontrola odłożenia

**Odłożenie opisuje się W SAMYM ISSUE** — etykieta `status:odlozone` plus komentarz mówiący, *co* je odblokuje. Etykieta jest sygnałem maszynowym (kurator odsiewa nią kandydatów jednym `gh issue list`), komentarz jest sygnałem dla człowieka. Sama proza bez etykiety nie wystarcza: kurator czyta listę, nie każdy komentarz.

Obowiązek jest po stronie tego, kto odkłada — właściciela albo pokolenia łańcucha, które napotka warunek z listy niżej. Odłożenie zapisane wyłącznie w planie albo w runbooku jest odłożeniem, o którym GitHub nie wie.

```bash
gh label create status:odlozone --color C5DEF5 \
  --description "Wstrzymane decyzja/oknem obserwacji — kurator roadmapy NIE bierze" 2>/dev/null || true
gh issue edit <nr> --add-label "status:odlozone"
gh issue comment <nr> --body "Odłożone: <powód>. Odblokuje: <warunek>. Źródło: <plik:linia>."
```

Powody, dla których issue jest odłożone:

- świadoma decyzja właściciela o wyłączeniu z fali;
- okno obserwacji / pomiarowe, które musi upłynąć — czasu nie da się nadrobić pracą agenta;
- plan etapu czekający na rozstrzygnięcie człowieka;
- etykieta `tor:remediacja-danych` (z definicji „decyzja czlowieka") — odkłada samodzielnie, bez `status:odlozone`;
- wymóg czegoś zabronionego z §6 (push, deploy, produkcja, KSeF).

### Zapadka na zastane issues — grep po repo

Konwencja etykiety obowiązuje od 2026-09-06 i **nie działa wstecz**. `POMIAR` (2026-09-06, issue #592): stan `OPEN`, etykiety `P1`, `typ:structural`, `modul:security`, zero komentarzy o wstrzymaniu — a odłożenie jest zapisane w repo, w dwóch miejscach naraz: `docs/plans/2026-09-05-czas-blokady-edycji-z-serwera-664.md:182` („#592 jest ŚWIADOMIE wyłączone z tej fali decyzją właściciela") oraz `docs/runbook/23-okno-obserwacji-write-route-enforce-592.md` (okno obserwacji). `WNIOSEK`: dla issue założonego przed tą datą GitHub nie jest źródłem prawdy o tym, czy wolno je teraz wziąć.

Dlatego dla KAŻDEGO kandydata bez `status:odlozone`, przed wciągnięciem do partii:

```bash
grep -rlnE "#<nr>\b" docs/plans docs/runbook --include='*.md' \
  | grep -v -- '-ledger\.md$' \
  | xargs grep -lE 'ŚWIADOMIE wyłączon|świadomie wyłączon|odłożon|wstrzyman|okno obserwacji|decyzj[ai] właściciela'
```

Filtr jest tu częścią reguły, nie optymalizacją. `POMIAR` (2026-09-06): goły `grep -rln "#592"` daje **26 plików**, bo wiersze ledgera mają format `## G<gen> · issue #<nr> · faza …` i leżą w `docs/plans` — każde issue tknięte przez jakąkolwiek falę gwarantuje trafienia. Nakaz „przeczytaj KAŻDE trafienie" przy 5-6 kandydatach oznaczałby ponad sto plików, a od 60 % okna `Read`/`Grep`/`Glob` dostają `deny` (§1). Krok nazwany „najdroższym do pominięcia" byłby wtedy zaprojektowany tak, że pominięcie go jest jedynym sposobem zmieszczenia się w oknie. `\b` odcina przy okazji `#5921` przy szukaniu `#592`.

Trafienie opisujące odłożenie → **wyklucz z partii, wpisz do roadmapy jako `ODŁOŻONE` z `plik:linia`, i dopisz brakującą etykietę razem z komentarzem** wg bloku wyżej. Retro-etykietowanie jest częścią kroku, nie uprzejmością: bez niego następna fala zapłaci za ten sam grep od nowa, a któraś w końcu go pominie.

`grep` bez trafień jest pomiarem, że **repo nic o odłożeniu nie mówi** — nie pomiarem, że issue jest gotowe. Trafienie przeczytane pobieżnie jest gorsze niż brak grepa, bo daje fałszywą pewność.

### Kurator NIE jest zwykłym pokoleniem

Kurator pisze roadmapę i ledger nowej fali, i **na tym kończy** — planów ani kodu nie pisze (§4, G1). Pierwszy wiersz nowego ledgera zawiera zmierzone progi i numer fali. Następcę rodzi wg §5 bez zmian.

## 5. Protokół przekazania

Kolejność jest istotna — każdy krok chroni przed konkretną, zmierzoną szkodą:

1. **Zacommituj WSZYSTKO z pathspec** (`git commit -m "..." -- <ścieżki>`). Następca pracuje w tym samym drzewie i nie zobaczy niczego, co masz tylko w kontekście. Commituj z pathspec: `git commit -m "..." -- <ścieżki>` — w drzewie wielosesyjnym samo `git add` nie chroni, bo indeks jest wspólny.
2. **Dopisz wiersz do ledgera i zacommituj go.**
3. **Zrodź następcę.** Prompt startowy JEST dostarczeniem handoffu **następcy** — osobny `SendMessage` do niego zbędny. Nie myl tego z **raportem do właściciela**: raport idzie przez `SendMessage` i jest osobnym obowiązkiem każdego pokolenia. Handoff → prompt, raport → SendMessage, a plik na dysku bez wysłania to notatka, nie przekazanie:
   **Spawn i zapis `.gen` MUSZĄ być JEDNYM wywołaniem Bash** — rozdzielone na dwa kroki dają się
   pominąć. Zmierzone 2026-09-05, przebieg 1: G5 zrodził G6 i **nie zapisał `.gen`**; sesja wiedziała
   z promptu, że jest szósta, a hook liczył ją jako drugą. G2, G3 i G4 ten sam krok wykonały — czyli
   nie chroni tu nic poza pamięcią pokolenia:
   ```bash
   OUT=$(claude --bg -n '<slug>-g<n+1>' \
     "Jesteś pokoleniem <n+1> łańcucha roadmapa. Roadmapa: <ścieżka>. Ledger: <ścieżka>.
      Przeczytaj OBA. PRZED wzięciem fazy sprawdź sygnał STOP wg §6 (dwie komendy, gałąź i worktree).
      Potem weź pierwszą niedomkniętą fazę i zrób TYLKO ją.
      Poprzednik: <id> — NIE zdejmuj go." 2>&1); echo "$OUT"
   NEW=$(printf '%s' "$OUT" | grep -oE '\b[0-9a-f]{8}\b' | head -1)
   echo <n+1> > ~/.claude/relay-state/$NEW.gen
   touch ~/.claude/relay-state/$CLAUDE_CODE_SESSION_ID.spawned
   cat ~/.claude/relay-state/$NEW.gen   # potwierdzenie zwrotne — bez niego pominięcie wygląda jak wykonanie
   ```
   Plik `<własny-sid>.spawned` mówi hookowi, że TA sesja już przekazała pracę — dzięki temu próg 40,
   który wypadnie później, nie każe jej zrodzić następcy po raz drugi (zmierzone: u G2 wtrysk „zródź
   następcę" przyszedł 2,5 minuty PO tym, jak G2 następcę już zrodził).
   **Zdejmowanie poprzednika jest krokiem OPCJONALNYM, nie domyślnym.** Domyślnie następca ma go zostawić. Wpisz `zdejmij go: claude rm <id>` tylko wtedy, gdy jednocześnie: poprzednik jest sesją tła (pokolenie ≥ 2), jego transkrypt nie będzie już potrzebny, i nikt nie jest do niego podłączony. Odwrotna kolejność — domyślne zdejmowanie z wyjątkiem na pokolenie 1 — zmusza KAŻDE pokolenie do rozstrzygania tego z pamięci, a pomyłka w jedną stronę jest nieodwracalna (ubija okno terminala właściciela). Zmierzone w suchym przebiegu: oba pokolenia musiały przepisać to zdanie na zaprzeczenie.
   `$NEW` to id, które wypisał `claude --bg`. `KTMS_RELAY_GEN` w linii poleceń **nie działa**: `POMIAR` 2026-09-05 — `claude --bg` dziedziczy środowisko *demona tła*, przechwycone przy jego pierwszym starcie, a nie komendy rodzącej; `KTMS_RELAY_GEN=42` dało w sesji `2`, a dodatkowa zmienna nie dotarła wcale. Ta sama pułapka dotyczy prób strojenia progów przez env w spawnowanej sesji — nie zadziała.

   `<id>` to **pierwsze 8 znaków twojego `session_id`** (zmierzone: `claude --bg` drukuje `65dd6e14`, `agents --json` pokazuje `65dd6e14-7d01-...`). **Pokolenia 1 nie zdejmuj nigdy** — to okno terminala właściciela.
4. **Potwierdź start** (`claude agents --json`), powiadom właściciela i **zatrzymaj się NATYCHMIAST**.

   **„Zatrzymaj się" znaczy: następne wywołanie narzędzia po potwierdzeniu startu jest złamaniem
   protokołu.** Nie „dokończ jeszcze jedną rzecz", nie „dopisz aneks". Zmierzone w przebiegu 1, DWA
   RAZY, tak samo: G2 zrodził G3 o 11:52:46 i pracował do 11:55:30, robiąc po drodze commit
   `ea8321625` do wspólnego drzewa; G3 zrodził G4 o 12:07:50 i pracował jeszcze 5 minut. O 12:12
   trzy pokolenia miały żywe transkrypty w jednym drzewie — dokładnie ta klasa szkód, którą ta
   sekcja zamyka.

   **Właściciela powiadamiaj przez `PushNotification`, nigdy przez `SendMessage`.** Zmierzone: trzy
   pokolenia (G2, G3, G4) wysłały raport na `SendMessage` do id poprzednika i **wszystkie trzy
   dostały `success:false`** („No agent named '9b01d99a' is reachable") — sesja pokolenia 1 zdążyła
   się zamknąć. Id poprzednika, które dostajesz w prompcie, jest adresem DO SPRZĄTANIA, nie adresem
   właściciela; właściciel nie ma stałej nazwy sesji, więc jedynym pewnym kanałem jest push.

   **Nie raportuj poprzednikom.** Zmierzone: G3 wysłał raport do `roadmapa-wrzesien-g2` i **wybudził
   sesję, która stała na 41% okna** i już przekazała pracę — dokładając jej zużycia bez żadnego
   pożytku. Ustalenia dla następców idą do ledgera, nie do poprzedników.

Łańcuch jest **ściśle sekwencyjny**. Dwie sesje piszące w jednym drzewie to zmierzona klasa szkód: cudzy plik skasowany przez `cat >`, cudza niezastage'owana praca zniknięta, commit porywający cudze pliki.

## 6. Warunki zatrzymania

**Zakończenie sukcesem — zależy od trybu łańcucha (§4c).** Pod trybem `ciągły` pokolenie domykające
ostatnią fazę roadmapy sprawdza warunki stopu niżej i — jeśli żaden nie zachodzi — rodzi **kuratora**
kolejnej fali zamiast kończyć; akapit poniżej opisuje tryb `partia`.

**Tryb `partia`.** Pokolenie, które domyka OSTATNIĄ fazę roadmapy, **nie rodzi następcy** — pisze wiersz ledgera z adnotacją „roadmapa wyczerpana", raportuje właścicielowi i zatrzymuje łańcuch. Musi też wpisać ten zakaz do promptu następcy… którego nie ma, więc obowiązek spada na pokolenie WCZEŚNIEJSZE: jeśli widzisz, że po Twojej fazie zostaje już tylko jedna, napisz następcy wprost „po tej fazie NIE rodź kolejnego pokolenia". Bez tego zdania powstaje pokolenie, które otwiera ledger i nie znajduje niedomkniętej fazy. Zmierzone w suchym przebiegu — G2 musiał tę instrukcję wymyślić sam.

**Zakaz zatrzymania pytaniem.** Obowiązuje od chwili powstania G2. Jedyny wyjątek jest przed łańcuchem,
nie w nim: G1 bez podanego zestawu issues MA zapytać, czy dobierać je autonomicznie (§4). Potem — żadne
pokolenie nie stoi bezczynnie, czekając na odpowiedź
właściciela — właściciela nie ma przy komputerze, więc pytanie bez odpowiedzi jest zatrzymaniem
łańcucha bez żadnego z warunków niżej. Przy stanie nieprzewidzianym (nie pasuje ani do reguły końca
fazy z §4, ani do żadnego punktu z listy niżej) pokolenie: (1) wykonuje najtańsze odwracalne
działanie, jakie da się uzasadnić z ledgera i roadmapy; (2) zapisuje niepewność w wierszu ledgera
(pole „Miny": „stan nieprzewidziany — <opis>, podjęto <działanie>"); (3) powiadamia właściciela przez
`PushNotification`. `POMIAR` (zdarzenie 2026-09-05): pokolenie z zużyciem ~0,05% okna zatrzymało
łańcuch pytaniem, czy wziąć następną fazę — dokładnie ten stan domyka reguła końca fazy w §4 razem
z tym zakazem.

Zatrzymaj łańcuch awaryjnie i powiadom właściciela, gdy:
- **zastój** — dwa kolejne pokolenia nie dopisały wiersza `Zrobione` do ledgera; zadanie się nie zbiega i decyzja należy do człowieka.
  **Ciszy nie mierz po transkrypcie pokolenia ani po `status` z `claude agents` — oba kłamią.**
  Zmierzone: (a) rodzic zablokowany na `Agent` NIE PISZE własnego transkryptu przez całą rundę
  recenzji — G6 milczał 12,5 minuty przy zerze commitów, podczas gdy dwóch jego recenzentów
  pracowało (transkrypty w `<sesja>/subagents/` zapisywane minutę przed alarmem); (b) `status: busy`
  utrzymywał się dla G2 jeszcze 13 minut po jego ostatnim wywołaniu API. Żywotność mierz mtime
  transkryptów pokoleń **oraz katalogu `<sesja>/subagents/`**;
- osiągnięto `RELAY_MAX_GEN` (domyślnie 30);
- **zapalony sygnał STOP** — sprawdza go KAŻDE pokolenie po domknięciu swojej fazy, nie tylko kurator.
  Jest to kanał właściciela do łańcucha, który nie ma z nim kontaktu: łańcuch dokańcza bieżące issue,
  dopisuje wiersz ledgera „stop na żądanie właściciela" i staje. **Sprawdzenie MUSI być odporne na
  gałąź i na worktree** — obie komendy, wystarczy jedna zapalona:

  ```bash
  test -f ~/.claude/relay-state/STOP-roadmapa && echo STOP        # niezależne od gałęzi i drzewa
  git cat-file -e main:docs/plans/STOP-roadmapa 2>/dev/null && echo STOP   # trwałe, przeżywa relay-state
  ```

  `POMIAR` (repo syntetyczne, 2026-09-06): plik zacommitowany na `main` jest **NIEWIDOCZNY** przez
  `test -f` z gałęzi `agent/issue-1` i z `git worktree` tej gałęzi — a to jest dokładnie miejsce, w którym
  biegną fazy `exec` i `verify` (§4) i w którym §6a każe trzymać każde issue. Samo
  `test -f docs/plans/STOP-roadmapa` byłoby więc hamulcem niewidocznym dla pokoleń, które mają go
  nacisnąć — ochroną próżniowo zieloną, tą samą klasą co progi z niewłaściwym mianownikiem (§1b).
  Właściciel zapala sygnał najprościej przez `touch ~/.claude/relay-state/STOP-roadmapa`; wariant
  w repo jest dla trwałości i wymaga commita na `main`.
  **Polecenie „niech to będzie ostatnie" wydane żywej sesji wiadomością NIE wystarcza** — ginie razem
  z jej kontekstem, a następca go nie zobaczy; pokolenie, które takie polecenie dostanie, ma
  **natychmiast utworzyć ten plik** (`touch docs/plans/STOP-roadmapa`) i go zacommitować, zanim zrobi
  cokolwiek innego. Trwały stan mieszka w repo, nie w kontekście (§3);
- **tryb `ciągły`: numer fali przekroczył 30** (`k` liczone wg §4c).
- **`RELAY_GEN` przekroczył `RELAY_MAX_GEN`** — sprawdzasz to **SAM**, komendą, po domknięciu fazy:
  ```bash
  cat ~/.claude/relay-state/${CLAUDE_CODE_SESSION_ID:0:8}.gen
  ```
  `POMIAR` (2026-09-06): `~/.claude/hooks/relay-post.sh:84` — warunek `[ "$RELAY_GEN" -ge "$RELAY_MAX_GEN" ]`
  stoi **wewnątrz gałęzi progu `handoff`**, więc cap emituje się wyłącznie wtedy, gdy zapali się próg
  procentowy. Tymczasem lista wykluczeń z §4 każe rodzić następcę **poniżej progu** (inny worktree, faza
  atomowa, wyłączny slot) — łańcuch przekazujący pracę na granicach faz przy kilku procentach zużycia
  przejdzie pokolenie 31, 50, 80 i hook nie powie ani słowa. `POMIAR`: licznik czytany jest z
  `relay-state/<sid8>.gen` (`relay-lib.sh:112-114`), a pokolenie rodzące następcę pisze tam `<n+1>` (§5) —
  **nic go nigdzie nie zeruje, także przy nowej fali.** `RELAY_MAX_GEN` liczy więc pokolenia **narastająco
  przez wszystkie fale**, niezależnie od capu fal. **Nie „naprawiaj" tego rozjazdu zapisem
  `echo 1 > …/<sid>.gen`** — to trwale wyłącza ostatni licznik pokoleń;
- faza wymaga czegoś zabronionego: pusha na `origin`, deploya, `gh issue close`, wysyłki do KSeF, operacji na produkcji;
- pełna suita wymaga wyłącznego slotu, a inne sesje pracują w drzewie;
- recenzent zgłosił finding `PLAUSIBLE` — wraca jako **zlecenie dwustronne** („ustal, czy X czy nie-X, i podaj, co rozstrzyga"), nigdy jako gotowy fix.

## 6a. Dwie fale równolegle

Skill opisuje JEDEN łańcuch. Właściciel może chcieć drugiego obok — bo pierwszy idzie wolniej, niż
zakładał. Wolno, ale łańcuch jest sekwencyjny **wobec samego siebie**, nie wobec świata, i druga fala
podwaja liczbę pisarzy w jednym drzewie. Warunki, bez których nie startuj:

| co | wymóg | dlaczego |
|---|---|---|
| slug | **inny dla każdej fali** (`fala-wrzesniowa`, `fala-b`…) | roadmapa i ledger to osobne pliki; dwie fale dopisujące do JEDNEGO ledgera to gwarantowana utrata wierszy |
| nazwy sesji | `<slug-fali>-g<n>` — muszą się różnić między falami | dwie sesje o tej samej nazwie łamią adresowanie i `hold` (§2) |
| zbiór issues | **rozłączny**, i to na poziomie PLIKÓW, nie numerów | dwie fale w tym samym pliku = cudza niezastage'owana praca znika |
| worktree | każde issue we własnym `.claude/worktrees/issue-<nr>` | drzewo główne ma jeden indeks dla obu fal |
| commit | `git commit -m "…" -- <pathspec>` **bezwzględnie** | zmierzone przy jednej fali: commit potrafi porwać cudze pliki z wspólnego indeksu |
| pełna suita | **żadna fala jej nie uruchamia** | wyłącznego slotu nie będzie; zapisz to w wierszu ledgera zamiast udawać zieleń |

**Triage G1 drugiej fali musi objąć gałęzie pierwszej**, nie tylko `main`:
```bash
git log --oneline --all --grep "#<nr>"      # --all, bo praca fali 1 siedzi na agent/issue-*
git branch -a --contains <commit-naprawy>
```
Inaczej druga fala weźmie issue, które pierwsza właśnie zamyka na swojej gałęzi — a `main` o tym
jeszcze nie wie.

`relay-state/` kolizji nie ma: pliki są kluczowane pełnym `session_id`, więc fale się tam nie widzą.
Nie ma za to **żadnego wspólnego licznika pokoleń** — `RELAY_MAX_GEN` liczy każdą falę osobno.

> To jedyna sekcja tego skilla, która NIE wzięła się ze zdarzenia w przebiegu, tylko z decyzji
> właściciela o puszczeniu drugiej fali (2026-09-05). Warunki w tabeli są wyprowadzone ze szkód
> zmierzonych przy JEDNEJ fali — nie z obserwacji dwóch. Pierwsza fala, która pójdzie równolegle,
> jest pomiarem tej sekcji.

## 7. Dyscyplina pomiaru (obowiązuje każde pokolenie)

Przed nazwaniem pomiaru przyczyną wykonaj pomiar, który tezę **obaliłby**. Zdania nośne oznaczaj `POMIAR` (z komendą albo `plik:linia`) albo `WNIOSEK`; wiersz ledgera z werdyktem stojącym na `WNIOSEK` jest niedomknięty. Zapadka bez dowodu mutacyjnego (zielona na kodzie, czerwona pod mutacją, z diagnozą nazywającą TEN defekt) nie liczy się jako zrobiona. Dowód mutacyjny wykonuj na kopii ładowanej przez `--bootstrap`, nie mutując pliku w drzewie.
