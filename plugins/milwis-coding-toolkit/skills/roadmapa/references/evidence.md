# roadmapa — evidence behind the session-per-issue cycle

Measurements behind `../SKILL.md` (intro). Not re-checked at run time; re-measure after a Claude Code upgrade that touches tmux sessions, `/exit`, hooks or the auto-mode classifier.

`POMIAR` (2026-09-24, scratch repo, Claude Code 2.1.281, auto mode): an interactive session in tmux merged
`--no-ff`, received `/clear` via `tmux send-keys`, did not remember the previous turn, received the
`SessionStart:clear` hook's context, and merged again — no classifier bounce. `POMIAR` (2026-09-26, KonkretnyTMS,
Claude Code 2.1.283, v1.5.35): two cycles on the watcher — `/exit`, `respawn-pane`, a new pid and a new session
named `kolejka #999 …`, the start prompt answered, the Stop hook fired in both; the default model comes up in
auto mode (haiku does not — it falls back to manual); a lead started by `lider.sh` in a scratch repo ran
`git merge --no-ff agent/test -m '… [roadmapa]'` into `main` — "Allowed by auto mode classifier". `NIEZMIERZONE`: a real issue
with L2 over a whole night — the first run on a project is a watched dry run.
