# milwis-coding-toolkit

Complete development toolkit: language-specific coding agents, security review, debugging, code review, and development workflow skills.

## Agents

Since v1.6.0 every agent states a goal and where the rules live, not the rules themselves: a writer implements what the brief describes under the project's own rules (`CLAUDE.md`, `.claude/rules/*.md` loaded when it opens a matching file, the standards they link) and proves it with the project's checks. Rules a subagent must apply reach it only that way or as lines of its brief — a skill does not load inside a subagent from its description (0 of 278 queue builders). See `UPDATE_LOG.md` v1.6.0 and `/lang-guidelines`.

### Builders (writers, goal-only)

| Agent | Mostly | Done means |
|-------|--------|------------|
| php-pro | PHP | targeted tests + named latches green, static analysis and lint with covered paths, stale docs updated, committed |
| javascript-pro | JavaScript/TypeScript front end | same, with the project's lint and type checks |
| nextjs-pro | Next.js / React | same, with lint, type checks and the build |
| python-pro | Python | same, with the project's linters and type checker |
| sql-pro | SQL and migrations without application code | same; a destructive step only as its own requested stage with a rollback path |
| mobile-pwa-developer | PWA / mobile | same; a service-worker change has an update path |
| database-optimizer | query and index performance | before/after measurement on the same data, equal results |
| test-automator | tests; also the surface verifier for a `verify-e2e` brief | each named behaviour has a test seen red / `VERDICT:` first, no tracked change |
| debugger | root cause | cause at `file:line` + repro command + an excluded alternative; a fix red→green when asked |

One builder carries a whole issue across layers, in dependency order, and also updates the docs its change makes stale (`task-lifecycle` Step 1).

### Judgment agents

| Agent | Focus |
|-------|-------|
| code-reviewer | Decides whether a diff merges: spec, project rules for the touched paths (it Reads them), security when the diff touches a trigger, tests that can fail. Tiers S/M/L from `git diff --stat`, severities 🔴/🟡/🔵/⚪/ℹ️, measured findings, coverage ledger |
| backend-security-coder | Security audits (`audit-360`, explicit passes): exploit paths input → sink / missing check, each link measured; proposes fixes, never edits. A diff's security is reviewed by `code-reviewer` |
| refactoring-orchestrator | End-to-end refactoring orchestration: backup → baseline → audit → delegated execution → equivalence proof. Never codes itself |

### Model class — two-tier policy (2026-08-19)

The toolkit runs a deliberate two-tier split:

- **`sonnet` (writer agents):** php-pro, sql-pro, javascript-pro, test-automator, debugger, database-optimizer, nextjs-pro, python-pro, mobile-pwa-developer.
- **`opus` (judgment gates):** code-reviewer, backend-security-coder, refactoring-orchestrator.
- **Audits are the exception:** the `audit-360` skill spawns EVERY specialist with an explicit `model: opus` override — audits are rare and quality-critical (see `skills/audit-360/SKILL.md` §1).

History: on 2026-08-17 a uniform-Opus policy was adopted based on API list pricing (Opus 5 vs Sonnet 5 ≈ 1.7×, so ~15-20% total saving — arguably not worth a quality risk). That analysis did not apply to the owner's actual billing: a **Max subscription quota**, where usage is weighted by model class and Opus burns the quota several times faster than Sonnet — the owner was exhausting a Max20 limit in 2-3 days. On 2026-08-19 the owner decided the two-tier split. The audit that triggered the change (KonkretnyTMS 360°, 19.08.2026) also showed the recorded P0s were caused by missing *rules* in agent instructions, not by model capability — Opus wrote those bugs too — so the quality question is addressed by rules + Opus review gates rather than by an Opus-everywhere roster. Since v1.6.0 those rules live in the project, not in the agents.

Revisit with data, not intuition: `task-lifecycle` reports review iterations per task — if work that used to pass review in one round starts needing 2-3, that is the signal the smaller writer model is not carrying the task. Do not silently flip models back in a maintenance run (see UPDATE_LOG maintenance policy).

Ground truth for the reviewer itself: [AACR-Bench](https://huggingface.co/datasets/Alibaba-Aone/aacr-bench) (Alibaba, 200 real PRs, 10 languages, 1 505 engineer-annotated defects) — the reference set for measuring `code-reviewer` precision/recall before and after a prompt change; a rule that raises tokens without moving precision on it does not stay.

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
| `/task-lifecycle` | Full autonomous cycle for one task: one builder subagent (all layers, docs included) → code-review loop with security inside it, fixes by the same builder kept warm (cap 3) → `verify-e2e` in a fresh subagent → report package. Main session orchestrates, never codes |
| `/retro` | Retrospective on a finished roadmapa queue run / session: ledger + subagent transcripts → ranked toolkit change proposals, each with a POMIAR (command / file:line) and final rule text. Runs after the run, applies nothing on its own |
| `/roadmapa` | The issue queue: an explicit list or the bug backlog P0→P3 without end; a lead in tmux handles one issue per session (fresh subagent: triage on HEAD + `task-lifecycle`), merges locally with `[roadmapa]` and closes the issue, then `/clear`. Started by the owner with `scripts/kolejka.sh start`; never pushes, never builds features from the backlog |
| `/deploy` | Owner-only (`disable-model-invocation: true`) production deploy for KonkretnyTMS: drives the repo's own `procedury.md` §DEPLOY (source of truth, never duplicated), adds owner stop-points (unreviewed `[roadmapa]` merges, changelog + version bump approval, any red gate) and pitfalls measured on failed deploys. Stops if the repo has no such procedure |
| `/nowe-issue` | Create GitHub issues sized for ONE `task-lifecycle` run (queue L2 or a single web session): duplicate check, measured anchors, a large problem split into an umbrella + independent portions in dependency order; mandatory label axes `modul:*` / `P0-P3` / `srodowisko:web\|lokalne` / `typ:*` read live from the repo and validated after creation (`scripts/sprawdz-etykiety.sh`, also `--otwarte` for a backlog audit) |

### Discipline skills (auto-triggered by matching context)

These skills are not slash commands — they auto-match based on their `description` field and get pulled in whenever the situation fits, in the session that runs them. Inside a subagent they do not load (measured 0/278 builders): an orchestrator passes the rules it needs as lines of the brief (`task-lifecycle` Step 1).

| Skill | Triggers when | Core rule |
|---|---|---|
| `verification-before-completion` | About to claim anything is done / fixed / passing, or to commit / push / PR | No completion claims without fresh verification evidence in the same message |
| `verify-e2e` | After implementing any user-facing change (GUI, API, CLI, cron) | Verify on the SURFACE the user touches, in a fresh adversarial subagent, with evidence artifacts (screenshots / responses / recordings) |
| `test-driven-development` | Implementing any feature, bugfix, refactor, or behavior change | Red → verify red → green → verify green → refactor. No production code before a failing test |
| `systematic-debugging` | Any bug, test failure, or unexpected behavior | Logs first, then ONE command that goes red on this bug (minimised), 3–5 ranked hypotheses tested one at a time with the disproof first, fix at the root. 3+ failed fixes = architectural problem |
| `resolving-merge-conflicts` | A merge / rebase / cherry-pick is in progress with conflicts (e.g. merging a wave's `agent/issue-*` branches) | Resolve each hunk by the INTENT of each side traced to commit / issue / ledger; never invent behaviour, never `--abort`; run the project's checks; finish the operation |
| `migration` | Any change to a persisted or public shape (schema, data, API, protocol, config, dependency major) | Map readers/writers first; forward AND rollback path; expand → migrate → verify → contract; destructive steps authorized separately; never contract implicitly |

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
3a. **When the change alters a schema, stored data, API contract, config key or dependency major** → invoke `migration` before editing; stop after the requested stage.
4. **For full feature development** → `/brainstorming` (if design unclear) → `/writingplans` → `/executingplans`, with the three discipline skills applied by the orchestrator and written into every builder brief.

The discipline skills are stackable and deliberately short — they are designed to be pulled in without derailing whatever else you're doing. Each states its **Entry** and **Stop** condition in its header, so an orchestrator can check per stage whether the skill has actually finished.

## Autonomy Layer

On top of the workflow above sits the orchestration layer (added after Boris's "steps of AI adoption" — the goal is that the human reviews *outputs*, not the *process*):

```
              ONE TASK                          A QUEUE OF ISSUES
          /task-lifecycle                       /roadmapa (kolejka.sh)
                │                                      │
   one builder (+docs) → review with     pick (list | bugs P0→P3) → fresh
   security, fixes by the warm builder   subagent: triage + task-lifecycle
   (≤3) → verify-e2e → report package    → local merge [roadmapa] + close
                │                          → /clear → next issue
                └──────────────┬───────────────────────┘
                               ▼
              user reviews: diff + evidence + blockers
              user decides: push / deploy (NEVER the agent)
```

Key principles baked in:

- **The orchestrator never writes code** — everything happens in subagents; the main context stays clean.
- **Verification is adversarial and isolated** — a fresh subagent tries to falsify the "done" claim on the user's surface (pixels / HTTP / CLI), producing evidence artifacts. Smarter models cheat more convincingly; isolation is the countermeasure.
- **Every loop has a hard cap** (3 review-fix, 3 verify-fix, one issue per lead session) — exhausted cap = stop and report, never spin.
- **BLOCKED is a first-class result** — missing test accounts / keys / tools get recorded in the project's `docs/VERIFICATION_ENV.md`, so the verification environment compounds over time.
- **Upstream feed:** `/audit-360` findings → GitHub issues (bug-typed, prioritised) → the `/roadmapa` queue closes the audit-to-remediation loop.
