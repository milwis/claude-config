#!/bin/bash
# PreToolUse hook of the queue, registered only through the --settings file kolejka.sh generates, so it runs in the
# lead and in every subagent of a queue session and nowhere else. Exit 2 blocks the call; stderr is the reason.
# - `git merge`, `git pull` and `git push` as a git subcommand, also through a path to the binary (/usr/bin/git): the
#   merge goes only through scal.sh (bramka.sh first), and the queue never pushes.
# - Verdict files ($K/recenzja-*, $K/weryfikacja-*): the gate reads them as evidence from a fresh context, so only the
#   agent of that role writes them. The lead (no agent_id) is blocked on Write/Edit and on a Bash command that writes,
#   moves or removes one. A subagent whose agent_type is another role is blocked too. A subagent without agent_type
#   (an older Claude Code) is let through, as before.
INPUT=$(cat)
NARZ=$(jq -r '.tool_name // empty' <<<"$INPUT")
AGENT_ID=$(jq -r '.agent_id // empty' <<<"$INPUT")
AGENT_TYPE=$(jq -r '.agent_type // empty' <<<"$INPUT")
WERDYKT='(recenzja|weryfikacja)-'

# The role that may write the verdict file named in $1 (recenzja → code-reviewer, weryfikacja → test-automator);
# plugin agents report a scoped name (`plugin:code-reviewer`).
wolno_pisac() {
  [ -n "$AGENT_ID" ] || return 1
  [ -n "$AGENT_TYPE" ] || return 0
  case "$1" in
    *recenzja-*) [[ "$AGENT_TYPE" == code-reviewer || "$AGENT_TYPE" == *:code-reviewer ]] ;;
    *weryfikacja-*) [[ "$AGENT_TYPE" == test-automator || "$AGENT_TYPE" == *:test-automator ]] ;;
    *) return 0 ;;
  esac
}
odmowa_werdyktu() {
  echo "Kolejka: plik werdyktu pisze świeży recenzent (code-reviewer) albo weryfikator (test-automator), nie lider ani inny agent${AGENT_TYPE:+ ($AGENT_TYPE)}. Brak pliku = podagent nie skończył albo trzeba uruchomić nowego." >&2
  exit 2
}

case "$NARZ" in
Bash)
  CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
  # git (bare or as a path ending in /git), then only global options (-C <dir>, -c <k=v>, --flag[=v]), then the
  # subcommand.
  OPCJE='([[:space:]]+(-[Cc][[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)|--[a-z-]+(=[^[:space:]]+)?))*'
  if grep -qE "(^|[^[:alnum:]_.-])([^[:space:]\"';|&()]*/)?git$OPCJE[[:space:]]+(merge|pull|push)([[:space:]]|\$)" <<<"$CMD"; then
    echo "Kolejka: surowy git merge/pull/push jest zablokowany. Scalanie tylko przez \"\$SKRYPTY/scal.sh\" \"\$K/config.env\" <N> (najpierw bramka.sh); push robi właściciel." >&2
    exit 2
  fi
  # A Bash write to a verdict file: a redirect or tee into it, or a command that copies, moves, edits in place,
  # creates or removes it, or an interpreter whose command line names it. Reading (cat, head, grep) passes.
  if grep -qE "$WERDYKT" <<<"$CMD"; then
    CEL="[^[:space:];|&]*$WERDYKT"
    if grep -qE ">>?[[:space:]]*[\"']?$CEL|tee([[:space:]]+-[a-z]+)*[[:space:]]+[\"']?$CEL|(^|[^[:alnum:]_-])(cp|mv|install|ln|rsync|dd|truncate|touch|rm|unlink)[[:space:]][^;|&]*$WERDYKT|(^|[^[:alnum:]_-])(sed|perl)[[:space:]][^;|&]*-i[^;|&]*$WERDYKT|(^|[^[:alnum:]_-])(python3?|php|node|ruby)[[:space:]][^;|&]*$WERDYKT" <<<"$CMD"; then
      wolno_pisac "$(grep -oE "$WERDYKT" <<<"$CMD" | head -1)" || odmowa_werdyktu
    fi
  fi ;;
Write|Edit|MultiEdit|NotebookEdit)
  PLIK=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$INPUT")
  case "$PLIK" in
    */.claude/tmp/kolejka/recenzja-*|*/.claude/tmp/kolejka/weryfikacja-*)
      wolno_pisac "$PLIK" || odmowa_werdyktu ;;
  esac ;;
esac
exit 0
