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
| nextjs-pro | Next.js 15+/React 19/TypeScript | App Router, Server Components, Server Actions as public endpoints, Next 15 caching semantics, CVE-2025-29927 |

### Universal Tools

| Agent | Focus |
|-------|-------|
| backend-security-coder | Three-tier security boundary system (Always/Ask/Never) |
| code-reviewer | Structured 7-axis reviews with severity labels |
| debugger | Systematic 6-step root cause analysis, log-first approach |
| database-optimizer | Database performance tuning and optimization |
| refactoring-orchestrator | End-to-end refactoring orchestration: backup → baseline → audit → delegated execution → equivalence proof. Never codes itself |
| test-automator | Comprehensive test automation strategies |
| mobile-pwa-developer | PWA development with offline-first architecture |

### Model class

Every agent in this toolkit runs on **Opus** (`model: opus` in each agent's frontmatter). This is uniform on purpose, and the uniformity is the decision — not an oversight nobody has optimized yet.

A two-tier split was evaluated (rule-driven producers on Sonnet, judgment gates on Opus) and rejected. The reasoning, kept here so it does not get re-litigated from scratch:

- **The price gap is small.** At list pricing, Opus 5 ($5/$25 per MTok) costs roughly 1.7x Sonnet 5 ($3/$15) — not the ~5x gap of the previous Opus generation. Moving half the roster to Sonnet saves on the order of 15-20% overall, depending on call mix.
- **The failure it buys is asymmetric.** These agents write and review backend code, migrations, and security-sensitive paths. A missed bug costs far more than 15% of a token budget, and the agents whose mistakes are *silent* — code-reviewer, backend-security-coder, debugger, sql-pro, database-optimizer — have to stay on Opus regardless, which is most of the saving gone before the risky part starts.
- **The remaining candidates are the ones under review anyway.** php-pro, python-pro, javascript-pro and nextjs-pro all produce backend code; there is no principled line that puts one on Sonnet and keeps another on Opus.

If this is revisited, revisit it with data rather than by intuition: `task-lifecycle` already reports the number of review iterations per task, so a tier change shows up as review rounds going from 1 to 2-3 on work that used to pass first time.

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
| `/task-lifecycle` | Full autonomous cycle for one task: build (subagent) → code-review loop with auto-fix (cap 3) → security pass → `verify-e2e` in a fresh subagent → report package. Main session orchestrates, never codes |
| `/issue-pipeline` | Batch resolution of GitHub issues / audit findings: triage against HEAD (stale findings die), file-disjoint batching, one `task-lifecycle` per issue on its own branch, monitor-by-exception, final status table |

### Discipline skills (auto-triggered by matching context)

These skills are not slash commands — they auto-match based on their `description` field and get pulled in whenever the situation fits. They provide *guardrails* that every other skill and agent in this toolkit leans on.

| Skill | Triggers when | Core rule |
|---|---|---|
| `verification-before-completion` | About to claim anything is done / fixed / passing, or to commit / push / PR | No completion claims without fresh verification evidence in the same message |
| `verify-e2e` | After implementing any user-facing change (GUI, API, CLI, cron) | Verify on the SURFACE the user touches, in a fresh adversarial subagent, with evidence artifacts (screenshots / responses / recordings) |
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

The discipline skills are stackable and deliberately short — they are designed to be pulled in without derailing whatever else you're doing.

## Autonomy Layer

On top of the workflow above sits the orchestration layer (added after Boris's "steps of AI adoption" — the goal is that the human reviews *outputs*, not the *process*):

```
              ONE TASK                          A BATCH OF ISSUES
          /task-lifecycle                       /issue-pipeline
                │                                      │
   build → review-fix loop (≤3)          triage on HEAD → batch by file-
   → security pass → verify-e2e           disjointness → one task-lifecycle
   → report package                       per issue → status table
                │                                      │
                └──────────────┬───────────────────────┘
                               ▼
              user reviews: diff + evidence + blockers
              user decides: merge / push / deploy (NEVER the agent)
```

Key principles baked in:

- **The orchestrator never writes code** — everything happens in subagents; the main context stays clean.
- **Verification is adversarial and isolated** — a fresh subagent tries to falsify the "done" claim on the user's surface (pixels / HTTP / CLI), producing evidence artifacts. Smarter models cheat more convincingly; isolation is the countermeasure.
- **Every loop has a hard cap** (3 review-fix, 3 verify-fix, 10 issues/run) — exhausted cap = stop and report, never spin.
- **BLOCKED is a first-class result** — missing test accounts / keys / tools get recorded in the project's `docs/VERIFICATION_ENV.md`, so the verification environment compounds over time.
- **Upstream feed:** `/audit-360` findings → GitHub issues → `/issue-pipeline` closes the audit-to-remediation loop automatically.
