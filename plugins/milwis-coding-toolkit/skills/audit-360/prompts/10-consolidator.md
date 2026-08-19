# Prompt for `code-reviewer` (CONSOLIDATION pass, model: opus)

Run AFTER all specialists return AND the critical-stop gate clears. The opus model is mandatory — dedup and axis mapping require deeper reasoning than sonnet.

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: code-reviewer
description: Audit-360 consolidation — final report
prompt: |
  You are the consolidator for the audit-360 of the application in
  <INVENTORY_PATH>. Model: opus. Operate under `verification-before-completion`.

  TASK:

  STEP 1 — Read EVERY findings file:
     audit/findings/01-security-backend.md
     audit/findings/02-php-deep.md (if present)
     audit/findings/03-js-deep.md (if present)
     audit/findings/04-sql.md (if present)
     audit/findings/05-db-perf.md (if present)
     audit/findings/06-architecture.md
     audit/findings/07-ai-specific.md
     audit/findings/08-tests.md
     audit/findings/09-deps-docs.md (if present)
     ... (any other NN-<area>.md the orchestrator created)

  STEP 2 — Deduplication:
     same finding from 2+ specialists ⇒ one entry with
     "Cross-confirmed by: SEC-BE-007, AI-013, PHP-022".
     Cross-confirmed automatically escalates one tier (P1 → P0).

  STEP 3 — Map to your 5-axis framework
     (Correctness / Readability / Architecture / Security / Performance):
     - one main axis per finding
     - severity mapping:
       🔴 CRITICAL → P0
       🟡 REQUIRED → P1
       🔵 OPTIONAL → P2
       ⚪ NIT     → P2
       ℹ️ FYI    → appendix only

  STEP 4 — Escalation rules (SKILL.md §6):
     Escalate P1 → P0 when:
     - financial / regulated / PII data involved (per INVENTORY §5)
     - violates a hard-rule from INVENTORY §9
     - occurs ≥3 times in the codebase
     - cross-confirmed by ≥2 specialists
     De-escalate P0 → P1 when:
     - endpoint behind auth + admin only + monitored + small blast radius
     - debugger marks as NOT_REPRODUCED or THEORETICAL after 3 attempts.

  STEP 5 — Generate audit/REPORT.md per format SKILL.md §7.

  STEP 6 — Generate audit/FIX_PROPOSALS.md:
     one fix per P0/P1 (P2 description-only). Each fix:
       * file:line
       * before/after diff
       * test to write (TDD: failing first)
       * estimated effort (minutes/hours)
       * risk of introducing regression (low/medium/high)

  STEP 7 — Executive summary at the top of REPORT.md:
     - finding counts P0=X, P1=Y, P2=Z
     - top 3 risks (with concrete file paths)
     - deploy recommendation: GO / NO-GO / GO-WITH-FIXES
     - estimated effort to fix P0+P1
     - per-integration risk map (table from INVENTORY §5)

  STEP 8 — Per-specialist statistics: how many findings each specialist
     contributed (raw before dedup, count after dedup, escalations).

  STEP 9 — Strengths section: what the code does WELL — be specific
     (file paths, counts), not generic ("good security practices").

  RULES:
  - Every P0 in the report MUST have an evidence quote (already in
    findings files).
  - Apply the 5-axis discipline — every finding has a concrete axis label.
  - Verdict: one CRITICAL = ❌ CHANGES REQUIRED, no exceptions.

  --- TWO MANDATORY POST-WRITE SELF-CHECKS ---

  CHECK A — Numeric consistency:
     `grep -c '^### P0-' audit/REPORT.md`
     `grep -c '^| P1-'  audit/REPORT.md`
     `grep -c '^| P2-'  audit/REPORT.md`
     If executive summary numbers don't match these counts ⇒ FIX before
     finalizing. Audit consolidations regularly miscount by 30%+ when this
     check is skipped.

  CHECK B — Fix-proposal hallucination:
     For every recommended class/method/package in FIX_PROPOSALS.md:
     - if PHP class/method: `grep -rn 'class FooService\|function foo' .`
     - if npm package: `npm view <pkg>`
     - if composer package: `composer show <pkg> 2>/dev/null`
     If zero hits / 404 ⇒ the fix proposal references a hallucinated API.
     Replace with a real one or mark the finding as "fix proposal pending —
     no canonical method exists in this codebase, requires implementation
     of <name> first".

  Output: audit/REPORT.md + audit/FIX_PROPOSALS.md.
```

---

## Addendum (2026-08-19) — lessons from a real audit's self-review FAIL

1. **Path fidelity:** copy every file path VERBATIM from the source findings files. Never rewrite, normalize, or "correct" a path — in a real audit the source modules had the path right and the consolidation invented a plausible wrong one, which then propagated into FIX_PROPOSALS.
2. **CHECK B is mechanical, not curated:** extract ALL symbols from your proposed diffs (function/method calls, class names, constants, file paths) and verify each — existence via grep, full SIGNATURE for functions called with arguments (arg-count mismatch = production TypeError), file paths via `git ls-files`, and each cited `file:line` must contain the quoted code (`sed -n '<line>p'`). A hand-picked verification list is how hallucinations survive.
3. **Number propagation:** any figure corrected anywhere in the document must be updated in the header and executive summary too. A resolution at the bottom with a stale number at the top is the exact "copied invariant" defect this audit flags in projects.
4. **Blast radius of every fix:** before labeling a fix "zero risk", trace what else the touched rule/file serves (e.g. blocking `vendor/` also blocks `vendor/js/` frontend assets). A fix that disables production is not Partia 0.
