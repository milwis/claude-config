#!/bin/bash
# Paths frozen by a file refactor (L18 of the 2026-11-12 audit, claude-config #27): the queue neither takes nor merges
# work on them while the refactor runs. Cards are listed in docs/VERIFICATION_ENV.md, section `## Bramka`, as
# `refaktor-karta: <glob>` (e.g. docs/refaktor/*/KARTA.md); a card with `status: aktywny` freezes every `zamrozone:` glob
# of its own `## Bramka`. Read from the repo's working tree.
#   zamrozone.sh <repo-dir>   → one line per glob: <card path> TAB <file under refactor> TAB <glob>
REPO=${1:-.}
SEKCJA=$(awk '/^## Bramka/{f=1;next} /^## /{f=0} f' "$REPO/docs/VERIFICATION_ENV.md" 2>/dev/null)
shopt -s nullglob globstar
while IFS= read -r G; do
  [ -n "$G" ] || continue
  for KARTA in "$REPO"/$G; do
    B=$(awk '/^## Bramka/{f=1;next} /^## /{f=0} f' "$KARTA")
    [ "$(sed -n 's/^status: *//p' <<<"$B" | head -1 | tr -d '[:space:]')" = aktywny ] || continue
    P=$(sed -n 's/^plik: *//p' <<<"$B" | head -1)
    sed -n 's/^zamrozone: *//p' <<<"$B" | sed -E 's/[[:space:]]+$//' | while IFS= read -r Z; do
      [ -n "$Z" ] && printf '%s\t%s\t%s\n' "${KARTA#"$REPO"/}" "$P" "$Z"
    done
  done
done < <(sed -n 's/^refaktor-karta: *//p' <<<"$SEKCJA")
