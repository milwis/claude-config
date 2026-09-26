#!/bin/bash
# Checks that issues carry the mandatory label axes of the nowe-issue skill.
#   sprawdz-etykiety.sh <nr> [<nr> ...]   the given issues
#   sprawdz-etykiety.sh --otwarte         every open issue (backlog audit)
# Axes: exactly one P0-P3, at least one modul:*, exactly one srodowisko:*, exactly one typ:*;
# the deprecated `request` is reported too. Issues labelled security-audit-tracker are automation, skipped.
# Prints "#<nr>	<missing axes>	<title>" per failing issue; exit 1 when any fails, 0 when all pass.
# Run from inside the repo (gh resolves it from the working directory).
set -euo pipefail

BRAKI='
  [.labels[].name] as $l
  | def ile(f): [$l[] | select(f)] | length;
  [ (ile(test("^P[0-3]$"))             | if . != 1 then "priorytet: \(.) (ma być 1)"   else empty end),
    (ile(startswith("modul:"))         | if . < 1  then "modul: brak"                   else empty end),
    (ile(startswith("srodowisko:"))    | if . != 1 then "srodowisko: \(.) (ma być 1)"  else empty end),
    (ile(startswith("typ:"))           | if . != 1 then "typ: \(.) (ma być 1)"         else empty end),
    ($l[] | select(. == "request") | "request: przestarzała, użyj typ:pomysl") ]'

FILTR="select([.labels[].name] | index(\"security-audit-tracker\") | not)
  | {number, title, b: ($BRAKI)} | select(.b | length > 0)
  | \"#\(.number)\t\(.b | join(\"; \"))\t\(.title)\""

if [ "${1:-}" = "--otwarte" ]; then
  wynik=$(gh issue list --state open --limit 1000 --json number,title,labels | jq -r ".[] | $FILTR")
elif [ $# -gt 0 ]; then
  wynik=""
  for n in "$@"; do
    w=$(gh issue view "$n" --json number,title,labels | jq -r "$FILTR")
    [ -z "$w" ] || wynik+="$w"$'\n'
  done
  wynik=${wynik%$'\n'}
else
  echo "użycie: $0 <nr> [<nr> ...] | --otwarte" >&2; exit 2
fi

if [ -n "$wynik" ]; then
  printf '%s\n' "$wynik"
  echo "BRAKI: $(printf '%s\n' "$wynik" | wc -l | tr -d ' ') issue(s)" >&2
  exit 1
fi
echo "OK: wszystkie osie etykiet obecne" >&2
