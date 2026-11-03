# Plan: autonomiczny refaktor god files z dowodem równoważności 1:1 (KonkretnyTMS)

Spisany 2026-11-01. Właściciel chce rozbić największe pliki KonkretnyTMS tak, żeby system działał **dokładnie tak samo**, i żeby cała procedura (refaktor + testy) szła **bez jego udziału**. Dowodem jest porównanie 1:1: każde zachowanie wykonane na starym i na nowym kodzie, wyniki porównane.

## Decyzje już podjęte (nie wracać do nich)

- **Główna bramka = test różnicowy 1:1** (stary kod z zamrożonego hasha kontra nowy kod, te same dane wejściowe, ta sama baza startowa). Testy jednostkowe, PHPStan, e2e to warstwy wspierające, nie dowód.
- **Kompletność mierzona, nie deklarowana:** pokrycie refaktorowanego pliku zebrane *podczas przebiegu różnicowego na starym kodzie*. Niepokryta linia = zachowanie nieporównane.
- **Model / effort:** lider kolejki Opus 5.5 `high` (pomiar 2026-09-25: high najlepszy, xhigh 2× koszt bez zysku). Recenzja: świeży `code-reviewer` (Opus). Fable 5.1 nie — niezmierzony na tym repo.
- **Silnik:** istniejąca kolejka `/roadmapa` (jedna maszyna kolejki, decyzja z 2026-09-24), nie osobny runner.
- **Push i deploy zostają u właściciela** (CLAUDE.md §2, reguła bezwzględna). „Autonomicznie” = do lokalnego scalenia w `main` włącznie + raport.
- **Pliki KSeF** (`KSeFOfflineQueueService`, `KSeFXmlController`, `KSeFSendController`) poza trybem autonomicznym, dopóki karta zgody (niżej) ich jawnie nie wymieni — reguła z `refactoring-orchestrator.md` („anything already sent to an external authority needs the owner's explicit consent”).

## Stan obecny (zmierzone 2026-11-01)

- `tests/regression/compare-api.php` (472 linie): porównuje **tylko body JSON**, POST tylko form-encoded, **jeden użytkownik** na instancję, bez diffu bazy, bez maili, plików, cronów. Diff bazy (MD5) robił ręcznie agent `tester-optymalizacji`, który handlery z mailem i usługami zewnętrznymi **pomija (SKIP)**. Do 1:1 to za mało.
- Brak abstrakcji zegara: `time()/date()/NOW()` bezpośrednio (RepairOrderController 36 miejsc, PurchaseService 20, Gutschrift 18). Czas w SQL pochodzi z serwera MySQL.
- SMTP: host z tabeli `settings` (`smtp_host`) przez PHPMailer — da się przekierować na lokalny łapacz bez zmiany kodu.
- Trasy deklaratywne w `php/routes/*.php` (`'controller' => 'RepairOrderController'`) — inwentarz tras da się wygenerować skryptem.
- `vendor/nikic/php-parser` jest w repo — wystarczy do kontroli przeniesień (AST).
- Konta testowe `e2e_test`, `e2e_test_0..7` odtwarza `/wczytaj-baze-dev`.
- **Pokrycia PHP nie ma nigdzie** (CI `coverage: none` od #1592, lokalnie brak pcov/xdebug). Brak Mailpit i libfaketime.
- Wiele testów czyta tekst źródła (CorrectionController 20 plików, InvoiceService 15) — po przeniesieniu czerwienieją bez zmiany zachowania.
- Lekcje z poprzednich refaktorów (raport z historii repo):
  - #401: globalna funkcja JS w innym chunku, `Promise.all` w losowej kolejności, ~miesiąc na prod;
  - #1058: węższe typy w nowym repozytorium, 500 zamiast 404;
  - #1045: repozytorium odziedziczyło `save/delete` z `BaseRepository`;
  - #481: zapadka czytająca źródło przestała pilnować po przeniesieniu metody;
  - PurchaseService: `static::class` w logach zmienia tag modułu;
  - pliki odrastają po refaktorze (PurchaseService 2536 → 3046).
- Skill `safe-refactor` (juliusbrussee/caveman, sprawdzony 2026-11-01): 6 zasad bez procedury. Pokrywa się z `refactoring-orchestrator`. Wzięte z niego dwa punkty do granicy zachowania: **zachowanie przy błędach** i **kolejność** (efektów ubocznych) — patrz §2.4. Nie instalować.
- Skill `request-refactor-plan` (mattpocock, sprawdzony 2026-11-01): wywiad z użytkownikiem → zakres → plan małych commitów → issue. Wzięte: jawna lista „co się zmienia / co NIE” w porcji 0. Wywiad zastępuje jednorazowa karta zgody (§1), bo tryb ma być autonomiczny. Nie instalować.
- Skill `refactor` (github/awesome-copilot, sprawdzony 2026-11-01): katalog code smells i proces commit-per-green-step. Wzięte: krok VERIFY „Performance unchanged” → porównanie sekwencji SQL i czasu (§2.4 pkt 7–8). **Odrzucony katalog smelli:** guard clauses, Strategy, typy domenowe zmieniają kod poza przeniesieniem i łamią regułę verbatim. Nie instalować.

## 0. Wejście dla właściciela — skill `/refaktor`

Nowy skill toolkitu, wywoływany tylko ręcznie (`disable-model-invocation: true`):

```
/refaktor php/controllers/GutschriftDocumentController.php
```

Robi tylko przygotowanie formalne, sam nie refaktoruje:
1. sprawdza warunki: stanowisko `tests/rownowaznosc/` istnieje, pcov i Mailpit działają, plik jest śledzony i czysty w `main`;
2. sprawdza kartę (§1): plik KSeF bez wpisu w karcie → odmowa; pliku nie ma w karcie → dopisuje go z domyślnymi progami po potwierdzeniu właściciela (jedno pytanie);
3. zakłada parasol `typ:structural` + `refaktor:rownowaznosc` i porcję 0 „przygotowanie”;
4. wypisuje komendę `kolejka start --parasol <N>` (albo uruchamia ją od razu, jeśli dostał `--start`).

Kolejne pliki: to samo wywołanie z inną ścieżką. Kilka plików naraz: kilka parasoli, kolejka bierze je po kolei.

## 1. Karta zgody (jednorazowo, właściciel, przed pierwszym biegiem)

Plik `docs/plans/refaktor-god-files/KARTA.md` w KonkretnyTMS. Właściciel zatwierdza raz, potem kolejka działa sama:

- lista plików w zakresie i ich kolejność (propozycja: GutschriftDocumentController (pilot) → PurchaseService → InvoiceService → CorrectionController → drivers.js → invoices-editor.js; RepairOrderController dopiero, gdy moduł warsztatu będzie miał dane produkcyjne; KSeF poza);
- próg pokrycia z przebiegu różnicowego (propozycja: 95% linii pliku; reszta z uzasadnieniem w raporcie, np. martwy kod → issue);
- docelowy limit rozmiaru po refaktorze (propozycja: cel ≤ 500 linii na klasę, twardy limit 800 jako zapadka; metoda ≤ 60 linii) — staje się zapadką;
- co wolno: tylko przeniesienia + 4 dozwolone zmiany z planu 2026-07-10 (verbatim). Wszystko inne = osobne issue `typ:bug`;
- zgoda, że testy czytające źródło mogą mieć zmienioną **wyłącznie ścieżkę/nazwę symbolu**.

## 1a. Standard docelowy — kod „jak od profesjonalisty”, raz i na stałe

Wymóg właściciela (2026-11-01): po refaktorze moduł ma być w **formie docelowej**, a każda kolejna zmiana ma trzymać styl, który powstanie w trakcie refaktoru. Bez wracania do tematu.

**Definicje.** LOC (SLOC) = linie z kodem, bez komentarzy i pustych (definicja `cloc` i SonarQube). Linie fizyczne = wszystkie linie.

Stan wyjściowy (pomiar 2026-11-01): GutschriftDocumentController ma 3849 linii fizycznych, z czego 2245 to komentarze i puste linie (58%). Kod to ok. 1600 linii w 59 metodach, bez bezpośredniego SQL. Najdłuższe metody mają 151–261 linii (`performAccept`, `applyReread`, `rereadDocument`, `resolveCompareResponse`, `acceptDiscrepancy`).

**Cztery fazy na plik.** Rozszerzenie §4.1. Dowód 1:1 obowiązuje we wszystkich fazach, bo porównuje zachowanie, a nie tekst kodu.

1. **Projekt docelowy modułu.** Podział na role:
   - kontroler: wejście HTTP → walidacja → wywołanie przypadku użycia → odpowiedź;
   - serwisy per przypadek użycia;
   - repozytoria (tylko SQL);
   - obiekty wartości / DTO;
   - renderer PDF i mapper odpowiedzi osobno.

   Projekt zawiera tabelę „klasa → odpowiedzialność → metody ze starego pliku” oraz listę „co się NIE zmienia”. Przy pilocie zatwierdza go właściciel; dla kolejnych plików projekt musi być zgodny ze wzorcem z pilota, a sprawdza to recenzent.
2. **Podział strukturalny verbatim.** Ciała metod przenoszone bez zmian. Kontrola AST z §3 + porównanie 1:1.
3. **Doprowadzenie do standardu.** Wydzielanie metod, nazwy, typy, guard clauses, komentarze. Kontrola AST verbatim tu nie obowiązuje. Obowiązują porównanie 1:1, pokrycie i sondy mutacyjne oraz bramki jakości z listy niżej.
4. **Zapisanie stylu.** Moduł trafia na listę modułów ze standardem; reguły i zapadki działają od tej chwili przy każdej zmianie (kolejka, sesje, CI).

**Standard (wartości do potwierdzenia na pilocie), egzekwowany maszynowo w CI.** Czerwony test = brak deploya, więc tego nie da się obejść:

- klasa ≤ 300 LOC i ≤ 800 linii fizycznych; metoda ≤ 40 LOC; złożoność cyklomatyczna metody ≤ 10; ≤ 5 parametrów; zagnieżdżenie ≤ 3;
- warstwy: kontroler nie woła PDO ani repozytoriów zapisu bezpośrednio, repozytorium nie woła serwisów, serwis nie czyta `$_GET/$_POST` ani nie robi `echo`. Zapadka na `nikic/php-parser`, wzorzec: istniejące zapadki w `tests/Static/`;
- PHPStan na maksymalnym poziomie dla katalogów modułu ze standardem (osobna sekcja `paths` lub drugi config); reszta repo zostaje na level 5;
- `declare(strict_types=1)`, typy wszędzie, `final` domyślnie, zależności przez konstruktor, `readonly` tam, gdzie się da;
- komentarze: docblock mówi **dlaczego**, nie **co** i nie **historię**. Historia incydentów idzie do `docs/claude-reference/incydenty/` z jednolinijkowym odsyłaczem w kodzie (np. `// Dlaczego: incydenty/gutschrift.md#reread-podwojny`), a regresji pilnuje test, nie komentarz. **Zatwierdzone przez właściciela 2026-11-01.** Przed usunięciem komentarza trzeba sprawdzić zapadki czytające źródło: jeśli któraś szuka tekstu komentarza, zmienia się ją na sprawdzenie zachowania albo wskazuje nowe miejsce. Treść incydentu nie może zginąć — recenzent porównuje usunięte komentarze z dopisanym dokumentem;
- testy nowych klas sprawdzają zachowanie przez publiczne API, nie tekst źródła (słabość wskazana w przeglądzie jakości z 2026-11-01).

**Utrzymanie stylu po refaktorze:**
- `docs/architektura/modul-<nazwa>.md`: mapa klas modułu i odpowiedzialności, wzorzec dla nowych funkcji („nowy przypadek użycia = nowa klasa w `.../UseCase/`, nie metoda w kontrolerze”);
- sekcja „Moduły ze standardem” w `.claude/rules/php-rules.md` (reguła ścieżkowa, dociera do podagentów jako `nested_memory` — zmierzone 2026-10-26) z odsyłaczem do dokumentu modułu;
- `code-reviewer` sprawdza diff na tych modułach względem dokumentu modułu;
- zapadki z listy wyżej obejmują katalogi modułu na zawsze. Dodanie modułu do listy jest jednokierunkowe.

**Odbiór jakości.** Poza zapadkami: ślepa ocena przez 2 świeżych recenzentów według rubryki z przeglądu jakości z 2026-11-01 (6 wymiarów po 1–5). Próg: ≥ 4 w każdym wymiarze i ≥ 27/30. Poniżej progu wraca faza 3.

## 2. Stanowisko różnicowe (KonkretnyTMS, `tests/rownowaznosc/`)

Budowane raz, przez sesję interaktywną (nie autonomicznie), na bazie `compare-api.php` (przenieść `sendRequest`/`compareJson`, resztę napisać).

### 2.1 Inwentarz zachowań — `inwentarz.php <plik>`

Generuje `inwentarz/<Plik>.json`: każda publiczna metoda pliku i każde jej wejście:
- trasy z `php/routes/*.php` wskazujące klasę lub klasy, które ją wołają (graf wywołań przez php-parser + grep na wywołania dynamiczne);
- crony i skrypty (`cron/`, `scripts/`) wołające klasę;
- moduły JS: eksporty `window.*` i handlery zdarzeń (dla plików JS).

Każda pozycja inwentarza musi mieć ≥ 1 scenariusz, inaczej przygotowanie się nie kończy.

### 2.2 Scenariusze — `scenariusze/<Plik>.json`

Jeden scenariusz = aktor (konto `e2e_test_N` z rolą) + wejście (HTTP: metoda, akcja, parametry, JSON/form/multipart; albo komenda CLI) + opcjonalny SQL przygotowujący. Obowiązkowo dla każdej pozycji: ścieżka szczęśliwa, każdy kod błędu (400/403/404/409/422), wartości brzegowe (null, 0, ujemne, dziesiętne, puste), każda rola z inną decyzją uprawnień.

### 2.3 Przebieg — `stanowisko.sh <plik> <hash-stary> <gałąź-nowa>`

- dwa worktree (stary @ zamrożony hash, nowy @ gałąź), dwie bazy `_rown_stary` / `_rown_nowy` z **jednego** snapshotu, dwa porty (np. 8091/8092 — nie kolidować z 8080 devserver i 808N worktree kolejki);
- `smtp_host` w obu bazach → Mailpit (`brew install mailpit`, port 1025, API 8025), osobna skrzynka na stronę (dwie instancje Mailpit albo nagłówek rozróżniający);
- usługi zewnętrzne (GUS, NBP, SMSAPI, KSeF): stuby z nagranymi odpowiedziami; `KSEF_SENDING_DISABLED` zostaje. Plik, który woła usługę zewnętrzną bez stuba, nie przechodzi przygotowania;
- scenariusze w **tej samej kolejności** po obu stronach, naprzemiennie (stary, zaraz potem nowy), żeby czas był jak najbliższy;
- stary kod uruchomiony z pcov (`-d pcov.enabled=1` + `auto_prepend_file` zapisujący pokrycie per request) → pokrycie pliku z przebiegu.

### 2.4 Porównanie — `porownaj.php`

Dla każdego scenariusza porównuje:

1. **odpowiedź**: status, wybrane nagłówki (Content-Type, Content-Disposition, Location), body (JSON znormalizowany; HTML/CSV/PDF → tekst);
2. **delta bazy**: `CHECKSUM TABLE` przed/po, dla zmienionych tabel wiersze po kluczu głównym. ID z autoincrement **nie są maskowane** — przy tym samym snapshocie i tej samej kolejności muszą wyjść równe, a różnica ujawnia zmianę liczby lub kolejności zapisów;
3. **pliki**: hashe katalogów zapisu (`storage/`, eksporty), PDF → tekst;
4. **maile**: z API Mailpit — odbiorcy, temat, treść, załączniki, **kolejność**;
5. **wywołania zewnętrzne**: payloady zapisane przez stuby;
6. **zachowanie przy błędzie**: kod, komunikat, brak częściowego zapisu (delta bazy pusta, jeśli stary kod był atomowy);
7. **sekwencja zapytań SQL**: znormalizowana lista instrukcji (literały → `?`) z `performance_schema.events_statements_history_long` albo general logu, per scenariusz. Przeniesienie verbatim nie zmienia ani liczby, ani kolejności zapytań, więc różnica tu (np. leniwy getter dociągający dane drugi raz, N+1 w nowym kolaboratorze) jest **twardą** różnicą;
8. **czas odpowiedzi**: tylko ostrzeżenie, nie bramka (mediana z 3 powtórzeń, próg +20%) — szum na Macu jest za duży na twardą bramkę.

**Kalibracja szumu:** najpierw przebieg stary kontra stary. Pola, które różnią się już wtedy (znaczniki czasu, tokeny), trafiają do `maska/<Plik>.json`. Maska jest zamrażana razem z bazą odniesienia. Jeśli czas okaże się nie do opanowania maską, fallback to libfaketime dla obu procesów PHP oraz `SET timestamp` po stronie MySQL — sprawdzić na pilocie.

### 2.5 Raport — `raport/<Plik>-<etap>.json` + `.md`

Per scenariusz `IDENTYCZNY` / `RÓŻNICA` (z diffem), pokrycie pliku %, lista niepokrytych linii z uzasadnieniem, liczba scenariuszy, hash starego kodu, hash maski.

## 3. Kontrola przeniesień (AST) — `sprawdz-przeniesienia.php <hash-przed> <hash-po>`

Na `nikic/php-parser`:
- każda metoda ze starego pliku istnieje dokładnie raz w nowym układzie, a jej ciało jest identyczne w AST, z dozwolonym przepięciem `$this->x` na `$this->kolaborator->x` i `self::` na `Stara::`;
- publiczne sygnatury fasady oraz trasy mają zerowy diff;
- typy parametrów i zwracane nowych metod nie są węższe niż w oryginale (#1058);
- nowe klasy nie dziedziczą metod zapisu z `BaseRepository`, chyba że oryginał też miał do nich dostęp (#1045);
- `static::class` / `__CLASS__` w przeniesionym kodzie dają ten sam tekst co przedtem;
- dla JS: zbiór `window.*` przed/po identyczny, a istniejące zapadki globali między chunkami zielone (#401).

## 4. Cykl w kolejce (claude-config, `roadmapa`)

### 4.1 Struktura issue

- Jeden **parasol** per plik (`typ:structural`, nowa etykieta `refaktor:rownowaznosc`), porcje w ścisłej kolejności:
  - **porcja 0 „przygotowanie”**: sekcja planu „Zmienia się / NIE zmienia się” (jawna lista: jakie klasy powstają, co zostaje nietknięte — fasada, trasy, kontrakty JSON, nazwy w logach) → inwentarz → scenariusze → kalibracja → przebieg na starym kodzie aż do progu pokrycia → sondy mutacyjne (`scripts/mutation-probe.sh`) na starym kodzie dla kluczowych metod, gdzie scenariusz musi wykryć mutanta → **zamrożenie** (hash starego kodu, maska, lista scenariuszy) commitem na `main` → plan porcji 1..N w `docs/plans/` → utworzenie porcji 1..N jako sub-issue;
  - **porcje 1..N**: jedno wydzielenie (jeden kolaborator / jedna granica własności) na porcję;
  - **porcja końcowa „domknięcie”**: pełny przebieg różnicowy zamrożony hash kontra końcowy `main`, predeploy e2e b1–b13, zapadka rozmiaru pliku, raport w parasolu.
- **Do sprawdzenia w implementacji:** czy picker podejmuje porcje utworzone w trakcie biegu. Jeśli nie, potrzebne są dwa biegi: przygotowanie, potem realizacja.

### 4.2 Bramka (`bramka.sh`, rozszerzenie)

Dla issue z etykietą `refaktor:rownowaznosc` bramka **sama** uruchamia `stanowisko.sh` + `porownaj.php` + `sprawdz-przeniesienia.php`. Nie ufa plikowi raportu agenta. Scalenie tylko gdy:
- 0 różnic ponad maskę we wszystkich zamrożonych scenariuszach;
- zbiór scenariuszy ⊇ zamrożony (dodawać wolno, bo dodany scenariusz też biegnie po obu stronach; usuwać i zmieniać nie);
- pokrycie starego kodu ≥ próg z karty;
- zbiory nazw PASS/FAIL/SKIP PHPUnit identyczne z bazą odniesienia (`comm`), lista błędów PHPStan identyczna;
- kontrola AST zielona.

### 4.3 Ochrona przed „dopasowaniem testów do kodu”

- `hook-pre-tool.sh`: w porcjach 1..N blokuje edycję `maska/`, zamrożonych wpisów `scenariusze/`, `inwentarz/` i hasha odniesienia;
- zmiany w testach czytających źródło: `code-reviewer` z osobnym poleceniem „sprawdź, czy żadna asercja nie została osłabiona; dozwolona jest tylko zmiana ścieżki/symbolu”. Werdykt jest plikiem, który bramka wymaga;
- zakaz poprawek „przy okazji”: znaleziony błąd → `nowe-issue` (`typ:bug`, odwołanie do parasola), refaktor zachowuje stary błąd.

### 4.4 Warunki stopu (bez właściciela)

- różnica ponad maskę → cofnięcie do ostatniego zielonego commitu porcji, jedna próba ponowna z diffem w briefie, potem `status:odlozone` + komentarz z raportem. Parasol w ścisłej kolejności staje, kolejka idzie do innych issue;
- próg pokrycia nieosiągalny (np. kod martwy, usługa bez stuba) → `status:odlozone` z listą linii;
- plik KSeF bez zgody w karcie → odmowa przy starcie (`porcje-parasola.sh`).

### 4.5 Wynik dla właściciela

Raport domknięcia w parasolu i na dashboardzie kolejki. Właściciel podejmuje jedną decyzję: push/deploy. Deploy refaktoru idzie **sam**, bez innych zmian. Po deployu routine obserwuje log-report przez 3 dni i zgłasza nowe błędy z modułu jako `typ:bug`.

## 5. Kolejność budowy

1. **Setup (zgoda właściciela na brew):** pcov, Mailpit; libfaketime tylko jeśli pilot pokaże potrzebę.
2. **Stanowisko** `tests/rownowaznosc/` (§2) + testy samego stanowiska: mutant w kopii starego kodu musi dać `RÓŻNICA`; stary kontra stary musi dać 0 po masce.
3. **`sprawdz-przeniesienia.php`** (§3) + test na znanym przypadku #1058 (zawężony typ → czerwono).
4. **Pilot interaktywny na GutschriftDocumentController** (zmiana 2026-11-01: moduł warsztatu nie ma jeszcze danych produkcyjnych, a porównanie 1:1 potrzebuje realnych przypadków; Gutschrift: 134 dokumenty, 81 z ostatnich 60 dni, 0 odwołań do KSeF, 11 tras w `php/routes/orders.php`) — przygotowanie + jedna porcja w sesji z właścicielem (pierwszy bieg obserwowany). Kalibracja progów i maski.
5. **Toolkit v1.8.0** (claude-config): `roadmapa/references/cykl-refaktoru.md`, rozszerzenie bramki i hooka, etykieta, zapadki, sync do KonkretnyTMS. Push i PR tylko na polecenie właściciela.
6. **Bieg autonomiczny** na kolejnych plikach z karty.

## Wynik pilota (2026-11-03, issue #20)

Gałąź `refaktor/gutschrift-pilot` w KonkretnyTMS (worktree `.claude/worktrees/refaktor-gutschrift`, bez pusha), stary kod `28e909055`. Ledger: `docs/plans/2026-11-03-pilot-rownowaznosc-gutschrift.md` (fazy A–C).

**Pomiary:**
- 167 scenariuszy w 8 trasach, 7 aktorów; przebieg 142–144 s, całość ~166 s (odtworzenie dwóch baz z wzorca 370 MB ~16 s); stary↔stary 167/167 IDENTYCZNY.
- maska: 7 wpisów; cały szum pochodzi spoza kontrolera (request_id, rate_limits, SchemaGuardCache, sekundy cooldownu);
- pokrycie: 86,68% surowo, 92,86% efektywnie (69 linii martwych po `exit` wykrywa AST), 0 niepokrytych zakresów bez kategorii;
- samotest: 4/4 mutanty RÓŻNICA, każdy we własnym kanale (odpowiedź, sam SQL, sam log, cooldown pod maską);
- kontrola AST: `tests/rownowaznosc/sprawdz-przeniesienia.php`, test 14 przypadków (#1058, #1045, `self::class`, ciało, duplikat, brak, sygnatura fasady, `get_called_class`, nowa metoda, stała, kolaborator, widoczność);
- wydzielenie 1: `RereadRules` (6 metod statycznych, 89 SLOC); AST ZIELONO, stary↔nowy 167/167 IDENTYCZNY.

**Decyzje (odpowiedzi na pytania pilota):**
- próg pokrycia = **efektywne ≥ 90% + 100% niepokrytych zakresów z kategorią** (surowe bez progu, bo martwe po `exit` zaniżają je o ~6 pp). Kategorie: obrona-trasy-405, wyjatek-infrastruktury, niezmiennik-bazy, wyscig, niezmiennik-kodu, json-niemozliwy, tylko-phpunit, odlozone, martwy-kod;
- limit pliku 300 SLOC / 800 fiz. **bez zmian**: pilot go nie podważył;
- `NOW()` / libfaketime: **niepotrzebne**. Wystarczy normalizacja `@TERAZ`/`@PRZEBIEG`, jedna podmiana regexem i bramka sekundy po zapisach;
- `auto_prepend_file` + pcov: działa dla wszystkich wejść HTTP przez `php -S` (jeden router). CLI do sprawdzenia na pierwszym pliku z wejściem cron/CLI (`php -d auto_prepend_file=`);
- reset bazy per bieg (nie per scenariusz) wystarcza. Scenariusze są uporządkowane, a stan przechodzi między nimi celowo (serie zbioru, cooldown).

**Projekt docelowy zatwierdzony przez właściciela (2026-11-03):** faza 2 verbatim przenosi tylko metody zamknięte na wywołania i bez `$this->error()`/metod BaseController (RereadRules, AcceptancePolicy, AcceptanceSnapshot, DocumentPresenter). `perform*`/`resolve*` przechodzą do UseCase/Query dopiero w fazie 3, z wyjątkiem `GutschriftActionRejected` zamiast `exit`. Wniosek dla kolejnych plików: projekt fazy 1 zaczyna się od **grafu wywołań** (kto woła `error()`/BaseController = faza 3).

**Do toolkitu v1.8.0 (`cykl-refaktoru.md`) — miny pilota:**
1. Porcja przepina testy spoza stanowiska: `ReflectionMethod` na starej klasie, zapadki z markerem sygnatury w tekście źródła, allowlisty `plik::metoda`. Krok porcji: grep nazw przenoszonych metod w `tests/`.
2. Nowa klasa w `php/services/` wpada pod zapadki usług (bezpośredni czas, pisarz znacznika, inwentarze 09a/09b), którymi kontroler nie był objęty. To przewidywalne, nie regresja.
3. Zapadki skanują `git ls-files`, więc nowy plik trzeba dodać do indeksu przed testami.
4. `--przed` kontroli AST = commit tuż przed wydzieleniem (gałąź pilota zmienia też `scripts/`).
5. Stany testowe muszą przejść CHECK-i bazy (`chk_*_type`, `json_valid`). Gałąź za CHECK-iem = niezmiennik-bazy.
6. Przebieg ujawnia utajone błędy (tu: `UserRepository::findById()` bez `full_name`, przez co nazwisko akceptującego nigdy się nie pokazuje). Refaktor zachowuje je 1:1, a poprawka idzie osobnym issue.

**Zostało:** toolkit v1.8.0 (§5 pkt 5), fazy 2–4 dla reszty Gutschrift (następne sesje), push/deploy gałęzi pilota — decyzja właściciela.
