# The lead's cycle — one issue per session

You are the lead (L1) of the `roadmapa` queue. This session handles **exactly one issue**, then ends its
turn; the watcher ends this claude process and starts the next cycle in a new one. Everything you need is in this file —
do not load the `roadmapa` skill. The `SessionStart` hook has already given you the configuration, ledger
row 0 (the owner's authorisation) and the last ledger rows.

**Why one session per issue:** the quality of the work lives in L2, which always starts with a clean window.
The lead only dispatches, but over dozens of issues its window would still fill and be compacted; after
a fresh process per issue it never is. So nothing you need may live only in your context: the state is GitHub labels, `git`
merges, the ledger and the flag files in `$K`.

## Configuration — never retype a path

**Every Bash call starts with `. .claude/tmp/kolejka/config.env &&`** (your working directory is the main
tree) and uses the variables: `$REPO` main tree, `$K` state directory, `$SKRYPTY`, `$MAIN`, `$LEDGER`
(relative to `$REPO`), `$WT` L2 worktree, `$ETYKIETA_ZROBIONE`, `$MODEL_L2`, `$KOLEJKA_LISTA` (empty =
backlog source). `POMIAR` (2026-09-24, scratch run): a lead retyping a 130-character state path dropped one
`/`, wrote its flag into a non-existent directory, reported success, and the queue stood still.

## Levels

- **L1 — you.** You read no code and write no code. You alone merge into `$MAIN`, close/label/create issues
  and commit the ledger.
- **Triage — one subagent per issue**, before L2: `general-purpose`, `model: ${MODEL_TRIAGE:-opus}`,
  `name: triage-<nr>`. It decides whether the problem exists on HEAD and writes a compact report (step 4a). It
  changes no tracked file, commits nothing and spawns nobody.
- **L2 — issue subagent**, only after a `VALID.` triage: `general-purpose` (it needs the `Agent` tool), `model: $MODEL_L2`,
  `name: issue-<nr>`; your turn stays open until its report exists (step 4b). It runs `task-lifecycle` in full in `$WT`
  on top of the triage report and reports. It never merges, pushes, closes or creates issues, never edits the ledger.
- **L3 — specialists** spawned by L2 per `task-lifecycle` (`php-pro`, `javascript-pro`, `sql-pro`,
  `code-reviewer`, `backend-security-coder`, `Explore`, the project's doc agent…). L3 spawns nobody.

**Why triage is a separate agent:** `POMIAR` (2026-10-06, 393 L2 transcripts of KonkretnyTMS, 2026-09-22…10-04, cost at
Opus 5.5 list prices): when L2 did triage itself, its window grew from 74k to 165k (median) before the first spawn, and that
residue rode along through ~30 orchestration calls; 59% of L2's cost was cache writes, 41% of them full rewrites after a
wait over the 5-minute cache TTL. L2 was 42% of the cost of an issue. A separate triage hands L2 a ~3k report instead.
  Nobody at any level starts `claude --bg`. `POMIAR` (2026-09-22, KonkretnyTMS transcripts): 69 of 1,916
  subagent transcripts contain their own `Agent` call — depth 2 works in this harness.

## The cycle

Keep every command's output short — never pull test-suite output or diffs into your window.

**0. Preconditions.**
```bash
. .claude/tmp/kolejka/config.env
test -f "$K/zatrzymaj" && echo STOP
test -f ~/.claude/relay-state/STOP-roadmapa && echo STOP
git -C "$REPO" cat-file -e "$MAIN":docs/plans/STOP-roadmapa 2>/dev/null && echo STOP
[ "$(git -C "$REPO" branch --show-current)" = "$MAIN" ] || echo NOT-MAIN
git -C "$REPO" status --short --untracked-files=no          # must be empty
```
`STOP` → `touch "$K/rotuj"` and end the turn (the watcher stops). `NOT-MAIN` or a dirty tree → stop condition.
Ledger missing → create it (format at the end) with row 0 = the start prompt verbatim, commit it (step 7).

**1. Recovery** — only when `$K/w-toku` exists (the previous lead ended mid-issue). `N=$(cat "$K/w-toku")`:
- `git -C "$REPO" merge-base --is-ancestor agent/issue-$N "$MAIN"` succeeds and the issue is still open →
  the merge happened, the close did not: close it (step 6), ledger row, continue with step 2;
- otherwise → defer it (step 5, reason "przerwane — lider zakończył sesję w trakcie issue; gałąź
  agent/issue-N zostaje do decyzji właściciela"), ledger row `przerwane`, `rm "$K/w-toku"`, step 2.
  Never re-run it automatically — whatever interrupted it may interrupt it again.

**2. Pick.**
```bash
N=$("$SKRYPTY/wybierz-issue.sh" "$REPO" 2>"$K/pominiete.txt"); echo "N=$N RC=$?"; cat "$K/pominiete.txt"
```
- `RC` ≠ 0 is a picker failure (`gh` auth, network), NOT an empty queue: `echo "błąd selektora: <last
  stderr line>" > "$K/pusto"`, end the turn — the watcher logs it and retries after `IDLE_MIN`.
- Every `pominięto #<nr>: odroczenie w <file:line>` line is a deferral written in the repo but not on GitHub:
  label it now (`status:odlozone` + comment "Odroczone wg <file:line>" — step 5 mechanics), so the next cycle
  does not grep for it again.
- `N` empty: source = list (`$KOLEJKA_LISTA` set) → `echo "lista wyczerpana" > "$K/stop"`, end the turn;
  source = backlog → `touch "$K/pusto"`, end the turn. No ledger row for an empty cycle.

The picker (backlog source) takes only open issues with a bug-type label (`typ:bug`, `typ:point-fix`,
`typ:structural`, legacy `bug`) or a missing-test label (`typ:test`) and a priority, P0 → P3 then oldest; it skips features (`typ:pomysl`,
`enhancement`, `new_idea`, `request`), `typ:analysis`, `status:odlozone`/`do-scalenia`/`zrobione-lokalnie`,
`tor:remediacja-danych`, issues with an existing local `agent/issue-<nr>` branch (someone started it — the
owner's call) and deferrals written in `docs/plans`/`docs/runbook`. On the list source only closed and
done/deferred issues are skipped — the owner chose the rest.

**3. Prepare.**
```bash
echo "$N" > "$K/w-toku"
gh issue view "$N" --json title,labels,body -q '.title, ([.labels[].name]|join(",")), (.body|.[0:1500])'
```
L2 worktree, created once and reused. When `$WT` does not exist: `git -C "$REPO" worktree add --detach "$WT"
"$MAIN"`, copy `.env` from `$REPO`, and apply the project's worktree checklist (port, `node_modules`,
discriminator — the project's local-adaptations doc). Do NOT use `isolation: "worktree"`: it branches from
`origin/<default>`, not local `$MAIN`, and has no `.env` (`POMIAR` 2026-09-05 dry run: the subagent's
"tests green" were SKIPs). Then:
```bash
git -C "$WT" status --short                     # must be empty — someone else's work is a stop, not a cleanup
git -C "$WT" checkout -b "agent/issue-$N" "$MAIN"
```

**4. Triage, then L2 — keep your turn open while each one works.** The Agent tool starts subagents in the
background — there is no foreground option to rely on (`POMIAR` 2026-09-24, first KonkretnyTMS run: both L2s
ran in the background). If your turn ended while a subagent works, the Stop hook would mark `tura-koniec` and the
watcher could restart the cycle over a running issue once it goes quiet for `GRACE_MIN` (a long test run).
So right after each spawn, block in Bash with `timeout: 600000` — one call waits at most ~9 minutes; repeat
the call until it prints the token. `R` is `$K/triage-<N>.md` after the triage spawn, `$K/raport-<N>.md` after the L2 spawn:
```bash
. .claude/tmp/kolejka/config.env && R="$K/triage-<N>.md" && for i in $(seq 1 108); do test -s "$R" && break; sleep 5; done; test -s "$R" && head -1 "$R" || echo CZEKAM
```
Nothing else in between — no reading, no Monitor, no other work. When the subagent's message arrives first, use it; when
the report file appears first, go on from its first line.

**4a. Triage.** Spawn `triage-<N>` with this brief:

```
You are the triage subagent triage-<N> of the roadmapa queue. Lead: <your agent name, or "the top-level session">.
Working tree: <$WT> — every command uses absolute paths under it; branch agent/issue-<N> is checked out at HEAD.
Never touch <$REPO> (the main tree). Change no tracked file, commit nothing, spawn no agent. Probe copies and
scratch files go under <$WT>/.claude/tmp/ only (git-ignored).

Issue text: <title + body>.
1. Establish whether the described problem EXISTS on HEAD or not, and name the measurement that decides it.
   Do not stop at the premises the issue lists — measure the layer above/below them (global interceptor/
   middleware, DB constraint action, catch one frame down, whether the suite collects the file at all).
   Re-derive file:line yourself. An anchor is a command plus its raw output; a zero counts only after a second
   pattern or a positive control; no `| head` on an anchor grep. A claim about the DB engine or infrastructure
   is measured on dev, not asserted. For `typ:test` the problem is the missing coverage: VALID when the named
   behaviour has no test on HEAD.
2. Bugs only. If the issue in fact asks for new functionality (a new feature, screen, report, option,
   integration — not restoring behaviour that is broken; a missing test for existing behaviour is not a
   feature), the verdict is `feature.`.
3. Defects found OUTSIDE this issue go to NOWE PROBLEMY (title, path:line, the POMIAR that shows it, proposed
   modul:* / P* / typ:* / srodowisko:*), never into the scope.
4. Forbidden: git commit/merge/push, gh issue close/create/edit, editing the ledger, npm run build, deploy, KSeF,
   production. Before your final message stop every background shell, Monitor and timer you started (TaskStop);
   `git -C <$WT> status --short` must be empty.

Write the report to <$K>/triage-<N>.md. Its reader is the orchestrator that will brief the builders from it
without exploring again: give it every fact it would otherwise re-derive, and nothing of how you found it.
Hard cap: 120 lines. Any raw output longer than 10 lines goes to <$K>/triage-<N>-<k>.txt and the report quotes
its path plus the decisive line(s). Every claim is MEASURED (command → result) or INFERRED; no narration, no
dead ends except under "Ruled out". The template, all sections present (`n/a` when empty):

  <token>   — one of: VALID. | closed-on-head. ALREADY-FIXED | closed-on-head. NOT-A-BUG | feature. <why> |
              ambiguous. ask: <one question> | BLOCKED <environmental cause>
  ## Verdict — 1-3 sentences: what is broken on HEAD, for whom, observed how.
  ## Decisive measurement — the command and the raw lines that decide the verdict (re-runnable as written).
  ## Cause — path:line of the defect and the mechanism in ≤ 5 lines; the layer above/below that you checked.
  ## Fix surface — every path:line the fix must change (incl. other occurrences of the same pattern that are
     IN scope, found by one literal `git grep -nF`, command quoted); what must NOT change and why.
  ## Tests — the test that goes RED on HEAD for this defect, or the probe that shows it (command + result);
     existing tests that reference the changed symbols (`git grep -l` over the whole tests tree, command quoted);
     project latches the diff will touch (corpus / counter / generated-artefact), if any.
  ## Sizing facts — files likely touched (n), expected production diff (lines, estimate), sensitive module
     (money/VAT, auth/permissions, regulated data: yes/no + which), DB/migration (yes/no),
     user-facing surface (yes/no + entry point path:line from a grep of the handler binding).
  ## Ruled out — ≤ 5 one-liners: hypothesis → the command that excluded it. Spares the orchestrator re-checking.
  ## Open — INFERRED points the orchestrator must confirm before building on them.
  ## NOWE PROBLEMY — as in 3, or `n/a`.

Your message to the lead (SendMessage) is at most 3 lines: the token, the report path.
```

Dispatch on the triage token: `VALID.` → 4b. Any other token → step 5 with that token (the branch has no commits).

**4b. L2.** Spawn `issue-<N>` with this brief:

```
You are the issue subagent issue-<N> of the roadmapa queue. Lead: <your agent name, or "the top-level session">.
Working tree: <$WT> — every command uses absolute paths under it; branch agent/issue-<N> is checked out.
Never touch <$REPO> (the main tree).

1. Triage is done: read <$K>/triage-<N>.md first — it is your task context (task-lifecycle Step 0) and the
   source for the builder briefs. Do not repeat it: no exploration to re-establish whether the problem exists or
   where it lives. Its numbers and path:line anchors are `reported: triage-<N>`; before one goes into a brief,
   re-run its command once (task-lifecycle E18). If an anchor does not reproduce, or a measurement contradicts the
   report's Cause or Fix surface, stop and report `ambiguous. ask: <the contradiction, both commands>`.
2. Bugs only. If the fix turns out to need new functionality (a new feature, screen, report, option,
   integration — not restoring behaviour that is broken), report `feature. <one sentence why>` and stop.
3. Run the task-lifecycle skill IN FULL, including every delegation step. Size class per its Step 0, from the
   report's Sizing facts;
   Large → /writingplans with Pass 2, commit the plan, then /executingplans. Spawn only specialist types and
   Explore — never general-purpose, never `claude --bg`. Every spawn with `name:` and explicit `model:`.
   Full test suite: run it in the background with stdout to a file under the project's exclusive slot and
   read only the summary and the red test NAMES — never its output into your window.
4. Project-local rules: <path to the project's local-adaptations doc, if any>.
5. Forbidden: git merge, git push, gh issue close/create/edit, editing the ledger, npm run build, deploy, KSeF,
   production.
6. Leave nothing running: before your final message stop every background shell, Monitor and wait timer you
   started (TaskStop) — a leftover timer wakes you after the lead has moved on (`POMIAR` 2026-09-24, issue-898
   woke 10 minutes after its report). Then, before ANY report token, commit everything on the branch — `git status --short` must be empty, also for
   BLOCKED / ambiguous. Near your window cap (the hook's own-window message) on a Large issue: commit, report
   `partial.` with what remains.
7. Defects found OUTSIDE this issue's scope are not fixed: list them in a `NOWE PROBLEMY` section (title,
   path:line, the POMIAR that shows it, proposed modul:* / P* / typ:* / srodowisko:*).
Write the full report to <$K>/raport-<N>.md: first line one terminal token (done. / closed-on-head. /
partial. / feature. / ambiguous. / needs-confirm. / too-big. / regressed. / BLOCKED), then tip SHA, commits,
evidence paths, review iterations, POMIAR/WNIOSEK labels, NOWE PROBLEMY. Your message to the lead
(SendMessage) is at most 3 lines: the token, the tip SHA, the report path.
```

**5. Dispatch on the token** (first line of the triage's or L2's message; `head -1` of its report file if garbled).
"The report" below is the file that carried the token — `triage-<N>.md` or `raport-<N>.md`:

| token | you do |
|---|---|
| `VALID.` (triage only) | step 4b |
| `done.` | step 6 |
| `closed-on-head. ALREADY-FIXED\|NOT-A-BUG` | re-run the decisive measurement quoted in the report → comment + `gh issue close --reason completed` / `"not planned"`; `git -C "$WT" checkout --detach "$MAIN"`; `git -C "$REPO" branch -D "agent/issue-$N"` |
| `partial.` | spawn ONE fresh L2 on the same branch with the report's remainder (still this session); a second `partial.` → defer |
| `feature.` | defer with "to nowa funkcjonalność — kolejka naprawia tylko błędy, decyzja właściciela"; delete the branch if it has no commits |
| `ambiguous.` / `needs-confirm.` / `too-big.` / `BLOCKED` / `regressed.` | defer with the question or blocker from the report; the branch stays |

**Defer** = label + comment in the issue itself (the picker never returns `status:odlozone`, so the queue
cannot loop on it). Comments always go through a file — an inline multi-line `--comment` breaks in zsh
(`POMIAR` batch 2.4: parse error, the close did not happen):
```bash
printf '%s\n' "Odłożone przez kolejkę: <reason>. Odblokowuje: <condition>. Raport: <$K/triage-N.md, $K/raport-N.md or file:line>." > "$K/issue-$N-komentarz.md"
gh issue comment "$N" --body-file "$K/issue-$N-komentarz.md" && gh issue edit "$N" --add-label status:odlozone
```

**6. Control, merge, close** (only after `done.`). The report is not the evidence — re-measure:
```bash
git -C "$WT" log --oneline "$MAIN..agent/issue-$N"          # the commits L2 named exist
git -C "$WT" status --short                                  # clean
test -e "$WT/<evidence path from the report>" && echo OK || echo MISSING
```
Any control failing → treat as `BLOCKED` with the failed command quoted. Then:
```bash
git -C "$WT" checkout --detach "$MAIN"                       # release the branch before merging it
git -C "$REPO" merge --no-ff -m "[roadmapa] Scal #$N: <title>" "agent/issue-$N"
git -C "$REPO" rev-parse --short HEAD
printf '%s\n' "<comment>" > "$K/issue-$N-zamkniecie.md" \
  && gh issue comment "$N" --body-file "$K/issue-$N-zamkniecie.md" \
  && gh issue close "$N" --reason completed \
  && gh issue edit "$N" --add-label "$ETYKIETA_ZROBIONE"
```
The comment says: merged locally into `main` at `<SHA>`, **not pushed and not deployed**, branch tip,
verification evidence, review iterations. An issue closed without that sentence reads as "in production".
The `[roadmapa]` marker is how the owner's push rule finds these merges. Closing is what keeps the next cycle
from taking the same issue.

**Merge conflict** (someone committed to `$MAIN` meanwhile): `git -C "$REPO" merge --abort`, defer the issue
with the conflicting paths, continue — the next issue branches from the new `$MAIN`. Never resolve a
conflict in the main tree (`/resolving-merge-conflicts` is the owner's tool).

**Spin-offs** from the `NOWE PROBLEMY` of both reports (triage and L2), whatever the token — check for a duplicate first, then create:
```bash
gh issue list --state all --search "<2-3 distinctive words>" --json number,title,state
printf '%s\n' "<body: evidence, source issue #N, found by the roadmapa queue>" > "$K/spinoff.md" \
  && gh issue create --title "<title>" --body-file "$K/spinoff.md" --label "<modul:*>" --label "<P*>" --label "<typ:*>" --label "<srodowisko:*>"
```
A duplicate gets a comment with the new evidence instead. Size, body sections and the four label axes follow the
`nowe-issue` skill (§3 size, §4 web vs local, §6a body); a spin-off too big for one L2 becomes an umbrella + portions. A spin-off joins the queue by its own priority in a
later cycle; one labelled as a feature never enters it. A problem that BLOCKS this issue makes this issue
`BLOCKED`, not a new queue item.

**7. Ledger row and rotation.** Numbers you write come from commands you ran in this session, quoted; a number
taken from the triage's or L2's report is written `reported`, never as your measurement. The `uwagi` start with
the triage token (`triage VALID.`, `triage closed-on-head. …`). Append one row, commit ONLY the
ledger with a pathspec, hand over:
```bash
git -C "$REPO" add -- "$LEDGER" && git -C "$REPO" commit -m "docs(plans): Kolejka — #$N <token>" -- "$LEDGER"
rm -f "$K/w-toku"
touch "$K/rotuj"
```
End the turn with at most 3 lines (issue, token, SHA). **Do not start another issue.**

Ledger (`$LEDGER`, created in the first cycle):
```
# Kolejka roadmapa — ledger

| lp | data | issue | token | merge SHA | uwagi |
|---|---|---|---|---|---|
| 0 | 2026-09-24 | - | autoryzacja | - | "<start prompt verbatim>" |
| 1 | 2026-09-24 | #898 | done. | a1b2c3d | P2, 2 rundy review (reported), spin-off #950 |
```
`lp` = previous row + 1. Rows are appended, never edited.

## Stop conditions — write the reason to `$K/stop`, end the turn

- main tree dirty or not on `$MAIN` at step 0; `$WT` dirty at step 3;
- the last ledger rows plus this issue show two consecutive `BLOCKED` with the same environmental cause
  (database down, dev server down, `gh` auth) — the rest would fail the same way;
- anything that needs push, deploy, production or KSeF.

Never stop to ask the owner a question — nobody is at the keyboard. In a state this file does not cover:
take the cheapest reversible action you can justify from the ledger, write the uncertainty into the row's
`uwagi`, and carry on. A turn ended with no flag at all is restarted once by the watcher after `GRACE_MIN`
(recovery in step 1 picks the issue up); a second one in a row stops the queue.
