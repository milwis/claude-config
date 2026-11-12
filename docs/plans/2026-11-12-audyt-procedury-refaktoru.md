# Audyt procedury refaktoru god-files (issue #46)

Data: 2026-11-12. Audytor: Fable 5.2, tylko odczyt. Przedmiot: procedura z `PLAN-refaktor-god-files.md` w wykonaniu pilota Gutschrift (#20–#33), przed plikami PurchaseService → InvoiceService → CorrectionController → drivers.js → invoices-editor.js.

Oznaczenia:
- `K` = `~/Programowanie/KonkretnyTMS`, `W` = `K/.claude/worktrees/integracja-gutschrift`, `R` = `W/tests/rownowaznosc`, `TK` = `plugins/milwis-coding-toolkit`.
- „ledger L<n>” = `W/docs/plans/2026-11-03-pilot-rownowaznosc-gutschrift.md`, linia n. Ledger i plan to deklaracje wykonawcy; cytuję je jako deklaracje, nie jako dowód działania narzędzia.
- `POMIAR` = odczytałem sam z kodu narzędzia lub wykonałem polecenie git tylko do odczytu. `POMIAR (podagent)` = odczyt podagenta Sonnet/Explore, którego nie powtórzyłem linia po linii. `NIEZMIERZONE` = teza bez pomiaru, do sprawdzenia przed użyciem.
- Niczego nie uruchamiałem (stanowisko, PHPUnit, bazy). Zieleń testów i stanowiska na `b8623fafd` znam wyłącznie z ledgera.

## 1. Werdykt

1. Stanowisko równoważności jest mocnym dowodem dla fazy 2a (przeniesienie bez zmiany treści) na pliku, który jest kontrolerem HTTP bez usług zewnętrznych: delta bazy z binlogu, sekwencja SQL, fail-closed przy uciętym kanale i osobna instancja MySQL działają tak, jak opisuje plan.
2. Procedura nie jest gotowa do biegu bez nadzoru na PurchaseService, bo żadna bramka toolkitu nie uruchamia stanowiska ani nie sprawdza jego wyniku, a wykonawca może zmienić maskę, scenariusze i sam komparator w tej samej gałęzi, w której pracuje.
3. Fazy 2b–4 (wyjątki zamiast `exit`, deduplikacja, standard) nie mają dowodu strukturalnego, a pokrycie mierzy wyłącznie stary plik po stronie A i niczego nie blokuje, więc zmiana w gałęzi błędu, której nie wykonuje żaden scenariusz, przechodzi jako IDENTYCZNY.
4. Dla kolejnych plików brakuje trzech rzeczy, których pilot nie potrzebował: stubów i blokady sieci (KSeF, NBP, GUS, poczta), działającego scenariusza CLI oraz jakiegokolwiek stanowiska dla JavaScriptu.
5. Ślepa ocena jest jedyną warstwą, która znalazła wady R1–R11, ale próg 27/30 jest przy tej rubryce strukturalnie nieosiągalny (0 piątek na 30 ocen w Poprawności, Designie i Czytelności), więc trzeba zmienić rubrykę i regułę stopu, a nie dokładać rund.

Kolejny plik PHP można zacząć po zamknięciu luk CRITICAL L1–L6 (sekcja 7, kroki 1–4). Plików JS nie zaczynać bez osobnego projektu (L7).

## 2. Luki

Liczba: 26, w tym CRITICAL 7, REQUIRED 12, MEDIUM 7. Koszt: S = do 2 h sesji wykonawcy, M = jedna sesja, L = 2–3 sesje.

### CRITICAL

**L1. Dowód równoważności nie jest bramką — cała procedura jest deklaratywna.**
- POMIAR: `TK/skills/roadmapa/scripts/bramka.sh` nie ma trybu refaktoru i nie czyta etykiet; 0 trafień `stanowisko|porownaj|sprawdz-przeniesienia` w `plugins/`; jedyny zaczep to linia `testy:` z `docs/VERIFICATION_ENV.md` (`bramka.sh:286-291`); treść `raport-N.md` jest przyjmowana na wiarę (`bramka.sh:183`). `cykl-refaktoru.md`, skill `/refaktor`, `KARTA.md` i etykieta `refaktor:rownowaznosc` nie istnieją (POMIAR (podagent), grep po `TK`). `R/` nie istnieje na `main` ani `main_dev` w K.
- Przeciek: wykonawca po kompakcji pisze w raporcie „IDENTYCZNY 168/168” z przebiegu sprzed ostatniego commita albo z `--tylko=<regex>`; bramka domyka porcję, bo sprawdza format raportu.
- Warstwa: bramka kolejki.
- Poprawka: tryb refaktoru w `bramka.sh` — bramka sama uruchamia `stanowisko.sh` na SHA porcji i czyta `raport.json` (`werdykt`, `scenariuszy`, `maska_sha256`) oraz `meta.json`; raport wykonawcy przestaje być źródłem werdyktu. Koszt: L (to jest rdzeń #27).

**L2. Maska, scenariusze i narzędzia nie są zamrożone.**
- POMIAR: `R/stanowisko.sh:66-67` bierze scenariusze i maskę z drzewa wywołującego; hashe są tylko zapisywane (`stanowisko.sh:309` `scenariusze_sha256`, `R/porownaj.php:294` `maska_sha256`) i nikt ich nie porównuje. `TK/hooks/hook-pre-tool.sh:12-58` chroni merge/pull/push i pliki recenzji, nie chroni `maska/`, `scenariusze/`, `uzasadnienia/`, `inwentarz/`. Narzędzia stanowiska zmieniano w trakcie refaktoru (8 commitów 11-08…11-12 na `stanowisko.sh`, `porownaj.php`, `lib/`). Werdykt K2 w #33 (168/168) policzono z maską spoza repo `K/.claude/tmp/i33/maska-i33.json` z dodatkowym globalnym `sql_pomijaj`; z maską z repo wynik był 166/168 (ledger L835).
- Przeciek: scenariusz daje RÓŻNICA, wykonawca uznaje ją za szum i dopisuje wzorzec do maski albo poprawia normalizację w `lib/`; kolejny przebieg jest zielony, recenzent porcji widzi zmianę maski jako jedną linię JSON wśród setek linii przeniesień.
- Warstwa: stanowisko + hook + bramka.
- Poprawka: `KARTA.md` pliku z `sha256` maski, scenariuszy, uzasadnień i katalogu narzędzi; `stanowisko.sh` odmawia przebiegu przy niezgodności; hook blokuje zapis tych ścieżek poza porcją oznaczoną „zmiana stanowiska”, którą zatwierdza nadzorca; narzędzia wchodzą na `main_dev` osobnym PR przed startem pliku i są uruchamiane z `main_dev`, nie z gałęzi refaktoru. Koszt: M.

**L3. Brak blokady sieci i stubów usług zewnętrznych.**
- POMIAR: `R/runtime/prepend.php:32-37` ładuje jeden stub (`CurlOpenAiTransport.inc`); w `R/runtime/stuby/` jest jeden plik; nic nie blokuje wyjścia do sieci. `stanowisko.sh:133-136` usuwa z `.env` tylko `PROD_*`, `IMAP_*` i wyłącza `KSEF_SENDING_ENABLE_ON_DEV`. Wymóg planu „plik bez stuba nie przechodzi przygotowania” nie ma odpowiednika w kodzie. Trafienia `ksef|nbp|gus|mailer|curl_|smsapi|openai` na `main_dev`: PurchaseService 132, InvoiceService 219, CorrectionController 243; `curl_init|curl_exec` w 20 plikach `php/` (m.in. `KSeFHttpClient`, `ResilientHttpClient`, `NotificationQueueService`).
- Przeciek: refaktor zmienia kolejność albo treść wywołania NBP/KSeF; wywołanie idzie na żywo po obu stronach, nie jest obserwowane (kanał `zewnetrzne` widzi tylko stuby), odpowiedzi są te same, werdykt IDENTYCZNY. Drugi wariant: usługa zewnętrzna odpowiada inaczej między stroną A i B i daje fałszywą RÓŻNICĘ, którą wykonawca zamaskuje (L2).
- Warstwa: stanowisko (przygotowanie).
- Poprawka: stuby na szwach transportu używanych przez plik + pułapka fail-closed: `HTTP(S)_PROXY` serwera `php -S` wskazuje lokalny port stanowiska, który zapisuje każde połączenie do kanału `zewnetrzne` i odmawia; zarejestrowane połączenie niestubowane = werdykt NIEWAŻNY. Skuteczność pułapki dla `file_get_contents`/`SoapClient` i kodu ustawiającego `CURLOPT_PROXY`: NIEZMIERZONE — zmierzyć jednym mutantem „wywołanie bez stuba”. Koszt: L na rodzinę usług, potem S na plik.

**L4. Pokrycie nie blokuje i nie mierzy nowego kodu.**
- POMIAR: `stanowisko.sh:302` wywołuje `pokrycie.php … || true`; `R/pokrycie.php:243-275` zapisuje JSON i nie ma progu ani kodu wyjścia; kategorie uzasadnień to dowolny napis (`pokrycie.php:203-221`). pcov działa tylko po stronie A i tylko dla `--plik` (`stanowisko.sh:205`), więc wynik jest stałą 86,87%/93,07% niezależnie od tego, co zrobiono po stronie B (ledger L96 potwierdza: kod przeniesiony do nowych klas nie wchodzi do procentu). Niepokryte zakresy pilota: `niezmiennik-bazy` 21 linii, `wyscig` 17, `wyjatek-infrastruktury` 10 — czyli ścieżki `catch`/rollback.
- Przeciek: porcja 2b zamienia `exit` na wyjątek i rollback na callable (ledger L130-134); gałąź `catch` nie jest wykonywana przez żaden scenariusz; rollback znika albo zmienia kolejność; 168/168.
- Warstwa: stanowisko + bramka.
- Poprawka: (a) `pokrycie.php` kończy się kodem ≠0 poniżej progu i przy zakresie bez kategorii z białej listy; (b) pcov po stronie B dla plików modułu i warunek „każda linia zmieniona w porcji 2b–4 jest wykonana po stronie B przez co najmniej jeden scenariusz albo ma test charakteryzujący napisany i zielony na starym kodzie przed zmianą”; (c) kategoria `tylko-phpunit` wymaga nazwy testu. Koszt: M.

**L5. Fazy 2b–4 nie mają dowodu strukturalnego; dowodem jest osąd recenzenta i ręczne mutanty wykonawcy.**
- POMIAR: `sprawdz-przeniesienia.php` jest zielone tylko w 2a; w 2b czerwone z konstrukcji (ledger L136: 5–15 różnic na porcję), decyzja z ledgera L33: 2b dowodzi stanowisko plus porównanie tokenów w recenzji; tryb z mapą podstawień odłożony do #27. Mutanty: 16 ręcznych łatek w `R/mutanty/`, wybieranych przez wykonawcę, około jednej na porcję.
- Przeciek: deduplikacja w fazie 3 scala dwie prawie identyczne gałęzie różniące się warunkiem brzegowym (`<` i `<=`), scenariusze wykonują tylko jedną; recenzent ocenia 400 linii przeniesień wzrokowo.
- Warstwa: narzędzie AST + stanowisko.
- Poprawka: tryb `--podstawienia=<mapa>` w `sprawdz-przeniesienia.php` (dozwolone przekształcenia 2b zapisane jawnie, reszta ma być identyczna) oraz warunek pokrycia zmienionych linii z L4(b); bez obu porcja 2b–4 nie przechodzi bramki. Koszt: L.

**L6. Awaria symetryczna i brak kontroli dodatniej dają IDENTYCZNY.**
- POMIAR: `porownaj.php:208-209` (`$a[$kat] ?? null`) — kanał pusty po obu stronach jest równy; fail-closed istnieje tylko dla `sql` (`sql_kompletne`, `porownaj.php:273`). Scenariusz nie deklaruje oczekiwanego statusu ani skutku. W pilocie narzędzie było fałszywie zielone trzy razy: `--nowy=HEAD` porównał stary ze starym (ledger L44), ucięty kanał `sql` (L45, #32), `getTmsConnection()` fail-open (L116); strażnik `stanowisko.sh:245-256` łapie tylko nieudane połączenia. Łatki mutantów gniją: ledger L263 („IDENTYCZNY porcji 2 i 3a nie miał kontroli dodatniej”), L752/L810 i L836 (aplikuje się 10/16).
- Przeciek: po zmianie w gałęzi obie strony zwracają 500 albo 401 (wygasła sesja aktora, brak tabeli w bazie stanowiska); odpowiedzi równe, delta pusta, werdykt IDENTYCZNY. W biegu autonomicznym nikt nie czyta logu.
- Warstwa: stanowisko.
- Poprawka: (a) każdy scenariusz deklaruje `oczekuj` (status i minimum skutków, np. „delta bazy niepusta”), niespełnienie po stronie A = NIEWAŻNY; (b) kontrola dodatnia jest częścią przebiegu: komplet mutantów musi się nałożyć i dać RÓŻNICA, inaczej NIEWAŻNY; (c) `stanowisko.sh` odmawia, gdy SHA obu stron wskazują to samo drzewo pliku. Koszt: M.

**L7. Pliki JavaScript nie mają żadnego stanowiska (dotyczy drivers.js i invoices-editor.js; nie blokuje plików PHP).**
- POMIAR: `sprawdz-przeniesienia.php:109` obejmuje `php cron scripts api.php index.php apps`; narzędzie parsuje wyłącznie PHP, choć plan obiecuje obsługę `window.*`; stanowisko mierzy odpowiedzi HTTP, nie zachowanie w przeglądarce. `js/modules/drivers.js` 2422 linie, `js/modules/invoices/invoices-editor.js` 2382 linie (`git show main_dev:`). Refaktor pilota zmienił w `js/` wyłącznie komentarze i tych zmian nie zbudowano do `dist/` (ledger L718, L811).
- Przeciek: cała procedura nie ma zastosowania; „IDENTYCZNY” ze stanowiska HTTP nic nie mówi o pliku JS.
- Warstwa: brak.
- Poprawka: osobny projekt przed czwartym plikiem (testy charakteryzujące w przeglądarce: zrzut DOM, żądania sieciowe i `localStorage` na scenariusz, porównanie stary/nowy build). Koszt: L+, wymaga osobnego audytu projektu.

### REQUIRED

**L8. Scenariusz `cli` jest zepsuty z konstrukcji, a kolejne pliki mają wejścia CLI.**
- POMIAR: `R/przebieg.php:145-151` uruchamia `php <komenda>` bez `auto_prepend_file` (brak stubów i pcov) i bez gniazda instancji stanowiska; w pilocie 0 scenariuszy `cli`. `scripts/backfill_purchase_vat_summary.php` i `scripts/backfill_purchase_vat_flags.php` wołają PurchaseService (grep na K).
- Przeciek: scenariusz CLI łączy się z domyślnym serwerem, dostaje odmowę po obu stronach, wynik równy (patrz L6).
- Warstwa: stanowisko. Poprawka: `-d auto_prepend_file`, `-d pdo_mysql.default_socket` i zmienne strony w komendzie; inwentarz wymaga scenariusza dla każdego skryptu i crona, który woła plik. Koszt: S.

**L9. Macierz scenariuszy nie jest wymuszana.**
- POMIAR: `R/inwentarz.php:126-140` wymaga co najmniej jednego scenariusza na akcję; wymóg planu (każdy kod błędu, brzegi, każda rola) nie ma kodu. Rozkład pilota: administrator 114 ze 168 scenariuszy, księgowość 4, grant 4, testerzy 2; `SuggestOrders`: administrator 7, dyspozytor zachód 2. K3 w #33 biegł tylko jako administrator i tylko GET (`K/.claude/tmp/i33/k3-odczyty.php:36-37`).
- Przeciek: bramka uprawnień przeniesiona do nowej klasy z błędem w gałęzi roli ograniczonej; wszystkie scenariusze tej akcji idą jako administrator. Wady tej klasy (R4, R10: macierz aktor × stan) znalazła dopiero ślepa ocena.
- Warstwa: inwentarz. Poprawka: inwentarz liczy z kodu pliku role z mapy uprawnień i literały kodów błędów; brak scenariusza na parę (akcja, rola: dozwolona/odmowa) i na kod błędu = czerwono; K3 obowiązkowo także dla jednej roli z widocznością ograniczoną. Koszt: M na plik.

**L10. Komparator nie rozróżnia `{}` od `[]` i widzi cztery nagłówki.**
- POMIAR: `przebieg.php:179-180` dekoduje `json_decode($body, true)`, `porownaj.php:113-128` spłaszcza; pusta mapa i pusta lista są równe, kolejność kluczy nie jest porównywana. `przebieg.php:193` zapisuje tylko `content-type`, `content-disposition`, `location`, `cache-control`.
- Przeciek: nowa klasa DTO zwraca `new stdClass` albo `(object) []` tam, gdzie było `[]`; frontend robi `.length` lub `.map` i lista znika. `Set-Cookie` zmienione przy przeniesieniu obsługi sesji — niewidoczne.
- Warstwa: stanowisko. Poprawka: dodatkowo porównywać surowe body po normalizacji (albo dekodować bez `assoc`), nagłówki porównywać wszystkie poza jawną listą pomijanych w masce. Koszt: S.

**L11. Normalizacja czasu maskuje zmianę terminów i TTL.**
- POMIAR: `R/lib/normalizacja.php:101-113` zastępuje znacznikiem `@PRZEBIEG` każdy czas z przedziału [start przebiegu − 2 s, koniec żądania + 7200 s].
- Przeciek: wygaśnięcie blokady lub termin zmienione z +10 min na +30 min w zapisie do bazy dają ten sam znacznik. Mutant 4 (cooldown 60→30) wykryto tylko dlatego, że wartość trafia do komunikatu odpowiedzi.
- Warstwa: stanowisko. Poprawka: czas przyszły normalizować do przesunięcia względem początku żądania z rozdzielczością 1 s (`@TERAZ+600`). Koszt: S.

**L12. Katalogi zapisu, sesja i cache są zaszyte pod Gutschrift albo nieobserwowane.**
- POMIAR: `stanowisko.sh:228` — `pliki_zapisu` to `storage/gutschrift_docs`, `storage/reports`, `uploads` (także `:137-138`); sesja PHP i cache nie są kanałem. Załączniki maili: nazwa, typ i rozmiar bez skrótu treści, HTML tylko jako sha, bez nagłówków (`R/lib/obserwator.php:353-381`).
- Przeciek: PDF faktury albo eksport zapisany do innego katalogu ze zmienioną treścią; załącznik o tym samym rozmiarze i innej treści (PDF z inną kwotą ma często ten sam rozmiar po kompresji — NIEZMIERZONE).
- Warstwa: stanowisko. Poprawka: `pliki_zapisu` w KARCIE pliku, domyślnie całe `storage/` i `uploads/`; skrót treści załącznika (dla PDF tekst z `pdftotext`, jak dla odpowiedzi); stan sesji jako kanał. Koszt: S–M.

**L13. Mutanty: wybiera je wykonawca, gniją, a mutanty recenzentów idą na PHPUnit.**
- POMIAR: 16 łatek w `R/mutanty/`, pisanych przez wykonawcę; brak reguły „mutant na zmienioną gałąź” i brak budżetu przeżywalności; ledger L836: K2 uruchomił mutanty 1–9. Mutanty recenzentów (m.in. rollback w `catch`, `lockForUpdate`) uruchamiano na PHPUnit; część GREEN „pilnuje tylko stanowisko” (ledger L339, L523).
- Przeciek: wykonawca pisze mutanta tam, gdzie wie, że stanowisko patrzy; ślepe pola komparatora (L10–L12) nigdy nie dostają mutanta.
- Warstwa: recenzent + stanowisko. Poprawka: mutanty porcji wybiera recenzent (albo generator z #2055 na liniach zmienionych w porcji), wykonuje je stanowisko; łatka, która się nie nakłada, to czerwień, nie pominięcie. Koszt: M.

**L14. Narzędzie AST nie rozwiązuje części nazw klas i spłaszcza wywołania przez kolaboratora.**
- POMIAR: `sprawdz-przeniesienia.php:233-244` rozwiązuje do pełnej nazwy tylko `new` i `instanceof`; wywołania statyczne, stałe klas i `catch (X $e)` porównuje tekstowo. `:263-268` traktuje `$this->kolab->x()` jak `$this->x()` dla każdej nowej właściwości. `:466` pomija konstruktor nowej klasy. Poziom pliku (`declare`, kod poza klasą) nie jest porównywany; dziś nieszkodliwe, bo PurchaseService, InvoiceService i CorrectionController mają już `declare(strict_types=1)`.
- Przeciek: po zmianie przestrzeni nazw `catch (ValidationException $e)` wskazuje inną klasę o tej samej krótkiej nazwie i nigdy nie łapie; ścieżka błędu nie jest pokryta scenariuszem (L4). PHPStan zgłosi brak klasy, ale nie kolizję nazw.
- Warstwa: narzędzie AST. Poprawka: `NameResolver` dla wszystkich węzłów nazw; mapowanie kolaboratora tylko dla metod, które rzeczywiście przeniesiono z tego pliku; porównanie `declare`. Koszt: S.

**L15. Samotesty narzędzi nie są uruchamiane automatycznie.**
- POMIAR: `R/test-przeniesien.php` i `R/test-ucietej-sekwencji.php` istnieją; 0 trafień ich nazw w `tests/Static`, `.github`, `scripts`, `docs/VERIFICATION_ENV.md` (grep na W).
- Przeciek: poprawka w `lib/obserwator.php` psuje wykrywanie uciętej sekwencji; nikt nie uruchamia samotestu; kanał `sql` wraca do stanu sprzed #32.
- Warstwa: stanowisko. Poprawka: `stanowisko.sh` uruchamia samotesty przed każdym przebiegiem i odmawia przy czerwieni. Koszt: S.

**L16. Istniejące testy i zapadki zmienia się razem z kodem, bez rozróżnienia przepięcia od osłabienia.**
- POMIAR (podagent, `git diff 5efe6e22f b8623fafd -- tests`): 40 zmodyfikowanych plików testów, 0 usuniętych. Zmiany asercji: typ wyjątku `ApiErrorException` → `GutschriftActionRejected` w czterech plikach, usunięty `testDetektorWykrywaBramkePoOdczycie` i zastąpiony dwoma innymi, testy `ReflectionMethod` prywatnych metod kontrolera zastąpione wywołaniami klas modułu. Zapadki: `SOURCE_AS_TEXT_TESTS` 553→555 (decyzja właściciela), `ServicesDirectTimeRead` + `RereadRules.php => 1`, `scripts/measure-untested-classes.php:36` wyłącza `tests/rownowaznosc` z miary. Ledger L743, L750–751: test przypinający zmieniony, 7 testów zastąpionych jednym.
- Przeciek: asercja, która pilnowała zachowania, zostaje „dostosowana do nowej struktury” i przestaje je pilnować; stanowisko tego nie widzi, bo nie mierzy testów.
- Warstwa: bramka + recenzent. Poprawka: bramka wypisuje usunięte i zmienione asercje oraz zmienione stałe zapadek w istniejących testach; każda pozycja musi mieć wiersz w raporcie porcji (przepięcie / zaostrzenie / osłabienie + powód); osłabienie i podniesienie stałej tylko decyzją właściciela. Testy czytające źródło starego pliku przepisać na testy zachowania przed rozbiciem (faza 0). Koszt: M.

**L17. Świadome odstępstwa od 1:1 przyjmuje sam wykonawca.**
- POMIAR: ledger L83 (pod SAPI `cli` odmowy dają 4xx zamiast `INTERNAL_ERROR`), L86 (tekst `LogicException`), L353 (`RowValue`: inne wejścia rzucają inny wyjątek; `DocumentIdInput::cast`), L750 (odmowa spod blokady akceptacji ujednolicona, rejestr `ACCEPT_REJECTIONS_RESTORED_TO_409` usunięty; commit `f92c0a930`). Uzasadnienia typu „przez HTTP nieosiągalne” (L708, L774).
- Przeciek: „nieosiągalne przez HTTP” jest osiągalne z crona, skryptu albo przyszłego wywołującego; odstępstwo nie trafia do żadnej listy, którą widzi właściciel przy odbiorze.
- Warstwa: bramka + nadzorca. Poprawka: tabela „Odstępstwa od 1:1” w ledgerze; każde odstępstwo = stop porcji i zgoda nadzorcy przed scaleniem; recenzent potwierdza każde wykonaniem starego i nowego kodu; argument „nieosiągalne” wymaga listy wywołujących z grep. Koszt: S.

**L18. Brak zamrożenia pliku w kolejce na czas refaktoru.**
- POMIAR: `git log 28e909055..5efe6e22f` — 1012 commitów na `main_dev` w czasie pilota, 0 dotknęło starego kontrolera (szczęśliwy przypadek), jeden dotknął kodu Gutschrift obok (`695db55de`), co wymagało nowego scenariusza `w34` i zmiany wzorca oraz stubu w trakcie (`556e812d6`). Zmienność kolejnych plików na `main_dev`: PurchaseService 6 commitów w 30 dni, InvoiceService 7, CorrectionController 3.
- Przeciek: poprawka błędu wchodzi na `main_dev` do starego pliku; przy integracji trzeba ją ręcznie przenieść do rozbitych klas; porównanie porcji ze starym SHA jej nie zna; chroni tylko końcowe porównanie `main_dev` ↔ integracja, o ile istnieje scenariusz dla poprawki.
- Warstwa: kolejka. Poprawka: kolejka nie bierze issues dotykających pliku w refaktorze (lista w KARCIE); wyjątek P0: nadzorca przenosi poprawkę i dopisuje scenariusz przed integracją; reguła „nigdy nie scalać `main_dev` do gałęzi refaktoru” zostaje. Koszt: S.

**L19. Brak inwentarza wad starego pliku przed rozbiciem.**
- POMIAR: R1–R11 (#34–#44) i #45: 0 regresji refaktoru, 16 razy wada sprzed refaktoru przeniesiona wiernie; wszystkie znalazła ślepa ocena w rundach 1–5, czyli po rozbiciu. W kodzie modułu nie ma komentarza o żadnej z R1–R11 (POMIAR (podagent)); `AcceptDiscrepancy.php:118` opisuje TOCTOU jako domknięte, a R3 jest wadą akceptacji.
- Przeciek: nie zachowania, lecz procesu — wady odkrywane po fakcie obniżają ocenę formy, wywołują kolejne rundy i nie mają kotwicy (patrz sekcja 6).
- Warstwa: faza 0. Poprawka: przed rozbiciem dwóch recenzentów ocenia stary plik pod kątem wad zachowania; wynik to issues i tabela „Znane wady” w KARCIE. Koszt: M (dwie oceny).

### MEDIUM

**L20. Sekwencja SQL to digest.** POMIAR: `obserwator.php:90-107` porównuje `DIGEST_TEXT` (literały jako `?`; `LIMIT`, listy `IN` i wartości niewidoczne); `stanowisko.cnf` nie ustawia `max_digest_length`. Przeciek: odczyt z innym `LIMIT` lub filtrem, którego skutek nie trafia do odpowiedzi scenariusza. Zapisy chroni delta binlogu. Poprawka: `SQL_TEXT` z normalizacją tylko znaczników czasu albo podniesienie `max_digest_length` i porównanie liczby wierszy. Koszt: S.

**L21. Brak współbieżności.** POMIAR: `php -S` jednowątkowy, `przebieg.php:165` czeka 150 ms na zapisy po odpowiedzi. Kolejność `BEGIN`/`FOR UPDATE`/`COMMIT` jest widoczna w kanale `sql` dla pokrytych scenariuszy. Przeciek: zmiana okna wyścigu przy nadawaniu numerów dokumentów (PurchaseService, InvoiceService). Poprawka: jeden scenariusz równoległy na numerację; wykonalność z `PHP_CLI_SERVER_WORKERS`: NIEZMIERZONE. Koszt: M.

**L22. Logi tylko z `logs/*.log`.** POMIAR: `obserwator.php:295-304`; stderr serwera nie jest porównywany. Ostrzeżenia PHP są widoczne, bo `api.php:556-581` kieruje je do loggera. Przeciek: błąd krytyczny przed rejestracją handlera. Poprawka: `serwer.log` jako kanał. Koszt: S.

**L23. Utrata wiedzy z usuwanych komentarzy wykrywana ręcznie i po fakcie.** POMIAR: audyt nadzorcy po #25 — 40 wątków, 6 utraconych, 5 niepotwierdzonych (ledger L716–717); odtworzona wiedza zawierała błąd (L736: „59 wierszy” to `AUTO_INCREMENT`, produkcja ma 54). Refaktor zmienił komentarze w 9 plikach poza modułem (−271 linii w `GutschriftDocumentRepository`, −160 w `GutschriftVerificationService`) — POMIAR (podagent). Poprawka: bramka listuje usunięte bloki komentarzy powyżej 5 linii; raport porcji mapuje każdy na miejsce docelowe; pliki poza modułem poza zakresem. Koszt: S.

**L24. Kalibracja szumu jednym przebiegiem.** POMIAR: ledger L833 — kalibracja `main_dev` ↔ `main_dev` raz, „nie dowodzi stabilności”; szum `SchemaGuard` dał 166/168. Poprawka: trzy przebiegi ta sama strona ↔ ta sama strona przed startem pliku; maska powstaje tylko z nich. Koszt: S (około 10 minut pracy stanowiska).

**L25. Zapadki na styk i równościowe.** POMIAR (podagent): `assertSame(7, …)` dla wywołań `documentNotFound`, ratchet równościowy pięciu plików w `GutschriftDocblockChronicleLatchTest.php:30-36`, metoda 40 SLOC przy progu 40. Przeciek: każda przyszła zmiana w kolejce czerwieni zapadkę i kusi podniesieniem stałej. Poprawka: zapadki standardu jako nierówności z zapasem; równość tylko tam, gdzie liczba jest kontraktem. Koszt: S.

**L26. Brak budżetu i reguły stopu.** POMIAR: ledger nie zawiera kosztu (USD, tokeny), limitów ani kompakcji; 114 commitów, 24 recenzje porcji i 10 ślepych ocen na jeden plik. `TK/agents/refactoring-orchestrator.md` nie ma limitu prób. `kolejka.sh:97-101` rozwiązuje listę porcji raz przy starcie. Kryterium #27 „wersja 1.8.0” jest niespełnialne (manifest 1.10.0). Poprawka: budżet w KARCIE (porcje, rundy, USD), pomiar per rola jak w `koszt-rol-kolejki`, stop po przekroczeniu. Koszt: S.

## 3. Wytyczne dla wykonawcy (do `cykl-refaktoru.md`)

Przed pierwszą porcją:
1. Uruchom stanowisko stary ↔ stary trzy razy i zacznij dopiero przy 3 × IDENTYCZNY. — Szum znaleziony później kusi maskowaniem prawdziwej różnicy.
2. Nie zmieniaj maski, scenariuszy, uzasadnień ani plików w `tests/rownowaznosc/` w porcji z kodem produkcyjnym; potrzebę zmiany zgłoś nadzorcy i zatrzymaj porcję. — Kto zmienia miarę i mierzony kod jednocześnie, nie ma dowodu.
3. Dla każdej akcji napisz scenariusz na każdą rolę z mapy uprawnień (dozwolona i odmowa) i na każdy kod błędu z pliku. — Bramki ról przenosi się najczęściej i widać je tylko pod właściwą rolą.
4. Wypisz z grep wszystkie wejścia do pliku: trasy, crony, skrypty, inne klasy; każde wejście dostaje scenariusz albo wpis „poza zakresem” z powodem. — „Nieosiągalne przez HTTP” bywa osiągalne z crona.
5. Wypisz usługi zewnętrzne, których dotyka plik, i przygotuj stub dla każdej; nie zaczynaj, gdy pułapka sieci rejestruje połączenie. — Wywołanie na żywo nie jest ani powtarzalne, ani obserwowane.
6. Testy czytające źródło starego pliku jako tekst przepisz na testy zachowania przed rozbiciem, w osobnej porcji, zielone na starym kodzie. — Inaczej trzeba je zmieniać razem z kodem i przestają być dowodem.

W każdej porcji:
7. Jedna porcja to jedna faza: 2a albo 2b, albo 3, albo 4; nie łącz przeniesienia ze zmianą treści. — Dowód AST działa tylko dla czystego przeniesienia.
8. W 2a przenoś ciała metod bez zmian, także formatowanie i komentarze; porządki rób w fazie 4. — Każda „drobna poprawka przy okazji” wyłącza dowód strukturalny.
9. W 2b–4 przed zmianą gałęzi sprawdź, że wykonuje ją scenariusz; jeśli nie, najpierw dopisz scenariusz albo test charakteryzujący i pokaż go zielonym na starym kodzie. — Zmiana w niewykonywanej gałęzi zawsze daje IDENTYCZNY.
10. Ścieżki `catch`, rollback i zwalnianie blokad zmieniaj wyłącznie z testem, który tę ścieżkę wykonuje. — To ścieżki, których stanowisko w pilocie nie pokrywało.
11. Zachowuj kolejność odczyt → blokada → zapis → audyt → commit; nie przesuwaj budowy obiektów z I/O przed `BEGIN` ani za `COMMIT`. — Kolejność SQL jest zachowaniem, a jej zmiana tworzy wyścig.
12. Nie zmieniaj typu ani treści wyjątku, kodu statusu, tekstu komunikatu ani kształtu JSON (`[]` wobec `{}`, kolejność kluczy). — Frontend i inne klasy zależą od nich, a komparator części z nich nie widzi.
13. Każde zamierzone odstępstwo od 1:1 wpisz do tabeli „Odstępstwa od 1:1” i zatrzymaj porcję do decyzji nadzorcy. — Odstępstwo przyjęte po cichu nie trafia do odbioru.
14. Kod uznaj za martwy tylko na podstawie wykonania (sonda, PHPStan `return.type`, lista wywołujących z grep), nigdy na podstawie braku pokrycia. — Niepokryte znaczy nietestowane, nie nieużywane.
15. Nie zmieniaj asercji w istniejących testach; jeśli test trzeba przepiąć na nową klasę, zachowaj asercję co do litery i wpisz przepięcie do raportu. — Zmiana asercji i kodu naraz niczego nie dowodzi.
16. Nie podnoś stałych zapadek i nie rozszerzaj list dozwolonych; zgłoś nadzorcy. — Zapadka podniesiona przez wykonawcę nie jest zapadką.
17. Nie ruszaj plików spoza pliku w refaktorze i jego modułu, także komentarzy. — Zmiany obok rozmywają zakres i odbiór.
18. Usuwając komentarz dłuższy niż 5 linii, wskaż w raporcie, gdzie przeniosłeś jego treść (dokument modułu, incydenty, commit). — Pilot utracił w ten sposób 6 wątków wiedzy.
19. Nie pisz w docblokach historii refaktoru („Wydzielone z…”, numery porcji i issue). — To kronika, nie opis kodu; zdradza też refaktor oceniającym.

Dowód porcji:
20. Do raportu wklej wynik `raport.json` z bieżącego SHA: werdykt, liczbę scenariuszy, `maska_sha256`, `scenariusze_sha256`; nie przepisuj wyniku z pamięci ani z wcześniejszego przebiegu. — Po kompakcji „pamiętany” wynik bywa wynikiem innego commita.
21. Nie używaj `--tylko` w przebiegu dowodowym. — Częściowy przebieg wygląda w raporcie jak pełny.
22. Uruchom komplet mutantów; mutant, który się nie nakłada, napraw w tej samej porcji. — IDENTYCZNY bez kontroli dodatniej nie jest dowodem.
23. Przy RÓŻNICY najpierw załóż, że to regresja: pokaż różnicę i jej przyczynę w kodzie; szumem nazwij ją dopiero po odtworzeniu na stary ↔ stary. — Trzy fałszywe zielenie pilota wzięły się z ufania narzędziu.
24. Pełną suitę porównuj zbiorem nazw czerwonych testów z bazą (`comm`), nie liczbą. — Liczba może się zgadzać przy innym składzie.
25. Po trzech nieudanych próbach tej samej porcji zatrzymaj się i oddaj nadzorcy opis przeszkody. — Kolejne próby pod presją kończą się obejściem bramki.

## 4. Lista kontrolna recenzenta porcji refaktoru (dodatek do `code-reviewer.md`)

Stosuj, gdy porcja ma etykietę refaktoru. Oś dodatkowa: „zachowanie zachowane”. Werdykt APPROVE wymaga wszystkich punktów; każdy punkt kończ dowodem (polecenie i wynik).

1. Zakres: `git diff --stat` porcji dotyka tylko pliku w refaktorze, jego modułu i testów; zmiana w `tests/rownowaznosc/` (maska, scenariusze, uzasadnienia, `lib/`, skrypty) poza porcją „zmiana stanowiska” to REQUEST_CHANGES bez dalszej analizy.
2. Faza: porcja deklaruje jedną fazę; w 2a uruchom `sprawdz-przeniesienia.php` sam i wklej wynik; w 2b–4 sprawdź każdą różnicę z mapy podstawień, nie próbkę.
3. Dowód: sam odczytaj `raport.json` dla SHA porcji; porównaj `maska_sha256` i `scenariusze_sha256` z KARTĄ; odrzuć przebieg z `--tylko` i przebieg z innego SHA.
4. Kontrola dodatnia: komplet mutantów nałożony i RÓŻNICA; dopisz co najmniej dwa własne mutanty na liniach zmienionych w porcji i uruchom je na stanowisku, nie tylko na PHPUnit.
5. Pokrycie zmiany: dla każdej zmienionej gałęzi w 2b–4 wskaż scenariusz lub test, który ją wykonuje; brak = REQUIRED.
6. Ścieżki błędu: dla każdego zmienionego `try`/`catch`/`finally`, rollbacku i zwolnienia blokady porównaj stary i nowy przebieg linia po linii; sprawdź, że typ w `catch` wskazuje tę samą klasę po zmianie przestrzeni nazw (pełna nazwa, nie krótka).
7. Kolejność efektów: odczyt → blokada → zapis → audyt → commit bez zmian; obiekty z I/O nie przeszły przez granicę transakcji.
8. Kontrakt wyjścia: status, kod błędu, tekst komunikatu, typ wyjątku, kształt JSON (pusta lista wobec pustego obiektu, typy liczb i `null`) bez zmian; dla każdej nowej klasy DTO lub prezentera porównaj surowe body starego i nowego kodu na jednym przypadku pustym i jednym pełnym.
9. Uprawnienia: każda bramka roli i widoczności ze starego kodu ma odpowiednik w nowym, w tym samym miejscu względem odczytu danych; scenariusz pod rolą ograniczoną istnieje.
10. Testy: wypisz usunięte i zmienione asercje w istniejących testach (`git diff -- tests | grep -E '^[-+].*(assert|expect)'`); każdą zaklasyfikuj jako przepięcie, zaostrzenie albo osłabienie; osłabienie bez decyzji właściciela = REQUEST_CHANGES.
11. Zapadki: zmieniona stała, lista dozwolonych albo wykluczenie w skrypcie miary bez decyzji właściciela = REQUEST_CHANGES.
12. Martwy kod: każde usunięcie ma dowód z wykonania albo listę wywołujących; „niepokryte” nie jest dowodem.
13. Odstępstwa: tabela „Odstępstwa od 1:1” zgadza się z diffem; każde odstępstwo potwierdź wykonaniem starego i nowego kodu na tym samym wejściu; odstępstwo spoza tabeli = REQUEST_CHANGES.
14. Wady sprzed refaktoru: znalezioną wadę zachowania sprawdź na starym SHA; jeśli istnieje tam identycznie, zgłoś ją jako „sprzed refaktoru” do osobnego issue i nie blokuj nią porcji; jeśli nie istnieje, to regresja i CRITICAL.
15. Komentarze: usunięte bloki powyżej 5 linii mają wskazane miejsce docelowe; nowe docbloki są prawdziwe względem kodu (pilot: trzy fałszywe opisy złapane dopiero w recenzji); brak kroniki refaktoru.
16. Rozmiar porcji licz z liczby zmienionych gałęzi, nie z `--stat`; czyste przeniesienie 600 linii z zielonym AST to porcja mała, 40 linii w 2b to porcja średnia.

Do `eval-recenzenta` dopisać przypadki refaktorowe (dziś 0 z 9): zmiana typu w `catch` po przeniesieniu przestrzeni nazw, `[]` → `{}`, rollback usunięty w gałęzi niepokrytej, osłabiona asercja w przepiętym teście, wpis dodany do maski w porcji z kodem.

## 5. Lista kontrolna właściciela przy odbiorze (około 20 minut, bez czytania diffu)

`<baza>` = `git merge-base main_dev <gałąź>`, `<gałąź>` = gałąź integracyjna, `<raport>` = katalog `tests/rownowaznosc/raport/<Plik>-<etap>/` ostatniego przebiegu.

1. `git diff --stat <baza> <gałąź> -- php js | tail -1` oraz lista plików spoza pliku i modułu. Czerwona flaga: plik produkcyjny spoza modułu z czymkolwiek poza komentarzami; zakres liczony od starego SHA zamiast od `<baza>` (w pilocie zawierałby 1012 obcych commitów).
2. `jq '.werdykt, .scenariuszy, .identycznych, .maska_sha256' <raport>/raport.json` i `grep sha256 KARTA.md`. Czerwona flaga: werdykt inny niż IDENTYCZNY, skróty różne od KARTY, maska spoza repo.
3. `git log --oneline <baza>..<gałąź> -- tests/rownowaznosc/maska tests/rownowaznosc/scenariusze tests/rownowaznosc/lib 'tests/rownowaznosc/*.php' 'tests/rownowaznosc/*.sh'`. Czerwona flaga: commit po pierwszym commicie produkcyjnym bez zgody nadzorcy w ledgerze.
4. Pytanie: „Ile mutantów się nałożyło i ile dało RÓŻNICA w ostatnim przebiegu?”. Czerwona flaga: mniej niż komplet („aplikuje się 10/16”), mutanty tylko na PHPUnit.
5. `jq '.bez_uzasadnienia, .linii_na_kategorie' <raport>/pokrycie.json`. Czerwona flaga: `bez_uzasadnienia` > 0; kategorie `wyscig`, `wyjatek-infrastruktury`, `niezmiennik-bazy` bez nazwy testu, który je wykonuje; brak pokrycia strony B.
6. Pytanie: „Pokaż tabelę ról × akcji ze scenariuszami”. Czerwona flaga: akcja pokryta tylko jako administrator; kod błędu bez scenariusza.
7. `git diff <baza> <gałąź> -- tests | grep -cE '^-.*(assert|expect)'` i to samo z `^\+`; `git diff --diff-filter=D --name-only <baza> <gałąź> -- tests`. Czerwona flaga: usunięte asercje bez tabeli klasyfikacji; usunięty plik testu.
8. `git diff <baza> <gałąź> -- tests/Static tests/Config scripts | grep -E '^[-+].*(const |=> *[0-9]|exclude|pomijaj)'`. Czerwona flaga: podniesiona stała lub poszerzona lista, której nie zatwierdziłeś.
9. Pytanie: „Pokaż `comm` zbioru czerwonych testów pełnej suity: baza wobec gałęzi”. Czerwona flaga: jakakolwiek nowa nazwa; wynik podany liczbą zamiast zbiorem.
10. Pytanie: „Pokaż tabelę odstępstw od 1:1”. Czerwona flaga: tabela pusta przy commitach z „ujednolicić”, „usunąć martwe”, „uprościć” w tytule (`git log --oneline <baza>..<gałąź> -- php | grep -iE 'ujednolic|martw|upro'`); odstępstwo bez Twojej zgody.
11. Pytanie: „Pokaż listę znanych wad sprzed refaktoru i ich issues”. Czerwona flaga: wada bez issue; wada bezpieczeństwa lub danych (klasa R10: ujawnienie stanu roli ograniczonej) bez terminu.
12. Pytanie: „Jakie wejścia poza HTTP ma ten plik i który scenariusz je wykonuje?”. Czerwona flaga: cron lub skrypt bez scenariusza; usługa zewnętrzna bez stubu; połączenia zarejestrowane przez pułapkę sieci.
13. Ręcznie na dev, 5 minut, na koncie roli ograniczonej (nie administrator): trzy najczęstsze akcje pliku, w tym jedna z odmową. Czerwona flaga: jakakolwiek różnica względem produkcji, pusta lista tam, gdzie były dane.
14. `wc -l docs/architektura/modul-<nazwa>.md` i pytanie do świeżej sesji: „Gdzie dodać nową akcję w tym module?”. Czerwona flaga: odpowiedź niezgodna z dokumentem; dokument opisuje historię zamiast wzorca.
15. Pytanie: „Koszt pliku (sesje, USD) wobec budżetu z KARTY i plan wdrożenia”. Czerwona flaga: brak danych o koszcie; refaktor wdrażany razem ze zmianą zachowania; brak osobnego wdrożenia z trzema dniami obserwacji `log-report` i wycofaniem jednym revertem.

## 6. Ślepa ocena

Stan (ledger L440, L497, L691–699): 6 wymiarów (Poprawność, Kompletność, Testy, Design, Czytelność, Zakres), próg ≥4 w każdym i ≥27/30, dwóch świeżych `code-reviewer` (opus) na kopii `git archive`. Wyniki A/B w pięciu rundach: 25/22, 26/25, 26/25, 25/25, 25/24. Definicji wymiarów i skali nie ma w ledgerze (POMIAR (podagent), grep).

Co mierzy naprawdę (przeliczenie z tabeli ledgera L691–697, 10 ocen × 6 wymiarów):
- Utracono 52 punkty z 300: Czytelność 12, Poprawność 11, Design 11, Testy 9, Zakres 5, Kompletność 4.
- Liczba piątek: Poprawność 0/10, Design 0/10, Czytelność 0/10, Testy 1/10, Zakres 5/10, Kompletność 6/10.
- Przy trzech wymiarach, w których piątka nie padła ani razu, 27 punktów wymaga piątki jednocześnie w Testach, Zakresie i Kompletności. Z częstości empirycznych daje to około 0,1 × 0,5 × 0,6 = 3% na oceniającego. Próg jest dla tej rubryki i tego obiektu strukturalnie nieosiągalny.
- „4” działa jak „znalazłem cokolwiek”: świeży recenzent na 3206 liniach zawsze coś znajduje. Rubrykę skalibrowano 2026-11-01 na małych diffach kolejki (28,0 wobec 27,5), gdzie brak znalezisk jest częsty; liczba znalezisk rośnie z rozmiarem obiektu, więc próg karze rozmiar.
- Poprawność trzyma 4 przez wady sprzed refaktoru (ledger L699), których refaktor nie może naprawić bez złamania 1:1. Rubryka ocenia więc jakość bezwzględną modułu razem z odziedziczonym długiem, a nie jakość refaktoru.
- Poprawki między rundami nie podnosiły sumy: po rundzie 1 skok +1/+3, potem pasmo 24–26 mimo ośmiu porcji; pojedyncze wymiary wahały się o ±1 bez zmiany w ich obszarze (Kompletność 5→4, Testy 5→4). Szum oceny: NIEZMIERZONE — ten sam SHA nie był oceniany dwukrotnie poza parą A/B (różnice sum 3, 1, 1, 0, 1).
- Kotwicy brak: stary kontroler nie dostał oceny tą rubryką, więc nie wiadomo, czy 25 to postęp z 15, czy z 24.
- Ślepość niepełna: docbloki i nagłówki testów zdradzały refaktor (ledger L440, L463).
- Wartość, którą trzeba zachować: to jedyna warstwa, która znalazła R1–R11 i wady formy wprowadzone przez refaktor (trzy kopie bramki, kronika w docblokach, fałszywe komentarze). Stanowisko z definicji ich nie widzi, bo mierzy różnicę, nie poprawność.

Rekomendacja: zmienić rubrykę, próg i fazę 4; ślepej oceny nie usuwać.
1. Faza 0 (nowa): dwóch recenzentów ocenia stary plik. Wynik: lista wad zachowania → issues i tabela „Znane wady”; ocena formy starego pliku tą samą rubryką = kotwica.
2. Rubryka fazy 4 obejmuje wyłącznie to, na co refaktor ma wpływ: Design, Czytelność, Testy, Zakres. Poprawność i Kompletność zastąpić listą znalezisk z klasyfikacją: regresja refaktoru (blokuje), wada sprzed refaktoru (issue, nie blokuje), wada formy wprowadzona przez refaktor (blokuje, jeśli REQUIRED).
3. Próg kryterialny zamiast punktowego: 0 regresji; 0 nierozwiązanych REQUIRED klasy „wprowadzone przez refaktor”; każdy wymiar formy u obu oceniających ≥4 i nie niżej niż kotwica starego pliku + 1; zapadka standardu zielona.
4. Reguła stopu: najwyżej dwie rundy. Runda 2 sprawdza tylko, czy znaleziska rundy 1 zamknięto; nowe znaleziska rundy 2 idą do issues, chyba że to regresja.
5. Jednorazowy pomiar szumu przed zmianą progu: ten sam SHA (`b8623fafd`) ocenić jeszcze dwoma oceniającymi i stary kontroler (`28e909055`) dwoma — cztery oceny. Bez tego każdy próg punktowy pozostaje NIEZMIERZONY.
6. Dla #33: wynik poniżej 27 nie jest dowodem słabej jakości modułu; z danych ledgera wynika 0 regresji i brak otwartych REQUIRED wprowadzonych przez refaktor poza delegatorami pod Reflection (27 wywołań, 9 plików testów). Decyzję o przyjęciu oprzeć na kryteriach z punktu 3, nie na sumie.

## 7. Kolejność zmian przed następnym plikiem

Zmiana zakresu #27: z „skill `/refaktor` i wersja 1.8.0” na „bramka, zamrożenie i wytyczne”; automatyczne łańcuchowanie porcji przez kolejkę dopiero po pierwszym pliku przeprowadzonym na nowej bramce pod nadzorem. Numer wersji: następny wolny (manifest ma 1.10.0), nie 1.8.0.

1. **Stanowisko na `main_dev`** (K, osobny PR, wykonawca Opus): przenieść `tests/rownowaznosc/` z gałęzi refaktoru; samotesty uruchamiane przez `stanowisko.sh` (L15); odmowa, gdy obie strony mają to samo drzewo pliku (L6c). Zamyka warunek wstępny L2.
2. **Utwardzenie komparatora** (K, ten sam lub następny PR): kod wyjścia i biała lista w `pokrycie.php`, pcov po stronie B (L4); `oczekuj` w scenariuszach i obowiązkowa kontrola dodatnia (L6); surowe body i wszystkie nagłówki (L10); `@TERAZ+n` (L11); `pliki_zapisu` z KARTY i skrót załączników (L12); naprawa scenariusza `cli` (L8); `NameResolver` i `declare` w AST (L14). Każda zmiana z mutantem, który przed nią był GREEN.
3. **Sieć** (K): pułapka fail-closed i stuby dla usług PurchaseService (L3). Jeśli pułapka okaże się niewykonalna, plik nie startuje — to decyzja właściciela.
4. **Toolkit, #27 w nowym zakresie** (claude-config): tryb refaktoru w `bramka.sh` (L1), `KARTA.md` ze skrótami i hook na ścieżki stanowiska (L2), listowanie zmienionych asercji, stałych zapadek i usuniętych komentarzy (L16, L23), tabela odstępstw (L17), wyłączenie pliku z kolejki (L18), budżet i stop (L26), `cykl-refaktoru.md` z sekcji 3, dodatek do `code-reviewer.md` z sekcji 4, pięć przypadków refaktorowych w `eval-recenzenta` z pomiarem bazowym.
5. **Tryb podstawień AST dla 2b** (L5) — może iść równolegle z krokiem 4; bez niego fazy 2b–4 PurchaseService wymagają recenzji nadzorcy każdej porcji.
6. **Ślepa ocena**: cztery oceny pomiaru szumu i kotwicy, potem nowa rubryka i reguła stopu (sekcja 6).
7. **Faza 0 PurchaseService**: inwentarz wad starego pliku (L19), wejścia i macierz ról (L9), trzy przebiegi kalibracji (L24), KARTA z budżetem. Dopiero potem pierwsza porcja.
8. **Po PurchaseService**: przegląd kosztu i luk MEDIUM (L20–L22, L25); przed drivers.js osobny projekt stanowiska JS (L7) i jego audyt.

Kroki 1–4 i 7 są warunkiem startu PurchaseService. Krok 5 jest warunkiem biegu faz 2b–4 bez nadzorcy. Krok 6 jest warunkiem fazy 4.

Uzupełnienia z sekcji 8: N1 i N3 dołączyć do kroku 1, N5 do kroku 4, N2 do wytycznych (sekcja 3) i listy recenzenta, N4 zmierzyć w kroku 7.

## 8. Porównanie z listą nadzorcy

Listę `K/.claude/tmp/audyt-procedury/znane-luki-nadzorcy.md` przeczytałem po zapisaniu sekcji 1–7; sekcji 2 po lekturze nie zmieniałem. Wynik: 5 pozycji znalezionych samodzielnie, 2 częściowo, 3 pominięte, 0 obalonych w całości (w pozycji 3 obalone uzasadnienie). Luki z mojej listy, których lista nadzorcy nie zawiera: L3, L4, L5, L6 (poza gniciem łatek), L7 jako brak stanowiska, L9–L20, L22–L23, L25–L26.

| # | Pozycja nadzorcy | Wynik | Odniesienie i uwagi |
|---|---|---|---|
| 1 | Brak automatyzacji (#27) | znaleziona sam | L1, L2. |
| 2 | Skrypty K3 i K5 tylko w `.claude/tmp/i33/`, poza repo | pominięta | Skrypty czytałem i odnotowałem maskę spoza repo (L2) oraz to, że K3 biegnie jako administrator i tylko GET (L9); braku skryptów w repo nie zgłosiłem jako luki. POMIAR po lekturze: `git ls-files .claude/tmp/i33` — brak w indeksie. Przyjmuję jako N1. |
| 3 | Stanowisko nie widzi współbieżności; R1, R3, R6, R7 wykryła recenzja | znaleziona sam, uzasadnienie częściowo obalone | L21. Korekta: R1/R3/R6/R7 to wady sprzed refaktoru, identyczne po obu stronach, więc stanowisko nie pokazałoby ich także przy żądaniach równoległych — mierzy różnicę, nie poprawność. Współbieżność w stanowisku chroni tylko przed zmianą okna wyścigu przez refaktor; stąd waga MEDIUM, a wady tej klasy łapie inwentarz fazy 0 (L19). |
| 4 | Strefa czasowa i środowisko (R9; jedna strefa) | pominięta | R9 sklasyfikowałem jako wadę sprzed refaktoru, ale środowiska nie zgłosiłem. POMIAR po lekturze: stanowisko używa `/opt/homebrew/bin/mysqld` (`R/mysqld.sh:27`), dev to MySQL 9.6, produkcja MariaDB 10.4 (`K/CLAUDE.md:37`, `K/docs/VERIFICATION_ENV.md:51`); strefa jedna (`przebieg.php:28`). Przyjmuję jako N2. |
| 5 | Crony, CLI i inni konsumenci poza scenariuszami HTTP | znaleziona sam | L8, wytyczna 4, punkt 12 listy właściciela. Dla pilota POMIAR (podagent): klasy modułu woła wyłącznie kontroler, więc w pilocie luka nie zadziałała; dla PurchaseService zadziała (dwa skrypty). |
| 6 | Maska jako ślepe miejsce; wpis `SELECT DATABASE()` zbędny, przyczyną był wzorzec bazy z 8 oczekującymi migracjami; kalibracja raz | częściowo | Znalezione: maska spoza repo, werdykt K2 policzony z nią, brak zamrożenia (L2), kalibracja jednym przebiegiem (L24). Pominięte: że wpis był zbędny, a przyczyna leżała we wzorcu bazy — przyjąłem wyjaśnienie z ledgera (szum `SchemaGuard`) bez sprawdzenia. To potwierdza scenariusz przecieku z L2: różnicę zamaskowano zamiast znaleźć przyczynę. Przyjmuję jako N3. |
| 7 | Ślepa ocena: próg lub rubryka źle ustawione albo faza 4 nie dowozi | znaleziona sam | Sekcja 6 rozstrzyga alternatywę pomiarem: wina rubryki i progu (0 piątek na 30 ocen w trzech wymiarach), nie fazy 4. |
| 8 | Koszt 168 ręcznych scenariuszy; skalowanie na InvoiceService i JS nieznane | częściowo | Znalezione: brak stanowiska JS (L7), brak budżetu (L26). Pominięte: koszt pisania scenariuszy jako osobna luka; moje L9 ten koszt podnosi. Przyjmuję jako N4. |
| 9 | Łatki mutantów przestają się aplikować | znaleziona sam | L6 (brak kontroli dodatniej), L13. |
| 10 | Zapadki repo czerwienieją dopiero przy scaleniu z `main_dev` | pominięta | Odnotowałem skutek (`SOURCE_AS_TEXT_TESTS` 553→555, L16), nie mechanizm. Przyjmuję jako N5. |

### Luki przyjęte z listy nadzorcy

**N1 (REQUIRED). Narzędzia bramy końcowej poza repo.** POMIAR: `k2.sh`, `k3-odczyty.php`, `k5-porownaj.py` leżą w `K/.claude/tmp/i33/`, poza indeksem git. Przeciek: brama dla kolejnego pliku powstaje od nowa, inna i niezweryfikowana; wyniku #33 nie da się odtworzyć po sprzątnięciu `tmp`. Warstwa: stanowisko. Poprawka: K3 (powtórzenie odczytów na zrzucie produkcji) i K5 (akcje z porównaniem binlogu) jako parametryzowane tryby `stanowisko.sh`, z własnymi mutantami. Koszt: M.

**N2 (MEDIUM; REQUIRED dla porcji zmieniającej tekst SQL). Inny silnik bazy i jedna strefa czasowa.** POMIAR: jak w wierszu 4. Przeciek: faza 3–4 zmienia zapytanie; MySQL 9.6 i MariaDB 10.4 dają inny wynik lub plan; obie strony stanowiska stoją na MySQL. Zamiana źródła czasu (`NOW()` ↔ zegar PHP) jest widoczna w kanale `sql` tylko jako zmiana digestu. Warstwa: bramka + recenzent. Poprawka: reguła „tekst SQL bez zmian w całym refaktorze”; porcja, która zmienia digest któregokolwiek zapytania, uruchamia testy bazodanowe pliku na MariaDB przez `scripts/ci-local/run.sh`; jeden scenariusz z sesją bazy w innej strefie niż PHP. Koszt: S.

**N3 (REQUIRED). Wzorzec bazy stanowiska nie jest walidowany.** POMIAR: pozycja 6 listy nadzorcy (pomiar nadzorcy: po oznaczeniu 8 migracji jako zastosowane wynik 168/168 bez nowego wpisu maski, 2 przebiegi); w `stanowisko.sh` i `przygotuj-wzorzec.sh` nie ma sprawdzenia oczekujących migracji (grep `migrac`: 0 trafień poza komentarzem `--wzorzec`). Przeciek: wzorzec z oczekującymi migracjami daje szum, który trafia do maski i zasłania prawdziwe różnice w tym samym kanale. Warstwa: stanowisko. Poprawka: przygotowanie odmawia przy oczekujących migracjach po którejkolwiek stronie; wpis globalny w masce wymaga odtworzenia szumu na stary ↔ stary i zgody nadzorcy. Koszt: S.

**N4 (MEDIUM). Koszt scenariuszy i skalowanie nieznane.** POMIAR: 168 scenariuszy na 8 tras pilota (21 na trasę); PurchaseService ma 33 metody publiczne i odwołania w 30 plikach `php/`. Koszt napisania scenariuszy pilota: NIEZMIERZONE (ledger nie zawiera kosztu). Poprawka: w fazie 0 PurchaseService zmierzyć koszt 20 pierwszych scenariuszy i ekstrapolować przed decyzją o starcie; odczyty pokrywać powtórzeniem żądań na zrzucie produkcji (tryb K3 z N1: 464 żądania bez pisania scenariuszy), ręczne scenariusze rezerwować dla zapisów, odmów i ról. Koszt: S (pomiar).

**N5 (REQUIRED). Zapadki repozytorium czerwienieją dopiero przy integracji.** POMIAR: pozycja 10 listy nadzorcy; `SOURCE_AS_TEXT_TESTS` podniesiono w ostatnim commicie integracyjnym `b8623fafd`; ledger L217 opisuje ten sam mechanizm (zapadka czerwona dopiero w pełnej suicie). Przeciek: dług wobec zapadek rośnie przez kilkadziesiąt porcji, a na końcu jedynym wyjściem jest podniesienie stałej pod presją scalenia. Warstwa: bramka. Poprawka: bramka porcji uruchamia `tests/Static` na próbnym scaleniu z bieżącym `main_dev` w katalogu tymczasowym (bez scalania do gałęzi refaktoru); budżet zapadek objętościowych zapisany w KARCIE przed startem. Koszt: M.

Łącznie po uzupełnieniu: 31 luk — CRITICAL 7, REQUIRED 15, MEDIUM 9.
