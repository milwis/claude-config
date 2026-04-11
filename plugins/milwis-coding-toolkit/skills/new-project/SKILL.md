---
name: new-project
description: "Universal project foundation skill. Creates a professional, scalable, and secure base for ANY new project — web app, trading system, API, CLI tool, etc. Covers: marketplace plugins, architecture, logging, security, exceptions, testing, resilience, CI/CD, Docker, documentation. Run ONCE at the start of a new project before writing business logic."
---

# New Project Foundation

## Overview

This skill creates a complete project foundation BEFORE any business logic is written.
It is technology-agnostic in structure but adapts to the chosen stack.

**When to use:** At the very beginning of a new project, after the initial idea/plan exists but before writing application code.

**What it produces:** A professional, scalable, secure base that doesn't need to be retrofitted later.

**Announce at start:** "I'm using the new-project skill to set up the project foundation."

---

## Step 0: Understand the Project

Before creating anything, gather these answers:

```
1. What does this project do? (1-2 sentences)
2. Tech stack? (language, framework, database, frontend)
3. How many users? (single-user, team, public)
4. Where will it run? (local, VPS, cloud, serverless)
5. External APIs/services it connects to?
6. Is there an existing plan/spec document?
7. Domain-specific safety rules? (financial calculations, medical data, PII, etc.)
```

If user has a plan document — READ IT FIRST. Extract: stack, architecture, modules, phases.

---

## Phase 1: Repository & Marketplace Plugins

### 1a. Git repository

- [ ] Git repository initialized
- [ ] Remote on GitHub/GitLab created
- [ ] `.gitignore` comprehensive for the stack (see checklist below)
- [ ] `.gitkeep` in directories that must exist but start empty (logs/, docs/plans/)

### 1b. Marketplace plugin — verify it's current

Since you're running this skill from the marketplace, it's already installed.
Just verify it's up to date:

```
/plugin marketplace update
```

**If running this skill NOT from the marketplace** (e.g., copied locally), the user must first:
```
/plugin marketplace add milwis/claude-config
/plugin install milwis-coding-toolkit@milwis-marketplace
```

### .gitignore must cover
- Language artifacts (__pycache__, node_modules/, .class, dist/)
- IDE files (.vscode/, .idea/, *.swp)
- OS files (.DS_Store, Thumbs.db)
- Secrets (.env, .env.local, credentials.*, api_keys.*)
- Build output (dist/, build/, out/)
- Log rotation backups (*.log.1, *.log.2) — but NOT main log files if they need to be accessible

### Key decision: What to track vs ignore
- `logs/` — TRACK if Claude Code needs remote access to logs. IGNORE rotation backups only.
- `.claude/settings.local.json` — IGNORE (machine-specific permissions)
- `.claude/settings.json` — TRACK (shared project config)
- `.env` — ALWAYS IGNORE. `.env.example` — ALWAYS TRACK.

---

## Phase 2: Claude Code Configuration

After marketplace plugins are installed, configure project-specific settings.

### Deliverables
- [ ] `.claude/settings.json` with enabled plugins (marketplace toolkit should be auto-enabled)
- [ ] `.claude/settings.local.json` with permissions (Bash, WebSearch, WebFetch domains for the project, Skills)
- [ ] `.claude/README.md` — index of agents, skills, rules
- [ ] Agents — review what marketplace provides, add/adapt project-specific ones
- [ ] Rules created for the specific stack (e.g., python-rules, js-rules, sql-rules)
- [ ] Domain-specific safety rules if applicable (e.g., trading-safety-rules, medical-data-rules)
- [ ] Core workflow skills verified: brainstorming, writingplans, executingplans, debugging-strategies
- [ ] Commands (UI/UX) if project has frontend

### Agent selection guide

Marketplace provides standard agents. Add project-specific ones when needed:

| Agent | When needed |
|-------|-------------|
| `code-reviewer` | ALWAYS — review before every commit |
| `debugger` | ALWAYS — root cause analysis |
| `test-automator` | ALWAYS — test strategy and creation |
| `refactoring-specialist` | ALWAYS — code cleanup |
| `backend-security-coder` | When project has API/auth/user data |
| `database-optimizer` | When project has database |
| `sql-pro` | When project has SQL database |
| Language-specific pro | Create via `/milwis-coding-toolkit:lang-guidelines` skill for the primary language |
| `mobile-pwa-developer` | When project has PWA/mobile |

### MANDATORY: Agent Routing Table in CLAUDE.md

**This is CRITICAL.** Without an explicit routing table in CLAUDE.md, Claude will NOT
use the specialized agents — it will write code directly, bypassing all the quality
guidelines, AI error prevention rules, and security practices in the agents.

The CLAUDE.md MUST contain an agent routing section. Generate it based on the project's
tech stack discovered in Step 0.

**Template to include in CLAUDE.md:**

```markdown
## Agent routing (marketplace: milwis-coding-toolkit)

| Files / Context | Agent | Invocation |
|-----------------|-------|------------|
| {backend_paths} | `{language}-pro` | ALWAYS for writing/reviewing {language} code |
| {frontend_paths} | `javascript-pro` | ALWAYS for JS/TS code |
| {sql_paths}, DB queries | `sql-pro` | ALWAYS for SQL queries and schema |
| Security, API keys, auth | `backend-security-coder` | ALWAYS for security-related code |
| Before every commit | `code-reviewer` | MANDATORY — never skip |
| Bugs, errors, failures | `debugger` | Start from logs, then code |
| Database performance | `database-optimizer` | For slow queries, indexing |
| Tests | `test-automator` | For test creation and strategy |
| Refactoring | `refactoring-specialist` | For code cleanup |
| PWA / mobile | `mobile-pwa-developer` | Only if project has PWA |

**Workflow:** `/milwis-coding-toolkit:brainstorming` → `/milwis-coding-toolkit:writingplans` → `/milwis-coding-toolkit:executingplans` → `code-reviewer` → commit
```

**Rules for generating the routing table:**

1. Replace `{backend_paths}` with actual project paths (e.g., `src/**/*.py`, `app/**/*.php`)
2. Replace `{language}-pro` with the actual language agent (e.g., `python-pro`, `php-pro`)
3. If project uses multiple backend languages, add a row for each
4. If project has no frontend, remove the `javascript-pro` row
5. If project has no database, remove `sql-pro` and `database-optimizer` rows
6. If project has no PWA, remove `mobile-pwa-developer` row
7. Add domain-specific agents if created (e.g., `skryba` for documentation)

**IMPORTANT — Non-negotiable rules to add to CLAUDE.md alongside the routing table:**

```markdown
## Non-negotiable rules

- ALWAYS use the agent specified in the routing table — NEVER write code directly when an agent exists for that file type
- ALWAYS run `code-reviewer` agent before committing
- ALWAYS start debugging with `debugger` agent (logs first, then code)
- Use `Decimal` for money — NEVER float
- Secrets in `.env` only — NEVER in code or logs
- Parameterized SQL only — NEVER string formatting
- Type hints on EVERY function
```

### Rules — create per stack layer

Each rule file targets specific file paths and contains:
- Mandatory patterns (what MUST be done)
- Forbidden patterns (what MUST NOT be done)
- Common pitfalls specific to that stack
- Pointer to the mandatory agent for that layer

---

## Phase 3: Project Architecture & Dependencies

### Deliverables
- [ ] Dependency management file created (`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`)
- [ ] Dev dependencies separated (linter, type checker, test framework, formatter)
- [ ] Directory structure created with all packages/modules
- [ ] Entry points defined (CLI, API server, worker)
- [ ] Abstract base classes / interfaces for extensible components
- [ ] Dependency injection via constructors (not global state)
- [ ] `docs/architecture.md` documenting the full structure

### Architecture principles

**1. Separation of concerns**
- Core business logic isolated from I/O (database, APIs, filesystem)
- External services behind interfaces/adapters (Adapter Pattern)
- Configuration separate from code (YAML/env, not hardcoded)

**2. Interface-first design**
- Define ABCs/interfaces/protocols for components that will have multiple implementations
- Examples: storage backends, API clients, notification channels, auth providers
- Enables: testing with mocks, swapping implementations, adding new ones without touching core

**3. Scalable structure**
```
project/
├── src/ (or app/)
│   ├── common/          # Shared: config, logging, types, exceptions, retry, shutdown
│   ├── core/            # Business logic (no I/O dependencies)
│   ├── adapters/        # External integrations (DB, APIs, queues)
│   ├── api/             # HTTP/WebSocket layer (if applicable)
│   │   ├── routes/
│   │   ├── schemas/     # Request/response models
│   │   ├── middleware.py # Auth, rate limiting, headers
│   │   └── dependencies.py
│   └── workers/         # Background jobs (if applicable)
├── config/              # Configuration files (YAML, TOML)
├── sql/migrations/      # Database migrations (if applicable)
├── tests/               # Mirror of src/ structure
├── scripts/             # Utility/CLI scripts
├── docker/              # Dockerfiles, init scripts
├── docs/                # Architecture, logging, plans
└── logs/                # Application logs (per-module)
```

**4. Type safety from day 1**
- Type hints on every function (parameters + return)
- Enums for domain states (not magic strings)
- Value objects for domain primitives (Money as Decimal, not float)
- Pydantic/dataclass models for data exchange

### CLAUDE.md — keep it LEAN

`CLAUDE.md` is loaded into EVERY conversation. Keep it under 60 lines:
- 1-2 sentence project description
- Table of links to detailed docs (`docs/architecture.md`, `docs/logging-system.md`, etc.)
- Quick commands (`make dev`, `make test`, etc.)
- Non-negotiable rules (5-8 bullet points max)
- Agent routing table (which files → which agent)
- Workflow: `/brainstorming → /writingplans → /executingplans → code-reviewer → commit`

Detailed documentation goes in `docs/` — NOT in CLAUDE.md.

---

## Phase 4: Docker & Infrastructure

### Deliverables
- [ ] `docker-compose.yml` for local dev (database, cache, message queue — whatever the project needs)
- [ ] `docker/` directory with init scripts (e.g., database extensions, seed data)
- [ ] Health checks on all services in docker-compose
- [ ] `make docker-up` / `make docker-down` commands

### Common services

| Service | When needed | Image |
|---------|-------------|-------|
| PostgreSQL | SQL database | `postgres:16` or `timescale/timescaledb:latest-pg16` |
| Redis | Cache / pub-sub / sessions | `redis:7-alpine` |
| MongoDB | Document store | `mongo:7` |
| RabbitMQ | Message queue | `rabbitmq:3-management-alpine` |
| Elasticsearch | Search / logs | `elasticsearch:8` |

Always include:
- Environment variables from `.env` (not hardcoded in compose)
- Named volumes for persistence
- Health checks with `test`, `interval`, `timeout`, `retries`
- Resource limits for memory if applicable

---

## Phase 5: Configuration & Secrets Management

### Deliverables
- [ ] Centralized config module (pydantic-settings, dotenv, or equivalent)
- [ ] `.env.example` with ALL variables documented with comments
- [ ] Startup validation — app REFUSES to start with missing/invalid credentials
- [ ] Secrets NEVER in code, NEVER in logs, NEVER in error messages
- [ ] Config files (YAML/TOML) validated by typed schema at load time (Pydantic or equivalent)

### Rules
- Secrets: `.env` only, loaded via library (pydantic-settings, dotenv, etc.)
- Parameters: config files (YAML/TOML), validated by typed models
- Startup check: validate ALL required credentials BEFORE doing any work
- Environment-aware: allow defaults for dev/testing, REQUIRE real values for production
- Document every variable in `.env.example` with comments

---

## Phase 6: Logging Infrastructure

### Deliverables
- [ ] Structured logging (JSON in files, human-readable in console)
- [ ] Per-module log files (not everything in one giant file)
- [ ] Correlation context (request_id, user_id, entity_id — automatically in every log line)
- [ ] Error aggregation (separate `system/errors.log` across all modules)
- [ ] Log rotation (max 5 MB per file, 2 backup copies)
- [ ] `docs/logging-system.md` documenting: file structure, format, routing, debugging guide
- [ ] NEVER `print()` — enforced by linter rules

### Log file structure pattern

```
logs/
├── {component-a}/
│   ├── general.log          # All logs from this component
│   ├── {submodule-1}.log    # Specific submodule
│   └── {submodule-2}.log
├── {component-b}/
│   └── ...
└── system/
    ├── all.log              # Everything from all components
    └── errors.log           # ERROR+ only — quick scanning
```

### Logging rules — MANDATORY for all modules

1. **Log CONTEXT, not just messages** — "Order failed" is useless. "Order failed: user_id=123 item=ABC error=OutOfStock" is debuggable.
2. **Log DECISIONS with reasons** — "Request REJECTED: reason=rate_limit, client=1.2.3.4, limit=60/min"
3. **Log BEFORE and AFTER I/O** — to know if an operation even started
4. **Always `exc_info=True` on errors** — stack traces are critical for debugging
5. **Proper levels:** DEBUG (calculations), INFO (operations), WARNING (rejections/degradation), ERROR (failures), CRITICAL (system cannot continue)
6. **Correlation context** — use contextvars or equivalent to inject IDs into all logs within a scope
7. **NEVER log secrets** — API keys, passwords, tokens must never appear in logs

---

## Phase 7: Exception / Error Handling Hierarchy

### Deliverables
- [ ] Base exception class for the project (catch-all)
- [ ] Mid-level groups per domain (ExternalServiceError, ValidationError, SecurityError, DomainError)
- [ ] Leaf exceptions with typed context (kwargs become attributes + `.context` dict)
- [ ] Tests for hierarchy (inheritance, context preservation, str output)

### Design pattern

```
ProjectBaseError
├── ExternalServiceError        # Anything outside our control
│   ├── ConnectionError         # Network/timeout
│   ├── APIError                # Bad response
│   └── RateLimitError          # Throttled
├── ValidationError             # Bad input/config
│   ├── InvalidConfigError
│   └── MissingFieldError
├── SecurityError               # Auth/authz failures
│   ├── AuthenticationError
│   └── AuthorizationError
└── DomainError                 # Business logic violations
    └── (project-specific)
```

### Key: Exceptions carry context

```python
class ProjectBaseError(Exception):
    def __init__(self, message: str = "", **kwargs):
        self._context = kwargs
        for key, value in kwargs.items():
            setattr(self, key, value)  # exc.field_name accessible as attribute
        ctx_str = " | ".join(f"{k}={v}" for k, v in kwargs.items())
        full_message = f"{message} [{ctx_str}]" if message and kwargs else message or ctx_str
        super().__init__(full_message)

    @property
    def context(self) -> dict:
        return dict(self._context)
```

This enables: `logger.error("Failed", **exc.context, exc_info=True)` — structured logging of every error with full context.

---

## Phase 8: Security Foundation

### Deliverables
- [ ] Authentication middleware (JWT, session, API key — depending on project type)
- [ ] Startup validation (app refuses to start with default/missing credentials)
- [ ] Rate limiting on public endpoints (strict on login, reasonable on API)
- [ ] Security headers on every response (X-Content-Type-Options, X-Frame-Options, Referrer-Policy, etc.)
- [ ] Health check endpoint (`/health` or `/api/health`) — checks DB, cache, external services
- [ ] Exception handlers that NEVER leak internals (stack traces, file paths, SQL errors)
- [ ] Pre-commit hook for secret detection

### Security rules — non-negotiable

1. **Secrets in .env ONLY** — never in code, never in logs, never in error responses
2. **Parameterized queries ONLY** — never string formatting/concatenation for SQL
3. **Input validation at boundaries** — validate ALL external input (API requests, file uploads, config)
4. **Output encoding** — escape for context (HTML, SQL, shell) before outputting user data
5. **Startup check** — validate credentials exist BEFORE doing any work
6. **Auth on every endpoint** — except health check and login. Default: deny access.
7. **Rate limiting** — login: strict (10/min), API: reasonable (60/min)
8. **Error responses** — generic messages to client, detailed logs server-side

### Domain-specific safety rules

Beyond general security, each project may have domain-specific safety rules. Identify them in Step 0 and create a dedicated rules file (e.g., `trading-safety-rules.md`, `medical-data-rules.md`). Examples:

- **Financial:** Decimal for money (never float), every transaction has audit trail, stop-loss mandatory
- **Medical:** PII encryption at rest, audit logging, consent tracking
- **E-commerce:** Idempotent payments, inventory race condition prevention
- **Infrastructure:** Rollback plan for every change, canary deployments

---

## Phase 9: Testing Infrastructure

### Deliverables
- [ ] Test framework configured (pytest, jest, vitest, etc.)
- [ ] `conftest.py` / test setup with shared fixtures
- [ ] Mock/fake implementations of external services (adapters from Phase 3)
- [ ] Test markers for categories: unit, integration, slow, external
- [ ] At least ONE real test per critical module (proves the infrastructure works)
- [ ] CI runs tests with infrastructure services (DB, cache via Docker in GitHub Actions)

### Mock adapters — critical for testability

If the project talks to external services, create mock implementations of the interfaces from Phase 3:

- Implement the SAME interface as the real adapter
- Track state in memory (records, orders, messages, etc.)
- Enforce the SAME rules as the real service (validation, constraints)
- Support error injection (`force_next_error()`) for testing failure paths
- Provide test helpers (`clear_state()`, `set_data()`)

Without mocks, you cannot test business logic without real external connections.

---

## Phase 10: Resilience Patterns

### Deliverables
- [ ] Retry decorator for external API calls (exponential backoff + jitter)
- [ ] Graceful shutdown handler (SIGTERM/SIGINT → cleanup callbacks → timeout → exit)

### Retry — what to retry vs NOT

| Retry (transient) | Do NOT retry (logic) |
|---|---|
| Connection timeout | Bad request (400) |
| Rate limit (429) | Authentication failed (401) |
| Server error (502/503/504) | Not found (404) |
| DNS resolution failure | Validation error |

### Graceful shutdown

Without signal handling, `kill` or `docker stop` terminates mid-operation.
For stateful apps this causes: orphaned connections, inconsistent data, lost work.

Pattern:
1. Register SIGTERM + SIGINT handlers
2. Set shutdown flag
3. Stop accepting new work
4. Run cleanup callbacks (close connections, flush buffers, save state)
5. Timeout (30s) — if cleanup hangs, force exit
6. Exit cleanly

---

## Phase 11: CI/CD & Quality Gates

### Deliverables
- [ ] GitHub Actions (or equivalent) workflow file
- [ ] Pipeline: lint → type check → test (with Docker services if DB/cache needed)
- [ ] Pre-commit hooks: syntax check, secret detection, stack-specific checks
- [ ] `Makefile` (or equivalent) with common commands

### Minimum Makefile commands

```makefile
make install       # Install production dependencies
make dev           # Install with dev dependencies
make lint          # Linter check
make format        # Auto-format code
make type-check    # Type checker (mypy, tsc, etc.)
make test          # Run all tests
make test-fast     # Unit tests only (no integration/slow)
make docker-up     # Start infrastructure (DB, cache, etc.)
make docker-down   # Stop infrastructure
```

### CI with infrastructure services

If tests need database/cache, add them as service containers in CI:

```yaml
services:
  postgres:
    image: postgres:16
    env: { POSTGRES_PASSWORD: test }
    options: --health-cmd "pg_isready" --health-interval 10s
  redis:
    image: redis:7-alpine
    options: --health-cmd "redis-cli ping" --health-interval 10s
```

---

## Phase 12: Documentation

### Deliverables
- [ ] `CLAUDE.md` — concise project pill (< 60 lines, links to detailed docs)
- [ ] `docs/architecture.md` — full architecture (diagram, modules, patterns, DB schema, data flow)
- [ ] `docs/logging-system.md` — log structure, format, routing, debugging commands
- [ ] `docs/plans/` — directory for implementation plans
- [ ] `.env.example` — documented template of all environment variables

### Documentation placement rule

| Content | Where | Why |
|---------|-------|-----|
| Quick reference, routing, rules | `CLAUDE.md` | Loaded every conversation — must be lean |
| Architecture details | `docs/architecture.md` | Read on demand — can be detailed |
| Logging system | `docs/logging-system.md` | Read when debugging — can be detailed |
| Implementation plans | `docs/plans/` | Historical record |
| API docs | Auto-generated (Swagger/OpenAPI) | Always up to date |

---

## Phase 13: Foundation Verification Audit

**MANDATORY before announcing "foundation complete."** Run through every item:

### Code quality
```bash
make lint          # Zero errors
make type-check    # Zero errors
make test          # All pass, zero failures
```

### Structure audit
- [ ] Every module has `__init__.py` (Python) or equivalent
- [ ] Every external service has an interface/ABC AND a mock implementation
- [ ] Every config value comes from .env or config file (grep for hardcoded values)
- [ ] No `print()` statements anywhere (linter enforces this)

### Security audit
- [ ] `.env` is in `.gitignore` — verify with `git status`
- [ ] `.env.example` exists with ALL variables documented
- [ ] Startup validation rejects default/empty credentials
- [ ] Pre-commit hook catches secrets in staged files
- [ ] Auth middleware applied to all endpoints except health/login

### Logging audit
- [ ] `logs/` directory structure matches `docs/logging-system.md`
- [ ] JSON format in files, human-readable in console
- [ ] Error aggregation log exists (`system/errors.log`)
- [ ] Correlation context works (test: set context → log → verify fields present)

### Resilience audit
- [ ] Retry decorator exists and is tested (transient retry, logic no-retry, exhaustion)
- [ ] Shutdown handler exists and is tested (signal → callback → timeout)
- [ ] Config validation rejects invalid files at startup

### Documentation audit
- [ ] `CLAUDE.md` under 60 lines
- [ ] `docs/architecture.md` matches actual directory structure
- [ ] `docs/logging-system.md` matches actual log file layout

### Agent routing audit (CRITICAL)
- [ ] `CLAUDE.md` contains "## Agent routing" section with a table
- [ ] Every tech stack layer has a matching agent row (backend → language-pro, SQL → sql-pro, etc.)
- [ ] `code-reviewer` row exists with "MANDATORY — never skip"
- [ ] `debugger` row exists with "Start from logs"
- [ ] Non-negotiable rules section exists with "ALWAYS use the agent specified in the routing table"
- [ ] Workflow line exists: brainstorming → writingplans → executingplans → code-reviewer → commit
- [ ] Agent names match what marketplace actually provides (verify with: ls of plugin agents)

**All checks pass?** → **"Foundation complete. Ready to write business logic."**

---

## Execution Order

Run phases in this order. Each builds on the previous.

```
Phase 1:  Repository + Marketplace plugins  (10 min)
Phase 2:  Claude Code config                (15-30 min)
Phase 3:  Architecture & dependencies       (30-60 min — biggest phase)
Phase 4:  Docker & infrastructure           (10 min)
Phase 5:  Config & secrets management       (15 min)
Phase 6:  Logging infrastructure            (20 min)
Phase 7:  Exception hierarchy               (15 min)
Phase 8:  Security foundation               (20 min)
Phase 9:  Testing infrastructure            (15 min)
Phase 10: Resilience patterns               (15 min)
Phase 11: CI/CD & quality gates             (10 min)
Phase 12: Documentation                     (15 min)
Phase 13: Verification audit                (10 min)
```

**Total: ~3-4 hours for a complete, professional foundation.**

---

## Anti-Patterns — What NOT to Do

1. **Don't skip marketplace plugins** — they contain tested, up-to-date agents and skills
2. **Don't skip logging setup** — "I'll add logging later" = `print()` everywhere, never refactored
3. **Don't use bare exceptions** — `except Exception: pass` hides bugs. Custom hierarchy from day 1.
4. **Don't hardcode anything** — secrets, URLs, ports, timeouts — all in config
5. **Don't skip test infrastructure** — if there's no setup, no tests will be written
6. **Don't put everything in CLAUDE.md** — it eats context window. Link to docs/ instead.
7. **Don't skip interfaces/ABCs** — adding them later means refactoring every caller
8. **Don't skip pre-commit hooks** — they catch secrets and syntax errors before they reach git
9. **Don't skip startup validation** — app should REFUSE to start with invalid config, not crash mid-work
10. **Don't skip Docker setup** — "I'll install Postgres manually" leads to "works on my machine" syndrome
11. **Don't skip domain safety rules** — general security isn't enough for financial/medical/critical systems
