#!/bin/bash
# One queue lead = one claude process = one issue. Run in the lead's tmux pane by kolejka.sh start and
# by the watcher (respawn-pane) for every next issue, so each issue is its own session — named after the
# issue in /resume and in Remote Control on the owner's phone. The start prompt goes in as the first
# message of the interactive session, never through `claude -p` (a background session's `git merge` bounces
# off the auto-mode classifier; an interactive one passes).
#   lider.sh <config.env>
# shellcheck disable=SC1090
. "$1"
# The issue this session will most likely take: the one left in progress, else the picker's next.
NR=$(cat "$K/w-toku" 2>/dev/null || "$SKRYPTY/wybierz-issue.sh" "$REPO" 2>/dev/null || true)
NAZWA="kolejka #${NR:-?} $(date '+%m-%d %H:%M')"
exec claude --permission-mode auto ${MODEL_LIDER:+--model "$MODEL_LIDER"} --settings "$K/settings.json" \
  -n "$NAZWA" --remote-control "$NAZWA" "$(cat "$K/start-prompt.txt")"
