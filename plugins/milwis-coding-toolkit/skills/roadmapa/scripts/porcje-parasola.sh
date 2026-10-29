#!/bin/bash
# The portions of an umbrella issue, in the umbrella's order — for `kolejka.sh start --parasol <P>`.
#   porcje-parasola.sh <repo-dir> <P> [<main>] [--plan]
# Reads the `## Porcje` checklist of the umbrella (nowe-issue §6b: `- [ ] #<n> — …`, dependency order) and prints
# one line per portion:
#   <n><TAB><plan>   plan = the first `docs/plans/<name>.md` named in the portion's body that exists on <main>
#                    (a `-design.md` is the design, not the plan); `-` when there is none: that portion goes
#                    through triage, because without a plan the question "does the problem exist on HEAD" is real.
# --plan (kolejka.sh start --parasol <P> --bez-triage): the owner says the umbrella came from a plan, so every open
# portion must name one on <main>. A portion that does not means a class of problems, not a plan series: exit 1 with
# those portions and print nothing, because a portion taken without triage loses its only "before" measurement.
# Exit 1 also when the umbrella has no `## Porcje` section or the section lists no issue.
set -euo pipefail

cd "${1:?repo}"
P="${2:?numer parasola}"
MAIN="${3:-main}"
WYMAGAJ_PLANU=0; [ "${4:-}" = "--plan" ] && WYMAGAJ_PLANU=1

cialo=$(gh issue view "$P" --json body -q .body | tr -d '\r')
porcje=$(awk '/^## /{w = ($0 ~ /^## Porcje[[:space:]]*$/); next} w && /^[-*] \[[ xX]\] #[0-9]+/' <<<"$cialo" \
  | sed -E 's/^[-*] \[[ xX]\] #([0-9]+).*/\1/')
[ -n "$porcje" ] || { echo "parasol #$P: brak sekcji ## Porcje z listą - [ ] #<nr>" >&2; exit 1; }

wynik=""; bez_planu=""
for n in $porcje; do
  plan=-
  for p in $(gh issue view "$n" --json body -q .body | grep -oE 'docs/plans/[A-Za-z0-9._/-]+\.md' \
      | grep -v -- '-design\.md$' || true); do
    if git cat-file -e "$MAIN:$p" 2>/dev/null; then plan="$p"; break; fi
  done
  wynik+="$n"$'\t'"$plan"$'\n'
  if [ "$plan" = - ] && [ "$WYMAGAJ_PLANU" = 1 ] && [ "$(gh issue view "$n" --json state -q .state)" != CLOSED ]; then
    bez_planu+=" #$n"
  fi
done
if [ -n "$bez_planu" ]; then
  echo "parasol #$P: otwarte porcje bez planu na $MAIN:$bez_planu — to nie seria z planu; start bez --bez-triage (triage dla każdej porcji)" >&2
  exit 1
fi
printf '%s' "$wynik"
