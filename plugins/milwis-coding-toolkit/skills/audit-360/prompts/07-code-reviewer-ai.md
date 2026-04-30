# Prompt for `code-reviewer` — AI-specific deep scrutiny

This is the longest specialist prompt. The `code-reviewer` agent runs in `opus` for this pass — deeper analysis is the whole point.

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: code-reviewer
description: AI-specific deep scrutiny — slopsquatting, fake APIs, confabulation
prompt: |
  You are auditing the application in <INVENTORY_PATH> for patterns
  characteristic of LLM-generated code (Claude Code, Copilot, Cursor).
  Mode: READ-ONLY. Model: opus.

  Go DEEPER than the other specialists — this is your "AI-Generated Code
  Extra Scrutiny" module from your system prompt.

  19 categories:

  1. SLOPSQUATTING / PACKAGE HALLUCINATION (P0): every package in
     composer.json / package.json / requirements.txt verified against the
     official registry. Packages <30 days old, <1000 weekly downloads,
     unknown author, near-typo of popular names = P0.

  2. FAKE API ENDPOINTS: cross-check every external URL against the
     documentation of the integration listed in INVENTORY §5. LLMs
     invent URLs that don't exist.

  3. UNFINISHED CODE: TODO, FIXME, XXX, HACK, "implementation here",
     `throw new Exception('not implemented')`, `pass  # TODO`,
     `return null;  // placeholder`.

  4. FAKE MOCK FUNCTIONS — looking real, doing nothing:
     `function verifySignature() { return true; }`
     `function authenticate($u, $p) { return true; /* TODO real auth */ }`
     `function isValid() { return $x !== null; }` (name suggests domain validation)
     Each occurrence with auth/payment/security-suggesting name = P0.

  5. HARDCODED VALUES / FAKE CREDENTIALS:
     api_key, secret, password, token, sk_test, sk_live in source.

  6. EVAL / SHELL_EXEC with user input (RCE = P0).

  7. RACE CONDITIONS the AI doesn't see:
     SELECT count → if count==0 → INSERT without transaction = race;
     file write without flock; counter increments without atomicity.

  8. CATCH-ALL ERROR HANDLING:
     `catch (\Exception $e) {}` (silent); `catch (\Exception $e) { return null; }`
     (lossy); except: pass.

  9. CONFABULATION IN COMMENTS (comment ≠ code):
     sample 50 functions manually — does the docblock match the body?
     "Validates VAT EU number" but body checks length 10 only.

  10. LONG-CONTEXT DEGRADATION:
      files >1500 LOC where the second half contradicts the first;
      same-name functions in different conventions inside one file.

  11. OVER-ENGINEERING:
      5 abstraction layers for CRUD, factories of factories, single-impl interfaces.

  12. UNDER-ENGINEERING (happy path only):
      validation only positive (`if ($x) doSomething()`); missing fallback for integrations.

  13. AI-SQL BUGS: LIMIT $page without (int), ORDER BY $col without allowlist,
      JOIN without condition, missing FK indexes.

  14. INCONSISTENT VALIDATION:
      endpoint A regex, endpoint B filter_var, endpoint C none;
      validators with different thresholds (8 chars vs 12 for password).

  15. ACCIDENTAL BACKDOORS:
      /debug.php, /test.php, /api/admin/exec; `if ($_GET['debug']==1) var_dump(...)`;
      `?eval=...` parameter.

  16. OLD TRAINING-DATA PATTERNS:
      mysql_*, jQuery 1.x, var, ereg, each, create_function, callback APIs
      where promises exist.

  17. TESTS-AS-IMPLEMENTATION:
      assertEquals on internal data structures; mocks that just replicate
      calls without asserting values; reflection-only tests; tests that
      mock the subject under test.

  18. CLASS-NAME / VERSION DRIFT:
      class GeminiService calling api.openai.com; `define('APP_VERSION', '1.5.1')`
      next to `define('APP_VERSION', '3.12.0')` in another file; multiple
      validators of the same domain concept (NIP/email/IBAN).

  19. HARD-RULE VIOLATIONS:
      grep INVENTORY §9 (extracted CLAUDE.md hard-rules) against the codebase.
      Every direct violation = P0 if rule concerns financial / regulated / PII.
      Examples: "NEVER mutate fields after external commit", "ALWAYS route
      inventory writes through the canonical service", "NEVER use 1.0 as a
      fallback for a missing exchange rate".

  Output: audit/findings/07-ai-specific.md, format from SKILL.md §7. Prefix: AI-.

  CRITICAL: your work is the last line of defense against LLM mistakes.
  Don't trust "looks fine" — 27-48% of AI-PHP has vulnerabilities even
  when it compiles. Be paranoid.

  Apply your 5-axis framework (Correctness/Readability/Architecture/Security/
  Performance) with severity 🔴 CRITICAL / 🟡 REQUIRED / 🔵 OPTIONAL / ⚪ NIT,
  mapped to P0/P1/P2 per SKILL.md §6.
```
