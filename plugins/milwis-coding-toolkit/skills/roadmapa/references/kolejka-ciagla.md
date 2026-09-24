# Continuous queue (`kolejka ciągła`) — one issue per lead session, `/clear` between issues

A variant of the night queue (`references/kolejka-nocna.md`) that runs without an end: bugs are taken by
priority P0 → P3 until the tracker has none, then the queue waits and looks again. It keeps the night
queue's levels (L1 lead / L2 issue subagent / L3 specialists), its report tokens, its control before merge and
its spin-off procedure. It differs in four points:

| | night queue | **continuous queue** |
|---|---|---|
| issue list | a roadmap chosen up front | **picked every cycle by `scripts/kolejka-ciagla/wybierz-issue.sh`**: open, bug-fix type, P0 → P3, oldest first |
| lead's life | one session for the whole batch (`/loop` heartbeat, compaction) | **one session per issue** — after the issue the watcher types `/clear` and the start prompt again |
| state | the lead's context + ledger | **only outside the context**: GitHub labels, `git` merges, the ledger, flag files in `.claude/tmp/kolejka-ciagla/` |
| end | roadmap exhausted | **never by itself** — empty queue = wait `IDLE_MIN` and look again; stops only on a stop condition or the owner's `STOP` |

Why one session per issue: the quality of the work lives in L2, which always starts with a clean window.
The lead only dispatches, but over dozens of issues its window would still fill and be compacted. With
`/clear` after every issue it never is — every lead starts with the rules, the owner's authorisation and the
last ledger rows injected by the `SessionStart` hook, and nothing else. `POMIAR` (2026-09-24, scratch repo,
Claude Code 2.1.281, auto mode): an interactive session in tmux merged `--no-ff`, received `/clear` via
`tmux send-keys`, lost the previous turn's context, got the hook's context, and merged again — no classifier
bounce. `NIEZMIERZONE`: a real issue with an L2 subagent and a whole night — the dry run measures it.

## Who does what

- **Owner** starts it with `scripts/kolejka-ciagla/kolejka.sh start <repo>` from their own terminal. The
  start prompt (`.claude/tmp/kolejka-ciagla/start-prompt.txt`) is the owner's authorisation to merge locally
  and close issues; the watcher types it verbatim every cycle, and ledger row 0 quotes it. It never covers
  `git push`, deploy, production, KSeF or `npm run build`.
- **Watcher** (`watcher.sh`, second tmux window, under `caffeinate`) never reads code or the screen. It acts
  on the lead's flag files, and only once the `Stop` hook has marked the end of the lead's turn.
- **Lead (L1)** = the interactive `claude` in the first tmux window. It runs exactly ONE cycle (below), then
  ends its turn. It reads no code and writes no code. It is the only one that merges, closes, labels,
  creates issues and commits the ledger.
- **L2 / L3** as in `references/kolejka-nocna.md` §"Three levels" (L2 `general-purpose` with an explicit
  `model:` = `MODEL_L2`, runs triage + `task-lifecycle` in full, spawns specialists; L3 spawns nobody).

**Runs alone.** The lead merges into `main` in the main tree, so no other lead (another queue, a wave) may
work in this repo at the same time — two leads in one tree collide on the index lock and one commit sweeps up
the other's uncommitted edit. `kolejka.sh start` refuses a dirty main tree or a branch other than `MAIN`.

## Configuration

`.claude/tmp/kolejka-ciagla/config.env` (written by `kolejka.sh start`, shown by the hook): `REPO` (main tree),
`K` (state directory), `SKRYPTY`, `MAIN`, `LEDGER` (relative to `REPO`), `WT` (L2 worktree),
`ETYKIETA_ZROBIONE`, `MODEL_L2`, `KOLEJKA_TYPY` / `KOLEJKA_POMIJAJ` (issue filter). **Every Bash call
starts with `. .claude/tmp/kolejka-ciagla/config.env &&`** (the lead's working directory is the main tree)
and uses the variables — `"$K/rotuj"`, `git -C "$REPO"`, `git -C "$WT"` — never a path retyped from the
screen. `POMIAR` (2026-09-24, scratch run): a lead retyping a 130-character state path dropped one `/`,
wrote its flag into a non-existent directory, reported success, and the queue stood still.

**Bug fixes only.** `wybierz-issue.sh` takes an issue only if it carries one of `KOLEJKA_TYPY` (default
`typ:bug`, `typ:point-fix`, `typ:structural`, legacy `bug`) and a priority label (`P0`–`P3`, legacy
`priorytet:*`), and none of `KOLEJKA_POMIJAJ` (features `typ:pomysl`/`enhancement`/`new_idea`/`request`,
`typ:analysis`, `status:odlozone`, `status:do-scalenia`, `status:zrobione-lokalnie`, `tor:remediacja-danych`,
`security-audit-tracker`). It also skips every issue that already has a local `agent/issue-<nr>` branch —
someone started it before (a wave, a crashed run); what happens to it is the owner's call.
Labels can lie: L2's triage is the second filter — an issue that in fact asks for new behaviour is reported
as `feature.` and never implemented.

## The cycle (one per lead session)

State directory `K`; ledger `REPO/LEDGER`. Every step's command output stays short — the lead never pulls
test-suite output or diffs into its window.

**0. Preconditions.**
```bash
. .claude/tmp/kolejka-ciagla/config.env
test -f "$K/STOP" -o -f ~/.claude/relay-state/STOP-roadmapa && echo STOP     # → flag rotuj, end turn (watcher stops)
[ "$(git -C "$REPO" branch --show-current)" = "$MAIN" ] || echo NOT-MAIN        # → stop condition
git -C "$REPO" status --short --untracked-files=no                             # must be empty → else stop condition
```
Ledger missing → create it (header below) with row 0 = the start prompt verbatim, commit (step 7 mechanics).

**1. Recovery** — only when `$K/w-toku` exists (the previous lead ended mid-issue: crash, hard stop, a turn
ended without a flag). Let `N=$(cat "$K/w-toku")`:
- `git -C "$REPO" merge-base --is-ancestor agent/issue-$N "$MAIN"` succeeds and the issue is still open →
  the merge happened, the close did not: close it now (step 6), ledger row, continue with step 2;
- otherwise → defer it: `status:odlozone` + comment "przerwane — lider zakończył sesję w trakcie issue;
  gałąź agent/issue-N zostaje do decyzji właściciela" (never re-run it automatically — whatever interrupted
  it may interrupt it again), ledger row `przerwane`, `rm "$K/w-toku"`, continue with step 2.

**2. Pick.**
```bash
N=$("$SKRYPTY/wybierz-issue.sh" "$REPO")
```
Empty → `touch "$K/pusto"`, end the turn with one line. No ledger row (an idle night would flood it).

**3. Prepare.**
```bash
echo "$N" > "$K/w-toku"
gh issue view "$N" --json title,labels,body -q '.title, ([.labels[].name]|join(",")), (.body|.[0:1500])'
```
L2 worktree, created once and reused: when `$WT` does not exist, `git -C "$REPO" worktree add --detach "$WT"
"$MAIN"`, copy `.env`, and apply the project's worktree checklist (`references/kolejka-nocna.md` pre-flight
step 3: port, `node_modules`, discriminator). Then:
```bash
git -C "$WT" status --short                      # must be empty — someone else's work is a stop, not a cleanup
git -C "$WT" checkout -b agent/issue-$N "$MAIN"
```

**4. Spawn L2 in the FOREGROUND** (`run_in_background` false) and wait for it. Unlike the night queue there
is no heartbeat inside the lead — the watcher watches for stalls — and a foreground wait means the lead's
turn cannot end while L2 is working, so the watcher can never `/clear` a running issue. Brief = the template
of `references/kolejka-nocna.md` §"Brief for L2", with these changes:
- working tree `$WT`, branch `agent/issue-$N` already checked out; never touch `$REPO` (the main tree);
- this queue fixes bugs only: if triage shows the issue asks for new functionality (a new feature, screen,
  report, option, integration — not restoring behaviour that is broken), report `feature. <one sentence why>`
  and stop, without changing code;
- write the full report to `$K/raport-$N.md`; the message to the lead is at most 3 lines: first line the
  token, then tip SHA and the report path. Its `NOWE PROBLEMY` section lives in the file.

**5. Dispatch on the token** (first line of L2's message; `head -1 "$K/raport-$N.md"` if the message is garbled):

| token | the lead does |
|---|---|
| `done.` | control (step 6), merge, close |
| `closed-on-head. ALREADY-FIXED\|NOT-A-BUG` | re-run the decisive measurement quoted in the report → comment + `gh issue close --reason completed` / `"not planned"`; `git -C "$WT" checkout --detach "$MAIN"`; `git -C "$REPO" branch -D agent/issue-$N` (empty branch) |
| `partial.` | spawn ONE fresh L2 on the same branch with the report's remainder (still this session); a second `partial.` → defer |
| `feature.` | `status:odlozone` + comment "to nowa funkcjonalność, kolejka ciągła naprawia tylko błędy — decyzja właściciela"; branch deleted if it has no commits |
| `ambiguous.` / `needs-confirm.` / `too-big.` / `BLOCKED` / `regressed.` | `status:odlozone` + comment with the question or blocker (from the report); branch stays |

Deferring = the label; `wybierz-issue.sh` never returns a `status:odlozone` issue, so the queue cannot loop on it.

**6. Control, merge, close** (only after `done.`). Control exactly as `references/kolejka-nocna.md`
§"Control before merge" (commits exist, `$WT` clean, evidence path exists); any failure → handle as `BLOCKED`
with the failed command quoted. Then:
```bash
git -C "$WT" checkout --detach "$MAIN"           # release the branch before merging it
git -C "$REPO" merge --no-ff -m "[roadmapa] Scal #$N: <title>" agent/issue-$N
git -C "$REPO" rev-parse --short HEAD
printf '%s\n' "<comment>" > "$K/issue-$N-close.md" \
  && gh issue comment "$N" --body-file "$K/issue-$N-close.md" \
  && gh issue close "$N" --reason completed \
  && gh issue edit "$N" --add-label "$ETYKIETA_ZROBIONE"
```
The comment says: merged locally into `main` at `<SHA>`, **not pushed and not deployed**, branch tip,
verification evidence, review iterations. Closing is what keeps the next cycle from taking the same issue.
**Merge conflict** (someone committed to `main` meanwhile): `git -C "$REPO" merge --abort`, defer the issue
with the conflicting paths in the comment, and continue — the next issue branches from the new `main`.
Never resolve a conflict in the main tree.

**Spin-offs** from the report's `NOWE PROBLEMY`: exactly `references/kolejka-nocna.md` §"New problems → new
issues" (duplicate check, three label axes). They join the queue by their own priority in a later cycle —
a spin-off labelled as a feature never enters it.

**7. Ledger row and rotation.** Append one row, commit ONLY the ledger with a pathspec, then hand over:
```bash
git -C "$REPO" add -- "$LEDGER" && git -C "$REPO" commit -m "docs(plans): Kolejka ciągła — #$N <token>" -- "$LEDGER"
rm -f "$K/w-toku"
touch "$K/rotuj"
```
End the turn with at most 3 lines (issue, token, SHA). **Do not start another issue** — the watcher clears
this session and starts the next cycle in a fresh one.

Ledger format (`LEDGER`, created in the first cycle):
```
# Kolejka ciągła — ledger

| lp | data | issue | token | merge SHA | uwagi |
|---|---|---|---|---|---|
| 0 | 2026-09-24 | - | autoryzacja | - | "<start prompt verbatim>" |
| 1 | 2026-09-24 | #898 | done. | a1b2c3d | P2, 2 rundy review, spin-off #950 |
```
`lp` = previous row + 1. A number in `uwagi` taken from L2's report is `reported`, not re-measured (`SKILL.md` §7).

## Stop conditions — write the reason to `$K/stop`, end the turn

- main tree dirty or not on `MAIN` at step 0; `$WT` dirty at step 3;
- the last ledger rows (injected by the hook) plus this issue show two consecutive `BLOCKED` with the same
  environmental cause (database down, dev server down, `gh` auth) — the rest would fail the same way;
- anything that needs push, deploy, production or KSeF.

The watcher notifies (macOS notification + `watcher.log`) and exits; the owner restarts with `kolejka.sh start`.
A turn ended WITHOUT any flag (a question, an error) is restarted once by the watcher after `GRACE_MIN` —
recovery (step 1) picks up the interrupted issue; a second one in a row stops the queue.

## Owner — morning / whenever

1. `kolejka.sh status <repo>` — current issue, flags, last ledger rows, local `[roadmapa]` merges not yet pushed.
2. Full suite + CI-parity gate on `main`, then push when satisfied (the push rule treats unpushed
   `[roadmapa]` merges as "ask before pushing").
3. Issues deferred by the queue carry `status:odlozone` and their question in a comment.
4. `kolejka.sh stop <repo>` — finish the current issue, then stop. `tmux kill-session -t kolejka` — hard stop.
