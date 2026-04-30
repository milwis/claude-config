# Prompt for `backend-security-coder` — Tier-1 security boundary

Paste the body below (after the `prompt: |` line) as the `prompt` parameter of the Task call. Replace `<INVENTORY_PATH>` with the actual path to `audit/INVENTORY.md` (typically the repo root + `/audit/INVENTORY.md`).

```
subagent_type: backend-security-coder
description: Backend security audit (Three-Tier boundary system)
prompt: |
  You are auditing the application described in <INVENTORY_PATH>.

  Mode: READ-ONLY. Do not modify code.
  Context: read <INVENTORY_PATH> before starting.

  Scope (your Three-Tier Boundary System Always/Ask/Never):
  1. ALWAYS: input validation, parameterized queries, password hashing
     (bcrypt / argon2id), CSRF, session regeneration on EVERY login path,
     secure headers, secrets in env vars, anonymized fixtures, permission
     consistency among neighbor routes.
  2. ASK: rate limiting, audit logging, IP allowlists for endpoints touching
     financial / regulated data.
  3. NEVER: eval/shell_exec/system with user input, hardcoded creds,
     MD5/SHA1 for passwords, raw user IDs in queries, autoload-anything,
     broad CORS, debug/test/diagnostic endpoints in production, tokens
     in $_GET/query string, vendor/ committed without `composer audit`
     in CI, Math.random/rand for cryptographic material.

  Focus on endpoints that mutate business state — listed in INVENTORY §5
  (external integrations classified as financial / regulated / PII).

  Output: audit/findings/01-security-backend.md, format from SKILL.md §7.
  ID prefix: SEC-BE-.

  Each finding MUST have: `id`, `severity` (P0/P1/P2 per SKILL.md §6),
  `cwe`, `owasp`, `file:line`, `evidence` (real code quote), `impact`,
  `recommendation` with concrete fix (diff).

  Operate under `verification-before-completion`: do not finalize the
  report without re-reading every cited snippet via Read.
```
