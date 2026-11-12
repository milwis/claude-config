#!/bin/bash
# PreToolUse hook of a refactor session (L2 of the 2026-11-12 audit, claude-config #27): the measure — the rig's tools,
# mask, scenarios, justifications, mutants and the KARTA — changes only in a portion the supervisor started as
# "zmiana stanowiska". The supervisor registers it in the session's --settings with the portion kind as an argument,
# so the executor cannot switch it (an `export` in its Bash tool never reaches the hook's process):
#   hook-refaktor.sh <kod|zmiana-stanowiska> [<glob> …]   (globs relative to the repo; default below)
# Exit 2 blocks the call, stderr is the reason. Blocked in a `kod` portion: Write/Edit/MultiEdit/NotebookEdit on a
# protected path, and a Bash command that writes one — a redirect, tee or sponge into it, cp/mv/rm/…, sed/perl with
# an in-place flag (-i, -pi, -0pi, --in-place) on it, `git checkout|restore … -- <it>`, any writer after a `cd` into
# it, and inline interpreter code (python -c / heredoc, php -r, node -e, ruby -e, perl -e, sh -c) in a command that
# names it. Running the rig or its checkers (`bash …/stanowisko.sh`, `php …/sprawdz-…php`) passes. The hook is the first line only: the refactor gate compares the hashes in the KARTA on every portion.
INPUT=$(cat)
PORCJA=${1:-}
shift
[ $# -gt 0 ] || set -- 'tests/rownowaznosc/**' '**/KARTA.md'
case "$PORCJA" in
  zmiana-stanowiska) exit 0 ;;
  kod) ;;
  *) echo "Refaktor: hook-refaktor.sh bez rodzaju porcji (kod | zmiana-stanowiska) — nadzorca ustawia go w --settings sesji." >&2; exit 2 ;;
esac
odmowa() {  # shellcheck disable=SC1111
  echo "Refaktor: $1 należy do miary równoważności (maska, scenariusze, uzasadnienia, narzędzia stanowiska, KARTA). W porcji z kodem jej nie zmieniasz: zatrzymaj porcję i zgłoś nadzorcy potrzebę porcji „zmiana stanowiska” (cykl-refaktoru.md, wytyczna 2)." >&2
  exit 2
}
NARZ=$(jq -r '.tool_name // empty' <<<"$INPUT")
case "$NARZ" in
Write|Edit|MultiEdit|NotebookEdit)
  P=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$INPUT")
  for G in "$@"; do
    G2=${G#\*\*/}
    # shellcheck disable=SC2053
    if [[ "$P" == $G || "$P" == */$G || "$P" == */$G2 || "$P" == $G2 ]]; then odmowa "$P"; fi
  done ;;
Bash)
  CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
  # Writers whose target is a relative path, used after a `cd` into the protected directory (redirects to /dev/null,
  # fd duplication and absolute targets such as /tmp/log do not count).
  BEZ=$(sed -E 's/[0-9]*>&[0-9-]+//g; s#[0-9]*>>?[[:space:]]*/dev/null##g' <<<"$CMD")
  PISZE=">>?[[:space:]]*[\"']?[^/[:space:]&\"']|(^|[^[:alnum:]_-])(tee|cp|mv|install|ln|rsync|dd|truncate|touch|rm|unlink|mkdir|patch|sponge)[[:space:]]|(^|[^[:alnum:]_-])(sed|perl)[[:space:]]([^;|&]*[[:space:]])?(-[A-Za-z0-9]*i|--in-place)|git[^;|&]*[[:space:]](checkout|restore|rm|mv|apply|am)[[:space:]]"
  # Inline interpreters: code in the command line or a heredoc can write any file it names.
  INTERP="(^|[^[:alnum:]_-])((python[0-9.]*|node|ruby|perl|deno|bun)[[:space:]]+(-[A-Za-z]*[cep]([[:space:]]|$)|-([[:space:]]|$)|<<)|php[[:space:]]+(-[A-Za-z]*r([[:space:]]|$)|<<)|(ba|z)?sh[[:space:]]+-c[[:space:]])"
  for G in "$@"; do
    # The literal part of the glob, as it appears in a command line: tests/rownowaznosc/, KARTA.md.
    # A directory without its trailing slash, so `rm -rf tests/rownowaznosc` and `cd tests/rownowaznosc` count too.
    F=${G#\*\*/}; F=${F%%\**}; F=${F%/}
    [ -n "$F" ] || continue
    grep -qF -- "$F" <<<"$CMD" || continue
    E=$(sed 's/[][\.*^$/]/\\&/g' <<<"$F")
    CEL="[^[:space:];|&<>]*$E"
    if grep -qE ">>?[[:space:]]*[\"']?$CEL|(tee|sponge)([[:space:]]+-[a-z]+)*[[:space:]]+[\"']?$CEL|(^|[^[:alnum:]_-])(cp|mv|install|ln|rsync|dd|truncate|touch|rm|unlink|mkdir|patch)[[:space:]][^;|&]*$E|(^|[^[:alnum:]_-])(sed|perl)[[:space:]]([^;|&]*[[:space:]])?(-[A-Za-z0-9]*i|--in-place)[^;|&]*$E|git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(checkout|restore|rm|mv|apply|am)[[:space:]][^;|&]*$E" <<<"$CMD" \
      || grep -qE "$INTERP" <<<"$CMD" \
      || { grep -qE "(^|[^[:alnum:]_-])(cd|pushd)[[:space:]]+[\"']?[^;|&[:space:]]*$E" <<<"$CMD" && grep -qE "$PISZE" <<<"$BEZ"; }; then
      odmowa "$F (polecenie: $(cut -c1-120 <<<"$CMD"))"
    fi
  done ;;
esac
exit 0
