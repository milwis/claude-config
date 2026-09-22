# Night queue (`kolejka nocna`) — one lead in the owner's session, one issue subagent at a time

Supplement to `SKILL.md` §4a. The third way to run a roadmap, built for the case "the owner starts it
before leaving and is away for 8–10 hours". It differs from the other two tracks in exactly three
points, and every rule of `SKILL.md` not named here applies unchanged (triage on HEAD, fixes only,
deferral check, ledger format, measurement discipline, stop conditions). Where `SKILL.md` forbids `git merge`
or `gh issue close` (§3 roadmap fields, §4b, §6), this file is the named exception — for the lead only:

| | relay (default) | orchestrator | **night queue** |
|---|---|---|---|
| who runs the batch | a chain of `claude --bg` sessions | one lead + parallel subagents in `isolation: worktree` | **one lead = the owner's own interactive session** |
| subagent depth | 1 (a subagent spawns nobody) | 1 | **2** (issue subagent spawns specialists) |
| end of an issue | branch + `status:do-scalenia` | branch + `status:do-scalenia` | **local `git merge --no-ff` with `[roadmapa]` + `gh issue close`, by the lead only** |

## When — owner's explicit instruction only

The mode is chosen **only** when the owner's own prompt, typed in the session they are sitting at,
names it and authorises merging and closing — e.g. *"/roadmapa kolejka nocna: <issues or 'select from
backlog'>, merge locally and close resolved issues"*. It is never inferred from the task's shape ("many
issues", "I'll be away"), never declared by a curator, and never carried to a `claude --bg` session.
The reason is mechanical: `POMIAR` (wave E, G10; wave G) — `git merge` from a background session bounces off
the auto-mode classifier; `POMIAR` (batch 2.3, 2026-09-15) — the same merge and `gh issue close` passed in
the owner's own session, three issues, zero bounces. Consent lives in the session that received it
(`SKILL.md` §4b "owner-at-keyboard note"); this mode is that note made durable for one batch.

With "select from backlog" the lead picks the issues it will later merge and close — the start prompt must say so explicitly ("select, merge and close"); otherwise the lead writes the roadmap and asks for confirmation while the owner is still present.

**Ledger row 0 quotes the owner's instruction verbatim** — it is the authorisation that must survive
compaction. Its scope is the issues of THIS roadmap plus issues closed at triage as `ALREADY-FIXED` /
`NOT-A-BUG`. It does not cover: `git push`, deploy, `npm run build`, `USE_BUNDLE`, KSeF, production, or
issues created during the night.

## Three levels

- **L1 — lead** (the owner's session). Reads no code, writes no code. Owns: the roadmap and the ledger,
  creating `agent/issue-<nr>` branches, merging into local `main`, `gh issue close` / `create` / labels,
  `PushNotification`. Nothing else writes to `main` or to the tracker.
- **L2 — issue subagent**, exactly ONE alive at a time. Type `general-purpose` (it must hold the `Agent` tool;
  specialist definitions such as `php-pro` do not), explicit `model:` (default `opus` — it decides validity,
  size class and whether review findings are real; the owner may override in the start prompt), `name:
  issue-<nr>`, **spawned in the background** (`run_in_background: true`) so the lead stays free for heartbeat wake-ups. It runs triage → `task-lifecycle` IN FULL on the branch the lead created, and reports.
  It never merges, never pushes, never closes or creates issues, never edits the ledger.
- **L3 — specialists** spawned by L2 per `task-lifecycle` / `writingplans` / `executingplans`
  (`php-pro`, `javascript-pro`, `sql-pro`, `code-reviewer`, `backend-security-coder`, `Explore`, the
  project's doc agent…). **L3 spawns nobody**: L2 never spawns `general-purpose` or another orchestrator,
  and nobody at any level starts `claude --bg`.

`POMIAR` (2026-09-22, transcripts of KonkretnyTMS): 69 of 1,916 subagent transcripts contain their own
`Agent` call — e.g. `orch-740` spawned `php-pro`, `code-reviewer`, `backend-security-coder`. Depth 2 works in
this harness; the depth-1 rule of `SKILL.md` §1a belongs to the relay track, where the risk was a
subagent starting a background session. If `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` is set, it must allow
depth 2 — measure it at pre-flight, never assume.

**Strictly sequential.** One L2 at a time, next issue only after the previous one is merged, deferred or
blocked. This is what makes a merge queue unnecessary: every branch starts from `main` right after the
previous merge, so no two branches ever wait on the same base. `POMIAR` (wave G, 2026-09-08): six branches
conflict-free against `main` one by one conflicted at the second merge — the failure mode of parallel
branches, absent here by construction. Parallel night queues are out of scope for this mode.

## Pre-flight — owner present, before leaving (≈15 min)

1. **Auto mode on, relay hooks measured** (`SKILL.md` first ledger row). Any permission prompt stalls
   the night — the first run of this mode is a dry run on 2 easy issues with the owner watching.
2. **Machine stays awake:** `caffeinate -dimsu` started in the background by the owner (macOS).
3. **Queue worktree from LOCAL `main`**, not `isolation: "worktree"` — that one branches from
   `origin/<default>` and has no `.env` (`references/tor-orkiestratora.md`, measured). The lead creates it
   once: `git worktree add .claude/worktrees/kolejka-<slug> main` (fails if `main` is checked out
   elsewhere — then use that tree only if it is clean, otherwise stop and ask now, while the owner is here),
   then copies `.env` and applies the project's worktree checklist (port, `node_modules`, discriminator).
   The owner's main tree is never touched.
4. **Heartbeat.** The lead waits on L2's completion notification; a hung L2 would leave it waiting all
   night. Run the lead under `/loop` in self-paced mode with a long fallback wake-up (1800 s): on each wake
   the lead re-reads the ledger and checks L2 liveness by the mtime of its transcript and its `subagents/`
   directory (`SKILL.md` §6 "stall" — `status: busy` lies). No change for 60 min → stall handling below.
   `NIEZMIERZONE` (2026-09-22): this heartbeat has not yet run for a full night — the dry run measures it.
5. **Row 0** in the ledger: owner's instruction verbatim, thresholds, worktree path, model per level.

## The lead's loop (per issue)

```bash
WT=<ABS path of .claude/worktrees/kolejka-<slug>>
test -f ~/.claude/relay-state/STOP-roadmapa && echo STOP
git cat-file -e main:docs/plans/STOP-roadmapa 2>/dev/null && echo STOP
git -C "$WT" status --short                     # must be empty — someone else's work is a stop, not a cleanup
git -C "$WT" checkout -b agent/issue-<nr> main
```

Then spawn L2 with the brief below and wait. On its report, read the first line (terminal token of
`task-lifecycle` hard rule 8, plus two queue tokens):

| token | the lead does |
|---|---|
| `done.` | control commands (below) → merge → close → ledger row → next issue |
| `closed-on-head. <ALREADY-FIXED\|NOT-A-BUG>` | re-run the decisive measurement L2 quoted → close with it (`--reason completed` / `--reason "not planned"`); `checkout main`, then delete the empty branch |
| `partial. <what is committed> / <what remains>` | L2 hit its window cap on a Large issue: spawn ONE fresh L2 on the same branch with the plan + remainder; a second `partial.` → defer |
| `ambiguous.` / `needs-confirm.` / `too-big.` / `BLOCKED` | branch stays; `status:odlozone` + comment with the question (`SKILL.md` §4c "Deferral check" block); `PushNotification` one sentence; **next issue** — never wait |
| `regressed.` | same as `BLOCKED`, plus the regression line in the comment |

**Control before merge** — the report is not the evidence, the lead re-measures (`SKILL.md` §7):

```bash
git -C "$WT" log --oneline main..agent/issue-<nr>          # the commits L2 named exist
git -C "$WT" status --short                               # tree clean — nothing left uncommitted
test -e "$WT/<evidence path from the report>" && echo OK || echo MISSING
```

Any control failing (commits absent, tree dirty, evidence `MISSING`) → no merge; the issue is handled as `BLOCKED` with the failed command quoted.

**Merge and close** (only after `done.` and a clean control):

```bash
git -C "$WT" checkout main
git -C "$WT" merge --no-ff -m "[roadmapa] Scal #<nr>: <title>" agent/issue-<nr>
git -C "$WT" rev-parse --short HEAD                        # SHA for the comment and the ledger
mkdir -p "$WT/.claude/tmp" && printf '%s\n' "<comment>" > "$WT/.claude/tmp/issue-<nr>-close.md" \
  && gh issue comment <nr> --body-file "$WT/.claude/tmp/issue-<nr>-close.md" \
  && gh issue close <nr> --reason completed
```

The comment states: merged locally into `main` at `<SHA>`, **not pushed and not deployed**, branch tip,
verification evidence, review iterations. An issue closed without that sentence reads as "in production".

**Merge conflict** cannot arise from the queue itself; if it does (someone committed to `main` during the
night), the lead does not resolve it: it spawns one subagent with `/resolving-merge-conflicts` in `$WT`.
Not resolved → stop the queue (the conflicted tree blocks every later issue) + `PushNotification`.

**Ledger row** (format of `SKILL.md` §3, one row per issue, `faza merge`) is committed with a pathspec in
`$WT` **always on `main`, on every path** — not only after a merge: first `git -C "$WT" checkout main`, then
write and commit the row, then the next `checkout -b`. A row committed on an issue branch is invisible to
`main` and to every later branch; after a compaction the lead would re-run a deferred issue and stall on
`checkout -b` of an existing branch.

## New problems → new issues (spin-offs)

L2 lists defects it found OUTSIDE its issue's scope in a `NOWE PROBLEMY` section: title, `path:line`,
the `POMIAR` that shows it, proposed labels. It does not fix them and does not create issues. The lead:

```bash
gh issue list --state all --search "<2-3 distinctive words>" --json number,title,state   # duplicate?
mkdir -p "$WT/.claude/tmp" && printf '%s\n' "<body: evidence, source issue #<nr>, found by night queue <slug>>" > "$WT/.claude/tmp/spinoff.md" \
  && gh issue create --title "<title>" --body-file "$WT/.claude/tmp/spinoff.md" --label "<modul:*>" --label "<P*>" --label "<typ:*>"
```

A duplicate gets a comment with the new evidence instead of a second issue. **A spin-off is never taken
the same night** — the queue must not feed itself; it enters the next batch through normal triage. A
spin-off that BLOCKS the current issue makes the current issue `BLOCKED`, not a new queue item.

## Brief for L2 (template)

```
You are the issue subagent issue-<nr> of night queue <slug>. Lead: <lead's name or "the top-level session">.
Working tree: <$WT> — every command uses absolute paths under it; branch agent/issue-<nr> is already checked out.
1. Triage on HEAD (issue-pipeline Step 1): VALID / ALREADY-FIXED / NOT-A-BUG / NEEDS-CLARIFICATION, with the
   measurement that decides it. Not VALID → report `closed-on-head. <verdict>` or `ambiguous. ask: <question>` and stop.
2. Run the task-lifecycle skill IN FULL, including every delegation step it prescribes. Size class per its
   Step 0; Large → /writingplans with Pass 2, commit the plan, then /executingplans. Spawn only specialist
   types and Explore — never general-purpose, never `claude --bg`. Every spawn with `name:` and explicit `model:`.
3. Project-local rules: <path to the project's local-adaptations doc>.
4. Forbidden: git merge, git push, gh issue close/create/edit, editing the ledger, npm run build, deploy, KSeF.
5. Before sending ANY report token commit everything on the branch — `git status --short` must be empty, also
   for BLOCKED / ambiguous (a dirty tree stops the whole queue). Near your window cap (hook message) on a
   Large issue: commit, report `partial.` with what remains.
Report via SendMessage to the lead. First line = one terminal token (done. / closed-on-head. / partial. /
ambiguous. / needs-confirm. / too-big. / regressed. / BLOCKED). Then: tip SHA, commits, evidence paths,
review iterations, POMIAR/WNIOSEK labels, and a `NOWE PROBLEMY` section (may be empty). Max 60 lines.
```

## Context of the lead

The lead's window grows by one report per issue (≤ 60 lines) plus its own control commands — it reads no
code and never pulls suite output (`SKILL.md` §4). State survives compaction because it lives in the
ledger: after a compaction the lead's first call is `cat <roadmap> <ledger>`, and it resumes from the last
row. At `RELAY_WARN_ABS` it writes and commits the current row before doing anything else.

## Stop conditions (in addition to `SKILL.md` §6)

- roadmap exhausted → final row "roadmap exhausted", status table, `PushNotification`, stop;
- two consecutive issues `BLOCKED` for the same environmental cause (DB down, server down, auth) — the
  rest will fail the same way;
- unresolved merge conflict; `$WT` dirty at the start of an issue;
- anything requiring push, deploy, production, KSeF.

## Morning — what the owner does

1. `git log origin/main..main --merges --grep '\[roadmapa\]'` — the night's merges; the project's push rule
   treats a non-empty result as "ask before pushing".
2. Full suite + CI-parity gate on the final SHA, then push when satisfied.
3. Issues marked `status:odlozone` tonight carry their question in a comment.
4. `git worktree remove .claude/worktrees/kolejka-<slug>` when done.
