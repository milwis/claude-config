# Update Log

## Latest Run: 2026-06-01

### Updated
- **python-pro.md**: Added Python 3.14 stable features — PEP 649 (deferred annotation evaluation), PEP 734 (multiple interpreters), PEP 758 (except without parens), PEP 779 (free-threaded Python officially supported), PEP 784 (compression.zstd), uuid7(), JIT compiler. Added 2026 CVEs: CVE-2026-3298 (asyncio buffer overflow), CVE-2026-4519 (webbrowser.open() injection), CVE-2026-0672 (cookies bypass). Added remote debugging security note. Updated description to 3.14+/3.15.
- **backend-security-coder.md**: Added OWASP Top 10 2026 new categories — A03 Software Supply Chain Failures and Mishandled Exceptions. Updated SSRF entry to note merger into Broken Access Control A01. Updated AI vulnerability stats: 92% of AI codebases have critical vuln (Sherlock Forensics 2026), 35 CVEs/month attributed to AI-generated code.
- **debugger.md**: Added 4 new AI-generated bug patterns — hallucinated APIs, incomplete-context conflicts (43% need production debugging per Lightrun 2026), performance anti-patterns, semantic error dominance (>60% of AI faults).
- **php-pro.md**: Added PHP 8.5 URI extension (Uri\Rfc3986\Uri, Uri\WhatWg\Url replacing parse_url()), closures in constant expressions.

### Skipped (up to date)
- **code-reviewer.md**: Last updated 2026-05-15 (17 days)
- **javascript-pro.md**: Last updated 2026-05-15 (17 days)
- **refactoring-specialist.md**: Last updated 2026-05-15 (17 days)
- **test-automator.md**: Last updated 2026-05-15 (17 days)
- **database-optimizer.md**: Last updated 2026-05-01 (31 days) — PG 18.4 point release is maintenance/security only, no new optimization patterns
- **mobile-pwa-developer.md**: Last updated 2026-05-01 (31 days) — no new PWA APIs or browser features since May update
- **sql-pro.md**: Last updated 2026-05-01 (31 days) — PG 18 and MySQL 9 features already comprehensive, no new dialect features
- **new-project/SKILL.md**: Last updated 2026-05-01 (31 days) — process skill with current tech references, no significant changes needed

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md

### Skipped (template/orchestration)
- lang-guidelines/SKILL.md (meta-skill for generating agents)
- audit-360/SKILL.md (orchestration process)

### Deferred to next run
- None — all 8 evolving files were processed

### Issues
- None

### Next run priorities
- database-optimizer.md (will be 61 days by next run)
- mobile-pwa-developer.md (will be 61 days by next run)
- sql-pro.md (will be 61 days by next run)
- new-project/SKILL.md (will be 61 days by next run)
- code-reviewer.md (will be 47 days by next run)
- javascript-pro.md (will be 47 days by next run)
- refactoring-specialist.md (will be 47 days by next run)
- test-automator.md (will be 47 days by next run)

---

## Run: 2026-05-15 — Post-Audit Incident Updates

Driven by 2026-05-15 incident (bulk `sed` on `catch (e) {` destroyed 13 JS files) and PR #155 / `ksef_daemon` orphan-test incident (7 tests passing CI against deleted code).

### Updated
- **javascript-pro.md**: New sections — Vite/bundler scope isolation checklist (cross-file `window.X`, eslint globals sync, implicit globals → `ReferenceError` in bundles); ES2019 catch binding rule with explicit ban on sed/regex bulk transforms (incident 2026-05-15); `Object.prototype.hasOwnProperty.call` rule.
- **code-reviewer.md**: Added 6th review axis — **Test-Production Contract**: orphan-test scan for DELETE/RENAME/signature/exception changes (`scripts/check_orphan_tests.sh <symbol>`, `grep tests/` patterns). Description and review-process headers updated 5→6 axes.
- **test-automator.md**: New **Pre-Flight** section — before editing tests or after a production change, run (1) orphan scan, (2) filtered sanity check, (3) MANDATORY full suite run (because `failOnWarning`/`failOnRisky` and orphan tests only surface in a full run, never in `--filter`).
- **refactoring-specialist.md**: Added safety rule #6 and new **Bulk Transformations — AST or Not at All** section. Explicit ban on `sed`/`awk`/`perl -pi` for catch bindings, signatures, declarations; allowed list (eslint --fix, jscodeshift, ts-morph, Rector, LibCST). Added Last-updated footer (previously missing).
- **sharp-edges (backup-skills)**: New category 7 — **Tooling Footguns: Bulk Regex/Sed on Source Code**. Codifies the 2026-05-15 catch-binding incident as a sharp-edge anti-pattern.

### Considered but skipped
- **eslint-cleanup skill (new, optional)**: content overlapped with new javascript-pro and refactoring-specialist sections; project-specific (CI free-tier, `sync_eslint_globals.sh`). Can be added later if a dedicated workflow checklist is wanted.

### Issues
- None — all edits are additive guidance, no breaking changes to existing structure.

---

## Run: 2026-05-01

### Updated
- **php-pro.md**: Added PHP 8.4 features (property hooks, asymmetric visibility, PDO driver subclasses, array_find/any/all, new-without-parens), PHP 8.5 features (pipe operator, clone with, array_first/last, #[\NoDiscard]), code examples; updated vulnerability stats to Veracode 2026 (~45%); updated description from 8.3+ to 8.4+/8.5
- **javascript-pro.md**: Updated Node.js LTS from v20+ to v22+ (WebSocket, watch mode, .ts execution, HTTP/3 QUIC); added TypeScript 5.8 features (erasableSyntaxOnly, rewriteRelativeImportExtensions); added ESLint 10 flat config (eslintrc removed Feb 2026); updated Vitest to 4+ (stable browser mode); updated AI vulnerability stats to Veracode 2026
- **backend-security-coder.md**: Added new AI & Agentic Security section covering OWASP Top 10 for Agentic Applications 2026, slopsquatting supply chain attacks, OWASP MCP Top 10, updated vulnerability stats
- **sql-pro.md**: Added PostgreSQL 18 features (async I/O, skip scan, uuidv7, virtual generated columns, temporal constraints, OAuth); added MySQL 9 features (vector data type, enhanced EXPLAIN, WebAuthn)
- **database-optimizer.md**: Added PostgreSQL 18 performance features (async I/O with 3x improvement, skip scan, virtual generated columns, uuidv7)
- **code-reviewer.md**: Added slopsquatting and deprecated config format checks to AI-generated code review table; updated vulnerability stats to Veracode 2026
- **test-automator.md**: Updated Vitest to 4+ (stable browser mode, visual regression testing), Jest to 30, added Playwright component testing
- **mobile-pwa-developer.md**: Updated iOS Safari to 16.4+, added Firefox 143+ PWA support, Workbox 7, manifest-only install prompts, WebGPU/WebNN on-device AI capabilities
- **new-project/SKILL.md**: Updated Docker images (postgres:18, mongo:8, rabbitmq:4), added PostgreSQL 18 feature notes
- **debugger.md**: Added slopsquatting and AI tool supply chain compromise to debugging patterns

### Skipped (up to date)
- **python-pro.md**: Last updated 2026-04-14 (17 days ago, within 30-day threshold)

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md

### Deferred to next run
- **refactoring-specialist.md**: Hit 10-file limit; refactoring patterns are relatively stable
- **audit-360/SKILL.md**: Hit 10-file limit; orchestration process, lower priority
- **lang-guidelines/SKILL.md**: Hit 10-file limit; meta-skill for creating agents

### Issues
- None

### Next run priorities
- refactoring-specialist.md (no "Last updated" date, deferred this run)
- audit-360/SKILL.md (no "Last updated" date, deferred this run)
- lang-guidelines/SKILL.md (no "Last updated" date, deferred this run)
- python-pro.md (will be 47+ days old by next monthly run)
