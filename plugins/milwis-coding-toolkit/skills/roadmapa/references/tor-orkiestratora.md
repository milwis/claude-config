# Tor orkiestratora — mechanika

Uzupełnienie `.claude/skills/roadmapa/SKILL.md` §4a. Opisuje DRUGI tor realizacji: jedną
długowieczną sesję-lead, która rozdziela pracę subagentom zamiast rodzić następców. Nie zastępuje
sztafety (§1-§7 głównego pliku, tor domyślny) — jest wyjątkiem dla partii, w których fazy są
KRÓTKIE i ROZŁĄCZNE PLIKOWO (kryterium wyboru: §4a głównego pliku).

## Co robi lead

- Czyta roadmapę i ledger na start (jak G1/Gn w sztafecie), potem tylko ledger — żeby wiedzieć,
  które fazy są niedomknięte.
- Rozdziela każdą niedomkniętą fazę jako osobne wywołanie `Agent` z `isolation: "worktree"` —
  każdy subagent pracuje na własnej kopii repo, więc równoległe fazy nie kolidują na wspólnym
  indeksie (klasa szkód, przed którą sekwencyjność sztafety broni się w §5/§6a głównego pliku).
- **Nie czyta plików kodu (`Read`/`Grep`/`Glob` na treść implementacji) i nic sam nie edytuje** —
  weryfikuje wyłącznie z tego, co subagent zwrócił w raporcie (komendy, wyjścia, `plik:linia`).
  Jeśli raport nie niesie dowodu rozstrzygającego, lead zleca subagentowi doprecyzowanie zamiast
  sprawdzać sam.
- Dopisuje wiersz ledgera na podstawie raportu subagenta i commituje go — to jedyna pisząca
  operacja na WSPÓLNYM drzewie, którą lead wykonuje sam (roadmapa i ledger żyją poza worktree
  subagentów, więc nie kolidują z ich pracą).
- Domyka przebieg, gdy `/goal` (niżej) jest spełniony, albo zatrzymuje się na warunkach z §6
  głównego pliku (te same zakazy: push na `origin`, deploy, `gh issue close`, KSeF).

## Co robi subagent

- Dostaje JEDNĄ fazę (plan/exec/verify jednego issue), pracuje we własnym worktree, zwraca raport
  z dowodem. Nie rodzi kolejnych subagentów — ten sam zakaz co w sztafecie (§1a głównego pliku:
  podagent nie przekazuje pracy w bok, nie zakłada osobnej sesji w tle).
- Commituje swoją pracę w SWOIM worktree przed zwróceniem raportu — lead nie ma innego sposobu
  odzyskania jej niż to, co subagent zdążył zapisać przed końcem swojego okna.

## `/goal` — warunek domknięcia

Brzmienie: „każde issue z roadmapy ma w ledgerze wiersz `verify` z dowodem albo wiersz
`BLOKADA` z powodem."

Warunek musi być rozstrzygalny z transkryptu: policz issues w roadmapie, sprawdź dla każdego, czy
ledger zawiera wiersz `verify` z sekcją `POMIAR` niosącą dowód, LUB wiersz `BLOKADA` z opisanym
powodem. Brak jednego z dwóch dla któregokolwiek issue = `/goal` niespełniony — lead nie ogłasza
końca przebiegu.

## Wiersze ledgera pod tym torem

Format wiersza (§3 głównego pliku) **zostaje bez zmian** — bez nowego pola na tor. Lead odróżnia
swoje wiersze, opisując w polu `Zrobione` albo `Miny`, że faza wykonał subagent w konkretnym
worktree, prozą — nie przez modyfikację szablonu.

## Uzupełnienie, nie zamiennik: `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`

Ta zmienna ogranicza głębokość spawnu subagentów niezależnie od treści komendy — działa tam, gdzie
regex `relay-pre.sh` (§1a głównego pliku) nie łapie (nazwa binarki podana zmienną, `bash -c`).
**Nie zastępuje blacklisty komend w `relay-pre.sh`** — blacklista zostaje, bo chroni przed inną
klasą wywołania (uruchomieniem nowej sesji w tle poza wiedzą leada), a `MAX_SUBAGENT_SPAWN_DEPTH`
przed tamtą klasą nie chroni.

## ZMIERZONE suchą próbą (Zadanie 7b, 2026-09-05) — jeden lead, jeden subagent

Przebieg: lead (sesja główna) rozdzielił JEDNĄ drobną fazę subagentowi z `isolation: "worktree"`,
sam nie edytował ani jednego pliku zadania. Wyniki są `POMIAR`, nie `WNIOSEK` — każdy z komendą.

**1. Worktree odgałęzia się od `origin/<gałąź domyślna>`, NIE od lokalnego HEAD leada.**
`POMIAR`: w drzewie leada było 26 commitów lokalnych ponad `origin/main` (szczyt `31efbd677`).
W worktree subagenta `git log --oneline origin/main..HEAD | wc -l` → `0`, a
`git merge-base --is-ancestor 31efbd677 HEAD; echo $?` → `1`. Ustawienie `worktree.baseRef` nie
występuje w żadnym pliku konfiguracji tego repo, więc obowiązuje domyślne `fresh`.

> **KONSEKWENCJA — to jest główna pułapka tego toru.** Subagent **nie widzi niezapushowanej pracy
> leada**. Zadanie zależne od commita, który leżał tylko lokalnie, subagent wykona na nieaktualnym
> kodzie i zwróci raport wyglądający na poprawny. Zanim zlecisz fazę tym torem, rozstrzygnij, czy
> zależy ona od czegoś spoza `origin/<gałąź domyślna>` — a jeśli tak, przekaż subagentowi SHA
> i polecenie `git merge <sha>` w jego worktree, albo nie używaj tego toru dla tej fazy.

**2. Worktree z commitem NIE jest sprzątany automatycznie.**
`POMIAR`: `git worktree list | wc -l` → 17 przed, **18 po**; wpis `agent-<id>` został na dysku
z gałęzią `worktree-agent-<id>`. W trakcie pracy subagenta wpis miał flagę `locked`, po
zakończeniu — nie ma. (Dokumentacja narzędzia mówi „auto-cleaned **if unchanged**"; przypadek
„zmieniony" zmierzony tutaj jako NIEsprzątany. Przypadek „bez zmian" pozostaje niezmierzony.)

**3. Praca wraca do leada BEZ pusha i bez zdalnego repo.**
`POMIAR`: z drzewa głównego `git log --oneline -1 <sha z worktree>` rozwiązuje się natychmiast —
baza obiektów jest wspólna dla wszystkich worktree tego repo. Lead odzyskuje pracę zwykłym
`git merge <gałąź-worktree>` albo `git cherry-pick <sha>` u siebie; **żaden fetch ani remote nie
jest potrzebny**. Nazwy gałęzi i katalogu nadaje harness (`agent-<id>` / `worktree-agent-<id>`),
lead ich nie wybiera — subagent MUSI je zwrócić w raporcie, inaczej lead nie wie, co scalać.

**4. Izolacja realna:** plik zmieniony przez subagenta pozostał w drzewie leada nietknięty
(`git status --short <plik>` u leada → pusto po zakończeniu subagenta).

**5. `isolation: "worktree"` wymusza tryb tła (async).** `POMIAR`: wywołanie zwróciło `agentId`
i komunikat o pracy w tle zamiast raportu synchronicznego. Lead dostaje wynik notyfikacją.

**6. W worktree NIE MA pliku `.env`.** `POMIAR`: `test -f .env` → `NIE`. Każdy przebieg testów
zależnych od środowiska da tam SKIP zamiast wyniku — czyli **fałszywy baseline**. Faza, której
kryterium odbioru jest „testy zielone", nie nadaje się do tego toru bez wcześniejszego dostarczenia
`.env` do worktree.

## NIEZMIERZONE — nadal otwarte

- **`/goal` nie jest dostępne w tym środowisku.** `POMIAR`: brak w `~/.claude/commands/`, brak
  w `.claude/commands/`, brak na liście skilli. Jeśli istnieje jako wbudowana komenda CLI, to nie
  jest wykrywalne z systemu plików. **Dopóki to nie zostanie rozstrzygnięte, warunek domknięcia
  z sekcji wyżej egzekwuje lead ręcznie** — czyta ledger i sam sprawdza, czy każde issue ma wiersz
  `verify` z dowodem albo `BLOKADA` z powodem. Nie udawaj, że robi to za Ciebie mechanizm.
- Czy dwóch subagentów przypadkowo skierowanych na TĘ SAMĄ fazę realnie nie koliduje, czy kolizja
  przesuwa się na scalanie do drzewa leada. Sucha próba miała **jednego** subagenta — ten punkt
  nie został dotknięty.
- Zachowanie przy worktree BEZ zmian (czy wtedy faktycznie znika sam).
