# Update Log

## Run: 2026-07-17 — Autonomy layer: task-lifecycle, issue-pipeline, verify-e2e

### Added
- **skills/verify-e2e**: Surface-level verification in a fresh adversarial subagent (GUI → browser + screenshots, API → real HTTP, CLI/cron → execution). Evidence artifacts mandatory; BLOCKED protocol appends missing prerequisites to project `docs/VERIFICATION_ENV.md` so the verification environment compounds. Rationale: smarter models fake completion more convincingly (Fable 5 system card) — isolation + adversarial prompt is the countermeasure.
- **skills/task-lifecycle**: Orchestrated end-to-end cycle for one task: build (specialist subagent) → code-review loop with auto-fix of CRITICAL/HIGH/MEDIUM (cap 3) → conditional security pass (backend-security-coder) → verify-e2e in fresh subagent (cap 3) → report package. Main session never writes code; feature-branch policy for deploy-from-main projects; merge/push/deploy always the user's decision.
- **skills/issue-pipeline**: Batch remediation: collect (gh issues / audit-360 findings / list) → mandatory triage on HEAD (stale-finding kill + fresh file:line anchors, per KNOWLEDGE lesson "audit older than commit delta") → file-disjoint batching (2-3 wide, executing-plans 4 conditions, DB issues never parallel) → one task-lifecycle orchestrator per issue on `agent/issue-<n>` → monitor by exception → status table. Cap 10 issues/run. Automates the previously manual audit → issues → orchestrators flow.

### Updated
- **verification-before-completion**: claim table row + integration note — verify-e2e is the OUTER gate (user surface), this skill the inner (commands/tests).
- **executingplans**: final group now includes verify-e2e for user-facing changes; companion-skills list extended (verify-e2e, task-lifecycle).
- **audit-360**: Quick-start step 13 — optional remediation handoff: P0/P1 → `gh issue create` → issue-pipeline.
- **README.md**: new skills documented + "Autonomy Layer" section (orchestration diagram, hard caps, BLOCKED-as-first-class, audit→issues→pipeline loop).
- **plugin.json**: 1.2.0 → 1.3.0; marketplace.json plugin entry aligned to 1.3.0 (was stale at 1.1.0).

### Source
- Boris (Claude Code) "steps of AI adoption" levels 1-4, via analyzed video transcript (2026-07-17): self-verification loop on the user surface, isolated verifier subagents, severity-gated auto-fix review loops with caps, orchestrator-not-builder main session, verification-environment investment, monitor-by-exception.

### Issues
- None

---

## Run: 2026-07-07 — Manual restructure: refactoring-specialist → refactoring-orchestrator

### Replaced
- **refactoring-specialist.md → refactoring-orchestrator.md**: Role changed from hands-on refactoring executor to end-to-end orchestrator (per user-authored prompt). Runs phases 0–6: mandatory backup with manifest, behavioral baseline (tests + static analysis), audit, plan with uncertainty gate, delegated execution (never codes itself — spawns php-pro/javascript-pro/sql-pro/test-automator via nested Agent tool, supported since Claude Code v2.1.172), equivalence verification (baseline diff + before/after regression + 7-axis code-reviewer pass), sign-off with user-confirmed backup release. Carried over from the old agent as "briefing knowledge" injected into subagent assignments: AST-or-nothing bulk transformation rules (incl. 2026-05-15 sed incident), PHP/JS refactoring pitfalls, large-file split patterns (Extract Class / Strangler Fig / Branch by Abstraction), smell table, refactoring catalog, metrics. Added read-only audit mode for audit-360 compatibility. No `Edit` tool by design.
- **audit-360**: `prompts/06-refactoring-specialist.md` renamed to `prompts/06-refactoring-orchestrator.md` (subagent_type updated, READ-ONLY audit mode noted); SKILL.md references updated.
- **executingplans / new-project / README**: agent routing references updated to `refactoring-orchestrator`.
- **plugin.json**: version 1.1.0 → 1.2.0.

### Issues
- None

---

## Run: 2026-07-01

### Updated
- **javascript-pro.md**: Updated Node.js LTS to v24+ (V8 13.6, Explicit Resource Management `using`/`await using`, `RegExp.escape()`, `Error.isError()`, built-in SQLite, npm 11). Added TypeScript 6.0 (March 2026: `strict` default, ES5 target removed, final JS compiler; TS 7.0 Go rewrite in development). Added `using`/`await using` pattern section.
- **mobile-pwa-developer.md**: Updated platform support — iOS Safari 26+ (WebGPU enabled by default, `<model>` 3D, Digital Credentials, Trusted Types, File System WritableStream, Home Screen default to web app mode), Safari 27 beta (Grid Lanes/CSS masonry, Customizable Select), Chrome 148+ (Prompt API stable, PWA origin migration, WebMCP origin trial). WebGPU reached Baseline status (January 2026, ~77% global coverage). WebNN updated CR but not production-ready (estimated 2027). Added Service Worker Static Routing API.
- **sql-pro.md**: Added PostgreSQL 19 Beta 1 (June 2026, GA expected September 2026). Added MySQL 9.6/9.7 quarterly innovation releases. Updated Modern Systems — CockroachDB 25.2 (distributed vector indexing), TiDB X (unified vector/graph/JSON/SQL engine + MCP integrations), Neon/Databricks Lakebase.
- **code-reviewer.md**: Added ProjectDiscovery 2026 stat (AI code 1.88× more likely to introduce vulnerabilities). Added specific slopsquatting incidents — `unused-imports` npm (~233 weekly downloads), `huggingface-cli` (30K+ downloads, Alibaba incident), CSA April 2026 autonomous agent risk. Added iterative refinement degradation anti-pattern (Arxiv 2506.11022).
- **database-optimizer.md**: Added PostgreSQL 19 Beta 1 (June 2026, GA expected September 2026).

### Skipped (up to date, < 30 days)
- **backend-security-coder.md**: Last updated 2026-06-01 (30 days)
- **debugger.md**: Last updated 2026-06-01 (30 days)
- **php-pro.md**: Last updated 2026-06-01 (30 days)
- **python-pro.md**: Last updated 2026-06-01 (30 days)

### Skipped (no significant new findings)
- **refactoring-specialist.md**: Last updated 2026-05-15 (47 days) — no significant new refactoring tools or patterns found in research
- **test-automator.md**: Last updated 2026-05-15 (47 days) — Vitest 4, Jest 30, Playwright already covered; no major new testing tool releases found
- **new-project/SKILL.md**: Last updated 2026-05-01 (61 days) — Docker images still current (PG 19 still beta, not GA), no significant changes needed

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md
- audit-360/SKILL.md

### Skipped (template/orchestration)
- lang-guidelines/SKILL.md (meta-skill for generating agents, stable process)

### Deferred to next run
- None — all files processed within the 10-file limit

### Issues
- None

### Next run priorities
- refactoring-specialist.md (will be 77 days by next run — consider adding new AST tooling or patterns)
- test-automator.md (will be 77 days by next run)
- new-project/SKILL.md (will be 91 days by next run — update Docker images when PG 19 reaches GA)
- backend-security-coder.md (will be 60 days by next run)
- debugger.md (will be 60 days by next run)
- php-pro.md (will be 60 days by next run)
- python-pro.md (will be 60 days by next run)

---

## Run: 2026-06-01

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
