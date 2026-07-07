---
name: audit-360
description: Comprehensive 360° code audit. Orchestrates parallel domain specialists from milwis-coding-toolkit (security, language experts, SQL, DB, architecture, AI-scrutiny, tests, dependencies), consolidates findings via code-reviewer (opus), reproduces P0 PoCs via debugger, self-reviews fix proposals against hallucinated APIs, and proposes agent updates from recurring patterns. Universal — adapts to any stack via audit/INVENTORY.md. Use when the user asks for "360 audit", "full code audit", "security review of project", "post-vibe-coding audit", "AI-generated code review", "pre-deploy audit", or runs after major sprints / quarterly cadence.
---

# Audit 360° (universal multi-stack code audit)

This skill is **orchestration-only**. Each specialist's prompt lives in its own file under `prompts/` — read them on demand when spawning that specialist. This keeps the skill body small (the full content of all specialist prompts together would put ~16 KB into your conversation context for the rest of the session).

## 0. What this skill produces

For any repository — regardless of language, framework, or domain:

- `audit/INVENTORY.md` — project context (stack, dependencies, integrations, schemas, hot files, project hard-rules)
- `audit/findings/NN-<area>.md` (one file per specialist) — raw findings with stable ID prefixes
- `audit/REPORT.md` — consolidated report with P0/P1/P2 classification, cross-confirmation matrix, top risks, deploy recommendation, strengths
- `audit/FIX_PROPOSALS.md` — diff-style fixes for every P0/P1, each with a TDD-style failing test
- `audit/repro/P0-NNN.md` — PoC reproduction artefacts for every P0
- `audit/AGENT_UPDATES.md` — proposed additions to specialist agents derived from recurring patterns (closes the feedback loop)

## 1. Prerequisites — `milwis-coding-toolkit` plugin

This skill DELEGATES to specialists from the `milwis-coding-toolkit` plugin. Without it, the skill cannot run.

```bash
/plugin list                                  # verify the plugin is enabled
/plugin install milwis-coding-toolkit         # if missing
```

Specialists invoked via the Task tool (`subagent_type: <name>`):

| # | Agent | Model | Domain | Prompt file |
|---|-------|-------|--------|-------------|
| 1 | `backend-security-coder` | sonnet | Three-tier security boundary (Always/Ask/Never) | `prompts/01-backend-security.md` |
| 2 | `php-pro` | inherit | PHP 8.3+ — strict types, OWASP, AI anti-patterns | `prompts/02-php-pro.md` |
| 3 | `python-pro` | inherit | Python 3.13+ — type safety, async, security | (use the same skeleton as `02-php-pro.md`, with python-pro categories) |
| 4 | `javascript-pro` | inherit | JS/TS — XSS, async, npm supply chain | `prompts/03-javascript-pro.md` |
| 5 | `sql-pro` | inherit | SQL injection, NULL handling, dialect, immutability | `prompts/04-sql-pro.md` |
| 6 | `database-optimizer` | inherit | Indexes, N+1, query plans, schema, partitioning | `prompts/05-database-optimizer.md` |
| 7 | `refactoring-orchestrator` (read-only audit mode) | inherit | Architecture, complexity, dead code | `prompts/06-refactoring-orchestrator.md` |
| 8 | `code-reviewer` | **opus** | AI-specific deep scrutiny | `prompts/07-code-reviewer-ai.md` |
| 9 | `test-automator` | sonnet | Coverage, test quality, anti-patterns | `prompts/08-test-automator.md` |
| 10 | `<lang>-pro` (2nd pass) | inherit | Dependencies + docs | `prompts/09-deps-docs.md` |
| 11 | `code-reviewer` | **opus** | Consolidation | `prompts/10-consolidator.md` |
| 12 | `debugger` | sonnet | PoC reproduction (one call per P0) | `prompts/11-debugger-repro.md` |
| 13 | `code-reviewer` | **opus** | Self-review (forked instance) | `prompts/12-self-review.md` |

Discipline skills active throughout (auto-loaded by the plugin):

- `verification-before-completion` — no specialist reports "done" without evidence
- `systematic-debugging` — guards `debugger` during PoC reproduction
- `test-driven-development` — guards fix-proposal generation (failing test before fix)

## 2. When to run this skill

- User asks for "360 audit", "code audit", "security review", "audit what AI wrote", "pre-deploy review"
- After a major sprint / before production deploy
- After an extended vibe-coding session (>5 days in auto-accept mode)
- Quarterly cadence for active projects
- Onboarding a new contributor to a long-lived AI-generated codebase

## 3. Procedure — orchestrated by the main agent

The MAIN agent (current Claude Code session) drives the procedure. All specialists are invoked via the Task tool.

**Announce at start**: "Running the audit-360 skill. I will delegate to N specialists from milwis-coding-toolkit and consolidate via code-reviewer (opus)."

### STEP 0 — Pre-flight sanity check

```bash
# 1. Claude Code version — multiple known CVEs require recent versions
claude --version
# Required: ≥ 2.0.65 (CVE-2026-21852), ≥ 1.0.111 (CVE-2025-59536),
#           ≥ 1.0.20  (CVE-2025-54795),  ≥ 1.0.4   (CVE-2025-55284)

# 2. Marketplace plugin
/plugin list | grep milwis-coding-toolkit

# 3. Hostile .claude/ contents in the repo
ls -la .claude/ 2>/dev/null
cat .claude/settings.json 2>/dev/null
find . -name "settings.local.json" -path "*/.claude/*"

# 4. Audit branch snapshot
git checkout -b "audit/360-$(date +%Y%m%d)"
git log --oneline -20
```

If `.claude/settings.json` in the repo declares unexpected `hooks`, `mcpServers`, or `env.ANTHROPIC_BASE_URL` — **HALT THE AUDIT** and report as P0 (potential RCE / API key exfiltration; pattern from CVE-2025-59536 / CVE-2026-21852). Do not run any subagent against a repository with unverified Claude Code configuration.

### STEP 1 — Inventory (main agent only, no subagents, ~10 min)

Build `audit/INVENTORY.md`. This file is the shared context for every specialist — it MUST capture the project's stack, integrations, and conventions so each specialist's prompt stays generic.

Required sections (adapt headings; never skip):

1. **Environment** — language runtimes (`php --version`, `node --version`, `python --version`, …), OS, deployment target.
2. **Codebase statistics** — `cloc . --exclude-dir=vendor,node_modules`, files + LOC per language, top 20 files by LOC.
3. **Architecture layers** — auto-detect controllers/handlers, services, repositories, migrations, frontend modules. Count each.
4. **Dependencies** — paste `composer.json` / `package.json` / `requirements.txt` / `go.mod` / `Cargo.toml`. Note lockfiles. Distinguish direct vs transitive.
5. **External integrations** — extracted from code: third-party APIs, payment processors, accounting/ERP systems, regulators, government portals, OAuth providers, message queues, analytics. For each: file paths, env vars, criticality (financial / PII / regulated / informational).
6. **Databases** — engines, versions, schema sources, multi-DB topology if present.
7. **Environment variables** — paste `.env.example` (NEVER `.env`). Classify each (DB / secret / feature flag / integration). Detect drift between `.env.example` and code (`grep getenv/$_ENV/process.env/os.environ`).
8. **Claude Code config in repo** — `.claude/agents`, `.claude/skills`, `.claude/settings.json`. `CLAUDE.md` presence + size (>300 LOC = note for code-reviewer).
9. **Project hard-rules** — extract verbatim from `CLAUDE.md` / `docs/standards/` lines containing: `NEVER`, `ALWAYS`, `MUST`, `MUSI`, `NIGDY`, `ZAWSZE`, `ZASADA BEZWZGLĘDNA`, `MANDATORY`, `FORBIDDEN`, `OBOWIĄZKOWE`. These become the project's domain invariants — every specialist will be told to grep for violations.
10. **Hot files** — files >1500 LOC (long-context degradation risk), files >2500 LOC (CRITICAL split needed), top 10 most-changed files (`git log --pretty=format: --name-only | sort | uniq -c | sort -rn | head`).
11. **Conventions** — naming, error handling, logging patterns, folder layout. Anything an AI editing the code should know.
12. **Specialist mapping** — which `audit/findings/NN-<area>.md` is owned by which specialist, and what the main areas are.

This inventory lets specialist prompts stay short and generic — "audit the project described in `audit/INVENTORY.md`" instead of hardcoding domain names.

### STEP 2 — Spawn specialists in parallel (one tool block)

**CRITICAL**: invoke all Task calls in a SINGLE message. That's the only way to get genuine parallelism in Claude Code.

For each specialist you want to run:

1. Read the corresponding prompt file from `prompts/` (Read tool).
2. Substitute `<INVENTORY_PATH>` with the actual absolute path to `audit/INVENTORY.md`.
3. Use the body as the `prompt` parameter of the Task call.

Specialist selection adapts to the stack detected in INVENTORY:

| Always spawn (every audit) | Conditional |
|---|---|
| `backend-security-coder` (`prompts/01-backend-security.md`) | `php-pro` (`prompts/02-php-pro.md`) — if `*.php` files present |
| `code-reviewer` AI-scrutiny pass (`prompts/07-code-reviewer-ai.md`) | `python-pro` — if `*.py` files present |
| `test-automator` (`prompts/08-test-automator.md`) | `javascript-pro` (`prompts/03-javascript-pro.md`) — if `*.js`/`*.ts` |
| `sql-pro` (`prompts/04-sql-pro.md`) — if any DB queries detected | `refactoring-orchestrator` (`prompts/06-refactoring-orchestrator.md`) — if codebase >5k LOC OR any file >1500 LOC |
| `database-optimizer` (`prompts/05-database-optimizer.md`) — if any DB present | second pass of the project's primary language specialist for `dependencies + docs` (`prompts/09-deps-docs.md`) |

Each specialist writes to `audit/findings/NN-<area>.md` with a unique ID prefix (`SEC-BE-`, `PHP-`, `JS-`, `SQL-`, `DB-`, `ARCH-`, `AI-`, `TEST-`, `DEP-`, …) and follows the finding format from §7.

### STEP 3 — Critical-stop gate

After all specialists return, the main agent does NOT proceed to consolidation if any of:

- a single specialist reported ≥ 2 findings classified P0
- total raw P0 across all specialists ≥ 3
- any specialist found a leaked secret, RCE primitive, or slopsquatted package

Then:

- Display: **"🛑 CRITICAL findings detected, audit halted at consolidation phase"**
- Show the P0 list with file:line + recommended immediate action (rotate secrets, take down endpoint, hotfix)
- Wait for user decision: continue full report / freeze deploy / hotfix-first

### STEP 4 — Consolidation by `code-reviewer` (opus)

Read `prompts/10-consolidator.md`, substitute `<INVENTORY_PATH>`, spawn `code-reviewer` with `model: opus`. The consolidator dedupes, applies escalation rules from §6, generates `audit/REPORT.md` and `audit/FIX_PROPOSALS.md`, and runs **two mandatory self-checks** at the end:

- **CHECK A (numeric consistency)**: counts in tables match executive summary
- **CHECK B (fix-proposal hallucination)**: every recommended class/method/package is verified to exist via grep / `npm view` / `composer show`

Skipping either check has produced miscounts of 30%+ and recommendations to call non-existent methods in real audits.

### STEP 5 — PoC reproduction for every P0 (`debugger`)

For each P0 in the consolidated report, read `prompts/11-debugger-repro.md`, substitute `<NNN>` and `<INVENTORY_PATH>`, spawn `debugger`. The debugger writes `audit/repro/P0-NNN.md` with status `REPRODUCED` / `NOT_REPRODUCED` / `THEORETICAL`. NOT_REPRODUCED after 3+ attempts → de-escalate to P1 with note in REPORT.

### STEP 6 — Self-review (forked code-reviewer, opus)

Read `prompts/12-self-review.md`, substitute `<INVENTORY_PATH>`, spawn a FRESH `code-reviewer` with `model: opus`. The self-reviewer checks the consolidator's work — verifies P0 PoC completeness, evidence grounding, fix safety, hallucinated APIs in fix proposals, executive summary numeric accuracy, missed cross-confirmations, and strengths claims. Verdict (`PASS` / `PASS-WITH-NOTES` / `FAIL`) appended to `REPORT.md` as `## Self-review`.

### STEP 7 — Verification before claiming done

```bash
wc -l audit/REPORT.md
ls -la audit/findings/
ls -la audit/repro/
grep -c '^### P0-' audit/REPORT.md
grep -c '^| P1-'  audit/REPORT.md
grep -c '^| P2-'  audit/REPORT.md
```

Show output to the user. Without this, the audit is not "done".

### STEP 8 — Feedback loop: propose agent updates

This step closes the loop between findings and the agents that should have prevented them.

For each pattern observed ≥ 2× in the consolidated report (e.g., "21 occurrences of `lastInsertId()` without `(int)` cast", "7 occurrences of direct UPDATE bypassing the canonical service"), produce `audit/AGENT_UPDATES.md` with:

```
## Pattern: <one-line description>

**Observed**: NN occurrences in <files>
**Severity in audit**: P0 / P1 / P2
**Target agent(s)**: php-pro, sql-pro, javascript-pro, …
**Proposed addition** (drop-in markdown for the agent):

   <ready-to-paste section>

**Rationale**: why the agent should have caught this before the code shipped
```

Present the file to the user and ASK whether to apply the updates. Do not modify any agent without explicit approval. The file itself is a useful audit artefact even when the user declines.

## 4. Common rules for every specialist

Every Task call's prompt (already encoded in the `prompts/` files) tells the specialist:

1. **Project context**: path to `audit/INVENTORY.md` — read first.
2. **Read-only mode**: do NOT modify project code, only write to `audit/findings/NN-<area>.md`.
3. **Output format**: every finding has the §7 structure (`id`, `severity`, `file:line`, `evidence`, `impact`, `recommendation`).
4. **Anti-hallucination**: if no problems in a category, write `none found` — never invent.
5. **Quote real code**: every finding cites a snippet read via Read/Grep, never assumed.
6. **Tool-call budget**: ~50 tool calls per specialist. On overrun, stop with `truncated: true` + list of unexplored areas.
7. **No nested subagents**: specialists do not spawn further Task calls (Anthropic SDK limit).
8. **Verify recommendations**: any class / method / package suggested in a fix proposal must be confirmed to exist (`grep` / `npm view` / `composer show`) before being written into the report.
9. **Hard-rules from INVENTORY §9**: grep the codebase for direct violations of every project hard-rule. Each violation = at least P1, automatic P0 if the rule concerns financial / regulated / PII data.

## 5. Specialist prompts — reference table

All specialist prompts live in `prompts/` so the main skill stays small. The workflow is always:

1. Read `prompts/<NN>-<name>.md`.
2. Find the fenced code block with the `subagent_type` / `description` / `prompt:` lines.
3. Substitute `<INVENTORY_PATH>` (always required) and any other placeholders documented in the file.
4. Use the body as the `prompt` parameter of the Task call.

| File | Purpose | When to use |
|------|---------|-------------|
| `prompts/01-backend-security.md` | Tier-1 security audit | Always |
| `prompts/02-php-pro.md` | Deep PHP audit | If `*.php` files |
| `prompts/03-javascript-pro.md` | Deep JS/TS audit | If `*.js`/`*.ts`/`*.tsx` |
| `prompts/04-sql-pro.md` | SQL injection / NULL / DDL / immutability | If any DB queries |
| `prompts/05-database-optimizer.md` | Indexes / N+1 / EXPLAIN / partitioning | If any DB |
| `prompts/06-refactoring-orchestrator.md` | Architecture / complexity / debt | If codebase >5k LOC OR file >1500 LOC |
| `prompts/07-code-reviewer-ai.md` | AI-specific 19-category scrutiny | Always |
| `prompts/08-test-automator.md` | Coverage / test quality | Always |
| `prompts/09-deps-docs.md` | Dependencies + docs (2nd pass) | Always |
| `prompts/10-consolidator.md` | Final report consolidation (opus) | Always, after all above |
| `prompts/11-debugger-repro.md` | One call per P0 from REPORT | After consolidation |
| `prompts/12-self-review.md` | Forked self-review of REPORT (opus) | After repro |

## 6. Priority classification (P0/P1/P2)

Modeled on CVSS v3.1/v4.0 + OWASP Risk Rating + production heuristic. The 5-axis severity from `code-reviewer` (🔴/🟡/🔵/⚪/ℹ️) maps to P0/P1/P2 inside `prompts/10-consolidator.md` STEP 3.

| Priority | Severity | Auto-assignment | Reaction time |
|----------|----------|-----------------|---------------|
| **P0** | 🔴 CRITICAL | CVSS ≥ 9.0 OR RCE / DB access / secret theft / auth bypass / PII leak / compromised regulated data | **24 h** (hotfix or feature flag off) |
| **P1** | 🟡 REQUIRED | CVSS 7.0–8.9 OR conditionally-exploitable / serious architectural defect / missing transactions in financial flows / coverage <50% | **7 days** |
| **P2** | 🔵 OPTIONAL / ⚪ NIT | CVSS < 7.0 OR quality / maintainability / docs / minor | **30 days** or backlog |

### Escalation / de-escalation

- **Escalate P1 → P0** when the finding:
  - touches financial / regulated / PII data (per INVENTORY §5),
  - violates a hard-rule from INVENTORY §9 (`NEVER`/`ALWAYS`/`MUSI`/`NIGDY`/`ZASADA BEZWZGLĘDNA`),
  - occurs ≥3 times across the codebase,
  - is generated by a single Claude Code session (cascade risk),
  - is **cross-confirmed by ≥2 specialists** (auto-escalation in STEP 4).

- **De-escalate P0 → P1** when:
  - endpoint is auth-protected + admin-only + small blast radius + monitored,
  - `debugger` in STEP 5 marks `NOT_REPRODUCED` or `THEORETICAL`.

### CVSS mapping

| CVSS Base | Severity (NVD) | audit-360 priority |
|-----------|----------------|---------------------|
| 9.0–10.0 | Critical | P0 |
| 7.0–8.9  | High     | P0 (auth/finance/PII) or P1 (other) |
| 4.0–6.9  | Medium   | P1 (auth/finance/PII) or P2 (other) |
| 0.1–3.9  | Low      | P2 |

## 7. Final report format (`audit/REPORT.md`)

```markdown
# Audit 360° Report — <Project Name>

**Date**: <YYYY-MM-DD>
**Branch / commit**: <branch> / <sha>
**Performer**: Claude Code <version> + skill `audit-360` v<x.y>
**Plugin marketplace**: milwis-coding-toolkit
**Specialists**: <list of subagent_types invoked>
**Consolidator**: code-reviewer (model: opus)

## 1. Executive summary

- Finding counts: P0 = X, P1 = Y, P2 = Z
- Top 3 risks (concrete file paths)
- Deploy recommendation: GO / NO-GO / GO-WITH-FIXES
- Estimated effort to fix P0+P1: <hours>
- PoCs reproduced: A/X

## 2. Per-specialist statistics

| Specialist | File | P0 raw | P1 raw | P2 raw |
|-----------|------|--------|--------|--------|

## 3. Findings P0 (critical) — full detail

### P0-001 [SEC-BE-013, AI-007] <one-line title>

- **Axis**: 🔴 SECURITY
- **Category**: OWASP A03:2021 Injection / CWE-89
- **CVSS**: 9.8
- **Cross-confirmed by**: SEC-BE-013, AI-007
- **Location**: `src/Invoice/Search.php:47`
- **Evidence**:
  ```php
  $sql = "SELECT * FROM invoices WHERE number LIKE '%" . $_GET['q'] . "%'";
  ```
- **Impact**: <…>
- **PoC**: audit/repro/P0-001.md, status REPRODUCED
- **Recommendation**: see FIX_PROPOSALS.md#P0-001
- **Failing test (TDD)**: <code block>
- **Priority justification**: <…>

## 4. Findings P1 (high) — table

| ID | Title | Axis | Location | XConf |
|----|-------|------|----------|-------|

## 5. Findings P2 (medium/low) — short table

| ID | Title | file:line | Specialist |
|----|-------|-----------|------------|

## 6. Per-integration risk map

| Integration (from INVENTORY §5) | P0 | P1 | P2 | Deploy status |
|-------------|----|----|----|---------------|

## 7. Strengths

- Specific facts (paths, counts), not generalities.

## 8. Test coverage assessment

## 9. Self-review (forked code-reviewer)

## 10. P0 reproduction (debugger)

## 11. Attachments

- audit/findings/*.md
- audit/FIX_PROPOSALS.md
- audit/repro/P0-*.md
- audit/INVENTORY.md
- audit/AGENT_UPDATES.md (STEP 8 output)

## 12. Numerical self-check (STEP 4 CHECK A)

- `grep -c '^### P0-' audit/REPORT.md` = X (matches §1)
- `grep -c '^| P1-'  audit/REPORT.md` = Y (matches §1)
- `grep -c '^| P2-'  audit/REPORT.md` = Z (matches §1)
```

## 8. Reference files (read on demand)

- `checklists/integrations.md` — integration-class checklists used by the consolidator (regulated APIs, accounting/ERP, AI-specific). Read in STEP 4 if the consolidator needs them.
- `checklists/tools-cheatsheet.md` — language-specific tool commands (PHP, Python, JS/TS, MySQL, PostgreSQL, secrets/supply-chain). Read by a specialist when it needs tool guidance beyond what its system prompt covers.

## 9. Best practices (operating manual)

1. **Spawn in one tool block (STEP 2)**: the main agent invokes ALL Task calls in a single message. That's the only path to genuine parallelism.
2. **Each specialist gets its own context**: it does NOT inherit the project's `CLAUDE.md` automatically. The specialist prompts already point to `<INVENTORY_PATH>`.
3. **Output schema**: every specialist writes to `audit/findings/NN-<area>.md` with the §7 finding format.
4. **Read-only on the project**: specialists write only to `audit/findings/`. Consider `chmod -R a-w` on the audit branch as an extra guardrail.
5. **Time/token budget**: each specialist has a budget of ~50 tool calls. The prompt already says so.
6. **No nested subagents**: SDK limit — specialists never spawn more Task calls.
7. **Discipline overlay**: `verification-before-completion`, `systematic-debugging`, `test-driven-development` activate automatically inside each specialist (they're plugin-bundled).
8. **Consolidation must be opus**: STEP 4 — the consolidator runs on `model: opus`. Sonnet misses cross-confirmations.
9. **PoC reproduction is mandatory**: STEP 5 — P0 without reproduction = P1 with note.
10. **Self-review is mandatory**: STEP 6 — fresh forked `code-reviewer` checks the consolidator's work.
11. **Both self-checks are mandatory**: STEP 4 CHECK A (numeric) + STEP 6 (d) (hallucinated APIs). Both have caught 30%+ defects in the report itself in real audits.
12. **Feedback loop is the deliverable**: STEP 8 — without `audit/AGENT_UPDATES.md` the audit doesn't help future code.
13. **Skill announcement**: the main agent says "Running the audit-360 skill..." at start (marketplace skill convention).

## 10. Limitations and known false-positive patterns

- **Psalm taint analysis** can flag taint through custom sanitizers — add `@psalm-taint-escape` in docblocks.
- **PHPStan level max** flags `mixed` — many libraries in PHP <8 don't have type hints; assess case by case.
- **Semgrep `p/php`** has known false-positives on `htmlspecialchars` with dynamic flags.
- **Slopsquatting check** can false-positive on private packages (Packagist Private, npm scoped `@company/`) — keep an allowlist in `audit/.allowlist`.
- **`composer audit`** sometimes reports CVEs in transitive dependencies that don't affect the used code path — `code-reviewer` (STEP 4) checks `composer why` before listing.
- **Long-context degradation** — the AI-scrutiny `code-reviewer` itself can suffer. If an audited file is >2000 lines, the code-reviewer chunks the review and consolidates in a second pass.
- **`debugger` Iron Law**: 3+ failed reproduction attempts ⇒ de-escalate to P1, NOT ignore.

## 11. Quick start — single-command flow

User says: "Run a 360 audit on this branch."

The main agent:

1. **Announce** the skill.
2. `git checkout -b "audit/360-$(date +%Y%m%d)" $(git rev-parse --abbrev-ref HEAD)`
3. **STEP 0** — pre-flight (`.claude/`, Claude Code version, plugin enabled).
4. **STEP 1** — `audit/INVENTORY.md` (auto-detect stack, dump dependencies, classify integrations, extract hard-rules).
5. **STEP 2** — read the relevant `prompts/` files, spawn specialists in one tool block.
6. After all return — **STEP 3** (critical-stop gate).
7. **STEP 4** — consolidator via `prompts/10-consolidator.md` → `audit/REPORT.md` + `audit/FIX_PROPOSALS.md`.
8. **STEP 5** — `prompts/11-debugger-repro.md` per each P0.
9. **STEP 6** — self-review via `prompts/12-self-review.md`.
10. **STEP 7** — `verification-before-completion` before presenting.
11. **STEP 8** — produce `audit/AGENT_UPDATES.md`; ASK whether to apply updates.
12. Output to user: report path + executive summary + GO/NO-GO + % of P0 reproduced + list of agent updates pending approval.

---

**Skill version**: 1.1 (refactored to skill+references pattern; SKILL.md kept under 500 lines per Anthropic guidance)
**Required Claude Code version**: ≥ 2.0.65 (CVE-fixed)
**Required plugin**: milwis-coding-toolkit (any version with the agents listed in §1)
