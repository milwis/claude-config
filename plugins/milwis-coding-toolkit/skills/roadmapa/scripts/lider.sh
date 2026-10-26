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
# Verification environment: the project's control CLI (`cli:` under `## CLI` in docs/VERIFICATION_ENV.md)
# runs its doctor with the fix option here, in plain bash, before the session — the same call made by the
# lead would go through the auto-mode classifier, which refused seeding test accounts before (#1046).
# A failing check is not a stop; triage and the lead read $K/doctor.json as the environment state.
CLI=$(awk '/^## CLI/{f=1;next} /^## /{f=0} f&&/^cli: /{sub(/^cli: /,"");print;exit}' "$REPO/docs/VERIFICATION_ENV.md" 2>/dev/null)
if [ -n "$CLI" ] && [ -x "$WT/$CLI" ]; then
  "$WT/$CLI" doctor --root "$WT" --fix > "$K/doctor.json" 2>&1 || true
elif [ -n "$CLI" ] && [ -x "$REPO/$CLI" ]; then
  "$REPO/$CLI" doctor --root "$REPO" --fix > "$K/doctor.json" 2>&1 || true
else
  echo "brak CLI" > "$K/doctor.json"
fi
# The lead implements the issue itself, so its rules must survive a compaction. The appended system prompt reaches
# only this session: a subagent gets its own system prompt (docs: sub-agents, "not the Claude Code system prompt"),
# which the SessionStart:compact hook cannot tell apart (no agent_id in that payload). The second paragraph is the
# docs' standing instruction for unattended Opus 5.5 runs (prompting-claude-opus-5-5, Unattended agentic runs), set
# from the first request as the docs require; merge and push stay blocked by hook-pre-tool.sh.
SYSTEM="Jesteś liderem kolejki roadmapa (sesja główna w tmux): jedno issue na sesję, implementujesz je sam w $WT. Zasady: $INSTRUKCJA. Po kompakcji kontekstu, przed następną akcją, przeczytaj ponownie zasady i $K/stan-<N>.md bieżącego issue.

A standing instruction from the user, the person you are working for. It is about how your turns end. A message with no tool call in it ends your turn, and the work stops there until you are asked to continue. The user has seen you end turns in four ways while work they asked for was still owed, and does not want any of them. One: a long summary of what was done that closes by announcing the next step and has no tool call, so the next thing never starts. Two: an offer to carry on with something unless the user would prefer otherwise, which stops to wait for an answer the user was not going to give. Three: a list of decisions for the user when, by your own account, none of them blocks the rest of the work. Four: deciding that this is a good place to report, because the turn has been long or a milestone is done. Status notes are welcome, and so are your recommendations on open decisions, but put them in the same message as your next tool call and carry on with whatever does not depend on the user's answer. If you notice yourself inviting the user to redirect you or offering to wait, delete it and do the next thing. The stops the user does want are the ones where nothing can move without them, or where the thing blocking you is deliberately protected from you. This does not override the need for confirmation on risky or destructive actions."
# Effort pinned here, first in the resolution order: a per-model effortLevel in the owner's user settings would
# otherwise win (POMIAR 2026-10-26: modelSettings claude-opus-5-5 = xhigh). claude.ai connectors are off: their
# instructions loaded into every queue subagent (POMIAR 2026-10-25, mcp_instructions_delta 8.5 KB) and the queue uses gh.
export ENABLE_CLAUDEAI_MCP_SERVERS=false
exec claude --permission-mode auto ${MODEL_LIDER:+--model "$MODEL_LIDER"} --effort "${EFFORT:-high}" \
  --settings "$K/settings.json" --append-system-prompt "$SYSTEM" \
  -n "$NAZWA" --remote-control "$NAZWA" "$(cat "$K/start-prompt.txt")"
