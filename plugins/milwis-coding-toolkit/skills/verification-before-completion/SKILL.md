---
name: verification-before-completion
description: "Use before claiming any work is done, fixed, passing, or ready — and before committing, pushing, or creating a PR. Run the verification command in THIS message and read the output before any success claim."
---

# Verification Before Completion

**Core:** Evidence before claims. Always. No exceptions.

**Announce at start:** "I'm using the verification-before-completion skill."

---

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you have not run the verification command **in this very message**, you cannot claim it passes. Previous runs don't count. "Should work now" doesn't count. Agent success reports don't count.

---

## The Gate

Before any statement implying success:

1. **IDENTIFY** — what command proves this claim?
2. **RUN** — execute the full command, fresh, now
3. **READ** — full output, exit code, count failures
4. **VERIFY** — does the output match the claim?
5. **THEN CLAIM** — with evidence inline

---

## What Counts as a Claim

- "Done", "Finished", "Complete", "Ready"
- "It works", "Tests pass", "Build green"
- "Fixed", "Addressed", "Resolved"
- "Implemented", "Shipped"
- "Should work now", "Probably fine", "Looks correct"
- Polish: "gotowe", "działa", "naprawione", "przechodzi", "powinno działać"
- Emojis that imply done (✅)
- Factual assertions about codebase: "system has statuses X, Y", "workflow is A → B → C", "table has columns..."
- Paraphrases count. Synonyms count. Spirit over letter.

---

## Common Claim → Required Evidence

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

---

## When to Apply

- Any phrasing of success / completion / satisfaction
- Committing, pushing, opening a PR
- Marking a TodoWrite item `completed`
- Moving from one group to the next during plan execution
- Telling the user "done"
- Returning results as a subagent

**Applied at group boundaries during plan execution — not per task.** Per-task gating was over-invoking this skill; per-group is where mistakes actually surface without letting bugs propagate.

---

## Integration

- `executing-plans` — runs this gate at each group boundary
- `test-driven-development` — Verify RED and Verify GREEN are this gate
- `systematic-debugging` — Phase 4 "Verify Fix" is this gate
- `code-reviewer` — before reporting "addressed"
- `verify-e2e` — the OUTER gate: this skill proves commands/tests pass, verify-e2e proves the user surface works. User-facing change = both gates.

---

## Bottom Line

Run the command. Read the output. **Then** claim the result.
