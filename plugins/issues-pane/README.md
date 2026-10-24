# issues-pane

Mod Claude Code otwierający panel **Issues** obok rozmowy z otwartymi issues repozytorium, w którym działa sesja.

- **Sortowanie:** po etykiecie priorytetu `P0`–`P3` (najwyższa wygrywa), w ramach priorytetu od najstarszych; issues bez priorytetu na końcu.
- **Wiersz:** wiek w dniach, potem `#numer tytuł` jako hiperłącze do issue na GitHubie.
- **Odświeżanie:** start sesji, przycisk **Odśwież**, komenda `/issues` (otwiera też zamknięty panel), po turze gdy lista ma ponad 5 minut.

Wymaga zalogowanego `gh` (GitHub CLI) — lista pochodzi z `gh issue list` w katalogu sesji.

## Instalacja

```
/plugin install issues-pane@milwis-marketplace
```
