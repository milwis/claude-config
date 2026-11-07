#!/bin/bash
# Jednorazowe przełączenie KonkretnyTMS na układ main_dev (praca) + main (produkcja). Plan: 2026-11-07-main-dev.md.
#   przelaczenie.sh --sprawdz    tylko warunki i próbne scalenia, nic nie zmienia
#   przelaczenie.sh --wykonaj    przełączenie; zatrzymuje się na pierwszym błędzie
# Kolejność jest celowa: toolkit najpierw (domyślnie wyłączony, więc niegroźny), lokalny `main` cofany dopiero po
# potwierdzeniu, że origin/main_dev ma całą pracę. `main` na GitHubie nie zmienia się w żadnym kroku.
# PROBA=1 (próba generalna na klonie): bez kroków toolkitu, domyślnej gałęzi i ~/.zshrc.
set -euo pipefail

TRYB="${1:-}"
case "$TRYB" in --sprawdz|--wykonaj) ;; *) sed -n '2,4p' "$0"; exit 2 ;; esac
REPO="${REPO:-$HOME/Programowanie/KonkretnyTMS}"
TOOLKIT="${TOOLKIT:-$HOME/Programowanie/claude-config}"
GALAZ_ZMIAN="agent/main-dev"
GALAZ_TOOLKITU="claude/main-dev-wypychanie"
SESJA="${KOLEJKA_SESJA:-kolejka}"
KLON_MARKETU="$HOME/.claude/plugins/marketplaces/milwis-marketplace/plugins/milwis-coding-toolkit"
PROBA="${PROBA:-}"

g() { git -C "$REPO" "$@"; }
blad() { echo "BŁĄD: $*" >&2; BLEDY=$((BLEDY + 1)); }
krok() { echo; echo "=== $*"; }
BLEDY=0

krok "Warunki"
if [ -z "$PROBA" ] && tmux has-session -t "$SESJA" 2>/dev/null; then blad "sesja tmux '$SESJA' działa: najpierw kolejka stop"; fi
[ ! -f "$REPO/.claude/tmp/kolejka/w-toku" ] || blad "kolejka ma issue w toku: #$(cat "$REPO/.claude/tmp/kolejka/w-toku")"
[ "$(g branch --show-current)" = main ] || blad "drzewo główne nie stoi na main"
[ -z "$(g status --short --untracked-files=no)" ] || blad "drzewo główne ma niezacommitowane zmiany"
g rev-parse --verify -q "refs/heads/$GALAZ_ZMIAN" >/dev/null || blad "brak gałęzi $GALAZ_ZMIAN"
! g rev-parse --verify -q refs/heads/main_dev >/dev/null || blad "lokalny main_dev już istnieje"
! g rev-parse --verify -q refs/tags/przed-main-dev >/dev/null || blad "tag przed-main-dev już istnieje"
# `git branch -f main` w kroku 4 odmawia, gdy main jest wypięty w innym worktree.
INNE=$(g worktree list --porcelain | awk -v r="$(g rev-parse --show-toplevel)" '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/main$/{if (w!=r) print w}')
[ -z "$INNE" ] || blad "main wypięty w innym worktree: $INNE"
g fetch -q origin
[ -z "$(g ls-remote --heads origin main_dev)" ] || blad "main_dev już jest na GitHubie"
if [ -z "$PROBA" ]; then
  git -C "$TOOLKIT" rev-parse --verify -q "refs/heads/$GALAZ_TOOLKITU" >/dev/null || blad "brak gałęzi toolkitu $GALAZ_TOOLKITU"
  [ -z "$(git -C "$TOOLKIT" status --short --untracked-files=no)" ] || blad "claude-config ma niezacommitowane zmiany"
fi

krok "Próbne scalenia (bez zapisu)"
# Obie operacje po kolei, jak w kroku 2: bez tego konflikt hotfixu ze zmianą przełączenia wyszedłby dopiero w --wykonaj.
if DRZEWO=$(g merge-tree --write-tree --name-only main origin/main); then
  echo "main + origin/main: bez konfliktów"
  POSREDNI=$(g commit-tree "$(head -1 <<<"$DRZEWO")" -p main -p origin/main -m probne-scalenie)
  if PROBNE=$(g merge-tree --write-tree --name-only "$POSREDNI" "$GALAZ_ZMIAN"); then echo "wynik + $GALAZ_ZMIAN: bez konfliktów"; else blad "konflikt z $GALAZ_ZMIAN: $PROBNE"; fi
else
  blad "konflikt main + origin/main: $DRZEWO"
fi
echo "scaleń kolejki w paczce: $(g rev-list --count --merges --grep '\[roadmapa\] Scal #' origin/main..main)"
echo "commitów ponad origin/main: $(g rev-list --count origin/main..main); origin/main ponad main: $(g rev-list --count main..origin/main)"

if [ "$BLEDY" -gt 0 ]; then echo; echo "Warunki niespełnione: $BLEDY. Nic nie zmieniono."; exit 1; fi
if [ "$TRYB" = --sprawdz ]; then echo; echo "Warunki spełnione. Nic nie zmieniono."; exit 0; fi

if [ -z "$PROBA" ]; then
  krok "1. Toolkit v1.8.0: master, GitHub, marketplace, plugin"
  git -C "$TOOLKIT" switch -q master
  git -C "$TOOLKIT" merge -q --no-ff -m "Scal $GALAZ_TOOLKITU: wypychanie gałęzi roboczej przez kolejkę (v1.8.0)" "$GALAZ_TOOLKITU"
  git -C "$TOOLKIT" push -q origin master
  claude plugin marketplace update milwis-marketplace
  claude plugin update milwis-coding-toolkit@milwis-marketplace
  [ "$(jq -r .version "$KLON_MARKETU/.claude-plugin/plugin.json")" = 1.8.0 ] || { echo "Klon marketplace nie ma v1.8.0"; exit 1; }
  [ -x "$KLON_MARKETU/skills/roadmapa/scripts/synchronizuj.sh" ] || { echo "Klon marketplace nie ma synchronizuj.sh"; exit 1; }
fi

krok "2. main_dev z pracy lokalnej, hotfixów z origin/main i tej zmiany"
g tag przed-main-dev main
g switch -q -c main_dev
g merge -q --no-ff -m "Scal origin/main do main_dev: wdrożone hotfixy przed przełączeniem gałęzi" origin/main
g merge -q --no-ff -m "Scal $GALAZ_ZMIAN: main_dev jako gałąź pracy, main jako produkcja" "$GALAZ_ZMIAN"
g merge-base --is-ancestor przed-main-dev main_dev
g merge-base --is-ancestor origin/main main_dev

krok "3. Push main_dev (żaden workflow nie ma na nią triggera)"
g push -q -u origin main_dev
[ "$(g ls-remote --heads origin main_dev | cut -f1)" = "$(g rev-parse main_dev)" ] || { echo "origin/main_dev nie zgadza się z lokalnym main_dev"; exit 1; }
echo "origin/main_dev = $(g rev-parse --short main_dev)"

krok "4. Lokalny main wraca na origin/main (praca jest już w origin/main_dev)"
g branch -f main origin/main
echo "main = $(g rev-parse --short main), przed-main-dev = $(g rev-parse --short przed-main-dev)"

if [ -z "$PROBA" ]; then
  krok "5. Gałąź domyślna na GitHubie"
  ( cd "$REPO" && gh repo edit --default-branch main_dev )
  g remote set-head origin -a
  [ "$( cd "$REPO" && gh api repos/:owner/:repo --jq .default_branch )" = main_dev ] || { echo "Domyślna gałąź nie przestawiona"; exit 1; }

  krok "6. Ustawienia kolejki w ~/.zshrc"
  grep -q '^export KOLEJKA_MAIN=' "$HOME/.zshrc" || echo 'export KOLEJKA_MAIN=main_dev' >> "$HOME/.zshrc"
  grep -q '^export KOLEJKA_WYPYCHAJ=' "$HOME/.zshrc" || echo 'export KOLEJKA_WYPYCHAJ=1' >> "$HOME/.zshrc"
  grep -n '^export KOLEJKA_\(MAIN\|WYPYCHAJ\)=' "$HOME/.zshrc"

  krok "7. Sprawdzenie: push main_dev niczego nie uruchomił"
  sleep 20
  ( cd "$REPO" && gh run list --branch main_dev -L 5 )
  echo "(pusta lista powyżej = 0 przebiegów)"
  ( cd "$REPO" && gh run list --workflow deploy.yml -L 1 )
fi

krok "Gotowe. Dalej ręcznie"
echo "source ~/.zshrc && kolejka start     # po release albo przed nim, wg planu"
