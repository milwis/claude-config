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
| code-reviewer | Structured 5-axis reviews with severity labels |
| debugger | Systematic 6-step root cause analysis, log-first approach |
| database-optimizer | Database performance tuning and optimization |
| refactoring-specialist | Safe code transformation techniques |
| test-automator | Comprehensive test automation strategies |
| mobile-pwa-developer | PWA development with offline-first architecture |

## Skills

| Skill | Type | Description |
|-------|------|-------------|
| `/lang-guidelines <language>` | Slash command | Create or update a language-specific expert agent |
| `/brainstorming` | Slash command | Scalable design sessions (LIGHT/FULL) before implementation |
| `/writingplans` | Slash command | Write comprehensive implementation plans with TDD |
| `/executingplans` | Slash command | Execute plans task-by-task with stop-the-line discipline |

## Development Workflow

The skills form a complete workflow:

```
/brainstorming  →  /writingplans  →  /executingplans
  (design)          (plan)            (implement)
```
