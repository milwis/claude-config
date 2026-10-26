#!/bin/bash
# PreToolUse hook of the queue, registered only through the --settings file kolejka.sh generates, so it runs in the
# lead and in every subagent of a queue session and nowhere else. Exit 2 blocks the call; stderr is the reason.
# - `git merge` and `git push` as a git subcommand: the merge goes only through scal.sh (bramka.sh first), and the
#   queue never pushes.
# - Write/Edit by the lead (no agent_id) on the reviewer's and verifier's verdict files: the gate reads them as
#   evidence from a fresh context, so the session whose work they judge does not write them.
INPUT=$(cat)
NARZ=$(jq -r '.tool_name // empty' <<<"$INPUT")
case "$NARZ" in
Bash)
  CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
  # git, then only global options (-C <dir>, -c <k=v>, --flag[=v]), then the subcommand.
  OPCJE='([[:space:]]+(-[Cc][[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)|--[a-z-]+(=[^[:space:]]+)?))*'
  if grep -qE "(^|[^[:alnum:]_./-])git$OPCJE[[:space:]]+(merge|push)([[:space:]]|\$)" <<<"$CMD"; then
    echo "Kolejka: surowy git merge/push jest zablokowany. Scalanie tylko przez \"\$SKRYPTY/scal.sh\" \"\$K/config.env\" <N> (najpierw bramka.sh); push robi właściciel." >&2
    exit 2
  fi ;;
Write|Edit|MultiEdit|NotebookEdit)
  [ -n "$(jq -r '.agent_id // empty' <<<"$INPUT")" ] && exit 0
  PLIK=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$INPUT")
  case "$PLIK" in
    */.claude/tmp/kolejka/recenzja-*|*/.claude/tmp/kolejka/weryfikacja-*)
      echo "Kolejka: plik werdyktu pisze świeży recenzent albo weryfikator, nie lider. Brak pliku = podagent nie skończył albo trzeba go uruchomić ponownie." >&2
      exit 2 ;;
  esac ;;
esac
exit 0
