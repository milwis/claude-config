# Prompt for `php-pro` — deep PHP audit (skip if no PHP detected)

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>` with the path to `audit/INVENTORY.md`.

```
subagent_type: php-pro
description: PHP deep audit — strict types, OWASP, AI anti-patterns
prompt: |
  You are auditing the PHP code in the application described in
  <INVENTORY_PATH>. Mode: READ-ONLY.

  Your expertise: PHP 8.3+, strict types, security-first, AI anti-patterns.
  AI-generated PHP has exploitable vulnerabilities in 27-48% of cases
  (Veracode 2025).

  Priority categories:

  A) Absolute Prohibitions (each occurrence = P0):
     SQL without prepared statements; output without context-aware escaping;
     md5/sha1 for passwords; == in security-sensitive comparisons;
     move_uploaded_file without finfo MIME validation; $_SESSION['user_id']
     without session_regenerate_id(true); unserialize($_*); deprecated
     APIs (mysql_*, ereg, FILTER_SANITIZE_STRING); missing
     declare(strict_types=1); hardcoded secrets; exec/shell_exec/passthru
     with user input; missing CSRF on state-changing endpoints.

  B) Finalized-record mutations (each = P0 if regulated):
     UPDATE on `*_sent`, `*_locked`, `*_finalized`, `*_exported` fields
     without WHERE-guard + rowCount check.

  C) Domain service bypass (each = P0 when CLAUDE.md mandates a service):
     direct UPDATE/INSERT on tables documented as service-owned (inventory,
     accounting, payments). Cross-reference INVENTORY §10 (extracted hard-rules).

  D) Cross-resource consistency (each = P0 for financial flows):
     file write + DB UPDATE without transaction + rollback + cleanup.

  E) Modern PHP 8.x quality (P2):
     missing readonly classes for DTOs, missing Enums for domain states,
     missing constructor property promotion, switch instead of match,
     strpos instead of str_contains/str_starts_with, missing typed class
     constants (PHP 8.3), missing #[\SensitiveParameter].

  F) Framework patterns (P1 when applicable):
     mass assignment ($guarded = []), $request->all() instead of
     ->validated(), missing Policy/Voter authorization, whereRaw with
     concatenation.

  G) AI anti-patterns (CRITICAL for AI-generated code):
     hallucinated APIs / non-existent methods; happy-path only (no error
     handling); phantom validation (typehints without runtime checks);
     mock functions like verifySomething() => true; placeholders (TODO,
     FIXME, "throw not implemented"); outdated training-data patterns;
     class-name confabulation (e.g. class GeminiService calling api.openai.com);
     version drift (multiple APP_VERSION definitions); silent 1:1 fallback
     in financial conversion functions.

  H) PDO config:
     PDO::ATTR_EMULATE_PREPARES => false?
     PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION?
     (int) cast on lastInsertId everywhere?

  I) Codebase hygiene:
     declare(strict_types=1) coverage in cron/, scripts/, tests/ — not just
     src/. Files >1500 LOC count + locations. Single source of truth for
     APP_VERSION. One validator per domain concept (NIP/SSN/email).

  Tools (run via Bash if available):
     vendor/bin/phpstan analyse --level=8 --error-format=json
     vendor/bin/psalm --taint-analysis --output-format=json
     composer audit --format=json

  Output: audit/findings/02-php-deep.md, format from SKILL.md §7. Prefix: PHP-.

  Operate under `verification-before-completion`: every fix-proposal API
  must be verified against actual library docs, not guessed.
```
