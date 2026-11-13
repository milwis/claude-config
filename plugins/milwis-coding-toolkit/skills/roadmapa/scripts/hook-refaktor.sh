#!/bin/bash
# PreToolUse hook of a refactor session (L2 of the 2026-11-12 audit, claude-config #27): the measure — the rig's tools,
# mask, scenarios, justifications, mutants and the KARTA — changes only in a portion the supervisor started as
# "zmiana stanowiska". The supervisor registers it in the session's --settings with the portion kind as an argument,
# so the executor cannot switch it (an `export` in its Bash tool never reaches the hook's process):
#   hook-refaktor.sh <kod|zmiana-stanowiska> [--nadzor=<glob> …] [<glob> …]   (globs relative to the repo; defaults below)
# --nadzor: the supervisor's directory of the KARTA (`nadzor:`; gate log and reviews, #58 F10), closed in BOTH portion
# kinds; default `.claude/tmp/refaktor/**`, the gate's default. The hook goes only into the executor's --settings: the
# supervisor's session (which saves the reviews there) and the gate (which writes the log) never run under it.
# Exit 2 blocks the call, stderr is the reason. Blocked in a `kod` portion: Write/Edit/MultiEdit/NotebookEdit on a
# protected path, and a Bash command that writes one — a redirect, tee or sponge into it, cp/mv/rm/…, sed/perl with
# an in-place flag (-i, -pi, -0pi, --in-place) on it, `git checkout|restore … -- <it>`, any writer after a `cd` into
# it, and inline interpreter code (python -c / heredoc, php -r, node -e, ruby -e, perl -e, sh -c) in a command that
# names it. Since #58 (F17) also: a writer after `cd`/`pushd`/`git -C` into a parent with the rest of the path in the
# command (`cd tests && sed -i … rownowaznosc/x`), a path built from a variable assigned in the same command
# (`D=tests/rownowaznosc; sed -i … $D/x`), `find … -exec|-execdir|-ok <writer>` / `find … -delete` and `… | xargs
# <writer>` on it, and `git -C <it> checkout|restore|…`. Running the rig or its checkers (`bash …/stanowisko.sh`,
# `php …/sprawdz-…php`) passes. The hook is the first line only: the refactor gate compares the hashes in the KARTA on every portion.
# After review r1 of #58: the supervisor's directory is checked by real path in hook-nadzor.py (cwd from the hook's JSON;
# relative paths from a worktree, links, scripts — see its header); the literal globs below remain for the measure and,
# without a git root at cwd, for the supervisor's directory. A writer in a parent counts only when its target holds the
# rest of the path; find -exec / xargs only with a writer as the command. Since the supervisor's review of 780f4f7 the
# supervisor's directory check is fail-closed (hook-nadzor.py). The hook is a guard against accidents, not a security
# boundary: the hard boundary is the executor's sandbox (claude-config #66), required before the first autonomous refactor.
INPUT=$(cat)
PORCJA=${1:-}
shift
NADZOR=()
while [ $# -gt 0 ]; do case "$1" in --nadzor=*) NADZOR+=("${1#*=}"); shift ;; *) break ;; esac; done
[ ${#NADZOR[@]} -gt 0 ] || NADZOR=('.claude/tmp/refaktor/**')
[ $# -gt 0 ] || set -- 'tests/rownowaznosc/**' '**/KARTA.md'
case "$PORCJA" in
  zmiana-stanowiska) set -- ;;   # the measure is open; the supervisor's directory is not
  kod) ;;
  *) echo "Refaktor: hook-refaktor.sh bez rodzaju porcji (kod | zmiana-stanowiska) — nadzorca ustawia go w --settings sesji." >&2; exit 2 ;;
esac
odmowa() {  # shellcheck disable=SC1111
  echo "Refaktor: $1 należy do miary równoważności (maska, scenariusze, uzasadnienia, narzędzia stanowiska, KARTA). W porcji z kodem jej nie zmieniasz: zatrzymaj porcję i zgłoś nadzorcy potrzebę porcji „zmiana stanowiska” (cykl-refaktoru.md, wytyczna 2)." >&2
  exit 2
}
odmowa_nadzor() {
  echo "Refaktor: $1 to katalog nadzorcy (dziennik bramki i recenzje, KARTA nadzor:). Sesja porcji go nie zapisuje w żadnym rodzaju porcji; recenzję zapisuje tam nadzorca (cykl-refaktoru.md, krok 4–5)." >&2
  exit 2
}
NARZ=$(jq -r '.tool_name // empty' <<<"$INPUT")
# The supervisor's directory by real path (hook-nadzor.py, r1 F1): relative paths from a worktree, links, `cd` into a
# parent, scripts. Without a resolvable root (no git at cwd) or if python fails, its globs go to the literal checks below.
WYNIK=$(NADZOR_GLOBY=$(printf '%s\n' "${NADZOR[@]}") python3 -I "$(dirname "$0")/hook-nadzor.py" <<<"$INPUT" 2>/dev/null) || WYNIK=""
WERDYKT=$(head -1 <<<"$WYNIK")
case "$WERDYKT" in
  BLOK*) odmowa_nadzor "${WERDYKT#BLOK?}" ;;
  OK) NADZOR_LIT=() ;;
  *) NADZOR_LIT=("${NADZOR[@]}") ;;
esac
case "$NARZ" in
Write|Edit|MultiEdit|NotebookEdit)
  P=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$INPUT")
  trafia() { local G=$1 G2=${1#\*\*/}
    # shellcheck disable=SC2053
    [[ "$P" == $G || "$P" == */$G || "$P" == */$G2 || "$P" == $G2 ]]; }
  for G in "${NADZOR_LIT[@]}"; do trafia "$G" && odmowa_nadzor "$P"; done
  for G in "$@"; do trafia "$G" && odmowa "$P"; done ;;
Bash)
  CMD0=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
  # Variables assigned in the command itself (`D=…; … $D/x`, `export D=…`) are expanded by hook-nadzor.py (on stdin, so a
  # command over ARG_MAX is checked too — r1 F7); without its output the raw command is checked.
  CMD=$(tail -n +2 <<<"$WYNIK")
  [ -n "$WYNIK" ] || CMD=$CMD0
  # Writers whose target is a relative path, used after a `cd` into the protected directory (redirects to /dev/null,
  # fd duplication and absolute targets such as /tmp/log do not count).
  BEZ=$(sed -E 's/[0-9]*>&[0-9-]+//g; s#[0-9]*>>?[[:space:]]*/dev/null##g' <<<"$CMD")
  PISZE=">>?[[:space:]]*[\"']?[^/[:space:]&\"']|(^|[^[:alnum:]_-])(tee|cp|mv|install|ln|rsync|dd|truncate|touch|rm|unlink|mkdir|patch|sponge)([[:space:]]|$)|(^|[^[:alnum:]_-])(sed|perl)[[:space:]]([^;|&]*[[:space:]])?(-[A-Za-z0-9]*i|--in-place)|git[^;|&]*[[:space:]](checkout|restore|rm|mv|apply|am)[[:space:]]|(^|[[:space:]])-delete([[:space:];&|)]|\$)"
  # A writer at a command position (after xargs, find -exec).
  WR="((tee|cp|mv|install|ln|rsync|dd|truncate|touch|rm|unlink|mkdir|patch|sponge)([[:space:]]|\$)|(sed|perl)[[:space:]]([^;|&]*[[:space:]])?(-[A-Za-z0-9]*i|--in-place))"
  # Inline interpreters: code in the command line or a heredoc can write any file it names.
  INTERP="(^|[^[:alnum:]_-])((python[0-9.]*|node|ruby|perl|deno|bun)[[:space:]]+(-[A-Za-z]*[cep]([[:space:]]|$)|-([[:space:]]|$)|<<)|php[[:space:]]+(-[A-Za-z]*r([[:space:]]|$)|<<)|(ba|z)?sh[[:space:]]+-c[[:space:]])"
  # Directories the command works in: `cd X`, `pushd X`, `git [-c k=v] -C X`.
  KONTEKSTY=$(grep -oE "(^|[^[:alnum:]_-])(cd|pushd)[[:space:]]+[\"']?[^;|&[:space:]\"']+|git([[:space:]]+(-c[[:space:]]+[^[:space:]]+|-[^Cc[:space:]][^[:space:]]*))*[[:space:]]+-C[[:space:]]+[\"']?[^;|&[:space:]\"']+" <<<"$CMD" \
    | sed -E "s/.*[[:space:]][\"']?//; s#/+\$##; s#^\./##")
  pisze_do() {  # $1 a literal path piece: does a writer in the command target a path with it (r1 F9)?
    local E GR CEL
    E=$(sed 's/[][\.*^$/+?(){}|]/\\&/g' <<<"$1"); GR="(\$|[/[:space:]\"';|&)<>])"
    CEL="[^[:space:];|&<>]*$E$GR"
    grep -qE ">>?[[:space:]]*[\"']?$CEL|(tee|sponge)([[:space:]]+-[a-z]+)*[[:space:]]+[\"']?$CEL|(^|[^[:alnum:]_-])(cp|mv|install|ln|rsync|dd|truncate|touch|rm|unlink|mkdir|patch)[[:space:]][^;|&]*$E$GR|(^|[^[:alnum:]_-])(sed|perl)[[:space:]]([^;|&]*[[:space:]])?(-[A-Za-z0-9]*i|--in-place)[^;|&]*$E$GR|git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(checkout|restore|rm|mv|apply|am)[[:space:]][^;|&]*$E$GR|(^|[^[:alnum:]_-])find[[:space:]][^;|&]*$E$GR[^|&]*((^|[[:space:]])-delete([[:space:];&|)]|\$)|-(exec|execdir|ok|okdir)[[:space:]]+$WR)" <<<"$CMD" \
      || { grep -qE "$E$GR" <<<"$CMD" && grep -qE "$INTERP" <<<"$CMD"; } \
      || { grep -qE "$E$GR" <<<"$CMD" && grep -qE "\|[[:space:]]*(xargs|parallel)([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+$WR" <<<"$CMD"; }
  }
  sprawdz() {  # $1 glob, $2 refusal function
    local G=$1 F X P REST
    # The literal part of the glob, as it appears in a command line: tests/rownowaznosc/, KARTA.md.
    # A directory without its trailing slash, so `rm -rf tests/rownowaznosc` and `cd tests/rownowaznosc` count too.
    F=${G#\*\*/}; F=${F%%\**}; F=${F%/}
    [ -n "$F" ] || return 0
    # Inside the protected path (`cd tests/rownowaznosc && sed -i … x`): any writer with a relative target.
    # In a parent of it with the rest of the path in the command (`cd tests && sed -i … rownowaznosc/x`,
    # `git -C tests checkout main -- rownowaznosc`): a writer whose target holds the rest.
    while IFS= read -r X; do
      [ -n "$X" ] || continue
      if [[ "$X" == *"$F"* ]] && grep -qE "$PISZE" <<<"$BEZ"; then "$2" "$F (polecenie: $(cut -c1-120 <<<"$CMD0"))"; fi
      P=$F
      while [[ "$P" == */* ]]; do
        P=${P%/*}; REST=${F#"$P"/}
        if { [ "$X" = "$P" ] || [[ "$X" == */"$P" ]]; } && pisze_do "$REST"; then
          "$2" "$F (polecenie: $(cut -c1-120 <<<"$CMD0"))"
        fi
      done
    done <<<"$KONTEKSTY"
    grep -qF -- "$F" <<<"$CMD" || return 0
    pisze_do "$F" && "$2" "$F (polecenie: $(cut -c1-120 <<<"$CMD0"))"
    return 0
  }
  for G in "${NADZOR_LIT[@]}"; do sprawdz "$G" odmowa_nadzor; done
  for G in "$@"; do sprawdz "$G" odmowa; done ;;
esac
exit 0
