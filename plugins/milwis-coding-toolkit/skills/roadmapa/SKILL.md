---
name: roadmapa
description: "Use when GitHub issues must be resolved autonomously one after another, without the owner watching — the issue queue: either an explicit list (`--issues 812,815`) or the bug backlog by priority P0→P3 without end. One lead in tmux handles exactly one issue per session (a fresh general-purpose subagent runs triage + task-lifecycle), merges it into local main with the [roadmapa] marker and closes the issue; a watcher then /clears the lead and starts the next. Never builds new features from the backlog, never pushes. Started by the owner: `scripts/kolejka.sh start`. For one issue with the owner present use task-lifecycle directly."
---

# Roadmapa — the issue queue

> **The source of truth for this skill is `milwis/claude-config`** (`plugins/milwis-coding-toolkit/skills/roadmapa/`).
> A project that vendors a copy into `.claude/skills/` gets it overwritten by its sync — change it upstream.

**Core idea.** Quality degrades before a context window fills, so the work is split by context, not by
time: every issue is solved by a fresh subagent (L2), and the lead that dispatches it lives for exactly
one issue — after it, a watcher types `/clear` and the start prompt again. Everything that must survive
lives outside any context: GitHub labels, `git` merges, a committed ledger, flag files.

`POMIAR` (2026-09-24, scratch repo, Claude Code 2.1.281, auto mode): an interactive session in tmux merged
`--no-ff`, received `/clear` via `tmux send-keys`, did not remember the previous turn, received the
`SessionStart:clear` hook's context, and merged again — no classifier bounce. `NIEZMIERZONE`: a real issue
with L2 over a whole night — the first run on a project is a watched dry run.

## When — and when not

| situation | use |
|---|---|
| one issue, owner at the keyboard, wants to talk it through | `task-lifecycle` directly |
| a chosen set of issues, owner away | `kolejka.sh start --issues 812,815,820` — ends after the last |
| "fix bugs until there are none" | `kolejka.sh start` — backlog P0→P3, waits when empty, never ends by itself |
| new functionality | never autonomously — the owner builds it with `brainstorming` → `writingplans` → `task-lifecycle` |
| several issues in parallel | not supported — see "Removed" below |

## Owner

```bash
kolejka.sh lista [repo]                      # the queue in order (skips and reasons on stderr)
kolejka.sh start [repo] [--issues 812,815]   # lead + watcher in tmux session "kolejka"
tmux attach -t kolejka                       # watch; Ctrl-b n = watcher window, Ctrl-b d = detach
kolejka.sh status [repo]                     # current issue, flags, last ledger rows, unpushed [roadmapa] merges
kolejka.sh stop [repo]                       # finish the current issue, then stop (hard: tmux kill-session -t kolejka)
```
`kolejka.sh` = `scripts/kolejka.sh` of this skill; settings via environment (header of the script).

**Before start:** `tmux`, `jq`, `gh` (logged in); the main tree on `main` with no uncommitted tracked changes
(the lead merges there); **no other lead working in the repo** — two leads in one tree collide on the index
lock and one commit sweeps up the other's uncommitted edit. The machine stays awake (`caffeinate` is built in).

**Afterwards:** `kolejka.sh status`, full suite + the project's CI-parity gate on `main`, push when satisfied.
The push rule treats unpushed `[roadmapa]` merges (`git log origin/main..main --merges --grep '\[roadmapa\]'`)
as "ask before pushing" — the marker is what makes the queue's work distinguishable from the owner's.
Issues the queue could not finish carry `status:odlozone` and the question in a comment.

## Invariants

- **Authorisation.** The start prompt (written by `kolejka.sh start`, typed by the watcher every cycle,
  quoted in ledger row 0) is the owner's instruction to merge locally and close issues. It never covers
  `git push`, deploy, `npm run build`, production, KSeF.
- **Only an interactive session merges.** The lead runs as a normal `claude` in tmux, never `claude --bg`:
  `POMIAR` (waves E and G, 2026-09-08) — `git merge` from a background session bounces off the auto-mode
  classifier; the same merge in an interactive session passed (batch 2.3, 2026-09-15; scratch run 2026-09-24).
- **One writer.** Only the lead merges into `main`, writes to the tracker and commits the ledger. L2 and its
  specialists work on `agent/issue-<nr>` in the queue worktree and never merge, push, close or create issues.
- **One issue at a time**, each branch from the `main` that already contains the previous merge — so no
  two branches ever race for the same base.
- **Bugs only from the backlog.** The picker filters by label; L2's triage is the second filter (`feature.`).
  The error is asymmetric: an idea taken = functionality nobody ordered, built overnight; a fix skipped =
  it waits one cycle. With unclear content, defer.
- **Deferral lives in the issue** — `status:odlozone` plus a comment saying what unblocks it. A deferral
  written only in a plan is one GitHub does not know about; the picker greps `docs/plans`/`docs/runbook`
  for those and the lead labels them.
- **Spin-offs** — defects found outside the issue become new issues (duplicate check first, three label
  axes `modul:*`/`P*`/`typ:*`), never "while we are here" fixes.
- **STOP** — `kolejka.sh stop`, `~/.claude/relay-state/STOP-roadmapa`, or `docs/plans/STOP-roadmapa`
  committed on `main` (read with `git cat-file -e main:…`, so it is visible from any branch or worktree).

The lead's procedure, the L2 brief, the report tokens and the stop conditions → `references/cykl-lidera.md`.
It is the only file the lead reads; the `SessionStart` hook points to it.

## Files

| file | role |
|---|---|
| `references/cykl-lidera.md` | the lead's cycle: preconditions, recovery, pick, L2 brief, dispatch, control, merge, close, ledger |
| `scripts/kolejka.sh` | owner's control: start / stop / status / lista |
| `scripts/watcher.sh` | `/clear` + start prompt after the lead's flag (`rotuj` / `pusto` / `stop`) AND the end of its turn |
| `scripts/wybierz-issue.sh` | the picker: list source or backlog source |
| `scripts/hook-session-start.sh`, `scripts/hook-stop.sh` | hooks of the lead session only (passed with `--settings`) |

State: `<repo>/.claude/tmp/kolejka/` (config, flags, L2 reports, `watcher.log`). Ledger:
`docs/plans/kolejka-ledger.md` (committed, append-only). L2 worktree: `<repo>/.claude/worktrees/kolejka`.

## Measurement discipline (lead, L2, ledger)

- Mark load-bearing sentences `POMIAR` (command or `file:line`) or `WNIOSEK` (conclusion). Before naming a
  measurement as the cause, run the measurement that would disprove it.
- **A number from a subagent's report enters the ledger or an issue only after you re-run its command**;
  otherwise it is written `reported`. The ledger is append-only, so a borrowed number is permanent.
  `POMIAR` (batch 4.8): of three load-bearing numbers a subagent reported, one was false (`0` vs real `2`)
  and one incomplete (3 files vs 5) — under a correct verdict.
- **A `0` is a measurement only after a second pattern or a positive control.** `git grep -E` does not know
  `\s`; `\b` and escaped ERE differ under BSD grep; an unexpanded `$FILES` in zsh returns the same `0` as a
  clean tree. Patterns handed to a subagent are literals (`git grep -nF -f <file>`), not hand-written regexes.
- No `| head` on a grep that produces an anchor — a truncated list reads exactly like a complete one.

## Removed on 2026-09-24 — do not rebuild

Tag `roadmapa-przed-konsolidacja` holds the previous version.

- **Relay chain** (`claude --bg` generations, window thresholds, `hold`, handoff protocol, curator, wave
  numbering, two parallel waves) — a background session cannot merge (above), so every issue ended on a
  branch waiting for the owner; not used since 2026-09-13, rejected by the owner on 2026-09-18. The
  subagent window hooks in `~/.claude/hooks` stay: L2 relies on their own-window message for `partial.`.
- **Orchestrator track, cloud track, `issue-pipeline`** (parallel issues in worktrees) — `POMIAR` (wave G,
  2026-09-08): six branches, each conflict-free against `main` alone, conflicted at the second merge; the
  shared dev database makes parallel DB-touching issues unsafe anyway. Used only in dry runs.
- **Night queue** (one lead for a whole night with a `/loop` heartbeat) — the same engine as this queue but
  with one long-lived, compacting lead; `--issues` replaces it.
