#!/bin/bash
# Keeps GitHub current when the queue works on a branch that does not deploy (KOLEJKA_WYPYCHAJ=1, `MAIN` e.g. main_dev,
# while GALAZ_PROD, default main, is the branch whose push runs Tests -> Deploy). Run by the watcher between issues and
# by `kolejka.sh start`, never by the lead: no lead is working then, and the lead's `git push` stays blocked.
#   synchronizuj.sh <config.env> [--tylko-push]
# Default: fetch, merge origin/$GALAZ_PROD (hotfixes) and origin/$MAIN (work from the cloud or the laptop) into the main
# tree, push $MAIN. A push the remote rejected because it moved meanwhile repeats the whole round, up to 3 times.
# --tylko-push: the push alone, for a retry while a lead may be working, or after its stop condition (dirty tree).
# Never pushes GALAZ_PROD and never forces: the refspec is exactly refs/heads/$MAIN on both sides.
# The merges carry --no-ff and the [roadmapa] marker like scal.sh, since nobody reviewed them either.
# Last line and exit code:
#   OK <short SHA> (0) | POMINIETO: <why> (0) | PONOW: <why> (1, retry later) |
#   KONFLIKT: <ref>: <paths> (2, merge aborted, tree unchanged) | ODMOWA: <why> (3, wrong configuration)
# shellcheck disable=SC1090
. "${1:?config.env}"
TRYB="${2:-}"
PROD="${GALAZ_PROD:-main}"
CZAS_S="${KOLEJKA_SYNC_CZAS_S:-120}"
export GIT_TERMINAL_PROMPT=0

koniec() { echo "$2"; exit "$1"; }
# perl alarm = a timeout macOS has without coreutils: a hung network must not hold the watcher's loop.
z_limitem() { ( perl -e 'alarm shift; exec @ARGV' "$CZAS_S" "$@" ) 2>&1; }

[ -n "${WYPYCHAJ:-}" ] || koniec 0 "POMINIETO: wypychanie wyłączone"
[ -n "${MAIN:-}" ] && [ "$MAIN" != "$PROD" ] || koniec 3 "ODMOWA: gałąź kolejki '${MAIN:-}' to gałąź produkcyjna — push uruchomiłby deploy"
[ "$(git -C "$REPO" branch --show-current)" = "$MAIN" ] || koniec 3 "ODMOWA: drzewo główne nie stoi na $MAIN"

# scal_zdalna <ref>: nothing when the remote branch is missing or already contained.
scal_zdalna() {
  local R="refs/remotes/origin/$1" WY KON
  git -C "$REPO" rev-parse --verify -q "$R" >/dev/null || return 0
  git -C "$REPO" merge-base --is-ancestor "$R" "refs/heads/$MAIN" && return 0
  [ -z "$(git -C "$REPO" status --short --untracked-files=no)" ] || koniec 1 "PONOW: origin/$1 ma nowe commity, ale drzewo główne ma zmiany — scalę później"
  # shellcheck disable=SC2015
  WY=$(git -C "$REPO" merge -q --no-ff -m "[roadmapa] Zsynchronizuj $MAIN z origin/$1" "$R" 2>&1) && return 0
  KON=$(git -C "$REPO" diff --name-only --diff-filter=U | tr '\n' ' ')
  git -C "$REPO" merge --abort 2>/dev/null
  # No conflicted paths = git refused before merging (e.g. a skip-worktree file the remote changed): quote its reason.
  koniec 2 "KONFLIKT: origin/$1: ${KON:-$(head -c 300 <<<"$WY" | tr '\n' ' ')}"
}
wypchnij() { z_limitem git -C "$REPO" push -q origin "refs/heads/$MAIN:refs/heads/$MAIN"; }
wynik_ok() { koniec 0 "OK $(git -C "$REPO" rev-parse --short "refs/heads/$MAIN")"; }

if [ "$TRYB" = "--tylko-push" ]; then
  WY=$(wypchnij) && wynik_ok
  koniec 1 "PONOW: push: $(head -c 300 <<<"$WY" | tr '\n' ' ')"
fi

WY=""
for _ in 1 2 3; do
  WY=$(z_limitem git -C "$REPO" fetch -q origin) || koniec 1 "PONOW: fetch: $(head -c 300 <<<"$WY" | tr '\n' ' ')"
  scal_zdalna "$PROD"
  scal_zdalna "$MAIN"
  WY=$(wypchnij) && wynik_ok
  sleep "${KOLEJKA_SYNC_PAUZA_S:-5}"
done
koniec 1 "PONOW: push: $(head -c 300 <<<"$WY" | tr '\n' ' ')"
