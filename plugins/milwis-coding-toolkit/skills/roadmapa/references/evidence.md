# roadmapa — evidence behind the session-per-issue cycle

Measurements behind `../SKILL.md` (intro). Not re-checked at run time; re-measure after a Claude Code upgrade that touches tmux sessions, `/exit`, hooks or the auto-mode classifier.

`POMIAR` (2026-09-24, scratch repo, Claude Code 2.1.281, auto mode): an interactive session in tmux merged
`--no-ff`, received `/clear` via `tmux send-keys`, did not remember the previous turn, received the
`SessionStart:clear` hook's context, and merged again — no classifier bounce. `POMIAR` (2026-09-26, KonkretnyTMS,
Claude Code 2.1.283, v1.5.35): two cycles on the watcher — `/exit`, `respawn-pane`, a new pid and a new session
named `kolejka #999 …`, the start prompt answered, the Stop hook fired in both; the default model comes up in
auto mode (haiku does not — it falls back to manual); a lead started by `lider.sh` in a scratch repo ran
`git merge --no-ff agent/test -m '… [roadmapa]'` into `main` — "Allowed by auto mode classifier". 

**v1.7.0 (2026-10-26), the lead implements.** `POMIAR` (scratch repo, `bramka.sh`): six scenarios (nothing written,
tier S on a sensitive path, a commit after the review, CRITICAL open, report PASS against a FAIL verification,
everything in place) gave five refusals with the right reason and one `SCALONO` with the `[roadmapa]` marker; a plain
`REQUIRED` counted on the `Otwarte:` line refuses too. `POMIAR` (`hook-pre-tool.sh`, 14 command strings): `git merge`
and `git push` blocked with `-C`, `-c`, quoted paths and `--no-pager`; `merge-base`, `log --merges`, a commit message
containing "merge", `gh pr merge` and `scal.sh` pass; the lead's Write on a verdict file is blocked, a subagent's is
not. Docs (sub-agents): a subagent gets "the agent's own prompt plus environment details … not the Claude Code system
prompt", so the lead's `--append-system-prompt` does not reach it. `POMIAR` (2026-10-26 17:22, scratch repo, Claude Code 2.1.310,
interactive session in tmux, auto mode, the queue's PreToolUse hook via `--settings`): `scal.sh` ran and printed
`SCALONO e8e8c08` (`[roadmapa] Scal #5`); the same session's raw `git -C <repo> merge --no-ff agent/issue-5` was blocked
by the hook. `NIEZMIERZONE`: the watcher's continuation on a turn that ends with a progress report; the
lead's window over a Large issue. The first run after v1.7 is watched.

**v1.7.1 (2026-10-26), gaps closed after an independent review.** The review measured four bypasses:
- the lead's Bash `printf … > $K/recenzja-N-k.md`;
- a builder's Write on a verdict file;
- `/usr/bin/git merge` and `git pull`;
- `Weryfikacja: n/a` declared by the lead on any diff.

`POMIAR` (`hook-pre-tool.sh`, 29 synthetic inputs): the first three now exit 2. The fourth is refused by
`bramka.sh` when the diff hits a `powierzchnia:` glob of `## Bramka`. The lead's `head`/`grep` of a verdict
file and the reviewer's and verifier's own writes (`agent_type`, bare or plugin-scoped) pass. A subagent without
`agent_type` passes, as before. Docs (hooks, common input fields): `agent_type` is "present when … the hook fires
inside a subagent", e.g. `"Explore"`, plugin agents as `plugin:name`.

The reviewer prompt went back to the full v1.5 checklist (35 KB). v1.6 had cut it to a 6 KB goal, and the owner
reported that the full checklist "wyłapywał dużo błędów". On top of the full checklist:
- the issue is read by the reviewer itself;
- `Rules read:` is a line of the report;
- the security table comes from the former `backend-security-coder`;
- MEDIUM is mapped to REQUIRED, so the gate counts it.
