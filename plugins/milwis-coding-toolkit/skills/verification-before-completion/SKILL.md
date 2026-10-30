---
name: verification-before-completion
description: "Use before claiming any work is done, fixed, passing, or ready — and before committing, pushing, or creating a PR. Run the verification command in THIS message and read the output before any success claim."
---

# Verification Before Completion

**Goal.** Every claim that something is done, fixed, passing or true of the codebase rests on output you produced
and read in this message. Earlier runs, "should work now" and a subagent's success report are not that output.

**Entry:** about to state that anything is done / fixed / passing, mark a todo completed, commit, push, or open a PR.
**Done when:** the proving command ran in THIS message, its full output was read, and the claim matches it — with pass AND skip counts, or an exact BLOCKED/unavailable statement instead of a claim.

## The gate

Before any statement implying success:
1. **Identify** the command that proves the claim.
2. **Run** it in full, now.
3. **Read** the whole output: exit code, failure and skip counts.
4. **Compare** the output with the claim.
5. **Claim** only what the output shows, with the evidence inline.

## What counts as a claim

- "Done", "Finished", "Complete", "Ready"
- "It works", "Tests pass", "Build green"
- "Fixed", "Addressed", "Resolved"
- "Implemented", "Shipped"
- "Should work now", "Probably fine", "Looks correct"
- Polish: "gotowe", "działa", "naprawione", "przechodzi", "powinno działać"
- Emojis that imply done (✅)
- Factual assertions about codebase: "system has statuses X, Y", "workflow is A → B → C", "table has columns..."

Paraphrases and synonyms count the same.

## Claim → required evidence

| Claim | Required evidence |
|---|---|
| Tests pass | Test command output this turn, 0 failures |
| Linter clean | Linter output this turn, 0 errors |
| Build succeeds | Build command, exit 0, this turn |
| Bug fixed | Test reproducing original symptom passes |
| Regression test works | Red → revert fix → red → restore fix → green |
| Requirements met | Line-by-line checklist vs. spec |
| Subagent completed | `git diff` / `git status` shows expected changes |
| Codebase fact stated | Grep/Read output confirming the fact exists |
| User-facing change works | `verify-e2e` PASS from a fresh subagent, with evidence artifacts |

## When to apply

- Any phrasing of success / completion / satisfaction
- Committing, pushing, opening a PR
- Marking a TodoWrite item `completed`
- Moving from one group to the next during plan execution
- Telling the user "done"
- Returning results as a subagent

**Applied at group boundaries during plan execution, not per task.** Per-task gating was over-invoking this skill;
per-group is where mistakes actually surface without letting bugs propagate.

## Integration

- `executingplans` — runs this gate at each group boundary
- `test-driven-development` — the red and green runs are this gate
- `systematic-debugging` — Phase 4 "Verify Fix" is this gate
- `code-reviewer` — before reporting "addressed" (it measures its own findings; this skill reaches it only through its brief)
- `verify-e2e` — the OUTER gate: this skill proves commands/tests pass, verify-e2e proves the user surface works. User-facing change = both gates.
