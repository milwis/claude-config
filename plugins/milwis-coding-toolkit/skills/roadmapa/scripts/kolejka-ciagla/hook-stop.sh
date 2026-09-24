#!/bin/bash
# Stop hook of the continuous-queue lead: marks "the lead's turn has ended". The watcher rotates the
# session (/clear + start prompt) only when this marker AND the lead's own flag (rotuj/pusto/stop) exist.
K="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp/kolejka-ciagla"
[ -d "$K" ] && date +%s > "$K/tura-koniec"
exit 0
