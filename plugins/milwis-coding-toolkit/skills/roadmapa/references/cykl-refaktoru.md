# The refactor cycle — one agent, one goal: old and new behave 1:1

Owner decision 2026-11-13 (claude-config, after #27/#51/#58): the refactor procedure is as simple as possible. One
agent session does the whole refactor of one file by itself, then keeps fixing the code under `/goal` until the
equivalence rig shows old and new behave identically. The KARTA, the refactor gate, the supervisor-directory hook and
the blind grading rubric were removed in v1.13.0. The only proof that counts is testing before and after.

## What makes it safe

1. **The equivalence rig** (KonkretnyTMS: `stanowisko`, run through `.claude/tmp/stanowisko-slot.sh`) runs the same
   scenarios on the old and the new code and compares responses and the database. Verdict `IDENTYCZNY` with exit 0
   and the coverage gate passing is the 1:1 proof.
2. **The full test suite** (KonkretnyTMS: `.claude/tmp/phpunit-slot.sh`): the set of red test names equals the
   baseline taken before the refactor.
3. **The measure is untouched.** The agent must never change the rig, its scenarios, masks or the existing tests to
   make them pass. One command checks it: `git diff --stat <old SHA>..HEAD -- <rig paths> tests/` lists only test
   files the agent added (new tests are allowed, edits and deletions of existing ones are not).

## Steps

1. **Before (supervisor).**
   - Worktree and branch from the base branch (`main_dev`). The old SHA = its HEAD.
   - Rig calibration on the old SHA (old vs old): `IDENTYCZNY`, exit 0, coverage gate passes. Without that the rig
     cannot judge this file: add scenarios first (a separate task), then start.
   - Full-suite baseline: the file of red test names.
   - Issues in the queue that touch the file get `status:odlozone` with a comment until the refactor merges.
2. **The task (one session, `hc run`).** The prompt is the goal below, followed by the spec: target structure
   (modules/classes and what moves where), the project's design rules, and the form rules — no history in comments
   ("previously", "now", issue numbers), one rule in one place, no dead code left behind.
3. **The goal** — the session's first prompt, filled in:

   ```
   /goal Refaktor <file> skończony: w tej rozmowie, dla obecnego HEAD i czystego drzewa, widać wynik
   (1) `<rig> --plik=<file> --stary=<old SHA> --nowy=HEAD` z „Werdykt: IDENTYCZNY” i kodem 0;
   (2) pełnej suity przez `<suite slot>` ze zbiorem czerwonych nazw równym `<baseline file>` (pokaż `comm`);
   (3) `git diff --stat <old SHA>..HEAD -- <rig paths> tests/` bez zmian ani usunięć istniejących plików.
   Albo minęło 40 tur — wtedy raport, czego brakuje.
   ```

   Rules for the agent (in the prompt, after the goal): refactor first, then run the rig; on any difference fix the
   production code, never the measure; a difference that is a real bug in the OLD code is not fixed — keep the old
   behaviour and report it; commit after every green step.
4. **After (supervisor, three commands, from the supervisor's own tree, not the agent's).** The rig on the final SHA,
   the suite against the baseline, the `git diff --stat` of the measure. Then one fresh `code-reviewer` against the
   spec. REQUIRED findings go back to the same session with the same `/goal`.
5. **Merge** to the base branch, remove `status:odlozone` from the deferred issues.

## Several files at once (2–3)

- One file = one worktree, one branch, one session, one `/goal`. The files must not share code that the refactor
  moves (check before the start: the spec of each names its paths; overlapping paths → not in parallel).
- The rig and the full suite run one at a time through their slots, so parallel sessions queue on them. While
  iterating, a session uses its own fast checks (the file's unit tests, a PHPUnit filter); the full rig and the full
  suite are for the goal's final check. Three files is the practical ceiling: beyond it the slot queue costs more than
  the parallelism gains.
- Merge one branch at a time. After each merge the remaining branches are rebased on the base branch and the
  supervisor repeats step 4 for them before their merge.

`/goal` is judged by a small model from what the session showed, not by exit codes. That is why step 4 repeats the
three checks independently; the agent's own "met" is never the verdict.
