# Foundation verification audit — full checklist

Used by `new-project` Phase 13. MANDATORY before declaring "foundation complete." Run every checkbox; if any is unchecked, return to that phase before adding business logic.

## Code quality

```bash
make lint          # zero errors
make type-check    # zero errors
make test          # all pass
```

## Structure

- [ ] Every module has `__init__.py` / equivalent
- [ ] Every external service has interface/ABC + mock
- [ ] Every config value comes from `.env` or config file (no hardcoded)
- [ ] No `print()` / `console.log` / `echo` for non-CLI output anywhere
- [ ] `src/` mirror in `tests/` — every public module has at least one test file
- [ ] Entry points clearly defined (CLI / API / worker)

## Security

- [ ] `.env` is in `.gitignore` (verify with `git status`)
- [ ] `.env.example` enumerates ALL variables read by the code
- [ ] Startup rejects default/empty/placeholder credentials
- [ ] Pre-commit hook catches secrets before commit
- [ ] Auth middleware on all endpoints except health/login (default deny)
- [ ] Rate limiting active on login (10/min) and API (60/min)
- [ ] Security headers on every response (CSP, X-Content-Type-Options, X-Frame-Options, HSTS in prod)
- [ ] Exception handlers never leak stack traces / internal paths to clients

## Logging

- [ ] `logs/` directory structure matches `docs/logging-system.md`
- [ ] JSON in files, human-readable in console
- [ ] `system/errors.log` exists and receives ERROR+
- [ ] Correlation context (`request_id`, `user_id`) appears in every log line
- [ ] Log rotation configured (5 MB max, 2 backups, doesn't lose lines)
- [ ] Linter rejects raw `print()` / `console.log` in production paths

## Resilience

- [ ] Retry decorator wraps all external service calls; tested with injected failures
- [ ] Shutdown handler tested — SIGTERM → cleanup → exit < 30s
- [ ] Config validation rejects malformed config files at startup
- [ ] Mock adapters support error injection and state inspection

## Documentation

- [ ] `CLAUDE.md` under 60 lines (loads in every conversation — keep lean)
- [ ] `docs/architecture.md` matches the actual directory structure
- [ ] `docs/logging-system.md` matches the actual `logs/` layout
- [ ] `.env.example` documents every variable's purpose + format
- [ ] `docs/plans/` directory exists for future implementation plans

## Agent routing (CRITICAL — without this, Claude bypasses the agents)

- [ ] `CLAUDE.md` has a `## Agent routing` section with a table
- [ ] Every tech layer in the project has an agent row
- [ ] `code-reviewer` row marked **MANDATORY** before commit
- [ ] `debugger` row mentions "start from logs"
- [ ] Non-negotiable rules section present (5–8 bullets)
- [ ] Workflow line: `brainstorming → writing-plans → executing-plans → code-reviewer → commit`
- [ ] Agent names match the marketplace (no typos like `code_reviewer` or `php_pro`)

## Domain safety (skip if N/A)

For projects identified in Step 0 as financial / medical / e-commerce / infrastructure:

- [ ] Dedicated rules file (`docs/domain-rules.md` or similar) with hard constraints
- [ ] Money handled as `Decimal` (never `float`) — assertion in tests
- [ ] PII fields encrypted at rest (verify schema)
- [ ] Audit log table exists for sensitive operations
- [ ] Idempotency keys on payment / billing endpoints

---

**All checks pass?** → "Foundation complete. Ready to write business logic."

**Any check fails?** → Return to that phase. Don't write business logic on a broken foundation — the cleanup later costs 10× the time saved now.
