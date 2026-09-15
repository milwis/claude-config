---
name: retro
description: "Retrospective on a finished roadmapa wave, issue-pipeline batch, or single session: read the ledger and the subagent transcripts, find where tokens and quality were lost, and propose changes to the toolkit's skills/agents/hooks — every proposal with a POMIAR (command or file:line) and the rule it changes. Run after the wave, never inside it."
disable-model-invocation: true
---

# Retro (wave → toolkit changes with measurements)

**Core:** The toolkit improves only from measured runs. A retro turns one finished run into a short list of rule changes, each anchored to the transcript line or ledger row that justifies it — the same shape as the A–L corrections of 2026-09-15. Proposals without a POMIAR are opinions and do not enter `UPDATE_LOG.md`.

**Entry:** the user names a wave / batch / session (ledger path, date, or "the last one"). Default: the most recent roadmapa ledger under `docs/plans/`.
**Stop:** the user has a ranked list of candidates, each with POMIAR + affected file + proposed rule text, and has chosen which to apply. Applying them is a separate step (this skill edits nothing in the toolkit on its own).

---

## Step 1: Primary sources, not memory

Read, in this order, and keep every number with the command that produced it:

1. **The ledger** (`docs/plans/<date>-roadmapa-…-ledger.md` or the issue-pipeline status table): per phase — window % at start/end, subagents spawned, `POMIAR`/`WNIOSEK` rows, what was left `NIE zmaterializowane`, every `CZĘŚCIOWA` handoff, every cap exhausted, every BLOCKED.
2. **Subagent transcripts** for that run: `~/.claude/projects/<project-slug>/*.jsonl`, filtered by the run's date range. Per subagent, extract with a script (never by reading the JSONL in context): model, turn count, max context (`.message.usage` cache-read + input), tool-call histogram (`Read`/`Grep`/`Bash`/`Agent`), re-reads of the same file, first and last user-facing message. Write the table to `.claude/tmp/retro-<date>.tsv` and read only the table.
3. **The diff of the run**: `git log --oneline <base>..<tip>` per branch, `git diff --stat`, review iterations per issue (count reviewer spawns), verify verdicts.
4. **The toolkit as it was**: the plugin version in `UPDATE_LOG.md` that the run used — a rule that already exists in a newer version is not a proposal.

---

## Step 2: Hunt in seven categories

For each category, look for the evidence named under *Use when*; skip the category when the evidence is absent — an empty category is a finding too.

| Category | Use when the sources show | What the proposal changes |
|---|---|---|
| **Navigation** | a subagent spent many calls finding one fact; the same file re-read across subagents; a builder searched for an artifact that "existed" only in a report | a context pointer in the task context block, a `file:line` anchor rule, a `CLAUDE.md` navigation line in the project |
| **Automated checks** | a reviewer or verifier caught what a lint/type/latch/probe could have caught earlier; a defect class recurred across issues | a latch test, a pre-commit gate, a `scripts/*.sh` probe — mechanical beats prose |
| **Coding standards → reviewer** | the reviewer missed a class of defect, or a builder was told a rule the reviewer should own instead (the builder carries the context pressure; the reviewer reads a diff) | a row in `code-reviewer`'s tables or discipline overlay, not a new builder paragraph |
| **Tool economy** | one subagent cost an outlier share of the run's tokens; a full suite delegated instead of backgrounded; an agent resumed instead of respawned; a plan written for a Small issue | a threshold, a cap, a "do this inline" exception, a `run_in_background` rule — with the measured before/after |
| **No-ops and sediment** | a rule in a skill/agent that no transcript shows changing behaviour; a paragraph restating what the environment already says (`package.json` scripts, `--help`, config); a NEVER that reads as an instruction to do the thing | delete the sentence (whole sentence, not trimmed words), or rewrite the prohibition as the positive target behaviour |
| **Information access** | BLOCKED verdicts; a verifier without a test account/port/browser; logs the builder could not see | a `docs/VERIFICATION_ENV.md` entry, a teed log, a read-only credential |
| **Relay mechanics** (roadmapa only) | a threshold fired too early/late; a `hold` forgotten; a handoff row missing a path; a successor that re-explored | a rule in `roadmapa/SKILL.md` — remember the project's latch test on that file |

---

## Step 3: Rank and write the candidates

Order by measured cost of the failure (tokens, hours stalled, defects escaped), not by how easy the fix is. For each candidate:

```
### <letter> — <one-line rule>
POMIAR: <command or ledger row / transcript line, with the number>
Where: <toolkit file and section>  |  Version it targets: <next plugin version>
Rule text: <the sentence(s) to add / delete / replace — final wording, positive phrasing>
Cost of the rule: <tokens added per invocation, or "removes N lines">
Not proposed because: <optional — a tempting change the evidence does not support>
```

Constraints from `UPDATE_LOG.md`'s maintenance policy apply to every candidate: no `model:` frontmatter changes, no news sections, rules only. A candidate that changes `roadmapa/SKILL.md` names the latch phrase it must keep.

---

## Step 4: Present, then stop

Show the ranked list and ask which to apply. The apply step is ordinary toolkit editing: the rule goes into the named file, the `UPDATE_LOG.md` entry cites the same POMIAR, the plugin version bumps. Do not apply anything the user did not pick, and do not "tidy" neighbouring rules while there.

---

## Integration

- `task-lifecycle` hard rule 5 ("manual step spotted twice → automate it") is the in-flight version of this skill; retro is the batch version.
- `lang-guidelines` — the pruning lens (no-ops, sediment, positive phrasing, cache-vs-environment) is the same one used when creating or updating an agent.
- `roadmapa` §7 measurement discipline — POMIAR / WNIOSEK labels are mandatory here as there.
