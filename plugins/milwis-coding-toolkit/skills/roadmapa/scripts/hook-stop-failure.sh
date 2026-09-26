#!/bin/bash
# StopFailure hook of the queue lead: an API error ended the turn, so the Stop hook did not fire.
# Marks the end of the turn (tura-koniec) and leaves the error type in blad-api for the watcher:
# `rate_limit` = the subscription limit is used up — the watcher waits for the reset and resumes the same
# issue (w-toku); any other error is a turn without a flag (restart after GRACE_MIN).
# Fire-and-forget: Claude Code ignores this hook's output and exit code.
INPUT=$(cat)
[ -n "$(jq -r '.agent_id // empty' <<<"$INPUT" 2>/dev/null)" ] && exit 0
K="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp/kolejka"
[ -d "$K" ] || exit 0
jq -r '.error // "unknown"' <<<"$INPUT" 2>/dev/null > "$K/blad-api" || echo unknown > "$K/blad-api"
date +%s > "$K/tura-koniec"
exit 0
