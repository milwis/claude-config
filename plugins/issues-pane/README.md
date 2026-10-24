# issues-pane

Mod Claude Code otwierający panel **Issues** obok rozmowy z otwartymi issues repozytorium, w którym działa sesja.

- **Sortowanie:** po etykiecie priorytetu `P0`–`P3` (najwyższa wygrywa), w ramach priorytetu od najstarszych; issues bez priorytetu na końcu.
- **Grupy:** nagłówek priorytetu z kolorową plakietką (P0 czerwony, P1 pomarańczowy, P2 żółty, P3 niebieski, bez priorytetu szary) i liczbą issues.
- **Karta issue:** ikona modułu (etykieta `modul:*`, np. 🧾 faktury, 🔧 warsztat, 🔒 security) albo typu, potem `#numer tytuł` jako hiperłącze do GitHuba. W drugiej linii typ (🐞 bug, 🩹 poprawka, 🧱 strukturalne, 🔍 analiza, 💡 pomysł), moduły, wiek w dniach, środowisko (🌐 web / 💻 lokalne) i ⏸ odłożone.
- **Odświeżanie:** w tle co 2 minuty (godzina pobrania w nagłówku), przy starcie sesji, przyciskiem **Odśwież**, komendą `/issues` (otwiera też zamknięty panel) i po turze, gdy lista ma ponad 5 minut. Odświeżanie nie zużywa tokenów modelu, tylko limit API GitHuba.

Wymaga zalogowanego `gh` (GitHub CLI) — lista pochodzi z `gh issue list` w katalogu sesji.

## Instalacja

```
/plugin install issues-pane@milwis-marketplace
```
