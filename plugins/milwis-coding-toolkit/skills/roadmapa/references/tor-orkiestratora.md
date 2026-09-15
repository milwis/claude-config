# Orchestrator track — mechanics

Supplement to `.claude/skills/roadmapa/SKILL.md` §4a. Describes the SECOND execution track: one
long-lived lead session that distributes work to subagents instead of spawning successors. It does not replace
the relay (§1-§7 of the main file, the default track) — it is an exception for batches in which phases are
SHORT and FILE-DISJOINT (selection criterion: §4a of the main file).

## What the lead does

- Reads the roadmap and the ledger at start (like G1/Gn in the relay), afterwards only the ledger — to know
  which phases are unclosed.
- Distributes every unclosed phase as a separate `Agent` call with `isolation: "worktree"` —
  each subagent works on its own copy of the repo, so parallel phases do not collide on the shared
  index (the class of harm the relay's sequentiality defends against in §5/§6a of the main file).
- **Does not read code files (`Read`/`Grep`/`Glob` on implementation content) and edits nothing itself** —
  verifies solely from what the subagent returned in its report (commands, outputs, `file:line`).
  If the report carries no decisive evidence, the lead asks the subagent to clarify instead of
  checking itself.
- Appends the ledger row based on the subagent's report and commits it — this is the only writing
  operation on the SHARED tree the lead performs itself (the roadmap and the ledger live outside the subagents'
  worktrees, so they do not collide with their work).
- Closes the run when `/goal` (below) is met, or stops on the conditions from §6
  of the main file (the same bans: push to `origin`, deploy, `gh issue close`, KSeF).

## What the subagent does

- Gets ONE phase (plan/exec/verify of one issue), works in its own worktree, returns a report
  with evidence. Does not spawn further subagents — the same ban as in the relay (§1a of the main file:
  a subagent does not hand work sideways, does not start a separate background session).
- Commits its work in ITS worktree before returning the report — the lead has no other way
  of recovering it than what the subagent managed to save before the end of its window.

## `/goal` — completion condition

Wording: "every issue in the roadmap has in the ledger a `verify` row with evidence or a
`BLOKADA` (blocked) row with a reason."

The condition must be decidable from the transcript: count the issues in the roadmap, check for each whether
the ledger contains a `verify` row with a `POMIAR` (measurement) section carrying evidence, OR a `BLOKADA` (blocked) row with a described
reason. Missing one of the two for any issue = `/goal` not met — the lead does not declare
the end of the run.

## Ledger rows under this track

The row format (§3 of the main file) **stays unchanged** — no new field for the track. The lead distinguishes
its rows by describing in the `Zrobione` (done) or `Miny` (mines) field that the phase was executed by a subagent in a specific
worktree, in prose — not by modifying the template.

## Supplement, not replacement: `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`

This variable limits the subagent spawn depth regardless of command content — it works where
the `relay-pre.sh` regex (§1a of the main file) does not catch (binary name given via a variable, `bash -c`).
**It does not replace the command blacklist in `relay-pre.sh`** — the blacklist stays, because it protects against a different
class of call (launching a new background session outside the lead's knowledge), and `MAX_SUBAGENT_SPAWN_DEPTH`
does not protect against that class.

## MEASURED in a dry run (Task 7b, 2026-09-05) — one lead, one subagent

Run: the lead (main session) distributed ONE small phase to a subagent with `isolation: "worktree"`,
and itself edited not a single file of the task. The results are `POMIAR`, not `WNIOSEK` — each with a command.

**1. The worktree branches off from `origin/<default branch>`, NOT from the lead's local HEAD.**
`POMIAR`: the lead's tree had 26 local commits above `origin/main` (tip `31efbd677`).
In the subagent's worktree `git log --oneline origin/main..HEAD | wc -l` → `0`, and
`git merge-base --is-ancestor 31efbd677 HEAD; echo $?` → `1`. The `worktree.baseRef` setting does not
appear in any configuration file of this repo, so the default `fresh` applies.

> **CONSEQUENCE — this is the main trap of this track.** The subagent **does not see the lead's unpushed
> work**. A task depending on a commit that existed only locally will be executed by the subagent on stale
> code, returning a report that looks correct. Before assigning a phase via this track, determine whether
> it depends on anything outside `origin/<default branch>` — and if so, pass the subagent the SHA
> and the instruction `git merge <sha>` in its worktree, or do not use this track for that phase.

**2. A worktree with a commit is NOT cleaned up automatically.**
`POMIAR`: `git worktree list | wc -l` → 17 before, **18 after**; the entry `agent-<id>` remained on disk
with branch `worktree-agent-<id>`. During the subagent's work the entry had the `locked` flag; after
completion — it does not. (The tool's documentation says "auto-cleaned **if unchanged**"; the
"changed" case measured here as NOT cleaned. The "unchanged" case remains unmeasured.)

**3. Work returns to the lead WITHOUT a push and without a remote repo.**
`POMIAR`: from the main tree `git log --oneline -1 <sha from worktree>` resolves immediately —
the object database is shared by all worktrees of this repo. The lead recovers the work with an ordinary
`git merge <worktree-branch>` or `git cherry-pick <sha>` on its side; **no fetch and no remote is
needed**. The branch and directory names are assigned by the harness (`agent-<id>` / `worktree-agent-<id>`),
the lead does not choose them — the subagent MUST return them in its report, otherwise the lead does not know what to merge.
**That merge goes into the lead's `agent/issue-<nr>` branch, never into `main`** — the ban from §4b of SKILL.md
applies under this track without exception.

**4. Isolation is real:** a file changed by the subagent remained untouched in the lead's tree
(`git status --short <file>` at the lead → empty after the subagent finished).

**5. `isolation: "worktree"` forces background (async) mode.** `POMIAR`: the call returned an `agentId`
and a message about background work instead of a synchronous report. The lead gets the result via notification.

**6. There is NO `.env` file in the worktree.** `POMIAR`: `test -f .env` → `NO`. Every run of tests
that depend on the environment will yield SKIP there instead of a result — i.e. a **false baseline**. A phase whose
acceptance criterion is "tests green" is unsuitable for this track without first delivering
`.env` to the worktree.

## UNMEASURED — still open

- **`/goal` is not available in this environment.** `POMIAR`: absent in `~/.claude/commands/`, absent
  in `.claude/commands/`, absent from the skills list. If it exists as a built-in CLI command, it is not
  detectable from the file system. **Until this is resolved, the completion condition
  from the section above is enforced by the lead manually** — it reads the ledger and checks itself whether every issue has a `verify` row
  with evidence or a `BLOKADA` (blocked) row with a reason. Do not pretend a mechanism does that for you.
- Whether two subagents accidentally directed at THE SAME phase really do not collide, or whether the collision
  shifts to merging into the lead's tree. The dry run had **one** subagent — this point
  was not touched.
- Behaviour with a worktree WITHOUT changes (whether it then really disappears on its own).
