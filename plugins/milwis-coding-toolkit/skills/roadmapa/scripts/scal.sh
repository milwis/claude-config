#!/bin/bash
# The only way the queue merges into main: bramka.sh, then `merge --no-ff` with the [roadmapa] marker the owner's
# push rule looks for. A raw `git merge` in a queue session is blocked by hook-pre-tool.sh.
#   scal.sh <config.env> <N>
# Last line: `SCALONO <short SHA>` (exit 0), `BRAMKA` (exit 1, the gate's lines above it) or
# `KONFLIKT: <paths>` (exit 2, merge aborted, main unchanged).
# shellcheck disable=SC1090
. "$1"
N="${2:?numer issue}"
"$SKRYPTY/bramka.sh" "$1" "$N" || { echo BRAMKA; exit 1; }
[ "$(git -C "$REPO" branch --show-current)" = "$MAIN" ] || { echo "drzewo główne nie stoi na $MAIN"; echo BRAMKA; exit 1; }
[ -z "$(git -C "$REPO" status --short --untracked-files=no)" ] || { echo "drzewo główne ma zmiany"; echo BRAMKA; exit 1; }
TYTUL=$(gh issue view "$N" --json title -q .title 2>/dev/null || echo "issue #$N")
git -C "$WT" checkout -q --detach "$MAIN"
if git -C "$REPO" merge -q --no-ff -m "[roadmapa] Scal #$N: $TYTUL" "agent/issue-$N" >/dev/null 2>&1; then
  echo "SCALONO $(git -C "$REPO" rev-parse --short HEAD)"
else
  KON=$(git -C "$REPO" diff --name-only --diff-filter=U | tr '\n' ' ')
  git -C "$REPO" merge --abort 2>/dev/null
  echo "KONFLIKT: ${KON:-?}"
  exit 2
fi
