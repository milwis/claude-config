# Prompt for SECOND PASS by primary language specialist — dependencies + docs

Run after the first language pass (e.g., a second `php-pro` or `python-pro` call) focused on supply chain and documentation. Skip if dep/docs surface area is small.

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: <project-primary-language-pro>     # php-pro / python-pro / javascript-pro
description: Dependencies + docs audit (second pass)
prompt: |
  You are auditing DEPENDENCIES and DOCUMENTATION of the application in
  <INVENTORY_PATH>. Mode: READ-ONLY.

  This is your SECOND Task call. Do NOT repeat findings from the first
  language pass — focus exclusively on supply chain and docs.

  ZONE A — DEPENDENCIES:

  A.1 Vulnerability scan:
     composer audit --format=json
     npm audit --json
     pip-audit
     HIGH/CRITICAL = P0, MEDIUM = P1, LOW = P2

  A.2 Slopsquatting check (CRITICAL for AI-generated code):
     For every entry: package exists in registry? Downloads >10k?
     Last release <2 years? Vendor known (spatie/, symfony/, laravel/,
     league/ for PHP; @types/, lodash, axios for npm)?
     Each suspicious package = P0.

  A.3 Lockfile present and committed?
     Missing = P1. Out-of-sync with manifest = P1.

  A.4 EOL versions:
     PHP <8.1 (EOL Nov 2024) = P0
     Node <20 = P1
     MySQL 5.7 (EOL Oct 2023) = P0

  A.5 Licenses:
     composer licenses
     npx license-checker --production --summary
     GPL/AGPL in proprietary product = compliance P1.

  A.6 Reproducible build:
     CI uses `composer install --no-dev --prefer-dist` with lockfile?
     CI uses `npm ci` (not `npm install`)?
     vendor/ committed = P1 (usually wrong).

  A.7 SRI for CDN scripts in HTML:
     Every <script src="https://..."> without `integrity=` and `crossorigin` = P1.

  ZONE B — DOCUMENTATION:

  B.1 README.md present + accurate (`composer install` / `npm install`
      actually work). Missing = P2.
  B.2 CLAUDE.md (if present): ≤300 LOC best practice; project-specific
      hard-rules clearly stated; no prompt-injection patterns.
  B.3 .claude/agents (if present): least-privilege tools; no unexpected
      Bash whitelist commands.
  B.4 ADRs present? Missing = P2.
  B.5 Comments confabulation: sample 30 functions, verify docblock vs body.
  B.6 API documentation (OpenAPI / Swagger) covers >50% endpoints?
  B.7 RUNBOOK / on-call playbook for production integrations? Missing = P1.
  B.8 CHANGELOG present + current?
  B.9 .env.example synced with code (every getenv/$_ENV/process.env
      key present in .env.example):
        diff <(grep -rhoE "getenv\\([\"'][^\"']+[\"']\\)" --include='*.php' . |
                grep -oE "[\"'][^\"']+[\"']" | tr -d "\"'" | sort -u) \
             <(grep -oE '^[A-Z_]+' .env.example | sort -u)
  B.10 Integration runbook: per integration in INVENTORY §5 — sequence diagram,
       retry policy, idempotency strategy, rollback procedure.
  B.11 Threat model / security docs: secret rotation? prod access? incident
       response procedure?

  Output: audit/findings/09-deps-docs.md, format from SKILL.md §7.
  Prefix: DEP- (deps), DOC- (docs).
```
