#!/bin/bash
# Picks the next issue for the queue. Prints its number, or nothing when the queue is empty.
#   wybierz-issue.sh [repo-dir]           next issue
#   wybierz-issue.sh --lista [repo-dir]   the whole queue in the order it will be taken
#
# Two sources, set in the queue's config.env (written by kolejka.sh start):
#   KOLEJKA_LISTA set    — the owner's explicit list, in the owner's order. No type filter (the owner chose);
#                          skipped only when closed or carrying a done/deferred status label.
#   KOLEJKA_LISTA empty  — the bug backlog: open, one of KOLEJKA_TYPY, none of KOLEJKA_POMIJAJ, a priority
#                          label, P0 -> P3, oldest first; skips issues with a local agent/issue-<nr> branch
#                          and issues whose deferral is written in the repo (KOLEJKA_ODROCZENIA dirs).
# Skip reasons go to stderr as "pominięto #<nr>: <reason>" — the lead labels those (see cykl-lidera.md).
set -euo pipefail

LISTA_TRYB=0
[ "${1:-}" = "--lista" ] && { LISTA_TRYB=1; shift; }
cd "${1:-.}"

KOLEJKA_LISTA=""
KOLEJKA_TYPY="typ:bug,typ:point-fix,typ:structural,bug"
KOLEJKA_POMIJAJ="typ:pomysl,enhancement,new_idea,request,typ:analysis,status:odlozone,status:do-scalenia,status:zrobione-lokalnie,tor:remediacja-danych,security-audit-tracker"
KOLEJKA_ODROCZENIA="docs/plans docs/runbook"
# shellcheck disable=SC1091
[ -f .claude/tmp/kolejka/config.env ] && . .claude/tmp/kolejka/config.env
STATUSY_KONCA="status:odlozone,status:do-scalenia,status:zrobione-lokalnie"

wypisz() { if [ "$LISTA_TRYB" = 1 ]; then echo "$1"; else echo "$1" | cut -f2 | tr -d '#'; exit 0; fi; }

# ---- source 1: the owner's explicit list --------------------------------------------------------
if [ -n "$KOLEJKA_LISTA" ]; then
  for n in ${KOLEJKA_LISTA//,/ }; do
    info=$(gh issue view "$n" --json state,title,labels \
      -q '[.state, ([.labels[].name] | join(",")), .title] | @tsv')
    stan=$(cut -f1 <<<"$info"); etykiety=$(cut -f2 <<<"$info"); tytul=$(cut -f3 <<<"$info")
    [ "$stan" = "OPEN" ] || continue
    zly=$(tr ',' '\n' <<<"$etykiety" | grep -xF -f <(tr ',' '\n' <<<"$STATUSY_KONCA") | head -1 || true)
    [ -z "$zly" ] || { echo "pominięto #$n: $zly" >&2; continue; }
    wypisz "lista	#$n	$tytul"
  done
  exit 0
fi

# ---- source 2: the bug backlog by priority ------------------------------------------------------
# A local agent/issue-<nr> branch means someone already started it (a wave, a crashed run) — the owner decides.
ZACZETE=$(git for-each-ref --format='%(refname:short)' 'refs/heads/agent/issue-*' \
  | sed -E 's#^agent/issue-([0-9]+).*#\1#' | sort -u | jq -R 'tonumber? // empty' | jq -s .)

# A deferral written in the repo (plans, runbooks) before the status:odlozone label existed. Same line as
# the issue number, in prose: ledgers and table rows are excluded — a progress-table row names several
# issues and a deferral of any one of them would match all (measured on KonkretnyTMS, 2026-09-24).
odroczenie() {
  local dirs=() d
  for d in $KOLEJKA_ODROCZENIA; do [ -d "$d" ] && dirs+=("$d"); done
  [ ${#dirs[@]} -gt 0 ] || return 1
  grep -rnE "#$1([^0-9]|$)" "${dirs[@]}" --include='*.md' 2>/dev/null | grep -v -- '-ledger\.md:' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*\|' \
    | grep -iE 'świadomie wyłączon|odłożon|odroczon|wstrzyman|okno obserwacji|decyzj[ai] właściciela' \
    | head -1 | cut -d: -f1,2
}

gh issue list --state open --limit 1000 --json number,title,labels,createdAt \
| jq -r --arg typy "$KOLEJKA_TYPY" --arg pomijaj "$KOLEJKA_POMIJAJ" --argjson zaczete "$ZACZETE" '
  ($typy | split(",")) as $T | ($pomijaj | split(",")) as $X |
  {"P0":0,"P1":1,"P2":2,"P3":3,
   "priorytet:krytyczny":0,"priorytet:wysoki":1,"priorytet:sredni":2,"priorytet:niski":3} as $PRIO |
  map({number, title, createdAt, l: [.labels[].name]})
  | map(. + {p: ([.l[] | $PRIO[.] // empty] | min)})
  | map(select(.p != null))
  | map(select(any(.l[]; . as $x | $T | index($x))))
  | map(select(all(.l[]; . as $x | $X | index($x) | not)))
  | map(select(.number as $n | $zaczete | index($n) | not))
  | sort_by(.p, .createdAt)
  | .[] | "P\(.p)\t#\(.number)\t\(.title)"
' | while IFS= read -r wiersz; do
  n=$(cut -f2 <<<"$wiersz" | tr -d '#')
  if gdzie=$(odroczenie "$n") && [ -n "$gdzie" ]; then
    echo "pominięto #$n: odroczenie w $gdzie" >&2
    continue
  fi
  wypisz "$wiersz"
done
