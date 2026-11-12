# pasek

Mod Claude Code rysujący jedną linię nad oknem promptu:

```
KonkretnyTMS · main · Opus 5.5 · ██████░░░░░░░░░░░░░░ 90k/300k · tydz. 42%
```

- **repo** — `owner/name` z remote `origin` (albo nazwa katalogu repozytorium, gdy remote brak),
- **gałąź** — `git rev-parse --abbrev-ref HEAD`,
- **model** — model głównej pętli, jak pokazuje `/model`,
- **kontekst** — pasek 20 kratek (zielony < 60%, żółty < 85%, czerwony powyżej) i zużycie w tysiącach tokenów względem okna,
- **tydz.** — procent wykorzystania tygodniowego limitu (`seven_day`); `—` poza subskrypcją lub przed pierwszą odpowiedzią API.

Elementy rozkładają się na całą szerokość okna z równymi odstępami, w złotej zaokrąglonej ramce. Pasek rysuje się tylko w aplikacji desktopowej; w terminalu te same dane pokazuje linia statusu.

Pasek nie pokazuje się sam: włącza go komenda `/pasek`, ta sama komenda go chowa (tak jak panel `/issues`).

Dane odświeżają się na starcie sesji, przy `/pasek`, po każdej turze i przy każdej zmianie pomiaru zużycia.

## Instalacja

```
/plugin install pasek@milwis-marketplace
```

albo w `~/.claude/settings.json`:

```json
"enabledPlugins": { "pasek@milwis-marketplace": true }
```
