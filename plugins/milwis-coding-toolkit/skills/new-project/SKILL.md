---
name: new-project
description: "Universal project foundation skill. Creates professional, scalable, secure base for any new project. Covers: marketplace plugins, architecture, logging, security, exceptions, testing, resilience, CI/CD, docs. Run ONCE at project start."
---

# New Project Foundation

**Core:** Create a complete foundation BEFORE any business logic. Technology-agnostic in structure, adapts to chosen stack.

**Announce:** "I'm using the new-project skill to set up the project foundation."

---

## Step 0: Understand the Project

Gather answers:
1. What does this project do? (1-2 sentences)
2. Tech stack? (language, framework, DB, frontend)
3. How many users? (single-user, team, public)
4. Where runs? (local, VPS, cloud, serverless)
5. External APIs/services?
6. Existing plan/spec doc?
7. Domain-specific safety rules? (financial, medical, PII)

**If user has a plan doc — READ IT FIRST.** Extract: stack, architecture, modules, phases.

---

## Phase 1: Repository & Marketplace Plugins

### Git repository
- [ ] Git initialized with remote on GitHub/GitLab
- [ ] `.gitignore` comprehensive for stack (see below)
- [ ] `.gitkeep` in empty-start directories (`logs/`, `docs/plans/`)

### Marketplace plugin

If running this skill from marketplace — it's installed. Verify current:
```
/plugin marketplace update
```

If NOT from marketplace:
```
/plugin marketplace add milwis/claude-config
/plugin install milwis-coding-toolkit@milwis-marketplace
```

### .gitignore must cover
- Language artifacts (`__pycache__`, `node_modules/`, `dist/`)
- IDE (`.vscode/`, `.idea/`, `*.swp`)
- OS (`.DS_Store`, `Thumbs.db`)
- Secrets (`.env`, `.env.local`, `credentials.*`, `api_keys.*`)
- Build output (`dist/`, `build/`, `out/`)
- Log rotation backups (`*.log.1`) — but NOT main log files

### Track vs ignore
- `logs/` → TRACK if Claude needs remote log access; IGNORE rotation backups only
- `.claude/settings.local.json` → IGNORE (machine-specific)
- `.claude/settings.json` → TRACK (shared config)
- `.env` → ALWAYS IGNORE; `.env.example` → ALWAYS TRACK

---

## Phase 2: Claude Code Configuration

### Deliverables
- [ ] `.claude/settings.json` with enabled plugins
- [ ] `.claude/settings.local.json` with permissions (Bash, WebSearch, WebFetch, Skills)
- [ ] `.claude/README.md` — index of agents, skills, rules
- [ ] Project-specific agents if needed
- [ ] Stack rules (e.g., `python-rules.md`, `js-rules.md`)
- [ ] Domain-specific safety rules if applicable

### Agent selection

| Agent | When needed |
|---|---|
| `code-reviewer` | ALWAYS — before every commit |
| `debugger` | ALWAYS — root cause analysis |
| `test-automator` | ALWAYS — test strategy |
| `refactoring-orchestrator` | ALWAYS — refactoring end-to-end |
| `backend-security-coder` | When project has API/auth/user data |
| `database-optimizer` | When project has database |
| `sql-pro` | When project has SQL database |
| `{language}-pro` | Create via `/lang-guidelines` for primary language |
| `mobile-pwa-developer` | When project has PWA/mobile |

### MANDATORY: Agent Routing Table in CLAUDE.md

**Without an explicit routing table, Claude will NOT use specialized agents** — it will write code directly, bypassing AI-error-prevention and security rules in the agents.

Generate based on stack from Step 0:

```markdown
## Agent routing (marketplace: milwis-coding-toolkit)

| Files / Context | Agent | Invocation |
|---|---|---|
| {backend_paths} | `{language}-pro` | ALWAYS for {language} code |
| {frontend_paths} | `javascript-pro` | ALWAYS for JS/TS code |
| {sql_paths}, DB queries | `sql-pro` | ALWAYS for SQL |
| Security, API keys, auth | `backend-security-coder` | ALWAYS for security-related |
| Before every commit | `code-reviewer` | MANDATORY — never skip |
| Bugs, errors, failures | `debugger` | Start from logs, then code |
| DB performance | `database-optimizer` | For slow queries, indexing |
| Tests | `test-automator` | For test creation |
| Refactoring | `refactoring-orchestrator` | Orchestrated, zero-regression process |
| PWA / mobile | `mobile-pwa-developer` | Only if PWA |

**Workflow:** `/brainstorming → /writing-plans → /executing-plans → code-reviewer → commit`
```

Rules for generating the table:
1. Replace `{backend_paths}` with actual paths (`src/**/*.py`, `app/**/*.php`)
2. Replace `{language}-pro` with actual (`python-pro`, `php-pro`)
3. Multiple backend languages → a row for each
4. No frontend → remove `javascript-pro` row
5. No DB → remove `sql-pro` and `database-optimizer` rows
6. No PWA → remove `mobile-pwa-developer` row

### Non-negotiable rules (add to CLAUDE.md alongside routing table)

```markdown
## Non-negotiable rules

- ALWAYS use the agent specified in the routing table — NEVER write code directly when an agent exists
- ALWAYS run `code-reviewer` before committing
- ALWAYS start debugging with `debugger` (logs first, then code)
- Use `Decimal` for money — NEVER float
- Secrets in `.env` only — NEVER in code or logs
- Parameterized SQL only — NEVER string formatting
- Type hints on EVERY function
```

---

## Phase 3: Architecture & Dependencies

### Deliverables
- [ ] Dependency file (`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`)
- [ ] Dev dependencies separated (linter, type checker, test framework, formatter)
- [ ] Directory structure created
- [ ] Entry points defined (CLI, API, worker)
- [ ] Abstract base classes / interfaces for extensible components
- [ ] DI via constructors (not global state)
- [ ] `docs/architecture.md`

### Principles

**Separation of concerns** — business logic isolated from I/O; external services behind interfaces; config separate from code.

**Interface-first** — ABCs/protocols for components with multiple implementations (storage, API clients, notifications, auth). Enables testing with mocks, swapping, extending.

**Scalable structure:**
```
project/
├── src/ (or app/)
│   ├── common/          # Shared: config, logging, types, exceptions, retry, shutdown
│   ├── core/            # Business logic (no I/O)
│   ├── adapters/        # External integrations (DB, APIs, queues)
│   ├── api/             # HTTP layer (if applicable)
│   │   ├── routes/
│   │   ├── schemas/
│   │   ├── middleware.py
│   │   └── dependencies.py
│   └── workers/         # Background jobs (if applicable)
├── config/
├── sql/migrations/
├── tests/               # Mirror src/ structure
├── scripts/
├── docker/
├── docs/
└── logs/                # Per-module
```

**Type safety from day 1:** type hints everywhere, enums for domain states, value objects for primitives (Money as Decimal, not float), Pydantic/dataclass models.

### CLAUDE.md — keep it LEAN (< 60 lines)

Contents:
- 1-2 sentence project description
- Table of links to detailed docs (`docs/architecture.md`, `docs/logging-system.md`)
- Quick commands (`make dev`, `make test`)
- Non-negotiable rules (5-8 bullets max)
- Agent routing table
- Workflow line

**CLAUDE.md is loaded into every conversation — keep it tight.** Detailed content goes in `docs/`.

---

## Phase 4: Docker & Infrastructure

### Deliverables
- [ ] `docker-compose.yml` for local dev (DB, cache, queue as needed)
- [ ] `docker/` with init scripts
- [ ] Health checks on all services
- [ ] `make docker-up` / `make docker-down`

### Common services

| Service | When | Image |
|---|---|---|
| PostgreSQL | SQL DB | `postgres:18` (currently `18.4`) or `timescale/timescaledb:latest-pg18` (PG 18: async I/O with up to 3x read throughput, skip scan, uuidv7, virtual generated columns) |
| Redis | Cache/sessions | `redis:7-alpine` |
| MongoDB | Documents | `mongo:8` |
| RabbitMQ | Queue | `rabbitmq:4-management-alpine` |
| Elasticsearch | Search/logs | `elasticsearch:8` |

Always: env vars from `.env`, named volumes, health checks, memory limits.

**Gotcha (postgres:18+):** the official image now defines its `VOLUME` at the parent `/var/lib/postgresql` and creates the data cluster in a versioned subdirectory (`/var/lib/postgresql/18/docker`) instead of directly in the mounted path — update volume mounts and `pg_upgrade` scripts accordingly when upgrading from `postgres:17` or earlier.

---

## Phase 5: Configuration & Secrets

### Deliverables
- [ ] Centralized config module (pydantic-settings, dotenv, etc.)
- [ ] `.env.example` with ALL variables documented
- [ ] Startup validation — app REFUSES to start with missing/invalid credentials
- [ ] Secrets NEVER in code, logs, or error messages
- [ ] Config files validated by typed schema at load time

### Rules
- Secrets: `.env` only, loaded via library
- Parameters: config files (YAML/TOML), typed validation
- Startup: validate ALL required creds BEFORE any work
- Environment-aware: dev defaults, production required
- Document every variable in `.env.example`

---

## Phase 6: Logging Infrastructure

### Deliverables
- [ ] Structured logging (JSON in files, human-readable in console)
- [ ] Per-module log files
- [ ] Correlation context (request_id, user_id automatically in every log)
- [ ] Error aggregation (`system/errors.log`)
- [ ] Log rotation (5 MB max, 2 backups)
- [ ] `docs/logging-system.md`
- [ ] NO `print()` — enforced by linter

### Log structure

```
logs/
├── {component-a}/
│   ├── general.log
│   ├── {submodule-1}.log
│   └── {submodule-2}.log
├── {component-b}/
│   └── ...
└── system/
    ├── all.log
    └── errors.log       # ERROR+ only
```

### Rules
1. Log CONTEXT, not messages — "Order failed: user_id=123 item=ABC error=OutOfStock"
2. Log DECISIONS with reasons — "REJECTED: reason=rate_limit, client=1.2.3.4"
3. Log BEFORE and AFTER I/O
4. Always `exc_info=True` on errors
5. Levels: DEBUG (calculations), INFO (operations), WARNING (rejections), ERROR (failures), CRITICAL (system cannot continue)
6. Correlation context via contextvars
7. NEVER log secrets

---

## Phase 7: Exception Hierarchy

### Deliverables
- [ ] Base exception class with typed context
- [ ] Mid-level groups: `ExternalServiceError`, `ValidationError`, `SecurityError`, `DomainError`
- [ ] Leaf exceptions with typed context
- [ ] Tests for hierarchy (each leaf catchable by its mid-level + base)

### Pattern (high level)

A four-branch hierarchy: external service errors (retry-eligible), validation errors (return 400), security errors (return 401/403 + alert), domain errors (business rule violations). Every exception carries a context dictionary so logs and error responses can extract structured data.

For the full type tree, language-specific implementations (Python, TypeScript, PHP), and use-site examples, see **`references/exception-hierarchy.md`**. Read it on demand when implementing this phase.

The key principle: enables `logger.error("Failed", **exc.context, exc_info=True)` — you log structured data, not strings.

---

## Phase 8: Security Foundation

### Deliverables
- [ ] Auth middleware (JWT/session/API key)
- [ ] Startup validation rejects default/empty credentials
- [ ] Rate limiting (strict on login, reasonable on API)
- [ ] Security headers on every response
- [ ] Health check endpoint
- [ ] Exception handlers that NEVER leak internals
- [ ] Pre-commit hook for secret detection (`gitleaks`, `trufflehog`, or `detect-secrets`)
- [ ] Automated dependency updates enabled (`Dependabot` or `Renovate`) with lockfiles committed (`poetry.lock`, `package-lock.json`, `go.sum`) — no unpinned/floating versions in prod deps
- [ ] SBOM (Software Bill of Materials) generated on build in CycloneDX or SPDX format — increasingly required for compliance (EU Cyber Resilience Act, US EO 14028) and needed to correlate dependencies against live CVEs
- [ ] MFA enforced on all accounts with publish/admin rights (GitHub org, package registries, cloud console)

### Non-negotiable rules

1. Secrets in `.env` ONLY
2. Parameterized queries ONLY
3. Input validation at boundaries
4. Output encoding for context
5. Startup validates credentials BEFORE work
6. Auth on every endpoint except health/login; default deny
7. Rate limiting: login strict (10/min), API reasonable (60/min)
8. Generic errors to client, detailed logs server-side
9. Dependencies pinned to exact versions/hashes — never unbounded ranges in production lockfiles
10. Vulnerability scan (`Trivy`, `Grype`, or `pip-audit`/`npm audit`) on every build; block on critical/high findings

### Domain-specific safety

Identify in Step 0, create dedicated rules file:
- **Financial:** Decimal for money, audit trail, stop-loss
- **Medical:** PII encryption, audit logging, consent tracking
- **E-commerce:** Idempotent payments, inventory race prevention
- **Infrastructure:** Rollback plan, canary deployments

---

## Phase 9: Testing Infrastructure

### Deliverables
- [ ] Test framework configured
- [ ] `conftest.py` / test setup with shared fixtures
- [ ] Mock adapters (same interface as real adapters from Phase 3)
- [ ] Test markers: unit, integration, slow, external
- [ ] At least ONE real test per critical module
- [ ] CI runs tests with Docker infrastructure

### Mock adapters — critical for testability

Same interface as real adapter. Track state in memory. Enforce same rules (validation, constraints). Support error injection (`force_next_error()`). Test helpers (`clear_state()`, `set_data()`).

---

## Phase 10: Resilience

### Deliverables
- [ ] Retry decorator (exponential backoff + jitter)
- [ ] Graceful shutdown handler (SIGTERM/SIGINT → cleanup → timeout → exit)

### Retry rules

| Retry (transient) | Don't retry (logic) |
|---|---|
| Connection timeout | Bad request (400) |
| Rate limit (429) | Authentication failed (401) |
| Server error (502/503/504) | Not found (404) |
| DNS resolution failure | Validation error |

### Shutdown pattern

1. Register SIGTERM + SIGINT handlers
2. Set shutdown flag
3. Stop accepting new work
4. Run cleanup callbacks (close connections, flush buffers, save state)
5. Timeout (30s) — force exit if hang
6. Exit cleanly

---

## Phase 11: CI/CD & Quality Gates

### Deliverables
- [ ] GitHub Actions workflow (still the dominant platform in 2026 for GitHub-hosted repos; GitLab CI/CD, Jenkins, CircleCI, or Argo CD/GitOps for Kubernetes-heavy deployments are the common alternatives)
- [ ] Pipeline: lint → type check → test (with Docker services) → dependency/vulnerability scan → SBOM generation
- [ ] Pre-commit hooks: syntax, secret detection, stack-specific
- [ ] Build fails automatically on critical/high vulnerability findings — security scanning lives INSIDE the pipeline, not as an afterthought
- [ ] `Makefile` with common commands

### Makefile commands

```makefile
make install       # Install prod deps
make dev           # Install with dev deps
make lint          # Linter check
make format        # Auto-format
make type-check    # Type checker
make test          # All tests
make test-fast     # Unit only
make docker-up     # Start infrastructure
make docker-down   # Stop infrastructure
```

### CI with infrastructure

```yaml
services:
  postgres:
    image: postgres:18
    env: { POSTGRES_PASSWORD: test }
    options: --health-cmd "pg_isready" --health-interval 10s
  redis:
    image: redis:7-alpine
    options: --health-cmd "redis-cli ping" --health-interval 10s
```

---

## Phase 12: Documentation

### Deliverables
- [ ] `CLAUDE.md` (< 60 lines, links to detailed docs)
- [ ] `docs/architecture.md` (diagram, modules, patterns, DB schema, data flow)
- [ ] `docs/logging-system.md` (structure, format, routing, debugging)
- [ ] `docs/plans/` — directory for implementation plans
- [ ] `.env.example`

### Placement rule

| Content | Where | Why |
|---|---|---|
| Quick ref, routing, rules | `CLAUDE.md` | Loaded every conversation — keep lean |
| Architecture details | `docs/architecture.md` | Read on demand |
| Logging system | `docs/logging-system.md` | Read when debugging |
| Plans | `docs/plans/` | Historical record |
| API docs | Auto-generated (Swagger/OpenAPI) | Always current |

---

## Phase 13: Foundation Verification Audit

MANDATORY before declaring "foundation complete." Read **`references/verification-audit.md`** for the full checklist (code quality, structure, security, logging, resilience, documentation, agent routing, optional domain safety). Run every checkbox; if any fails, return to that phase before adding business logic.

The five red lines that always block:

```bash
make lint && make type-check && make test    # all green
```
- [ ] `.env` in `.gitignore`, `.env.example` complete
- [ ] Auth + rate limiting active; startup rejects default credentials
- [ ] Logging + correlation context active; no raw `print` / `console.log`
- [ ] `CLAUDE.md` has the agent routing table with names matching the marketplace

**All checks pass?** → "Foundation complete. Ready to write business logic."
**Any fail?** → Return to that phase. Don't write business logic on a broken foundation.

---

## Execution Order

```
Phase 1:  Repo + marketplace       (10 min)
Phase 2:  Claude Code config       (15-30 min)
Phase 3:  Architecture + deps      (30-60 min)   ← biggest
Phase 4:  Docker                   (10 min)
Phase 5:  Config + secrets         (15 min)
Phase 6:  Logging                  (20 min)
Phase 7:  Exceptions               (15 min)
Phase 8:  Security                 (20 min)
Phase 9:  Testing                  (15 min)
Phase 10: Resilience               (15 min)
Phase 11: CI/CD                    (10 min)
Phase 12: Documentation            (15 min)
Phase 13: Verification             (10 min)
```

Total: ~3-4 hours for a complete foundation.

---

## Anti-Patterns

1. Skipping marketplace plugins — you lose the tested agents
2. "I'll add logging later" → `print()` everywhere, never refactored
3. Bare exceptions → hides bugs; custom hierarchy from day 1
4. Hardcoded anything → secrets, URLs, ports, timeouts all in config
5. Skipping test infrastructure → no tests will be written
6. Everything in CLAUDE.md → eats context window; link to docs
7. Skipping interfaces/ABCs → adding them later requires refactoring every caller
8. Skipping pre-commit hooks → secrets slip through
9. Skipping startup validation → crash mid-work instead of refusing to start
10. Skipping Docker → "works on my machine" syndrome
11. Skipping domain safety → general security isn't enough for financial/medical
12. Skipping SBOM/dependency scanning → unpinned deps and unknown CVEs ship to production; increasingly a compliance requirement, not optional

<!-- Updated: 2026-05-01 — Updated Docker images (postgres:18, mongo:8, rabbitmq:4), added PG 18 feature notes -->
<!-- Updated: 2026-08-01 — Added SBOM generation (CycloneDX/SPDX), dependency pinning/lockfiles, automated dependency updates (Dependabot/Renovate), secret-scanning tool names (gitleaks/trufflehog/detect-secrets), vulnerability scanning (Trivy/Grype) in CI, MFA-on-publish-rights rule, postgres:18 Docker volume-path gotcha, and CI/CD platform landscape note -->
Last updated: 2026-08-01
