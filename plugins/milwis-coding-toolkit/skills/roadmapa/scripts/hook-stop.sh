#!/bin/bash
# Stop hook of the queue lead: marks "the lead's turn has ended". The watcher rotates the
# session (/clear + start prompt) only when this marker AND the lead's own flag (rotuj/pusto/stop) exist.
# Subagents end with SubagentStop, not Stop; the agent_id guard is there in case that ever changes.
[ -n "$(jq -r '.agent_id // empty' 2>/dev/null)" ] && exit 0
K="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp/kolejka"
[ -d "$K" ] && date +%s > "$K/tura-koniec"
exit 0
