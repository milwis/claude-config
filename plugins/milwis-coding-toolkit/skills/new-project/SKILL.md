---
name: new-project
description: "Universal project foundation skill. Creates professional, scalable, secure base for any new project. Covers: marketplace plugins, architecture, logging, security, exceptions, testing, resilience, CI/CD, docs. Run ONCE at project start."
disable-model-invocation: true
---

# New Project Foundation

**Core:** Create a complete foundation BEFORE any business logic. Technology-agnostic in structure, adapts to chosen stack.

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

**If the user has a plan doc, read it first.** Extract: stack, architecture, modules, phases.

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
- `.env` → ignore; `.env.example` → track

---

## Phase 2: Claude Code Configuration

### Deliverables
- [ ] `.claude/settings.json` with enabled plugins and the deny rules for secrets (§Rules that must always hold)
- [ ] `.claude/settings.local.json` with permissions (Bash, WebSearch, WebFetch, Skills)
- [ ] `.claude/README.md` — index of agents, skills, rules
- [ ] Project-specific agents if needed
- [ ] Stack rules (e.g., `python-rules.md`, `js-rules.md`) with `paths:` frontmatter — the only place language rules live: the toolkit's agents are goal-only and load a rules file when they open a file it matches
- [ ] Domain-specific safety rules if applicable

### Agent selection

| Agent | When needed |
|---|---|
| `code-reviewer` | Every project — fresh review of every non-trivial diff, security included |
| `test-automator` | Every project — tests as their own task, and surface verification (`verify-e2e`) |
| `debugger` | Every project — a failure with an unknown cause |
| `builder` | Every project — an independent sizeable task beside the main session |
| `refactoring-orchestrator` | Every project — a behaviour-preserving refactor as its own task |
| `backend-security-coder` | When project has API/auth/user data — security audits only |
| `database-optimizer` | When project has database |

Language rules live in `.claude/rules/<language>-rules.md` with `paths:` (`/lang-guidelines`), not in agents.

### CLAUDE.md

`CLAUDE.md` loads into every session, so it holds only what Claude cannot learn by reading the repo, in under 60 lines:

```markdown
# <Project>
<1–2 sentences: what it does and for whom>

## Commands
- install: `make dev`
- one test file: `<test command> path/to/test`
- all tests: `make test` · lint: `make lint` · types: `make type-check`

## Conventions
- <only where the code misleads or two approaches are reasonable, e.g. "errors: the hierarchy in src/common/exceptions.py, never raw strings">

## Gotchas
- <what has already bitten someone; empty at the start>

## Workflow (milwis-coding-toolkit)
- One task end to end: `/task-lifecycle`. A new module or a cross-module feature: `/brainstorming` → `/writingplans` → `/executingplans`.
- A diff is reviewed by a fresh `code-reviewer`, and a user-facing change is verified by `test-automator` with a `verify-e2e` brief; neither runs in the context that wrote the change.

Details: `docs/architecture.md`, `docs/logging-system.md`.
```

Left out on purpose: the directory layout and the architecture (Claude reads the repo; the detail lives in `docs/architecture.md`), language rules (`.claude/rules/<language>-rules.md` with `paths:`, `/lang-guidelines`), and a routing table that repeats the agents' own descriptions.

### Rules that must always hold

A rule with no exceptions is enforced by a tool, not written as a capitalised line in `CLAUDE.md`: prose is guidance the model weighs, and piled-on emphasis makes it over-apply the rule, while a tool applies it every time.

| Rule | Where it is enforced |
|---|---|
| Secrets stay out of the repo and the session | `.gitignore`; deny rules in `.claude/settings.json`: `Read(./.env)`, `Read(./.env.*)`, `Read(./secrets/**)`; the secret-scan pre-commit hook (Phase 8) |
| Types on every function; no `print()` / `console.log` | type checker and linter config at the strictness the project chose; CI fails on them (Phase 11) |
| Parameterized SQL; money as `Decimal`, never float | the stack rules file with `paths:`; a linter rule (`bandit`, `semgrep`, ESLint) where the stack has one |
| Review before merge | the project's gate (a CI check or a pre-commit hook) when the owner wants it on every change; otherwise the Workflow line above |

A rule that is only a preference stays in the rules file or under Conventions, not in a hook.

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

The architecture goes into `docs/architecture.md`, not into `CLAUDE.md` (Phase 2, §CLAUDE.md).

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
- [ ] Startup validation — the app refuses to start with missing/invalid credentials
- [ ] Secrets absent from code, logs and error messages
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
- [ ] Exception handlers that keep internals out of client responses
- [ ] Pre-commit hook for secret detection (`gitleaks`, `trufflehog`, or `detect-secrets`)
- [ ] Automated dependency updates enabled (`Dependabot` or `Renovate`) with lockfiles committed (`poetry.lock`, `package-lock.json`, `go.sum`) — no unpinned/floating versions in prod deps
- [ ] SBOM (Software Bill of Materials) generated on build in CycloneDX or SPDX format — increasingly required for compliance (EU Cyber Resilience Act, US EO 14028) and needed to correlate dependencies against live CVEs
- [ ] MFA enforced on all accounts with publish/admin rights (GitHub org, package registries, cloud console)

### Non-negotiable rules

1. Secrets in `.env` only
2. Parameterized queries only
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
| Commands, conventions, gotchas, workflow | `CLAUDE.md` | Loaded every conversation — only what the repo does not show |
| Rules with no exceptions | Linter, type checker, hooks, deny rules, CI | Applied every time, not read (Phase 2) |
| Language and domain rules | `.claude/rules/*.md` with `paths:` | Loaded when a matching file is opened |
| Architecture details | `docs/architecture.md` | Read on demand |
| Logging system | `docs/logging-system.md` | Read when debugging |
| Plans | `docs/plans/` | Historical record |
| API docs | Auto-generated (Swagger/OpenAPI) | Always current |

---

## Phase 13: Foundation Verification Audit

Run it before declaring "foundation complete." Read **`references/verification-audit.md`** for the full checklist (code quality, structure, security, logging, resilience, documentation, CLAUDE.md and enforcement, optional domain safety). Run every checkbox; if any fails, return to that phase before adding business logic.

The five red lines that always block:

```bash
make lint && make type-check && make test    # all green
```
- [ ] `.env` in `.gitignore`, `.env.example` complete
- [ ] Auth + rate limiting active; startup rejects default credentials
- [ ] Logging + correlation context active; no raw `print` / `console.log`
- [ ] `CLAUDE.md` has Commands and Workflow, every command in it runs, and each rule of the Phase 2 enforcement table is enforced by the tool its row names

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

<!-- Updated: 2026-10-30 (v1.7.7: CLAUDE.md tylko z tym, czego nie widać w repo; reguły bez wyjątków egzekwowane narzędziem — historia zmian w UPDATE_LOG.md) -->
Last updated: 2026-10-30
