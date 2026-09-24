#!/bin/bash
# Picks the next issue for the continuous queue: open, bug-fix type, highest priority (P0 -> P3),
# oldest first within a priority. Prints the issue number, or nothing when the queue is empty.
# Usage: wybierz-issue.sh [repo-dir]        (--lista prints the whole ordered queue instead)
#
# Configuration (environment):
#   KOLEJKA_TYPY     labels that make an issue a bug fix (any one suffices)
#   KOLEJKA_POMIJAJ  labels that exclude an issue even if it is a bug (features, deferred, done, human decision)
set -euo pipefail

LISTA=0
[ "${1:-}" = "--lista" ] && { LISTA=1; shift; }
REPO="${1:-.}"

TYPY="${KOLEJKA_TYPY:-typ:bug,typ:point-fix,typ:structural,bug}"
POMIJAJ="${KOLEJKA_POMIJAJ:-typ:pomysl,enhancement,new_idea,request,typ:analysis,status:odlozone,status:do-scalenia,status:zrobione-lokalnie,tor:remediacja-danych,security-audit-tracker}"

cd "$REPO"
# The queue's own configuration (written by kolejka.sh start) wins over the defaults above.
if [ -f .claude/tmp/kolejka-ciagla/config.env ]; then
  TYPY=$(. .claude/tmp/kolejka-ciagla/config.env; echo "$KOLEJKA_TYPY")
  POMIJAJ=$(. .claude/tmp/kolejka-ciagla/config.env; echo "$KOLEJKA_POMIJAJ")
fi

# An issue with a local agent/issue-<nr> branch was already started by someone (a wave, a crashed run):
# its fate is the owner's decision, not the queue's.
ZACZETE=$(git for-each-ref --format='%(refname:short)' 'refs/heads/agent/issue-*' \
  | sed -E 's#^agent/issue-([0-9]+).*#\1#' | sort -u | jq -R 'tonumber? // empty' | jq -s .)

gh issue list --state open --limit 1000 --json number,title,labels,createdAt \
| jq -r --arg typy "$TYPY" --arg pomijaj "$POMIJAJ" --argjson zaczete "$ZACZETE" --argjson lista "$LISTA" '
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
  | if $lista == 1 then .[] | "P\(.p)\t#\(.number)\t\(.title)" else (.[0].number // empty) end
'
