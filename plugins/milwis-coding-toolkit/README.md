# milwis-coding-toolkit

Complete development toolkit: language-specific coding agents, security review, debugging, code review, and development workflow skills.

## Agents

### Language Experts (with AI error prevention)

| Agent | Language | Focus |
|-------|----------|-------|
| python-pro | Python 3.13+/3.14 | AI error prevention, PEP 8, type hints, async, security |
| javascript-pro | JavaScript/TypeScript | Security-first, ES2025, XSS/injection prevention, npm defense |
| sql-pro | SQL | AI error prevention, query optimization, injection defense |
| php-pro | PHP 8.3+/8.4/8.5 | Security-first, PSR-12, Laravel/Symfony, AI vulnerability mitigation |

### Universal Tools

| Agent | Focus |
|-------|-------|
| backend-security-coder | Three-tier security boundary system (Always/Ask/Never) |
| code-reviewer | Structured 7-axis reviews with severity labels |
| debugger | Systematic 6-step root cause analysis, log-first approach |
| database-optimizer | Database performance tuning and optimization |
| refactoring-specialist | Safe code transformation techniques |
| test-automator | Comprehensive test automation strategies |
| mobile-pwa-developer | PWA development with offline-first architecture |

## Skills

### Workflow skills (slash commands)

| Skill | Description |
|---|---|
| `/lang-guidelines <language>` | Create or update a language-specific expert agent |
| `/brainstorming` | Scalable design sessions (LIGHT/FULL) before implementation |
| `/writingplans` | Write comprehensive implementation plans with TDD |
| `/executingplans` | Execute plans task-by-task with stop-the-line discipline |
| `/new-project` | Universal foundation scaffold for any new project |
| `/audit-360` | Comprehensive 360° code audit. Orchestrates parallel domain specialists, consolidates via code-reviewer (opus), reproduces P0 PoCs via debugger, self-reviews fix proposals against hallucinated APIs, and proposes agent updates from recurring patterns. Universal — adapts to any stack via `audit/INVENTORY.md` |

### Discipline skills (auto-triggered by matching context)

These skills are not slash commands — they auto-match based on their `description` field and get pulled in whenever the situation fits. They provide *guardrails* that every other skill and agent in this toolkit leans on.

| Skill | Triggers when | Core rule |
|---|---|---|
| `verification-before-completion` | About to claim anything is done / fixed / passing, or to commit / push / PR | No completion claims without fresh verification evidence in the same message |
| `test-driven-development` | Implementing any feature, bugfix, refactor, or behavior change | Red → verify red → green → verify green → refactor. No production code before a failing test |
| `systematic-debugging` | Any bug, test failure, or unexpected behavior | 4 phases before any fix: investigate → compare → hypothesize → fix. 3+ failed fixes = architectural problem |

## Development Workflow

The skills form a layered workflow:

```
         DESIGN              PLAN                IMPLEMENT
      /brainstorming  →   /writingplans   →   /executingplans
                                                    │
                                                    ▼
                          (for every task in the plan)
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
   test-driven-        systematic-debugging        verification-
   development        (when something breaks)      before-completion
   (for new code)                                  (before claiming done)
```

**Rules of thumb for agents working in any repo:**

1. **Before writing any production code** for a feature or bugfix → invoke `test-driven-development`.
2. **Before claiming anything is done / fixed / passing** (including marking a TodoWrite item `completed` or committing) → invoke `verification-before-completion`.
3. **When hitting any bug, test failure, or broken build** → invoke `systematic-debugging` *before* proposing a fix.
4. **For full feature development** → `/brainstorming` (if design unclear) → `/writingplans` → `/executingplans`, with the three discipline skills applied inside each step.

The three discipline skills are stackable and deliberately short — they are designed to be pulled in without derailing whatever else you're doing.
