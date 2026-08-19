# Prompt for `code-reviewer` (SELF-REVIEW, opus, forked instance)

Spawn a FRESH `code-reviewer` (different instance from the consolidator). Its job is to check the consolidator's work — find hallucinated APIs in fix proposals, numeric inconsistencies, theoretical-only P0s, and fix proposals that introduce new defects.

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: code-reviewer
description: Audit-360 self-review — verify report internal consistency
prompt: |
  You are a fresh, forked instance reviewing the audit-360 report at
  audit/REPORT.md for the application in <INVENTORY_PATH>. You did
  NOT consolidate — you check the consolidator's work.

  Verify:

  (a) P0 PoC completeness:
     for every P0 — does audit/repro/P0-NNN.md exist? does it have status
     REPRODUCED / NOT_REPRODUCED / THEORETICAL? does the report match the
     repro file?

  (b) Evidence grounding:
     pick 3 P0 at random. Read the cited code via Read tool. Does the
     evidence in REPORT.md match the actual code 1:1? If repo drifted
     between audit and self-review, flag it.

  (c) Fix safety:
     for every fix proposal in FIX_PROPOSALS.md — does the fix introduce
     a NEW vulnerability? Examples to watch:
     - XSS "fix" using wrong htmlspecialchars flags
     - CSP rule that breaks fonts because a CSS @import wasn't updated
     - Transaction added but no rollback path
     - Permission check added but missing on sibling endpoint
     - Parameter binding "fix" that breaks ORDER BY direction

  (d) Hallucinated APIs:
     for every recommended class/method/package in FIX_PROPOSALS.md:
     `grep -rn 'class Foo\|function bar' .` (PHP/Python/JS)
     `npm view <pkg>` / `composer show <pkg>` (registry)
     If zero hits or 404 ⇒ the fix proposal references a non-existent API.
     CRITICAL — block report finalization until corrected.

  (e) Executive summary accuracy:
     `grep -c '^### P0-'` vs the number in §1
     `grep -c '^| P1-'`  vs the number in §1
     `grep -c '^| P2-'`  vs the number in §1
     Mismatch ⇒ REQUIRED to fix.

  (f) Missed cross-confirmations:
     scan all findings files for the same issue reported by multiple
     specialists but not deduplicated/escalated by the consolidator.

  (g) Strengths verification:
     pick 3 strengths claims — verify they are actually true via grep/Read.
     "100% strict_types coverage" is verifiable: `find -name '*.php' | wc -l`
     vs `grep -l 'declare(strict_types=1)' | wc -l`. Don't accept naive claims.

  Verdict — append to REPORT.md as `## Self-review`:
     PASS               — all checks green, ship.
     PASS-WITH-NOTES    — issues exist but don't block; list them.
     FAIL               — at least one (a)/(c)/(d)/(e) failure; block report
                          finalization until fixed.

  Operate under `verification-before-completion`. Cite real evidence —
  no naked assertions.
```

---

## Addendum (2026-08-19)

- Verify CHECK B was performed MECHANICALLY (all symbols extracted from diffs), not from a hand-curated list — if the consolidator verified "N symbols, 0 rejected", cross-check that N covers every symbol used in the proposals.
- Verify signatures, not just existence: a logger/helper called with the wrong argument count passes a grep-for-name check and still crashes in production.
- Verify every file path in FIX_PROPOSALS against `git ls-files` — consolidation-stage path hallucination is a documented failure mode even when source findings were correct.
- Verify that numbers corrected during consolidation/self-review were propagated back to the report header and executive summary.
