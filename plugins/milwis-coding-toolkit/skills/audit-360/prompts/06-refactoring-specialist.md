# Prompt for `refactoring-specialist` — architecture, complexity, debt

Paste the body below as the `prompt` parameter. Replace `<INVENTORY_PATH>`.

```
subagent_type: refactoring-specialist
description: Architectural audit — debt, complexity, large-file risk
prompt: |
  You are auditing architecture and structural quality of the application
  in <INVENTORY_PATH>. Mode: READ-ONLY (do NOT refactor — diagnose).

  Categories:

  A) PSR / linter compliance (per language).
  B) Complexity:
     classes >500 LOC = P2, >1000 = P1; methods >50 = P2, >100 = P1;
     cyclomatic >10 = P2, >20 = P1; files >1500 LOC = P1 (long-context
     degradation); files >2500 LOC = automatic CRITICAL.
  C) Duplication: phpcpd / jscpd, >5% = P1; identical validation/integration
     logic copied in N places.
  D) SOLID violations: god objects (30+ methods), switch on type instead of
     polymorphism, fat interfaces, hardcoded `new` instead of DI.
  E) DI: every external integration (API client, mailer, logger) must be
     injectable; new \PDO inside Service = P1.
  F) Layering: SQL in controllers, HTML in services, business logic in views.
  G) Routing: scattered if-else dispatch instead of one router.
  H) Error handling architecture: typed domain exception hierarchy?
     `catch (\Exception)` empty body? logging with structure?
  I) Naming consistency (key for AI-generated code): getX vs findX vs x_get
     in same project; camelCase vs snake_case mixed.
  J) Configuration: magic values in code instead of env; .env.example sync.
  K) AI red flags:
     over-engineering (5 abstraction layers for CRUD), under-engineering
     (1500-line procedural functions), premature abstraction (interface
     with one implementation), duplicate-class-creation tendency
     (UserService + UserService2 + UserManager).

  Tools:
     phploc / phploc; phpcs / eslint --max-warnings=0;
     phpmd codesize,cleancode,design,naming,unusedcode;
     phpcpd / jscpd --min-lines 5.

  Output: audit/findings/06-architecture.md, format from SKILL.md §7. Prefix: ARCH-.

  Operate under `test-driven-development`: every refactor proposal must
  include the characterization test to write BEFORE anyone refactors.
```
