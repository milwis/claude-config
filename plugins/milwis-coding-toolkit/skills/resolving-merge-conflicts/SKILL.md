---
name: resolving-merge-conflicts
description: "Use when a git merge, rebase, or cherry-pick is in progress with conflicts — typically when merging a wave's agent/issue-* branches into main. Resolves hunk by hunk by the INTENT of each side traced to primary sources (commit message, issue, ledger row, plan), never invents behaviour, never --abort, then runs the project's checks and finishes the operation."
---

# Resolving Merge Conflicts

**Core:** A conflict is two intents meeting in one hunk. Resolve by intent, not by picking the longer side. Every intent is read from its primary source; nothing new is written into the merge.

**Entry:** `git status` shows an in-progress merge / rebase / cherry-pick with unmerged paths.
**Stop:** the operation is finished (merge committed, rebase continued to the end), the project's checks pass on the result, and every non-trivial resolution is listed in the report with its trade-off.

---

## Step 1: See the state

```bash
git status                       # which operation, which files
git log --oneline -5 HEAD        # our side
git log --oneline -5 MERGE_HEAD  # theirs (rebase: REBASE_HEAD / the commit being replayed)
git diff --name-only --diff-filter=U
```

Record the base: `git merge-base HEAD MERGE_HEAD`. Enable `git config merge.conflictStyle diff3` for this operation if it is not set — the base hunk is what tells you which side changed what.

---

## Step 2: Find the primary source of each side

For each conflicting file, before touching a hunk:

- **Our side:** the commit(s) that last changed the region (`git log -L<start>,<end>:<file> HEAD`), their messages, the issue / plan / ledger row they cite.
- **Their side:** the same on `MERGE_HEAD`. For a roadmapa branch the ledger row of that issue (`Zrobione:` with commit SHAs) says what the change was for.
- **The intent of the merge itself:** what the user asked for ("merge the three wave branches", "rebase onto main"). Where the two sides are incompatible, this is the tie-breaker.

Comments in the code are not a source of intent when they contradict the commit or the issue — the commit is what was decided.

---

## Step 3: Resolve each hunk

- Preserve **both** intents when they touch different concerns in one hunk (two new methods, two new rows in a table, two guards) — keep both, in the order the base suggests.
- When both sides changed the same line for different reasons, pick the one that matches the merge's stated goal and **write the trade-off down** for the report.
- Do **not** invent a third behaviour, "improve" the code while there, or drop a guard because it looks redundant — a guard only one side has is usually that side's whole fix.
- Generated or lock files (`composer.lock`, `package-lock.json`, build artifacts): take the side that will be regenerated, then regenerate; never hand-merge them.
- Do not `--abort`, `--skip` a commit, or `checkout --ours/--theirs` a whole file as a shortcut. If a hunk cannot be resolved without a decision only the user can make (two contradicting business rules), stop with the hunk quoted and both intents named — that is the one allowed pause.

After each file: `git diff --check` (no leftover markers), then stage it.

---

## Step 4: Run the project's checks

In the order the project documents (`CLAUDE.md`, CI config), typically: syntax check of every touched file (`php -l`, `node --check`, `python -m py_compile`) → typecheck / lint → targeted tests of the touched areas → the full suite where the merge touches shared code (on a shared dev DB, under the project's exclusive slot; `run_in_background`, read only the summary lines). Report pass AND skip counts. Anything the merge broke is fixed in the merge, not deferred.

`verification-before-completion` governs the claim: no "merged cleanly" without the check output in the message.

---

## Step 5: Finish the operation

- **Merge:** commit with the project's merge-message convention (e.g. a `[roadmapa]` marker when merging chain branches — the project `CLAUDE.md` says whether one is required and what it changes downstream, such as a deploy workflow).
- **Rebase:** `git rebase --continue` and repeat Steps 1–4 for every further conflicting commit until the rebase completes.
- Never push as part of this skill; pushing `main` is the user's call, and for roadmapa branches the project's push rules apply.

Report: files resolved, each non-trivial resolution with the intent chosen and the trade-off, check results with counts, and the final SHA.

---

## Integration

- `roadmapa` §4b — the chain never merges to main; this skill is the owner's step after a wave, run by the owner's session.
- `verification-before-completion` — the gate on every "merged / tests pass" claim in the report.
- `systematic-debugging` — when a test breaks only on the merged result and neither side explains it.
