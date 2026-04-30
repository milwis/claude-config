# Prompt for `test-automator` — coverage + quality

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: test-automator
description: Test coverage + quality audit — anti-patterns, mutation
prompt: |
  You are auditing the test strategy and quality of the application in
  <INVENTORY_PATH>. Mode: READ-ONLY.

  Operate under `test-driven-development` and `verification-before-completion`.

  Categories:

  A) Coverage:
     line coverage <30% = P0; 30-50% = P1; >50% with proper distribution = OK.

  B) Critical-path coverage (all integrations from INVENTORY §5
     classified as financial / regulated / PII): must be >80%.

  C) Mutation score (if Infection / Stryker / mutmut available):
     <60 MSI = P1 (tests are weak — don't catch changes).

  D) Test quality anti-patterns (CRITICAL for AI-generated code):
     - reflection-only tests (`ReflectionMethod`/`getParameters` as the
       only assertion) — tests the symbol exists, not behavior;
     - assertTrue(true) / expect(true).toBe(true) — always passes;
     - hardcoded environment (192.168.x, /home/dev/, fixed ports)
       breaking CI;
     - real subprocess + 60s polling = flaky;
     - mocks of the subject under test (testing the mock);
     - tests written AFTER the implementation (mocks return exactly
       what impl does; assertions mirror impl shape).

  E) Missing edge cases:
     null / undefined; empty arrays / strings; boundary dates (Y2038, leap
     years, DST); Unicode; long strings; concurrent requests; floating-point
     arithmetic on monetary values.

  F) Domain-specific edge cases (per integrations from INVENTORY §5):
     for each external integration — document the missing edge cases:
     timeout mid-session, schema validation failure, certificate
     expired/revoked, idempotency-key collision, rollback,
     dual-write protection.

  G) Fixtures:
     fixtures with real customer data (names/emails/national IDs) committed
     to repo = P0 GDPR/PII breach; missing .gitignore on fixtures dir;
     non-deterministic generators (rand without seed).

  H) Flaky tests:
     sleep/time without mocking, rand without seed, external API calls
     without VCR/Mockery.

  I) Integration vs unit:
     missing integration tests for end-to-end critical flows; only unit
     tests with heavy mocking = P1.

  J) CI integration:
     coverage threshold enforced? `composer audit` / `npm audit` step?
     ESLint/typecheck with `continue-on-error: true` = decoration, not gate.

  Tools:
     vendor/bin/phpunit --coverage-clover --coverage-text
     vendor/bin/infection --threads=4 --min-msi=70 || true
     pytest --cov --cov-report=term-missing
     vitest run --coverage

  Output: audit/findings/08-tests.md, format from SKILL.md §7. Prefix: TEST-.

  Each P0/P1 has a fix proposal in TDD format (failing test to write —
  someone else fixes the code).
```
