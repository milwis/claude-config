---
name: roadmapa
description: "Use when a BATCH of issues must be resolved with the owner away from the keyboard — a self-spawning chain of sessions, one phase each (triage / plan / execute / verify), handing work through a committed roadmap + append-only ledger rather than through context. Input: issue numbers or a backlog. Output: `agent/issue-<nr>` branches with evidence in the ledger and a status table; the chain never merges to main — that is the owner's step."
---

# Roadmapa (a chain of sessions that resolves a batch of issues without the owner present)

> **The source of truth for this file is `milwis/claude-config`** (`plugins/milwis-coding-toolkit/skills/roadmapa/`).
> The `sync-claude-toolkit` workflow copies it from there every Monday via `cp -rf`, so **editing the copy
> in `.claude/skills/` will be silently overwritten** — make changes upstream. The sync carries only
> `agents/` and `skills/`: the relay hooks (`~/.claude/hooks/relay-*.sh`) on which the thresholds in §1 stand **do not
> travel with it** and must be wired up separately in a new repo.

**Core idea:** context is a consumable resource, and the quality of work degrades before the window fills up. Instead of one session grinding until it hits the wall — **a chain of sessions, each of which does ONE phase and hands the work to the next one**, which it spawns itself. The owner is not at the keyboard; everything that must survive has to live in the repo, not in context.

**Announce at start:** "Using the roadmapa skill, generation N."

**The first ledger row contains MEASURED thresholds**, not assumed ones:
```bash
bash -c 'source ~/.claude/hooks/relay-lib.sh; echo "WARN=$RELAY_WARN HANDOFF=$RELAY_HANDOFF CEILING=$RELAY_CEILING HARD=$RELAY_HARD_CAP"'
```
A wired-up hook with thresholds different from what you assume looks identical to a working mechanism and **stays silent for the whole run** — that is vacuously green protection. Measure it and write it down.

**Requires the relay hooks to be wired up** (`~/.claude/hooks/relay-{lib,post,pre}.sh` in `settings.json`). Without them the thresholds will not fire and the chain will not move on its own — check `jq '.hooks' ~/.claude/settings.json` and abort if it is `null`.

---

## 1. Thresholds and what you do at each of them

| % of window | What happens | Enforced by |
|---|---|---|
| 35 | complete the handoff in the ledger; only closable threads from now on | `PostToolUse` injection |
| 40 | stop taking on new threads; `Agent` blocked; spawn a successor | `deny` + injection |
| 60 | everything cut off except `Bash`, `Write`, `SendMessage`, `TodoWrite`, `ListAgents` — including `Read`, `Grep`, `Glob`, `Edit` | `deny` |
| 80 | hard ceiling — `hold` does NOT lift it | `deny` |

**The thresholds are a SAFETY NET, not a schedule.** Measured in run 1 (five handoffs):
4 out of 5 happened because of the **phase boundary from §4**, at 31.5% / 38.6% / 26.8% / 37.0% — i.e. BELOW
the 40 threshold, which never fired at all. Only the fifth (44.4%) was driven by the threshold. So do not plan work "up
to the threshold": hand off at the phase boundary, and treat the thresholds as what catches you when a phase turns out longer
than you assumed.

The number lags by one turn and is computed against a limit **derived from the model** (§1b).
Measured delay: **one tool round (~27 s)** — the hook after the FIRST tool over the threshold
still reads the usage of the PREVIOUS turn, so the injection arrives ~0.5 pp past the threshold (G2: crossing
35% at 352,880, injection at 355,042). `RELAY_LIMIT` has NO default value — it is an emergency override; the default 1e6 comes from `RELAY_LIMIT_DEFAULT`. Setting `RELAY_LIMIT` to something that is not a positive number is rejected with a warning, not silently. A fresh session in this repo starts at ~14% (`CLAUDE.md` + `incident-lessons.md`; measured: G2 = 143,729,
G3 = 143,860, G6 = ~144,000 — the value is stable).

`POMIAR`: handoff points in run 1 fell at 31.5% / 38.6% / 26.8% / 37.0% / 44.4%, on average
33.5%, and the difference between consecutive handoffs is ~19 points. `WNIOSEK` (corrected 2026-09-05):
this number **does not measure window capacity** — it measures the effect of the "one phase per generation" rule from
the §4 of that time, which mandated handing off at the phase boundary regardless of usage. The third premise
("could the generation have kept working") was not measured, so the label "real bandwidth" was a
false generalisation — an instance of `§Parent class` from `incident-lessons.md` (two premises
measured, the third not, false conclusion). §4 removes that coupling: a generation with usage below
`RELAY_WARN` takes the next unclosed phase instead of automatically handing off at the phase boundary, so
"19 points" is no longer a basis for slicing roadmap stages into ~19-point pieces.

## 1a. Subagents have their own thresholds

A subagent is not a small session — **it cannot hand work off to anyone**; its only exit is returning a report to its parent. It does have its own window and its own transcript (`<project>/<session-id>/subagents/agent-<agent_id>.jsonl`), so the hooks measure it separately:

| % of its own window | What happens |
|---|---|
| 45 | "wrap up, close the thread, return the report" |
| 65 | **every** tool gets `deny` — the only thing left is writing the report |

Cutting off tools here is an enforcing mechanism, not a punishment: a subagent without tools has to answer.

The same principle governs the session ceiling: from 60% **reading** is cut off (`Read`, `Grep`, `Glob`, `Edit`), because those are the four largest consumers of the window — a ceiling that lets them through protects against nothing. `Bash` stays open, because without it you cannot do `git` or `claude --bg`; **the ceiling cuts off tools, not intentions**, so it is on you not to read files via `cat`. An incomplete report is useful; an interrupted subagent without a report is not.

Conclusions for the delegator: **delegate narrowly**. A task like "review the whole module" eats the subagent's window before it reports anything. Give verification assignments two-sidedly ("determine whether X or not-X, and state what settles it") — that is a `CLAUDE.md` requirement anyway, and it also limits material gathering.

**A subagent never hands work off sideways.** It does not spawn a second subagent (most definitions lack the `Agent` tool — `php-pro` has `Read, Write, Edit, Bash, Glob, Grep`) and does not start a session via `claude --bg` from Bash.

The hook blocks the typical forms of that call, but this is **defence in depth, not a latch** — and you need to know that before relying on it. The command blacklist is by definition incomplete: `sudo claude`, `nohup claude`, `timeout 600 claude`, `bash -c 'claude …'` and a binary name passed via a variable **get through** (measured). The first version of the guard even let through `KTMS_RELAY_GEN=2 claude --bg …`, i.e. literally the form §5 of this skill teaches and which the hook itself injects into context — the ban could be defeated by copying the instruction the subagent received from the very same mechanism. Closed, but the remaining gaps stay: what really holds here is the content of the injected instruction, not the regex.

**Why there is NO `permissions.deny` rule with `Bash(claude:*)` here** — considered and rejected 2026-09-05 after measurement, not by oversight. The rule is stronger than the regex: `POMIAR` (`claude -p --disallowedTools "Bash(claude:*)"`) showed that it blocks `nohup claude …` and `C=claude; $C …`, i.e. variants no regex can catch, and **there are no false positives** on commands merely quoting `claude` (`echo`, `grep`, `git log --grep`). The shared hole of both is `bash -c '…'`.

The blocker is **scope**: rules in `settings.json` apply to the SESSION, not selectively to its subagents. Putting `Bash(claude:*)` there would cut `claude --bg` off from the orchestrator too — which would kill the mechanism the whole relay stands on (§5 step 4). There is no "subagent only" scope, and `.claude/agents/*.md` is overwritten by the `sync-claude-toolkit` workflow (`cp -f "${SRC}/agents/"*.md`), so an agent's frontmatter is not a durable carrier either. What remains is the regex in the hook as defence in depth — deliberately weaker, because the stronger version would cost more than it gives. Continuity belongs solely to the lead: the report returns to them, and they decide whether to assign the rest to a fresh subagent with a narrower task. The report is also a **compression point** — 200k of exploration turns into 2k of findings; passing context directly between subagents would carry ballast instead of trimming it.

A cost to keep in mind: the report lands in the **lead's** window. Every subagent round fattens it, so a subagent cut off at the ceiling accelerates the generation change at the parent. Tune the thresholds via `RELAY_SUB_WARN` / `RELAY_SUB_CAP`.

## 1b. Where the denominator comes from — a model-derived limit

A percentage means nothing without a window, and the window **depends on the model, not on a constant**. The hook reads `.message.model` from the measured transcript and picks the limit: `haiku` → 200,000, any other model → 1,000,000 (owner's ruling, 2026-09-05). Override via `RELAY_LIMIT_HAIKU` / `RELAY_LIMIT_DEFAULT`, and in an emergency via `RELAY_LIMIT` (forces the value regardless of model).

**Why this is a separate section and not an implementation detail:** a wrong denominator breaks the mechanism in BOTH directions, and silently each time. Too large — the threshold never fires, the protection is vacuously green (exactly the state in which a subagent reaches 800k). Too small — tools are cut off at a fraction of the real window and **destroy correct work**. The latter really happened on 2026-09-05: a 200k limit for sonnet, taken from a truncated sample (`find -size +200k | head -40`), cut off a live subagent at 459,849 tokens, mid-task.

The decisive measurement, on the **full** set of 975 subagent transcripts — maximum observed context per model:

| model | max observed | what it proves |
|---|---|---|
| claude-sonnet-5 | 981,531 | window ≥ 1M |
| claude-opus-5 | 503,833 | window ≥ 504k |
| claude-opus-4-7 | 273,157 | window ≥ 273k |
| claude-sonnet-4-6 | 125,583 | nothing above 126k |
| claude-haiku-4-5 | 88,458 | nothing above 89k |

These are **lower bounds**, not window sizes — "max observed" never proves where the window ends. That is why **absolute** thresholds stand next to the percentage ones (`RELAY_SUB_WARN_ABS` 500k, `RELAY_SUB_CAP_ABS` 700k, `RELAY_HANDOFF_ABS` 450k, `RELAY_CEILING_ABS` 650k): whichever comes **first** fires. With a 1M window the percentage always wins, so the absolute thresholds are invisible — they surface only when we guessed the model limit too high, and then they save you from a runaway. When adding a new model, do not guess its window: leave the default 1M and let the absolute net do its work.

**The number you see in the TUI for a running subagent ("↓ 456.5k tokens") is THE SAME quantity the hook measures** — measured: 459,396 vs 456.5k. It is NOT a cumulative sum (that one, for the same subagent, was 54.6 million, i.e. 119×). So you can calibrate thresholds by what you see on screen.

## 2. Atomic phases — `hold`

Some phases **must not** be handed off halfway: a plan written to the middle is worse than a plan finished at ten points more cost, and a mutation probe abandoned in flight leaves a mutated file in the tree.

**A non-atomic phase does NOT set a `hold`** — do not infer that a contrario from the list below. A commit that triggers six pre-commit guards takes a long time and looks like a hang, but it is not an atomic phase. A forgotten `rm -f $SID.hold` lifts thresholds 40 and 60 for the rest of the session's life, so a `hold` set "just in case" is worse than none.

Atomic phases:
- writing a plan via `/writingplans` **together with the specialist audit (Pass 2)** — a plan without Pass 2 is not a plan; this exists ONLY for issues classified **Large** at intake (§4) — the other classes have no plan phase to hold;
- a mutation probe in progress (file mutated, not yet restored);
- a review→fix round in flight (reviewer returned findings, fix not committed).

Take your own `session-id` from the environment — **do not derive it from the session name**:
```bash
SID="$CLAUDE_CODE_SESSION_ID"
mkdir -p ~/.claude/relay-state
```
The variant via `claude agents --json | jq 'select(.name==…)'` has two silent failure modes, both measured: names `<slug>-g<n>` are generated deterministically, so a repeated generation yields two sessions with the same name, `$SID` becomes two-line and the `hold` file is created under a name containing a newline; and generation 1 has no name at all, so `$SID` is empty and `~/.claude/relay-state/.hold` is created, which the hook will never find. In both cases the `hold` **does not work and says nothing about it** — the atomic phase is interrupted by a threshold, i.e. exactly the harm this section was created to prevent.

Entry and exit:
```bash
echo "writingplans #<nr>" > ~/.claude/relay-state/$SID.hold   # entry
rm -f ~/.claude/relay-state/$SID.hold                        # exit — MANDATORY
```
`hold` suspends thresholds 40 and 60 (together with their absolute variants), **it does not suspend the hard ceiling — neither the percentage one (80%) nor the absolute one (`RELAY_HARD_CAP_ABS`, default 850,000)**. Until 2026-09-05 the absolute ceiling did not exist at all, and `hold` switched off the whole ABS net — i.e. exactly in the scenario the net was built for (window guessed too high), an atomic phase was left without any ceiling whatsoever. An escape hatch without a limit stops being a hatch and becomes a bypass of the mechanism. After reaching the hard ceiling during an atomic phase: save what you have, mark the phase in the ledger as `INTERRUPTED` with the exact interruption point, and hand off — the successor **restarts the phase from the beginning**, not from the middle.

## 3. Durable state — roadmap and ledger

Context dies with the session; the repo does not. Two files, both **committed**:

The roadmap does not have to be a list of issues — it can be a list of phases of any task. In that case replace `issue #<nr>` in the ledger row header with `stage N`, and skip the fields about the `agent/issue-<nr>` branch and triage on HEAD.

**An artefact that grows over many generations** (report, inventory, aggregate file) is appended to only via `cat >>` or `Edit` — `cat >` will delete the predecessor's work, and the write will look fully successful. After writing check `git status --short -- <file>`: ` M` means appended, `??` means you have just created the file anew.

**Roadmap** — `docs/plans/<date>-roadmapa-<slug>.md`, written by generation 1, then read-only:
- the list of issues after triage, each with a one-sentence scope, a **size-class hint** (Trivial / Small / Standard / Large per `task-lifecycle` Step 0 — from the fresh anchors: expected diff, files, modules, whether it touches money/auth/regulated data), the phases that follow from it (`plan` only for Large) and a `cloud-safe`/`local-only` label (criterion in §4a). The hint is G1's estimate; the generation that opens the issue makes the final call at intake (§4) and records it in the ledger with the reason;
- ordering (first what unblocks the rest; never two issues touching the same table next to each other);
- **execution track** — relay (default) / orchestrator / cloud, chosen per the criterion in §4a and justified in ONE sentence;
- **issue completion mode** — always `branch` (§4b); the `local-merge` mode has been abolished and must not be declared;
- **chain mode** — `batch` (default: the chain ends together with the roadmap) or `continuous`
  (after the roadmap is exhausted, a curator of the next wave is created) — §4c;
- what the chain must not do: push to `origin`, deploy, `gh issue close`, sending to KSeF.

**Ledger** — `docs/plans/<the-same-slug>-ledger.md`, **append-only**, one row per completed phase.

The only exception to append-only is the **phase queue table** in the header (if you keep one): its
`status` column by definition requires in-place editing and may be overwritten. Everything below the header is
appended and untouchable. Measured in run 1: G2's ledger commit was 47 insertions and **2 deleted
lines** — both in that table; G2 had to decide on its own that this was allowed, because the previous version of this section
only said "append-only" and did not foresee a table at all. A phase row, once appended, is not
corrected — new findings go as an annex with its own header.

Row format:

```
## G<gen> · issue #<nr> · faza <triage|plan|exec|verify> · <date time>
- Gałąź: agent/issue-<nr>
- Klasa: <Trivial|Small|Standard|Large> — <one sentence why; in the `plan` row, then repeated unchanged>
- Okno: <% at phase start> → <% when writing this row> (measured, command below)
- Zrobione: <what actually went in, with commits>
- POMIAR: <command → result; what was measured>
- WNIOSEK: <what was inferred — separately, never mixed with POMIAR>
- Zostało: <the next step, concretely>
- Miny: <what the successor must NOT do and why>
```

Field names (`faza`, `Gałąź`, `Klasa`, `Okno`, `Zrobione`, `Zostało`, `Miny` = phase, branch, class, window, done, remaining, mines) stay in Polish on purpose — existing ledgers use them and later generations grep for them.

**Every "ready" artefact named in `Zrobione`/`Zostało` — a fixture, a probe, a script, a plan — carries a repo path (`file:line` or commit SHA) or the label `NIE zmaterializowane` (not materialised).** `POMIAR` (batch 2.3, #698): the issue text promised fixtures E1/E5/E12 "already written"; they existed only inside a wave-J subagent report, never in the tree, and the builder spent 4 tool calls looking for them. A sentence like "fixture ready" without a path is a claim about somebody's context, not about the repo — and context dies with the session (§3, first paragraph).

`Okno` is measured with the hook's own function, not inferred from whether an injection has arrived (the WARN injection fires once and lags a turn; a generation that never saw it does not know whether it is at 20% or 34%):

```bash
bash -c 'source ~/.claude/hooks/relay-lib.sh; SID="$CLAUDE_CODE_SESSION_ID"; TP=$(ls ~/.claude/projects/*/"$SID".jsonl | head -1); relay_measure "$(jq -n --arg tp "$TP" --arg sid "$SID" "{transcript_path:\$tp,session_id:\$sid}")" && echo "OKNO ${PCT}% (${USED}/${LIMIT}, $MODEL)"'
```

The number is the input to the end-of-phase rule (§4, condition 2) and the calibration source for the per-phase costs quoted there — a wave whose rows carry `Okno` lets the next curator size phases from measurement instead of from this file.

**Every number and fact in a ledger row or a subagent brief comes from a command executed in THIS turn, quoted next to it** — not from memory, not from an earlier turn's grep, and not from a subagent's report taken as is: a claim admitted from a report gets ONE control command first (`git ls-files <path>`, `grep -c`, `ls`). `POMIAR` (batch 3.1): three false alarms from exactly this — the verify brief for #685 gave the expected count "8" from memory (`grep -c` said 10, the verifier spent calls resolving a non-alarm), the roadmap listed `toggleP` as debt from a prefix grep (the builder had to refute it), and the ledger accepted the fixer's "`js/main.js` untracked" (refuted by the orchestrator's own `git ls-files` after the commit — amend). A number the orchestrator did not just measure is an anchor the subagent will pay to unlearn — and a number from a pipe ending in `head` is not a measurement either (§4, triage).

The ledger is the real handoff. The successor's start prompt is just a pointer to it — this way the quality of the handoff does not depend on how much context the predecessor had left.

## 4. Generation roles

**G1 — curator.** Picks 5-6 issues and writes the roadmap.

**Modes come from the owner's instruction, never from inference.** Defaults: `track: relay`, `chain mode: batch`; the `issue completion mode` is FIXED (`branch`, §4b) and is not up for choice. You enable `continuous` **exclusively on explicit request** — the shape of the task ("lots of issues", "I'll be away") is NOT a request. A guess here goes one way irreversibly: a chain that switched itself into continuous mode works through the night on issues the owner never gave it.

**When the owner did NOT provide a set of issues — ask before you pick anything.** The question is: should the curator select issues autonomously (and in which chain mode), or will the owner provide a list. This is the ONLY moment at which stopping with a question is allowed — the owner has just issued the instruction, so they are at the keyboard; from the moment G2 comes into existence, the **ban on stopping with a question** from §6 applies without exceptions. Do not launch the chain "as a trial" with a default set: the first phase will have created a branch and a commit before the owner sees what you picked. Mandatory **triage on HEAD**: an open issue does not mean unresolved (measured: two out of five were already in `main`). For each: `git log --oneline --all --grep "#<nr>"`, `gh issue view <nr>`, checking whether the described defect still exists in the code. **The code check is delegated, not done in G1's window — but sized to the issue, not one subagent per issue by reflex.** Issues whose triage is ≤3 commands (a `git log --grep`, one `grep`, one HTTP probe) or whose text is itself a measurement (a latch to add, a duplicate to confirm) are done by G1 inline — `POMIAR` (batch 2.3): a dedicated `Explore` for #511 (a duplicate of #457) cost 75k tokens / 44 calls to return one sentence. The remaining issues go to one `Explore` subagent per **2–3 simple issues** (`model: sonnet`, `name: triage-<nrs>`, in parallel); a dedicated subagent is reserved for an issue whose triage needs a corpus trace (grep across many files, a data-shape question against the live DB). Every subagent gets the triage prompt of `issue-pipeline` Step 1 (VALID / ALREADY-FIXED / NOT-A-BUG / NEEDS-CLARIFICATION, fresh `file:line` anchors, list of files a fix would touch, flags DB/GUI/shared-file, and the **size-class hint**). Six short reports land in G1's context instead of six explorations — the roadmap copies the anchors and the hint verbatim. **An anchor is a command plus its raw output, never a count that is already a conclusion.** A number without the command that produced it does not enter the roadmap, and a ZERO ("no guard", "no call site", "0 hits") enters only after a SECOND pattern — a synonym, an alias, the function-call spelling of the constant — also returned zero; one pattern is one measurement (`incident-lessons.md` §Parent class). `POMIAR` (batch 2.5, #716): triage wrote "no entry guard" from `grep -c PHP_SAPI → 0` in three files; two of the three guarded via `php_sapi_name()`, and the builder spent part of its 70 calls disproving the orchestrator's own anchor. A false anchor is more expensive than a missing one — the builder trusts it, then pays to unlearn it. **No `| head -N` on a grep that produces an anchor.** `head` truncates without a signal, and a truncated list reads exactly like a complete one: the anchor is `git grep -c` plus the FULL file list (`git grep -l`), and above ~20 hits the count and the file list alone, never an excerpt of the lines. `POMIAR` (batch 3.2, #710): triage wrote "the `'orders-daily'` bucket lives only in `orders-daily.js`" from a grep cut with `| head -20`; the control `git grep -n "orders-daily" -- js | grep -v orders-daily.js` found 3 hits in `orders-transport-status.js`, and the omission cost a full fixer round (175k) plus a second review. **A claim about DDL or infrastructure ("MODIFY without a type change passes despite the FK", "the cron runs as this user", "the endpoint is behind auth") is a claim about the engine, not about the code — it enters the roadmap or `Miny` only as a `POMIAR` executed on dev (the `ALTER` on a `_probe` copy of the table, the request, the dry-run), or it goes into the builder brief labelled HYPOTHESIS with "measure first, both branches: passes / fails — then act".** `POMIAR` (batch 3.1, #687): the roadmap stated the MODIFY passes as a fact; the first run hit errno 1833, the builder stopped, and its 19M input tokens were discarded — triage had measured two premises (the column has an FK; MODIFY keeps the type) and not the third (what InnoDB does to a referenced column), `incident-lessons.md` §Parent class again. Issue already done → ledger row `CLOSED ON HEAD` with evidence, without entering implementation. **HTTP probes against production during triage go only to the documented production domain** (deploy runbook / prod `.env` `APP_URL`), never to a bare LAN IP, and an unexpected `200` becomes a finding only after the response BODY confirms it is the application under test — `POMIAR` (batch 2.3, #531): `192.168.3.2:80` answered `200` for `/.git/HEAD` and looked like an exposed repo; the body was a different SPA with a catch-all `200`, the real domain answered `403` four times. G1 **writes neither plans nor code** — at 40% it spawns G2.

**G2..Gn — phase executors.** Read the roadmap and the ledger **with a single command** (`cat <roadmap> <ledger>`), not two — with a tight budget every tool call counts. Each generation takes the first unclosed phase from the ledger and does **only that** (then applies the end-of-phase rule below).

**One issue = one `task-lifecycle`, cut into relay phases at that skill's own step boundaries.** The generation IS the orchestrator of `task-lifecycle` (it writes no code; every unit of work is a fresh, named subagent spawned with an explicit `model:`, reporting back by `SendMessage` to the generation's name); the relay only decides where the lifecycle may be handed to the next session. The three phases:

- `plan` = **intake, `task-lifecycle` Step 0.** Restate the issue from the fresh anchors, classify its size — **Trivial / Small / Standard / Large** by the criteria of that step (Large = multi-task, 3+ modules, needs design, or the project's own decision tree routes it to a written plan, e.g. more than 3 implementation steps or a regulated/financial domain) — write the task context block, create `agent/issue-<nr>`. Then:
  - **Large** → `/writingplans` with Pass 2 (atomic phase, `hold`) → commit the plan → ledger row → handoff or continue per the end-of-phase rule. `POMIAR` (wave L, 2026-09-11): a plan with Pass 2 costs the generation **12-16 points of window** (start ~14% → 26.2% / 29.7% after the plan), so it fits under `RELAY_WARN` only from a nearly fresh generation — a generation already past ~20% spawns a successor for it (exclusion list, item 3) instead of starting a plan that will be cut off.
  - **any other class** → NO `/writingplans`, NO specialist audit — the ledger row records `Klasa: <class> — <why>` plus the context block, takes minutes, and the same generation proceeds to `exec` (the end-of-phase rule: headroom below `RELAY_WARN`, no exclusion). A plan for an issue that fits in one builder prompt is cost without a decision behind it — measured: two Opus specialists auditing the plan of a 20-line change.

  **Classification is a decision on the anchors, not an exploration.** The generation classifies from the roadmap's hint, the issue text and the triage file list — it does not open the code to "make sure": every file read at intake lands in the orchestrator's window and is paid on every later turn. In doubt take the **cheaper** class (Small↔Standard → Standard; Standard↔Large → Standard) and let the builder produce the evidence: a builder that finds the task needs 3+ modules, more than 3 steps or a design decision **stops and reports that** instead of improvising; the generation then appends a ledger annex `Reklasyfikacja: Standard → Large — <builder's POMIAR>` and runs `/writingplans` (fresh generation if headroom is short). Escalation to Large is always triggered by measured evidence, never by the orchestrator's guess — the guess costs a plan, the evidence costs one aborted builder.

  **Trivial** (copy, CSS, config, docs) keeps the `task-lifecycle` exception: the generation may make the DIRECT edit itself — a spawn for a three-line change costs more than the change — and goes straight to `verify`.
- `exec` = **`task-lifecycle` Steps 1-3** on `agent/issue-<nr>`: build in a specialist subagent (Large: `/executingplans` over the committed plan; the others: one builder prompt carrying the context block and acceptance criteria) → review loop with the skill's caps (Small: a single review pass, or the builder's self-audit where the project's review threshold exempts the diff) → security pass if the triggers match → pre-commit gate per the project's `CLAUDE.md` → commit on the branch. Targeted tests only inside the loop; the full suite once, at the gate, delegated to a subagent (below). `POMIAR` (wave L): an `exec` with the plan already written cost the generation **~5-6 points** (G11: 29.7% → 34.8%; G12: 26.2% → ~32%), `verify` **~2-3 points**. `exec` is NOT atomic, but it has exactly one safe cut point: **after the builder's commit, before the reviewer is spawned.** If `RELAY_WARN` has fired by then, hand off there — ledger row `faza exec (CZĘŚCIOWA — <what is committed>, <what remains> → G<n+1>)`, the successor spawns the reviewer with the diff — instead of starting a review→fix round (atomic, §2) that will not fit before `RELAY_HANDOFF` blocks `Agent`. Three of wave L's exec phases were split exactly there, all because the plan had eaten the window first; with no plan for Small/Standard the split becomes the exception.
- `verify` = **`task-lifecycle` Steps 4-5**: `/verify-e2e` in a fresh subagent, **mandatory for Small, Standard and Large** — a change without a GUI still has a surface in the verify-e2e table (endpoint, CLI, consumer, DB). For **Trivial** the fresh subagent is spawned only when a user-facing surface changed (copy, CSS — the project's `CLAUDE.md` §4c rule); docs/config changes are verified by the generation's own measurement written into the row (`git diff --stat`, the targeted test or latch that covers the file). Then the ledger row with evidence paths, the **tip SHA** and the done-label (§4b).

A **Large** issue taking three or four generations is **normal**; a **Small** one should open and close within one generation — if it does not, the ledger `Miny` field says what ate the window.

**You do NOT pull the full suite's output into your context — you run it in the background with stdout to a file, or delegate it to a subagent.** This applies to `phpunit` without `--filter`, `vitest run`, `npm test` and any run whose output you cannot bound in advance to a few dozen lines. For yourself you keep only targeted runs (`--filter <TestClass>`) — their output is short and needed for a decision in the same turn.

**Preferred form — background run, 0 subagent tokens.** `Bash` with `run_in_background: true`, the command under the project's exclusive slot (`.claude/tmp/phpunit-slot.sh <ABS tree>` in KonkretnyTMS), stdout redirected to `.claude/tmp/<phase>-suite-stdout.txt`. When the notification arrives you read ONLY: `grep -E "<YOUR TEST NAMES>|Configuration:|^Tests:|^OK" <log>`, then `comm -3 <baseline .names> <run .names>`, then the project's CI-parity gate (`scripts/ci-parity-check.sh <names>` = exit 0). `POMIAR` (batch 2.3 vs 2.2): the same full suite delegated to a subagent in 2.2 cost 60–100k tokens per run for a dozen lines of report; the background run in 2.3 cost 0 subagent tokens and ~40 lines of orchestrator context. Delegate to a subagent only where `run_in_background` is unavailable or the run needs a decision mid-way (a slot wait you cannot script).

`POMIAR` (10–11 Sep, 213 sessions, 24,879 turns): an orchestrator generation performs on average 73 `Bash` calls per session, including **10 phpunit/vitest runs**; one full PHP run is ~1.4 MB of output. The cost of a session is `start × N + increment × N²/2`, so output that once enters the context is paid for in EVERY subsequent turn of that generation. `WNIOSEK`: the orchestrator's context is the most expensive place suite output can land — a subagent reads it once and returns a dozen or so lines.

The assignment for the subagent states: the command, the requirement of an exclusive slot (§6) and **the report format — the PHPUnit/Vitest summary line, the list of NAMES of red classes, the path to the full log**. Do not ask for the output to be pasted. Comparing the set of NAMES against the baseline (not the count — `narrow-test-oracle-is-blind`) stays on your side: you do it on the list of names, not on the log.

This is a rule about WHAT you do not pull into context, never about what you do not measure. Skipping the full suite to save context is a mistake more expensive than the run itself.

**End-of-phase rule (deterministic, without asking the owner).** After appending the ledger row and
committing it, re-read the ledger. Take the next phase **in the same session** if ALL
three conditions hold at once:
1. there is a next unclosed phase in the roadmap;
2. current window usage — measured with the `Okno` command from §3, not guessed — plus the phase's cost from §4 stays below `RELAY_HANDOFF`, and the usage itself is below `RELAY_WARN`;
3. the next phase is not on the exclusion list below.

Spawning a successor (§5) is reserved for the case where any of these three
conditions fails — not for the mere fact of closing a phase. The default move of a generation with
window headroom is **to take the next phase**, not to pass it on.

**Exclusion list** — do NOT take the next phase in the same session; spawn a successor instead:
- the phase touches the same file as the phase just closed, and the reviewer is to assess it independently;
- the phase is atomic (§2, `hold`) and does not fit into the reserve up to `RELAY_WARN` — a Large `plan` (12-16 points) practically never fits into a generation that has already done something; an `exec` fits from ≤ ~28% (6 points + the review round that must not be cut);
- the phase requires a different worktree than the current one.

The full suite is deliberately NOT on this list: it runs in the background (or a subagent) under the slot (below) and costs the generation a dozen lines, so "this phase ends with the full suite" — which every `exec` now does — is not a reason to hand off. A slot held by ANOTHER session is a stop condition (§6), not a handoff reason: a successor would wait on the same slot.

`POMIAR` (event 2026-09-05): a generation closed a `verify` phase, used ~0.05% of the window, did not
cross any threshold — and nevertheless stopped, asking the owner whether to take the next phase.
The previous version of this section only mandated "do ONLY it" and described no move for
the state "phase closed, threshold not fired, roadmap not exhausted". `WNIOSEK`: the generation's behaviour
was consistent with the skill of that time — the defect was in the skill, not in the agent; the rule above closes it.

**Under the orchestrator track the generation roles from the table above do not apply** — there are no successive generations, only one long-lived lead session (does not read files, does not write code) and subagents per phase with `isolation: worktree`. Mechanics, the `/goal` format and what the lead does not do → `references/tor-orkiestratora.md`.

## 4a. Choosing the track

Three tracks, chosen at G1, recorded in the roadmap (§3) and justified in ONE sentence:

| Track | When | Who works |
|---|---|---|
| **Relay** (default, §1-§7 below) | everything except the two rows below — including long/atomic phases (§2, `hold`) and batches where phases overlap on the same files | successive sessions, one at a time |
| **Orchestrator** | phases that are SHORT and FILE-DISJOINT — subagents can run in parallel in separate worktrees without collision | one lead session + subagents (`isolation: worktree`) |
| **Cloud** | a batch labelled `cloud-safe` | `claude --cloud`, one session per issue |

The measured advantage of the relay for the owner: it lets several issues be closed without approaching the computer and uses noticeably fewer tokens than the previous arrangement — which is why it stays the default, and the other two tracks are an exception for a specific batch shape, not an equal alternative chosen freely.

**G1 triage labels EVERY issue `cloud-safe` or `local-only`.** `local-only` is at minimum: a dependency on the local MySQL database, on the dev server (`localhost:8080`), on the KSeF sandbox, on files outside the repo (network shares, `Z:\`, `Y:\`). An issue labellable `cloud-safe` may go via the cloud track regardless of which track the rest of the batch takes — the label is per issue, the base track is per batch.

> **A trap measured in a dry run (2026-09-05):** a subagent's worktree branches off from `origin/<default branch>`, **not** from the lead's local HEAD — the lead's pre-push work is invisible to the subagent, and its report still looks correct. There is also no `.env` in the worktree, so "tests green" as an acceptance criterion yields SKIP instead of a result. Details and the remaining measurements → `references/tor-orkiestratora.md`.

The mechanics of the orchestrator track (what the lead does, what the subagent does, the completion condition, how to write ledger rows, what the lead does NOT do) → `references/tor-orkiestratora.md`. §1-§7 of this skill describe the relay track. Under the orchestrator track **ONLY what concerns handing work between sessions does not apply** — i.e. the successor-spawning mechanics from §5, splitting a wave into two parallel relays from §6a **and the
`continuous` mode from §4c** (spawning a curator IS spawning a successor, and under this track there are no further generations —
a new wave is opened by the owner). **The merge ban from §4b applies under every track without exception** — the orchestrator lead merges
just as little as a relay generation, i.e. not at all, and a `claude --cloud` session does not even have the owner's local `main`,
so its only exit would be a push, banned separately. Everything else applies unchanged, and in particular two things that are easy to consider outdated but are not:

- **File-disjointness from §6a applies JUST THE SAME.** Subagents have their own worktrees, but the lead writes the roadmap and the ledger in the SHARED tree — so disjoint slugs, separate ledger files and the ban on two parallel writes to the same file remain in force.
- **Notify the owner via `PushNotification`, never with a message to an agent** (§5). This is a rule about the channel to the HUMAN, not about sequentiality — under this track it is just as binding.

## 4b. Issue completion mode — `branch` only

The chain finishes its work on an issue on `agent/issue-<nr>` and **does not touch `main`** — exactly as `CLAUDE.md` §4c describes. Merging belongs to the owner or to a session the owner is sitting at. The chain delivers a branch, evidence in the ledger and a label; that is where its role ends.

**The `local-merge` mode has been ABOLISHED (2026-09-08, owner's decision).** Do not declare it in the roadmap, do not propose it to the owner and do not recreate the five-condition gate in any form. The reason is mechanical, not stylistic:

- `POMIAR` (wave E, ledger row G10; independently wave G): `git merge` invoked from a background session **bounces off the auto-mode classifier** — a permissions layer of the harness, entirely separate from textual directives and from the consent written down in `CLAUDE.md` §0. A generation has no way around it: only a `! <command>` typed manually by the owner unlocks it.
- `WNIOSEK`: a gate whose last step cannot execute is not a gate — it is a cost paid under it by every generation closing `verify`. The chain measured five conditions and stalled on the sixth, unwritten one. An explicit ban is the better state: a generation does not spend context on measurements that end in calling a human anyway.

**After a green `verify` phase, in the same turn:**

```bash
gh issue edit <nr> --add-label "status:do-scalenia"
```

The `status:do-scalenia` ("to be merged") label ("Done and verified on branch agent/issue-<nr>, waiting to be merged by the owner") is **the only signal by which a curator of a later wave will recognise that an issue is done** — `gh issue list --state open` will still show it, because the chain is not allowed to close issues. Omitting the label costs a full triage of the same issue in the next wave. The ledger row of the `verify` phase MUST give the **SHA of the branch tip**; without it the owner does not know what exactly to merge.

**What the chain must not do — closed list:** `git merge` into `main` (also `--ff`), `git push`, `gh issue close`, deploy, `npm run build`, changing `USE_BUNDLE`, sending to KSeF. "Verified on the branch" means "ready for the owner's review", not "deployed" nor "merged".

**Owner-at-keyboard note — an instruction, not a mode.** When the owner's OWN prompt, in the session they are sitting at (G1, no `claude --bg` in between), explicitly says "merge locally and close each issue", that sentence authorises THAT session to merge with the `[roadmapa]` marker in the merge message and to `gh issue close` — for the issues named in that batch only. This is not something the roadmap declares, not something a generation may infer from the shape of the task, and it does not travel to G2+: a successor is a background session, the classifier from the `POMIAR` above stops it anyway, and a relayed quotation of the owner's consent is not consent (`CLAUDE.md` §4c — the session that received the instruction acts on it, no other). The ledger row quotes the owner's instruction verbatim and the final report still carries both warnings below. Mechanics of the close: write the markdown comment to a file and post it with `gh issue comment <nr> --body-file <path>`, then `gh issue close <nr> --reason completed` — never `--comment "<multi-line markdown>"` inline (`POMIAR` batch 2.4: zsh parse error on the inline body, the close did not happen). `POMIAR` (batch 2.3, 2026-09-15): three issues merged and closed under such an instruction in G1's own window, with the marker, without a single classifier bounce.

**When the owner merges themselves — two things the chain must warn them about in the final report:**

1. **The `[roadmapa]` marker in the merge message.** `POMIAR` (2026-09-06): `tests.yml` fires on push to `main`, `deploy.yml` on `workflow_run` with `conclusion == success` → server webhook; `CLAUDE.md` §2 authorises pushing to GitHub up front, without asking. `WNIOSEK`: a merge is reversible in the tree, but NOT in its effects — it changes what the next routine push will do. That is why `CLAUDE.md` §2 requires checking `git log origin/main..main --merges --grep '\[roadmapa\]'` before pushing `main`, and a non-empty result revokes the consent granted up front. Marker omitted = the chain's work is indistinguishable from the owner's own commits.
2. **The merge order of a wave matters, and a conflict is normal.** `POMIAR` (wave G, 2026-09-08): six branches, each conflict-free against `main` **individually**, produced a conflict at the second merge — two branches independently shifted the same `file:line` anchor register. It is settled by a MEASUREMENT on the tree AFTER the merge (`grep -n` in the merged file), never by picking one side: both numbers were false at that point.

## 4c. Chain mode — `batch` and `continuous`

The roadmap also declares what happens after the list of issues is exhausted:

- **`batch`** (default) — the chain ends together with the roadmap, per §6.
- **`continuous`** — the generation closing the last phase does not end the chain, but spawns a successor in the role of **curator**: a new wave, a new roadmap, a new ledger, the same chain.

Continuous mode introduces one naming change without which waves cannot be counted: the slug has the form `<baza>-w<k>` (`baza` = base name), and the files are `docs/plans/<date>-roadmapa-<baza>-w<k>.md` and `…-w<k>-ledger.md`. You **derive the wave number from git history**, never from memory, from the prompt, nor from a directory listing:

```bash
k=$(( $(git log --diff-filter=A --name-only --pretty=format: -- 'docs/plans/*-roadmapa-<baza>-w[0-9]*.md' \
        | grep -v -- '-ledger\.md$' | grep -c . ) + 1 ))
```

Two traps, both measured 2026-09-06, both yielding a number that looks correct:

- **The glob catches the ledger.** A wave leaves `…-w1.md` **and** `…-w1-ledger.md`, so `ls | wc -l` counts every wave twice: after the first wave `k=3` instead of `2`, after the second `k=5` instead of `3`. The numbers in file names lie (w1, w3, w5…), and the "30 waves" cap fires after sixteen. Hence `grep -v -- '-ledger\.md$'`.
- **`-w*` catches ordinary words.** `POMIAR`: the pattern `*-roadmapa-*-w*.md` returns in this repo
  `2026-09-05-roadmapa-fala-**w**rzesniowa.md` — a `batch`-mode wave, which has no number. Hence
  `-w[0-9]*`, verified with two tools (`git log` and `ls | grep -E`): both give `0` today.
- **A directory listing loses archived files.** `POMIAR`: `docs/plans/zrealizowane/` has 273 files — moving completed plans there is an established practice here. The glob does not descend recursively, so archiving **lowers `k`**: the cap recedes indefinitely, and a new wave gets a number already used. Git history does not lose moves.

A counter kept in context or in `relay-state/` dies with the session and looks like it is working meanwhile — and that is exactly the state in which the wave cap silently stops firing. Count `k` **with two different tools** before you name the wave's files.

### Batch selection by the curator

The curator of a new wave does triage on HEAD per §4 (this applies unchanged) and selects 5-6 issues, in this order of steps:

1. **Stop conditions BEFORE selection** — check them before you count anything (§6).
2. **Candidate set:** `gh issue list --state open` **minus** everything labelled
   `status:do-scalenia` (done and verified by an earlier wave, waiting to be merged by the
   owner), `status:zrobione-lokalnie` (merged by earlier waves, still open because
   the chain is not allowed to close issues), `status:odlozone` (deferred), `tor:remediacja-danych` (data remediation track) — **minus the class of
   ideas, per the section below**.
3. **Order by priority:** `P0` → `P1` → `P2` → `P3`, with the deprecated equivalents
   (`priorytet:krytyczny|wysoki|sredni|niski`) treated as equal; at the end issues **without** a priority
   label — never as a guess "probably medium". `POMIAR` (2026-09-06): 13 of 148 open issues have no
   priority, and `P0`..`P3` and `priorytet:*` do not co-occur on any of the 625 issues, so the mapping
   is unambiguous.
4. **Sift out the deferred:** `--label status:odlozone` drops out of the candidate set. For the rest — a deferral
   check per issue per the two sections below; this is the most expensive step of this skill to skip.
5. **File-disjointness within the batch** per §3: never two issues touching the same table or the same file next to each other.

### Autonomously ONLY fixes — new functionality is the owner's decision

The curator picks on its own only issues describing a **defect, debt or regression**: a bug, an audit finding, dead code, a missing latch, an unapplied migration, a vulnerability. **An idea for new functionality is the owner's decision** and does not enter any autonomously selected wave — even labelled `P1`, even when it sits at the top of the priority list. The owner may point to it explicitly; the curator may not choose it on their behalf.

The sifting goes in two steps, because labels alone are not enough:

1. **By label — exclude unconditionally:** `typ:pomysl` (idea) and its deprecated equivalents on old
   issues (`enhancement`, `new_idea`, `request`), as well as `typ:analysis` ("analysis/decision, no code changes"
   — by definition a human's ruling).

   Labels in this repo have had three axes since 2026-09-06 and a **new** issue carries one of each:
   `modul:*` (what it concerns), `P0`..`P3` (priority), `typ:*` (`typ:bug`, `typ:point-fix`,
   `typ:structural`, `typ:test`, `typ:analysis`, `typ:pomysl`). Old issues were left as they were, so
   the curator must understand BOTH vocabularies: `bug` ≈ `typ:bug`, `enhancement`/`new_idea`/`request` ≈
   `typ:pomysl`, `priorytet:krytyczny|wysoki|sredni|niski` ≈ `P0`..`P3`. Deprecated variants have this
   written into their own description (`gh label list`) — do not guess the mapping from the name.
2. **By content — read the rest.** `POMIAR` (2026-09-06): of 148 open issues **89 have no type label at all** (and 105 have no `modul:*`); the fix class marked with a label is 51, the idea class — 1, `typ:analysis` — 8. A sample of those 89 is almost exclusively audit findings and debt (`[ARCH-*]`, `[DEP-*]`, `[TEST-*]`, dead code, unapplied migration). `WNIOSEK`: a rule "take only what is labelled as a bug" would cut out ~60% of the real fix work, so a missing label does **not** exclude — only the content does.

**The sifting error is asymmetric, and it sets the default answer in case of doubt.** Taking an idea = the chain builds overnight functionality nobody ordered and hands the owner a branch to merge. Skipping a fix = it waits one wave. With genuinely unclear content, **exclude** and enter the issue in the roadmap under "for the owner's decision".

**Mark every exclusion by content with a label** (`enhancement` for an idea) together with a short comment. Without it the next wave reads the same issue from scratch, and eventually one of them reads it cursorily.

### Deferral check

**A deferral is described IN THE ISSUE ITSELF** — the `status:odlozone` label plus a comment stating *what* unblocks it. The label is the machine signal (the curator sifts candidates with it in a single `gh issue list`), the comment is the signal for a human. Prose alone without the label is not enough: the curator reads the list, not every comment.

The obligation lies with whoever defers — the owner, or the chain generation that encounters a condition from the list below. A deferral recorded only in a plan or a runbook is a deferral GitHub does not know about.

```bash
gh label create status:odlozone --color C5DEF5 \
  --description "On hold by decision/observation window — the roadmap curator does NOT take it" 2>/dev/null || true
gh issue edit <nr> --add-label "status:odlozone"
printf '%s\n' "Deferred: <reason>. Unblocked by: <condition>. Source: <file:line>." > .claude/tmp/issue-<nr>-comment.md
gh issue comment <nr> --body-file .claude/tmp/issue-<nr>-comment.md
```

Reasons an issue is deferred:

- a deliberate decision by the owner to exclude it from the wave;
- an observation / measurement window that must elapse — time cannot be made up with agent work;
- a stage plan awaiting a human's ruling;
- the `tor:remediacja-danych` label (by definition "a human's decision") — defers on its own, without `status:odlozone`;
- a requirement for something forbidden by §6 (push, deploy, production, KSeF).

### Latch for pre-existing issues — grep across the repo

The label convention has applied since 2026-09-06 and **does not work retroactively**. `POMIAR` (2026-09-06, issue #592): state `OPEN`, labels `P1`, `typ:structural`, `modul:security`, zero comments about a hold — yet the deferral is recorded in the repo, in two places at once: `docs/plans/zrealizowane/2026-09-05-czas-blokady-edycji-z-serwera-664.md:182` ("#592 is DELIBERATELY excluded from this wave by the owner's decision") and `docs/runbook/23-okno-obserwacji-write-route-enforce-592.md` (observation window). `WNIOSEK`: for an issue created before that date, GitHub is not the source of truth about whether it may be taken now.

Therefore for EVERY candidate without `status:odlozone`, before pulling it into the batch:

```bash
grep -rlnE "#<nr>\b" docs/plans docs/runbook --include='*.md' \
  | grep -v -- '-ledger\.md$' \
  | xargs grep -lE 'ŚWIADOMIE wyłączon|świadomie wyłączon|odłożon|wstrzyman|okno obserwacji|decyzj[ai] właściciela'
```

(The grep terms are Polish: "DELIBERATELY excluded", "deferred", "on hold", "observation window", "owner's decision".)

The filter is part of the rule here, not an optimisation. `POMIAR` (2026-09-06): a bare `grep -rln "#592"` gives **26 files**, because ledger rows have the format `## G<gen> · issue #<nr> · phase …` and live in `docs/plans` — every issue touched by any wave guarantees hits. A mandate "read EVERY hit" with 5-6 candidates would mean over a hundred files, and from 60% of the window `Read`/`Grep`/`Glob` get `deny` (§1). The step called "the most expensive to skip" would then be designed so that skipping it is the only way to fit into the window. `\b` also cuts off `#5921` when searching for `#592`.

A hit describing a deferral → **exclude from the batch, enter into the roadmap as `DEFERRED` with `file:line`, and add the missing label together with a comment** per the block above. Retro-labelling is part of the step, not a courtesy: without it the next wave pays for the same grep again, and eventually one of them skips it.

A `grep` with no hits is a measurement that **the repo says nothing about a deferral** — not a measurement that the issue is ready. A hit read cursorily is worse than no grep, because it gives false certainty.

### The curator is NOT an ordinary generation

The curator writes the roadmap and the ledger of the new wave, and **stops there** — it writes neither plans nor code (§4, G1). The first row of the new ledger contains the measured thresholds and the wave number. It spawns a successor per §5 unchanged.

## 5. Handoff protocol

The order matters — each step protects against a specific, measured harm:

1. **Commit EVERYTHING with a pathspec** (`git commit -m "..." -- <paths>`). The successor works in the same tree and will not see anything you have only in context. Commit with a pathspec: `git commit -m "..." -- <paths>` — in a multi-session tree `git add` alone does not protect, because the index is shared.
2. **Append a row to the ledger and commit it.**
3. **Spawn the successor.** The start prompt IS the delivery of the handoff to the **successor** — a separate `SendMessage` to it is unnecessary. Do not confuse this with the **report to the owner**: the report goes via `SendMessage` and is a separate duty of every generation. Handoff → prompt, report → SendMessage, and a file on disk without being sent is a note, not a handoff:
   **The spawn and the `.gen` write MUST be ONE Bash call** — split into two steps they can be
   skipped. Measured 2026-09-05, run 1: G5 spawned G6 and **did not write `.gen`**; the session knew
   from its prompt that it was the sixth, and the hook counted it as the second. G2, G3 and G4 performed that same step — so
   nothing protects here except the generation's memory:
   ```bash
   OUT=$(claude --bg -n '<slug>-g<n+1>' \
     "You are generation <n+1> of the roadmapa chain. Roadmap: <path>. Ledger: <path>.
      Read BOTH. BEFORE taking a phase check the STOP signal per §6 (two commands, branch and worktree).
      Then take the first unclosed phase and do ONLY that.
      Predecessor: <id> — do NOT remove it." 2>&1); echo "$OUT"
   NEW=$(printf '%s' "$OUT" | grep -oE '\b[0-9a-f]{8}\b' | head -1)
   echo <n+1> > ~/.claude/relay-state/$NEW.gen
   touch ~/.claude/relay-state/$CLAUDE_CODE_SESSION_ID.spawned
   cat ~/.claude/relay-state/$NEW.gen   # read-back confirmation — without it a skip looks like execution
   ```
   The `<own-sid>.spawned` file tells the hook that THIS session has already handed off work — thanks to that the 40
   threshold, which fires later, does not tell it to spawn a successor a second time (measured: at G2 the "spawn
   a successor" injection arrived 2.5 minutes AFTER G2 had already spawned one).
   **Removing the predecessor is an OPTIONAL step, not the default.** By default the successor leaves it in place. Write `remove it: claude rm <id>` only when all of the following hold: the predecessor is a background session (generation ≥ 2), its transcript will no longer be needed, and nobody is attached to it. The reverse order — removal by default with an exception for generation 1 — forces EVERY generation to settle this from memory, and a mistake in one direction is irreversible (it kills the owner's terminal window). Measured in the dry run: both generations had to rewrite that sentence into its negation.
   `$NEW` is the id printed by `claude --bg`. `KTMS_RELAY_GEN` on the command line **does not work**: `POMIAR` 2026-09-05 — `claude --bg` inherits the environment of the *background daemon*, captured at its first start, not of the spawning command; `KTMS_RELAY_GEN=42` gave `2` in the session, and an extra variable did not arrive at all. The same trap applies to attempts to tune thresholds via env in the spawned session — it will not work.

   `<id>` is **the first 8 characters of your `session_id`** (measured: `claude --bg` prints `65dd6e14`, `agents --json` shows `65dd6e14-7d01-...`). **Never remove generation 1** — that is the owner's terminal window.
4. **Confirm the start** (`claude agents --json`), notify the owner and **stop IMMEDIATELY**.

   **"Stop" means: the next tool call after confirming the start is a breach of
   protocol.** Not "finish one more thing", not "add an annex". Measured in run 1, TWICE,
   the same way: G2 spawned G3 at 11:52:46 and kept working until 11:55:30, making along the way commit
   `ea8321625` to the shared tree; G3 spawned G4 at 12:07:50 and kept working for 5 more minutes. At 12:12
   three generations had live transcripts in one tree — exactly the class of harm this
   section closes.

   **Notify the owner via `PushNotification`, never via `SendMessage`.** Measured: three
   generations (G2, G3, G4) sent their report via `SendMessage` to the predecessor's id and **all three
   got `success:false`** ("No agent named '9b01d99a' is reachable") — generation 1's session had already
   closed. The predecessor id you get in the prompt is an address FOR CLEANUP, not the owner's
   address; the owner has no fixed session name, so the only reliable channel is push.

   **Do not report to predecessors.** Measured: G3 sent a report to `roadmapa-wrzesien-g2` and **woke up
   a session sitting at 41% of its window** that had already handed off — adding to its usage without any
   benefit. Findings for successors go into the ledger, not to predecessors.

The chain is **strictly sequential**. Two sessions writing in one tree are a measured class of harm: someone else's file deleted by `cat >`, someone else's unstaged work vanished, a commit hijacking someone else's files.

## 6. Stop conditions

**Successful completion — depends on the chain mode (§4c).** Under `continuous` mode the generation closing
the last phase of the roadmap checks the stop conditions below and — if none holds — spawns a **curator**
of the next wave instead of finishing; the paragraph below describes `batch` mode.

**`batch` mode.** The generation closing the LAST phase of the roadmap **does not spawn a successor** — it writes a ledger row annotated "roadmap exhausted", reports to the owner and stops the chain. It must also write this ban into the successor's prompt… which does not exist, so the duty falls on the EARLIER generation: if you see that after your phase only one remains, tell the successor explicitly "after this phase do NOT spawn another generation". Without that sentence a generation comes into being that opens the ledger and finds no unclosed phase. Measured in the dry run — G2 had to invent that instruction itself.

**Ban on stopping with a question.** Applies from the moment G2 comes into existence. The only exception is before the chain,
not within it: G1 without a provided set of issues MUST ask whether to select them autonomously (§4). After that — no
generation stands idle waiting for the owner's
answer — the owner is not at the keyboard, so an unanswered question is a stop of the
chain without any of the conditions below. In an unforeseen state (matching neither the end-of-phase
rule from §4 nor any item on the list below) the generation: (1) performs the cheapest reversible
action that can be justified from the ledger and the roadmap; (2) records the uncertainty in the ledger row
(the "Mines" field: "unforeseen state — <description>, action taken <action>"); (3) notifies the owner via
`PushNotification`. `POMIAR` (event 2026-09-05): a generation with ~0.05% window usage stopped
the chain with a question whether to take the next phase — exactly the state closed by the end-of-phase rule in §4 together
with this ban. One level down the same ban binds the builder (`task-lifecycle` Step 1): a decision with a documented
precedent in the repo is the builder's to take and cite, not to return as `ambiguous. ask:` — `POMIAR` (batch 3.1, #687):
a builder stopped on `SET FOREIGN_KEY_CHECKS=0/1`, a documented idiom, and hard rule 6 then cost a fresh spawn with a
~50k prefix on top of the 19M already spent.

Stop the chain in an emergency and notify the owner when:
- **stall** — two consecutive generations did not append a `Done` row to the ledger; the task is not converging and the decision belongs to a human.
  **Do not measure silence by a generation's transcript or by `status` from `claude agents` — both lie.**
  Measured: (a) a parent blocked on `Agent` does NOT write its own transcript for a whole
  review round — G6 was silent for 12.5 minutes at zero commits, while two of its reviewers
  were working (transcripts in `<session>/subagents/` written a minute before the alarm); (b) `status: busy`
  persisted for G2 for 13 more minutes after its last API call. Measure liveness by the mtime of
  generation transcripts **and of the `<session>/subagents/` directory**;
- `RELAY_MAX_GEN` reached (default 30);
- **STOP signal raised** — checked by EVERY generation after closing its phase, not only the curator.
  It is the owner's channel to a chain that has no contact with them: the chain finishes the current issue,
  appends a ledger row "stop at the owner's request" and halts. **The check MUST be resistant to
  branch and to worktree** — both commands, one raised is enough:

  ```bash
  test -f ~/.claude/relay-state/STOP-roadmapa && echo STOP        # independent of branch and tree
  git cat-file -e main:docs/plans/STOP-roadmapa 2>/dev/null && echo STOP   # durable, survives relay-state
  ```

  `POMIAR` (synthetic repo, 2026-09-06): a file committed on `main` is **INVISIBLE** via
  `test -f` from branch `agent/issue-1` and from that branch's `git worktree` — and that is exactly the place where
  the `exec` and `verify` phases run (§4) and where §6a says every issue must be kept. A bare
  `test -f docs/plans/STOP-roadmapa` would therefore be a brake invisible to the generations that are supposed to
  press it — vacuously green protection, the same class as thresholds with a wrong denominator (§1b).
  The owner raises the signal most simply via `touch ~/.claude/relay-state/STOP-roadmapa`; the in-repo variant
  is for durability and requires a commit on `main`.
  **An instruction "let this be the last one" given to a live session as a message is NOT enough** — it dies together
  with its context, and the successor will not see it; a generation that receives such an instruction must
  **immediately create that file** (`touch docs/plans/STOP-roadmapa`) and commit it before doing
  anything else. Durable state lives in the repo, not in context (§3);
- **`continuous` mode: the wave number exceeded 30** (`k` counted per §4c).
- **`RELAY_GEN` exceeded `RELAY_MAX_GEN`** — you check this **YOURSELF**, with a command, after closing the phase:
  ```bash
  cat ~/.claude/relay-state/${CLAUDE_CODE_SESSION_ID:0:8}.gen
  ```
  `POMIAR` (2026-09-06): `~/.claude/hooks/relay-post.sh:84` — the condition `[ "$RELAY_GEN" -ge "$RELAY_MAX_GEN" ]`
  sits **inside the `handoff` threshold branch**, so the cap is emitted only when the percentage
  threshold fires. Meanwhile the exclusion list from §4 says to spawn a successor **below the threshold** (a different worktree, an atomic
  phase, an exclusive slot) — a chain handing off work at phase boundaries at a few percent usage
  will pass generation 31, 50, 80 and the hook will not say a word. `POMIAR`: the counter is read from
  `relay-state/<sid8>.gen` (`relay-lib.sh:112-114`), and the generation spawning a successor writes `<n+1>` there (§5) —
  **nothing ever resets it, not even at a new wave.** So `RELAY_MAX_GEN` counts generations **cumulatively
  across all waves**, independently of the wave cap. **Do not "fix" this discrepancy by writing
  `echo 1 > …/<sid>.gen`** — that permanently disables the last generation counter;
- a phase requires something forbidden: a push to `origin`, a deploy, `gh issue close`, sending to KSeF, operations on production;
- the full suite requires an exclusive slot, and other sessions are working in the tree;
- the reviewer reported a `PLAUSIBLE` finding — it comes back as a **two-sided assignment** ("determine whether X or not-X, and state what settles it"), never as a ready fix.

## 6a. Two waves in parallel

The skill describes ONE chain. The owner may want a second one alongside — because the first is going slower than
they assumed. Allowed, but the chain is sequential **with respect to itself**, not to the world, and a second wave
doubles the number of writers in one tree. Conditions without which you must not start:

| what | requirement | why |
|---|---|---|
| slug | **different for each wave** (`fala-wrzesniowa`, `fala-b`…) | the roadmap and the ledger are separate files; two waves appending to ONE ledger is guaranteed loss of rows |
| session names | `<wave-slug>-g<n>` — must differ between waves | two sessions with the same name break addressing and `hold` (§2) |
| issue set | **disjoint**, and at the level of FILES, not numbers | two waves in the same file = someone else's unstaged work disappears |
| worktree | every issue in its own `.claude/worktrees/issue-<nr>` | the main tree has one index for both waves |
| commit | `git commit -m "…" -- <pathspec>` **without exception** | measured with one wave: a commit can hijack someone else's files from the shared index |
| full suite | **neither wave runs it** | there will be no exclusive slot; write that down in the ledger row instead of faking green |

**G1 triage of the second wave must cover the branches of the first**, not only `main`:
```bash
git log --oneline --all --grep "#<nr>"      # --all, because wave 1's work sits on agent/issue-*
git branch -a --contains <fix-commit>
```
Otherwise the second wave takes an issue the first is just closing on its branch — and `main`
does not know about it yet.

There is no collision in `relay-state/`: files are keyed by the full `session_id`, so waves do not see each other there.
There is, however, **no shared generation counter** — `RELAY_MAX_GEN` counts each wave separately.

> This is the only section of this skill that did NOT arise from an event in a run, but from the
> owner's decision to launch a second wave (2026-09-05). The conditions in the table are derived from harms
> measured with ONE wave — not from observing two. The first wave that runs in parallel
> is the measurement of this section.

## 7. Measurement discipline (applies to every generation)

**Search patterns handed to a subagent are literals, not regexes.** Write them to a file and brief `git grep -nF -f <file> -- <paths>` (or `-F -e <literal>`), never a hand-written regex with `\b`, escaped dots or a `$FILES` variable the subagent's shell may not expand. The subagent runs on macOS/zsh, where BSD grep and the ERE escaping rules differ from what the orchestrator typed, and a broken pattern returns the same `0` as a clean file. `POMIAR` (batch 2.5, #620): the reviewer's first three "0 hits" were all tooling (double-escaped ERE, `\b` under BSD grep, `$FILES` unexpanded in zsh) — a dozen calls before the first real measurement. The reviewer's own duty (positive control before trusting a zero) is in `agents/code-reviewer.md`; this rule is about not handing it a broken tool in the first place.

Before naming a measurement as the cause, perform the measurement that would **disprove** the thesis. Mark load-bearing sentences as `POMIAR` (measurement, with a command or `file:line`) or `WNIOSEK` (conclusion); a ledger row with a verdict standing on a `WNIOSEK` is not closed. A latch without mutation proof (green on the code, red under mutation, with a diagnosis naming THIS defect) does not count as done. Perform mutation proofs on a copy loaded via `--bootstrap`, not by mutating the file in the tree.
