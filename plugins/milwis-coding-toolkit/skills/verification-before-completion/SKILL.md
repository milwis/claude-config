---
name: verification-before-completion
description: "Use BEFORE claiming any work is done, fixed, passing, or ready — and before committing, pushing, or creating a PR. Requires running the verification command in THIS message and reading the output before making any success claim. Evidence before assertions, always."
---

# Verification Before Completion

## Overview

Claiming work is complete without fresh verification is dishonesty dressed as efficiency. Trust, once broken, is expensive to rebuild.

**Core principle:** Evidence before claims. Always. No exceptions.

**Announce at start:** "I'm using the verification-before-completion skill."

---

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you have not run the verification command **in this very message**, you cannot claim it passes. Previous runs don't count. "Should work now" doesn't count. Agent success reports don't count.

**Violating the letter of this rule violates the spirit of this rule.** Paraphrases and synonyms count as claims too.

---

## The Gate

Before any statement that implies success, run this loop:

```
1. IDENTIFY: What command proves this claim?
2. RUN:      Execute the FULL command, fresh, now.
3. READ:     Full output. Check exit code. Count failures.
4. VERIFY:   Does the output match the claim?
             - NO  → state actual status with evidence
             - YES → state claim WITH evidence inline
5. ONLY THEN: Make the claim.
```

Skipping any step = lying, not verifying.

---

## What Counts as a Claim

The rule applies to ALL of these, not just literal phrases:

- "Done", "Finished", "Complete", "Ready"
- "It works", "It passes", "Tests pass", "Build green"
- "Fixed", "Bug fixed", "Addressed", "Resolved"
- "Implemented", "Shipped", "Ship it"
- "Great!", "Perfect!", "Nice!" (implicit satisfaction = implicit claim)
- "Should work now", "Probably fine", "Looks correct"
- Any Polish equivalents: "gotowe", "działa", "naprawione", "przechodzi", "powinno działać"

---

## Common Claim → Required Evidence

| Claim | Required evidence | NOT sufficient |
|---|---|---|
| Tests pass | Test command output, 0 failures, this turn | Previous run, "should pass" |
| Linter clean | Linter output, 0 errors, this turn | Partial scope, extrapolation |
| Build succeeds | Build command, exit 0, this turn | Linter passing, "it compiled earlier" |
| Bug fixed | Test reproducing original symptom passes | Code changed, assumed fixed |
| Regression test works | Red → revert fix → red → restore fix → green | Test passes once |
| Requirements met | Line-by-line checklist vs. spec | Tests passing |
| Subagent completed | `git diff` / `git status` shows expected changes | Agent's "success" report |

---

## Red Flags — STOP Before You Type

Watch for these thought patterns. All of them mean "run the verification first":

- "Should work now"
- "I'm confident"
- "Linter passed, so build must pass"
- "Agent said success, so it's done"
- "Just this once"
- "I'm tired, let's just commit"
- "Partial check is enough"
- "Different words, so the rule doesn't apply"
- Any urge to express satisfaction before you've seen the output

---

## Rationalization Table

| Excuse | Reality |
|---|---|
| "Should work now" | Run it. |
| "I'm confident" | Confidence ≠ evidence. |
| "Just this once" | No exceptions. |
| "Linter passed" | Linter ≠ compiler. |
| "Agent said success" | Verify with `git diff`. |
| "I'm tired" | Exhaustion ≠ excuse. |
| "Partial check is enough" | Partial proves nothing. |
| "Different words, so the rule doesn't apply" | Spirit over letter. |
| "It worked five minutes ago" | Run it now. |

---

## Patterns

**Tests:**
```
✅ [run npm test] [see: 34/34 pass, exit 0] → "All tests pass (34/34)"
❌ "Should pass now" / "Looks correct"
```

**Regression test (red-green cycle):**
```
✅ Write test → run (fails) → apply fix → run (passes) →
   revert fix → run (MUST fail again) → restore fix → run (passes)
❌ "I wrote a regression test" (without red-green proof)
```

**Build:**
```
✅ [run build] [exit 0] → "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**PHP syntax check (for PHP projects):**
```
✅ [run `php -l path/to/file.php`] [see: No syntax errors] → "PHP syntax OK"
❌ "I only edited strings, it must be fine"
```

**Subagent delegation:**
```
✅ Agent reports success → [run git diff] → inspect changes → report actual state
❌ "Agent finished, task done"
```

**Requirements checklist:**
```
✅ Re-read plan → build checklist → check each box → report gaps or completion
❌ "Tests pass, phase complete"
```

---

## When To Apply

**ALWAYS before:**
- Any phrasing of success / completion / satisfaction
- Committing, pushing, opening a PR
- Marking a TodoWrite item as `completed`
- Moving to the next task
- Telling the user "done"
- Returning a result to the parent when acting as a subagent

**Applies to all forms of communication:** exact phrases, paraphrases, synonyms, implications, Polish translations, emojis that imply done (✅), and anything else suggesting the work is in a good state.

---

## Integration With Other Skills

- **executing-plans** — runs this gate at every "Incremental Verification" step and before marking any TodoWrite item complete.
- **test-driven-development** — the Verify RED and Verify GREEN steps are instances of this gate.
- **systematic-debugging** — Phase 4 "Verify Fix" is this gate.
- **code-reviewer agent** — when acting on review feedback, run this gate before reporting "addressed".

---

## The Bottom Line

Run the command. Read the output. **Then** claim the result.

No shortcuts. Non-negotiable.
