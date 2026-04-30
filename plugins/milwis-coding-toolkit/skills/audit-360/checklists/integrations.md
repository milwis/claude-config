# Integration-class checklists (consolidator reference)

Each specialist has its own built-in checklists in its system prompt (from the marketplace). The lists below are **integration-class** checklists that the consolidator uses when mapping axis and priority. They are domain-agnostic — apply to any "this kind of integration" found in INVENTORY §5.

## Regulated external API (e-invoicing, government portals, regulators)

- [ ] TLS 1.2+, trusted CA certificate, no `CURLOPT_SSL_VERIFYPEER=0` / `verify=False`
- [ ] Schema validation before submission (XSD / JSON Schema)
- [ ] Cryptographic signing + signature verification on responses
- [ ] Idempotency: every request has a deterministic key derived from business identifiers
- [ ] Retry with exponential backoff on 5xx, NOT on 4xx
- [ ] Full session logging (`reference_number`, `session_token`, status) — but never PII in logs
- [ ] Long-term storage of acknowledgements (legal retention period, often 5+ years)
- [ ] Session token in secure storage (httpOnly cookie / server-side session, not localStorage)
- [ ] WHERE-guard on UPDATE of fields set after external commit (immutability of finalized records)

## Accounting / ERP integration (financial data into a downstream system)

- [ ] Every accounting write inside a DB transaction (`BEGIN`...`COMMIT`/`ROLLBACK`)
- [ ] Idempotency key on imports (hash of `document_number + entity_id + date + amount`)
- [ ] Document/entity identifier validation (NIP/SSN/IBAN checksum) BEFORE export
- [ ] Account mapping in config, never hardcoded
- [ ] Single source of truth — conflict resolution rules documented
- [ ] Dual-write protection (no chance of double-posting the same document)
- [ ] File + DB writes wrapped in transaction with cleanup on failure

## AI-specific (paired with `code-reviewer` AI scrutiny pass — `prompts/07-code-reviewer-ai.md`)

- [ ] Every package in dep manifests exists in the official registry, has >1000 weekly downloads OR is the official client for the integration
- [ ] No package published <30 days before the code was written (unless pinned to a known version)
- [ ] No `verify*()`, `authenticate*()`, `is*Valid()` returning literal `true` without logic
- [ ] No placeholders (`// TODO real implementation`, `throw new Exception("not implemented")`) in production code
- [ ] Every integration has a fallback / error path, not just happy path
- [ ] No hardcoded URLs to non-existent APIs (cross-check against official docs)
- [ ] Comments describe what the code actually does (sample 50 functions manually)
- [ ] No files >1500 LOC (long-context degradation)
- [ ] Naming convention consistent within each module
- [ ] No scattered "debug" / "test" / "diagnostic" endpoints in production routes
- [ ] `.claude/settings.json`, `hooks`, `mcpServers` in repo verified against CVE-2025-59536 / CVE-2026-21852
- [ ] No duplicate classes (`UserService` + `UserService2` + `UserManager`) — Claude Code tends to create files instead of editing
- [ ] Class name reflects current implementation (no `GeminiService` calling OpenAI)
- [ ] Single source of truth for `APP_VERSION` / similar version constants
- [ ] One validator per domain concept (NIP / email / IBAN — never three implementations)
- [ ] Every hard-rule from CLAUDE.md / docs/standards/ has zero direct violations in code
