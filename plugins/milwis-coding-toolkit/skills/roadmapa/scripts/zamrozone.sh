#!/bin/bash
# Paths frozen by a file refactor (L18 of the 2026-11-12 audit, claude-config #27): the queue neither takes nor merges
# work on them while the refactor runs. Cards are listed in docs/VERIFICATION_ENV.md, section `## Bramka`, as
# `refaktor-karta: <glob>` (e.g. docs/refaktor/*/KARTA.md); a card with `status: aktywny` freezes every `zamrozone:` glob
# of its own `## Bramka`, and its own path. Read from a commit, not the working tree: the queue's base branch (`$MAIN`)
# is where the supervisor commits the card when the refactor starts; a card that exists only on another branch
# freezes nothing (cykl-refaktoru.md §The KARTA).
#   zamrozone.sh <repo-dir> [ref, default HEAD]   → one line per glob: <card path> TAB <file under refactor> TAB <glob>
REPO=${1:-.}
REF=${2:-HEAD}
G() { git -c core.quotePath=false -C "$REPO" "$@"; }
G rev-parse --verify -q "$REF^{commit}" >/dev/null || exit 0
sekcja() { awk '/^## Bramka/{f=1;next} /^## /{f=0} f'; }
SEKCJA=$(G show "$REF:docs/VERIFICATION_ENV.md" 2>/dev/null | sekcja)
PLIKI=$(G ls-tree -r --name-only "$REF")
while IFS= read -r WZ; do
  [ -n "$WZ" ] || continue
  while IFS= read -r KARTA; do
    [ -n "$KARTA" ] || continue
    # shellcheck disable=SC2053
    [[ "$KARTA" == $WZ ]] || continue
    B=$(G show "$REF:$KARTA" | sekcja)
    [ "$(sed -n 's/^status: *//p' <<<"$B" | head -1 | tr -d '[:space:]')" = aktywny ] || continue
    P=$(sed -n 's/^plik: *//p' <<<"$B" | head -1 | sed -E 's/[[:space:]]+$//')
    { echo "$KARTA"; sed -n 's/^zamrozone: *//p' <<<"$B" | sed -E 's/[[:space:]]+$//'; } | while IFS= read -r Z; do
      [ -n "$Z" ] && printf '%s\t%s\t%s\n' "$KARTA" "$P" "$Z"
    done
  done <<<"$PLIKI"
done < <(sed -n 's/^refaktor-karta: *//p' <<<"$SEKCJA" | sed -E 's/[[:space:]]+$//')
