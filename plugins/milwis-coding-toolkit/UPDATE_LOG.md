# Update Log

## Run: 2026-09-01 — Monthly maintenance sweep

### Updated
- **skills/new-project/SKILL.md** (486→488 lines): Added two-tier vulnerability-scan strategy as a RULE (fast production-only scan gates every PR, full scan including dev dependencies runs weekly as a CI artifact). Added "Action allowlisting enabled on the repo/org" to the CI/CD checklist (restrict workflows to approved third-party Actions). Reframed SBOM generation as a compliance-reporting prerequisite rather than a later add-on. Deliberately did NOT add PostgreSQL point-version bumps, PG19-beta status, or dated EU CRA enforcement dates found during research — per the 2026-08-19 maintenance policy above, dated version/news content is out of scope for this routine; only actionable rules were kept.

### Skipped (up to date, < 30 days)
- backend-security-coder.md: Last updated 2026-08-30 (2 days)
- code-reviewer.md: Last updated 2026-08-30 (2 days)
- database-optimizer.md: Last updated 2026-08-30 (2 days)
- debugger.md: Last updated 2026-08-30 (2 days)
- javascript-pro.md: Last updated 2026-08-30 (2 days)
- mobile-pwa-developer.md: Last updated 2026-08-30 (2 days)
- nextjs-pro.md: Last updated 2026-08-30 (2 days)
- php-pro.md: Last updated 2026-08-30 (2 days)
- python-pro.md: Last updated 2026-08-30 (2 days)
- refactoring-orchestrator.md: Last updated 2026-08-24 (8 days)
- sql-pro.md: Last updated 2026-08-30 (2 days)
- test-automator.md: Last updated 2026-08-30 (2 days)

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- audit-360/SKILL.md
- issue-pipeline/SKILL.md
- systematic-debugging/SKILL.md
- task-lifecycle/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md
- verify-e2e/SKILL.md
- lang-guidelines/SKILL.md — meta-skill for generating other agents; no "Last updated" of its own, no external technology domain to research (process definition)

### Deferred to next run
- None — only 1 evolving file found (new-project/SKILL.md), well within the 10-file cap

### Issues
- None — all 5 WebSearch queries returned useful results, no rephrasing needed, no git conflicts. Note: most research findings (PostgreSQL 18.6/19-beta, specific EU CRA dates) were discarded rather than applied, per the repo's own no-dated-news policy — see Updated section above.

### Next run priorities
- refactoring-orchestrator.md (will be ~38 days by next monthly run)
- All other agents will be ~33 days by next run — check for real rule changes (new AI error patterns, new CVEs), not version bumps

---

> **MAINTENANCE POLICY (obowiązuje rutynę miesięczną — od 2026-08-19):**
> 1. **Nie zmieniaj frontmatter `model:`** — podział jest celowy: `sonnet` dla agentów piszących, `opus` dla code-reviewer / backend-security-coder / refactoring-orchestrator. Audyty (audit-360) i tak spawnują specjalistów z override `model: opus` — patrz SKILL.md §1.
> 2. **Nie dodawaj sekcji „newsowych"** (wydania PostgreSQL/MySQL/Node/Safari, listy narzędzi, statystyki branżowe z datami). Zostały celowo usunięte 2026-08-19 — starzeją się co miesiąc, nie zmieniają decyzji przy pisaniu kodu i zżerają tokeny przy każdym wywołaniu agenta. Aktualizuj wyłącznie REGUŁY (co wolno / czego nie wolno / jak zweryfikować).
> 3. **Nie przywracaj sekcji frameworkowych do php-pro** (Laravel/Symfony) ani katalogów narzędzi do test-automator.
> 4. Stopka pliku agenta: jeden komentarz `<!-- Updated: ... -->` + `Last updated:`; historia żyje w tym pliku, nie w agentach.

## Run: 2026-08-30 — Klasa błędu „pomiar ≠ wniosek": procedura falsyfikacji u agentów piszących (v1.5.1)

Źródło: diagnoza agenta po fali 11 issues w KonkretnyTMS (2026-08-29/30). Sześciu agentów piszących popełniło ten sam błąd (jeden trzykrotnie): dwie prawdziwe przesłanki zmierzone, trzecia niezmierzona, wniosek fałszywy (403 CSRF vs globalny interceptor; `--exclude-group` vs plik w ogóle niezbierany przez suitę; „sieroty" vs `FK ON DELETE SET NULL`; „zdarzenia przepadają" vs logger łapiący `PDOException` piętro niżej). Reguły kodowały WNIOSKI z incydentów, nie PROCEDURĘ; jedyne miejsce łapiące klasę systematycznie to wymóg dowodu mutacyjnego (procedura, nie przestroga). code-reviewer (krok weryfikacyjny w definicji) wyłapał 5/6 — brakowało odpowiednika u piszących.

### Updated
- **Wszyscy agenci piszący** (php-pro, javascript-pro, test-automator, sql-pro, database-optimizer, mobile-pwa-developer, nextjs-pro, python-pro, backend-security-coder, debugger): wspólna sekcja „Discipline overlay — measurement vs. conclusion" — nazwana klasa, 4-krokowa procedura (teza → pomiar OBALAJĄCY → wykonaj → etykiety MEASURED/INFERRED w raporcie), zasada zleceń dwustronnych („ustal, czy X czy nie-X, i podaj, co rozstrzyga", nigdy „sprawdź, czy X"). debugger dodatkowo: krok 3/4 — zapisz obalenie przed uruchomieniem, root cause tylko po przeżytym obaleniu.
- **code-reviewer:** zasada „Disproof before verdict" — CONFIRMED tylko z pokazanym pomiarem obalającym; znalezisko od agenta piszącego bez etykiet MEASURED/INFERRED lub z niezmierzonym ogniwem → degradacja do PLAUSIBLE.
- **Skille (minimalnie, tylko formułowanie zleceń):** task-lifecycle — zlecenia weryfikacyjne dwustronne, PLAUSIBLE od recenzenta wraca jako zlecenie dwustronne, nie jako fix; issue-pipeline — triage „ustal, czy istnieje czy NIE" + nowy werdykt NOT-A-BUG z pomiarem obalającym; systematic-debugging — Faza 3 krok „najpierw obalenie", raport MEASURED/INFERRED.
- Nie ruszono: refactoring-orchestrator (ma już wymóg dowodu przeciwnego), workflow i reszta skilli (nie były przyczyną ani razu w fali).

### Issues
- Zvendorowane ręcznie do KonkretnyTMS/.claude tego samego dnia; tam dodatkowo nagłówek klasy w `.claude/rules/incident-lessons.md`, jednoliniówka w CLAUDE.md §4 i overlay w `skryba.md`.

---

## Run: 2026-08-19 — Audit-360 feedback loop (KonkretnyTMS) + token economy (v1.5.0)

> **SUPERSEDES wpis „2026-08-17 — stay uniformly on Opus".** Tamta analiza liczyła koszt po cenniku API (luka Opus/Sonnet ~1,7×) i na tej podstawie odrzuciła podział dwupoziomowy. Użytkownik pracuje jednak na **subskrypcji Max (limit kwotowy)**, gdzie zużycie liczone jest wg wagi modelu, a nie cennika API — Opus wypala limit wielokrotnie szybciej niż Sonnet — i decyzją użytkownika (19.08, po wypaleniu limitu Max20 w 2-3 dni) agenci piszący przechodzą na Sonneta. Ryzyko jakościowe adresują: review na Opusie (code-reviewer, backend-security-coder, refactoring-orchestrator), override `model: opus` dla WSZYSTKICH specjalistów w audit-360 oraz metryka z tamtego wpisu (liczba iteracji review w task-lifecycle — jeśli zadania zaczną wymagać 2-3 rund zamiast 1, wracamy do rozmowy z danymi).

### Updated
- **Modele:** agenci piszący → `sonnet` (php-pro, sql-pro, javascript-pro, test-automator, debugger, database-optimizer, nextjs-pro, python-pro, mobile-pwa-developer); `opus` zostaje: code-reviewer, backend-security-coder, refactoring-orchestrator. Skill audit-360 spawnuje specjalistów z jawnym override `model: opus` (polityka w SKILL.md §1).
- **Nowe reguły z audytu 360° KonkretnyTMS 19.08.2026 (AGENT_UPDATES.md, wzorce 1-9):** kanon Money/VAT + reguła kierunku dokumentu (php-pro, javascript-pro); trigger-scope + grep-all-writers przy rekordach finalnych oraz seeding z autorytatywnego słownika / legacy twins (sql-pro); raportowanie ZAKRESU narzędzia + liczniki SKIPPED zamiast gołego „zielono" (code-reviewer krok 6, test-automator, php-pro, javascript-pro, debugger); reguły dopasowania w configach — sonda 403-vs-404 zamiast czytania, allowlista katalogów (backend-security-coder, code-reviewer, php-pro); guard `PHP_SAPI` + zakaz inline poświadczeń w skryptach operatorskich (php-pro, backend-security-coder); autoloader przed pierwszym `exit` w cronach (php-pro, debugger); antywzorce testowe + próba mutacyjna (php-pro); martwe odwołania w dokumentacji (code-reviewer, projektowy skryba).
- **Ekonomia testów:** testy celowane w iteracji, pełna suita RAZ na bramce z raportem passed+skipped (php-pro, test-automator, task-lifecycle).
- **Skille:** task-lifecycle — klasa Small (diff <30 linii → 1 review pass), cap pętli 3→2, obowiązkowy Task-context block dla subagentów; verify-e2e — polityka dowodów (1 screenshot przy PASS, komplet przy FAIL, GIF na życzenie, API = dump tekstowy); issue-pipeline — cap 10→3 issues na przebieg; writingplans — Pass 2 warunkowy (>5 zadań lub domena regulowana, max 2 specjalistów); audit-360 — polityka modeli, `audit/RUN_META.md` (koszt/czas/utracone przebiegi), CHECK B mechaniczny (wszystkie symbole + sygnatury + weryfikacja file:line), path fidelity konsolidatora + addenda w prompts/10 i prompts/12.

### Removed (token economy)
- php-pro: sekcje Laravel/Symfony i zdublowany „Modern PHP Quick Reference" (~150 linii); sql-pro + database-optimizer: bloki newsów wersji baz (~80 linii); test-automator: katalogi narzędzi AI/API/perf (~25 linii); wszyscy: skumulowane stopki changelogowe.

### Issues
- Zmiany zvendorowane ręcznie do KonkretnyTMS/.claude tego samego dnia (kopie identyczne z pluginem).

---

## Run: 2026-08-17 — Model-class decision: stay uniformly on Opus; doc drift fixed

### Decided
- **Two-tier split (Sonnet producers / Opus gates) was evaluated and rejected.** All 12 agents stay on `model: opus`. No agent frontmatter changed in this run.

### Updated
- **skills/audit-360/SKILL.md**: the specialist table's Model column had drifted to a mix of `inherit` / `sonnet` / `opus` that stopped describing what actually ran once the 2026-08-01 run forced every agent to opus. Column corrected to the real value (`opus` throughout), with a note that the uniformity is deliberate and that any future row reading otherwise is a change someone made on purpose. Best-practice #8 reworded accordingly.
- **skills/lang-guidelines/SKILL.md + references/agent-template.md**: resolved a standing contradiction — SKILL.md required `model: inherit` in generated agents while its own template wrote `model: opus`. Both now say `model: opus` and point at the README rationale, so newly generated language experts land in the right class.
- **README.md**: new "Model class" section recording the decision and the reasoning behind it.
- **plugin.json / marketplace.json**: 1.4.3 → 1.4.4.

### Rationale
The question was whether to cut token cost by moving rule-driven producers to Sonnet ahead of the weekly-limit promotion ending. Three findings killed it:

1. **The price gap is much smaller than the previous Opus generation's.** At list pricing Opus 5 is $5/$25 per MTok against Sonnet 5's $3/$15 — about 1.7x, not the ~5x that made this trade obviously worthwhile in the past. (Sonnet 5 introductory pricing of $2/$10 runs through 2026-08-31, so the gap is temporarily ~2.5x.)
2. **The agents that must stay on Opus are most of the roster.** Anything whose mistakes are silent — `code-reviewer`, `backend-security-coder`, `debugger`, `refactoring-orchestrator` — plus anything whose output is irreversible once it runs — `sql-pro`, `database-optimizer` — cannot move. That is 6 of 12 before considering the risky cases, leaving roughly 15-20% total saving.
3. **The remaining candidates have no principled boundary.** `php-pro`, `python-pro`, `javascript-pro` and `nextjs-pro` all produce backend code; there is no rule that puts one on Sonnet and keeps another on Opus, so the choice is all-or-nothing rather than per-agent.

15-20% is not worth a quality question mark over backend code, migrations, and security-sensitive paths.

### If this is revisited
Revisit with data, not intuition. `task-lifecycle` Step 2 already reports review iterations per task, so a tier change is measurable: work that used to pass review in one round starting to need two or three is the signal that the smaller model is not carrying the task. Re-check the price gap first — this analysis is only valid while it stays near 1.7x.

### Issues
- None

---

## Run: 2026-08-01 — Set all toolkit agents to opus model class

### Updated
- **All agent frontmatter**: `model:` set to `opus` across every toolkit agent (was a mix of `inherit`/unset), so agents run on the Opus class regardless of the session model.
- **plugin.json / marketplace.json**: 1.4.1 → 1.4.2.

### Issues
- None

---

## Run: 2026-08-01 — Generalize nextjs-pro to be project-agnostic

### Updated
- **agents/nextjs-pro.md**: removed all assumptions inherited from the project it was created on (`aplikacja_portfel_inwestycyjny`): fixed stack list in the intro (Tailwind/Serwist/Zod/Vitest/Netlify/local JSON) replaced with a "discover the stack from `package.json` / `tsconfig.json` / `next.config.*` first" instruction plus a new Core Philosophy bullet ("The repository is the source of truth"); "this project's data layer is local JSON" → serverless-filesystem guidance for any host (Netlify/Vercel/Lambda as examples); hardcoded path aliases (`@config/*`, `@data/*`) → "check `tsconfig.json` paths"; "tsconfig here already runs strict…" → recommended baseline to verify; project CSP claims → general security-header guidance; "Vitest 4 + RTL" → "use the repo's existing runner"; domain-specific coverage list (rates, inflation, indicators) → generic (calculations, parsing, validation); Tailwind/Serwist/Netlify ecosystem notes gated behind "only when `package.json` shows the project uses it"; checklist items reworded (fs writes conditional on serverless target, scripts read from `package.json`).
- **plugin.json / marketplace.json**: 1.4.0 → 1.4.1.

### Rationale
The agent was generated during an audit of a specific Next.js project and carried that project's stack as hard facts ("this project", "this repo"). As a marketplace plugin agent it runs against arbitrary repositories — stated assumptions that are false in a given repo (e.g. "your data layer is local JSON") are worse than no assumption. Same generalization pass previously applied to systematic-debugging (4aa5edf).

### Issues
- None

---

## Run: 2026-08-01 — New language expert: nextjs-pro

### Added
- **agents/nextjs-pro.md**: Next.js 15.5+ / React 19.2 / TypeScript 5 expert (App Router, Server Components, Server Actions), generated via `/lang-guidelines` with web research. 15 documented AI failure modes with ❌/✅ examples, each grounded in a source: Pages Router APIs smuggled into App Router (`getServerSideProps`, `next/router`, `next/head`); synchronous `cookies()`/`headers()`/`params`/`searchParams` (async since Next 15); assuming `fetch` and GET Route Handlers are still cached by default (they are not); Server Actions treated as trusted instead of public HTTP endpoints; middleware as the sole auth layer (CVE-2025-29927); server data leaking into Client Components via props; `"use client"` at page/layout level instead of leaves; `forwardRef` in React 19; `useEffect` for initial data; hydration mismatches from nondeterministic render; mutations without `revalidatePath`/`revalidateTag`; hallucinated imports; `redirect()`/`notFound()` swallowed by try/catch; `.parse()` at the boundary with `any` behind it; filesystem writes on serverless. Ecosystem notes cover Tailwind 4, Serwist/PWA caching pitfalls, Zod 4, Netlify deployment.

### Updated
- **README.md**: nextjs-pro added to the Language Experts table.
- **plugin.json / marketplace.json**: 1.3.0 → 1.4.0.

### Rationale
Toolkit had no specialist for the JS meta-framework stack. `javascript-pro` covers language-level JS/TS but not framework semantics — and Next 15 / React 19 are exactly where LLM training data actively fights correct code (years of Pages Router and Next 13/14 content dominate), so a dedicated agent carries the most weight per token.

### Origin
Created during an `/audit-360` run on the `aplikacja_portfel_inwestycyjny` project (Next.js 15.5.22 + React 19.2.4 + Serwist PWA on Netlify), where the specialist-selection step found no matching language expert.

### Issues
- None

---

## Run: 2026-08-01 — Monthly maintenance sweep

### Updated
- **agents/python-pro.md** (411→415 lines): Corrected version status (Python 3.14 stable / 3.15 beta, RC1 due 2026-08-04, final 2026-10-01 per PEP 790; 3.10 EOL Oct 2026). Added CVE-2026-5713 (profiling/asyncio-introspection privilege escalation) and CVE-2026-4786/6100 (CERT-FR CPython RCE advisory). Noted incomplete-mitigation follow-ups for CVE-2026-4519 and CVE-2026-0672. Added slopsquatting persistence note and an architecture-persona tip for AI-generated modules.
- **agents/sql-pro.md** (500→528 lines): Added new PART 2.5 "Common AI-Generated SQL Failure Patterns" (fan-out aggregation, hallucinated schema, WHERE-scope drift on iteration, ~78% zero-shot text-to-SQL accuracy benchmark). Confirmed PostgreSQL 19 Beta 2 (July 16, 2026) feature list. Confirmed MySQL 9.6 (Innovation) and 9.7 LTS (first LTS since 8.4) feature detail. Added 2026 CVE precedents (CVE-2026-44381 MISP, CVE-2026-42208 LiteLLM) to injection guidance.
- **agents/database-optimizer.md** (246→268 lines): Updated PostgreSQL 19 to confirmed Beta 2 with full feature list (pg_plan_advice, native REPACK, parallel autovacuum, logical replication of sequences, SQL/PGQ, GROUP BY ALL). Added MySQL 9.7 LTS (Hypergraph Optimizer now in Community Edition, cpuset cgroup support, HA telemetry now free). Added vector (HNSW/IVF) index row. Added "Redis-compatible alternatives" section (Valkey, Dragonfly, Garnet, Kvrocks).
- **agents/mobile-pwa-developer.md** (105→110 lines): Added Declarative Web Push (Safari 18.4+/18.5+, no service worker required). Documented Safari's 7-day inactivity data-eviction gotcha (Home Screen installs exempt). Added common AI-generated Service Worker scope/stale-HTML pitfall plus fix, and two corresponding Quality Checklist items.
- **agents/test-automator.md** (200→217 lines): Refreshed Vitest to 4.1+ (AST-based coverage remapping, shared vite.config) and noted Playwright overtaking Cypress as 2026 default. Added new "AI-Powered Test Generation & Execution Tools" section (Gartner's first AI-testing Magic Quadrant, autonomous generation, self-healing execution, visual validation, AI failure triage). Added "just click accept" anti-pattern for AI-suggested test fixes.
- **skills/new-project/SKILL.md** (477→486 lines): Added SBOM generation (CycloneDX/SPDX), automated dependency updates (Dependabot/Renovate) with lockfile pinning, named secret-scanning tools (gitleaks/trufflehog/detect-secrets), vulnerability scanning (Trivy/Grype/pip-audit) as a CI gate, MFA-on-publish-rights rule, and a postgres:18+ Docker volume-path gotcha.

### Skipped (up to date, < 30 days)
- **backend-security-coder.md**: Last updated 2026-07-05 (27 days)
- **code-reviewer.md**: Last updated 2026-07-07 (25 days)
- **debugger.md**: Last updated 2026-07-05 (27 days)
- **javascript-pro.md**: Last updated 2026-07-05 (27 days)
- **php-pro.md**: Last updated 2026-07-05 (27 days)
- **refactoring-orchestrator.md**: Last updated 2026-07-07 (25 days)

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- audit-360/SKILL.md
- issue-pipeline/SKILL.md
- systematic-debugging/SKILL.md
- task-lifecycle/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md
- verify-e2e/SKILL.md
- lang-guidelines/SKILL.md — meta-skill describing how to research/generate other agents; no "Last updated" of its own and no external technology domain to research (process definition, same category as brainstorming/writingplans/executingplans)

### Deferred to next run
- None — all 6 evolving files processed within the 10-file cap

### Issues
- None — all WebSearch queries returned useful results, no rephrasing needed, no git conflicts, all diffs self-reviewed clean (frontmatter intact, no deletions, line counts grew)

### Next run priorities
- backend-security-coder.md, debugger.md, javascript-pro.md, php-pro.md (last updated 2026-07-05 — will be ~57 days by next run)
- code-reviewer.md, refactoring-orchestrator.md (last updated 2026-07-07 — will be ~55 days by next run)

---

## Run: 2026-07-17 — Autonomy layer: task-lifecycle, issue-pipeline, verify-e2e

### Added
- **skills/verify-e2e**: Surface-level verification in a fresh adversarial subagent (GUI → browser + screenshots, API → real HTTP, CLI/cron → execution). Evidence artifacts mandatory; BLOCKED protocol appends missing prerequisites to project `docs/VERIFICATION_ENV.md` so the verification environment compounds. Rationale: smarter models fake completion more convincingly (Fable 5 system card) — isolation + adversarial prompt is the countermeasure.
- **skills/task-lifecycle**: Orchestrated end-to-end cycle for one task: build (specialist subagent) → code-review loop with auto-fix of CRITICAL/HIGH/MEDIUM (cap 3) → conditional security pass (backend-security-coder) → verify-e2e in fresh subagent (cap 3) → report package. Main session never writes code; feature-branch policy for deploy-from-main projects; merge/push/deploy always the user's decision.
- **skills/issue-pipeline**: Batch remediation: collect (gh issues / audit-360 findings / list) → mandatory triage on HEAD (stale-finding kill + fresh file:line anchors, per KNOWLEDGE lesson "audit older than commit delta") → file-disjoint batching (2-3 wide, executing-plans 4 conditions, DB issues never parallel) → one task-lifecycle orchestrator per issue on `agent/issue-<n>` → monitor by exception → status table. Cap 10 issues/run. Automates the previously manual audit → issues → orchestrators flow.

### Updated
- **verification-before-completion**: claim table row + integration note — verify-e2e is the OUTER gate (user surface), this skill the inner (commands/tests).
- **executingplans**: final group now includes verify-e2e for user-facing changes; companion-skills list extended (verify-e2e, task-lifecycle).
- **audit-360**: Quick-start step 13 — optional remediation handoff: P0/P1 → `gh issue create` → issue-pipeline.
- **README.md**: new skills documented + "Autonomy Layer" section (orchestration diagram, hard caps, BLOCKED-as-first-class, audit→issues→pipeline loop).
- **plugin.json**: 1.2.0 → 1.3.0; marketplace.json plugin entry aligned to 1.3.0 (was stale at 1.1.0).

### Source
- Boris (Claude Code) "steps of AI adoption" levels 1-4, via analyzed video transcript (2026-07-17): self-verification loop on the user surface, isolated verifier subagents, severity-gated auto-fix review loops with caps, orchestrator-not-builder main session, verification-environment investment, monitor-by-exception.

### Issues
- None

---

## Run: 2026-07-07 — Manual restructure: refactoring-specialist → refactoring-orchestrator

### Replaced
- **refactoring-specialist.md → refactoring-orchestrator.md**: Role changed from hands-on refactoring executor to end-to-end orchestrator (per user-authored prompt). Runs phases 0–6: mandatory backup with manifest, behavioral baseline (tests + static analysis), audit, plan with uncertainty gate, delegated execution (never codes itself — spawns php-pro/javascript-pro/sql-pro/test-automator via nested Agent tool, supported since Claude Code v2.1.172), equivalence verification (baseline diff + before/after regression + 7-axis code-reviewer pass), sign-off with user-confirmed backup release. Carried over from the old agent as "briefing knowledge" injected into subagent assignments: AST-or-nothing bulk transformation rules (incl. 2026-05-15 sed incident), PHP/JS refactoring pitfalls, large-file split patterns (Extract Class / Strangler Fig / Branch by Abstraction), smell table, refactoring catalog, metrics. Added read-only audit mode for audit-360 compatibility. No `Edit` tool by design.
- **audit-360**: `prompts/06-refactoring-specialist.md` renamed to `prompts/06-refactoring-orchestrator.md` (subagent_type updated, READ-ONLY audit mode noted); SKILL.md references updated.
- **executingplans / new-project / README**: agent routing references updated to `refactoring-orchestrator`.
- **plugin.json**: version 1.1.0 → 1.2.0.

### Issues
- None

---

## Run: 2026-07-01

### Updated
- **javascript-pro.md**: Updated Node.js LTS to v24+ (V8 13.6, Explicit Resource Management `using`/`await using`, `RegExp.escape()`, `Error.isError()`, built-in SQLite, npm 11). Added TypeScript 6.0 (March 2026: `strict` default, ES5 target removed, final JS compiler; TS 7.0 Go rewrite in development). Added `using`/`await using` pattern section.
- **mobile-pwa-developer.md**: Updated platform support — iOS Safari 26+ (WebGPU enabled by default, `<model>` 3D, Digital Credentials, Trusted Types, File System WritableStream, Home Screen default to web app mode), Safari 27 beta (Grid Lanes/CSS masonry, Customizable Select), Chrome 148+ (Prompt API stable, PWA origin migration, WebMCP origin trial). WebGPU reached Baseline status (January 2026, ~77% global coverage). WebNN updated CR but not production-ready (estimated 2027). Added Service Worker Static Routing API.
- **sql-pro.md**: Added PostgreSQL 19 Beta 1 (June 2026, GA expected September 2026). Added MySQL 9.6/9.7 quarterly innovation releases. Updated Modern Systems — CockroachDB 25.2 (distributed vector indexing), TiDB X (unified vector/graph/JSON/SQL engine + MCP integrations), Neon/Databricks Lakebase.
- **code-reviewer.md**: Added ProjectDiscovery 2026 stat (AI code 1.88× more likely to introduce vulnerabilities). Added specific slopsquatting incidents — `unused-imports` npm (~233 weekly downloads), `huggingface-cli` (30K+ downloads, Alibaba incident), CSA April 2026 autonomous agent risk. Added iterative refinement degradation anti-pattern (Arxiv 2506.11022).
- **database-optimizer.md**: Added PostgreSQL 19 Beta 1 (June 2026, GA expected September 2026).

### Skipped (up to date, < 30 days)
- **backend-security-coder.md**: Last updated 2026-06-01 (30 days)
- **debugger.md**: Last updated 2026-06-01 (30 days)
- **php-pro.md**: Last updated 2026-06-01 (30 days)
- **python-pro.md**: Last updated 2026-06-01 (30 days)

### Skipped (no significant new findings)
- **refactoring-specialist.md**: Last updated 2026-05-15 (47 days) — no significant new refactoring tools or patterns found in research
- **test-automator.md**: Last updated 2026-05-15 (47 days) — Vitest 4, Jest 30, Playwright already covered; no major new testing tool releases found
- **new-project/SKILL.md**: Last updated 2026-05-01 (61 days) — Docker images still current (PG 19 still beta, not GA), no significant changes needed

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md
- audit-360/SKILL.md

### Skipped (template/orchestration)
- lang-guidelines/SKILL.md (meta-skill for generating agents, stable process)

### Deferred to next run
- None — all files processed within the 10-file limit

### Issues
- None

### Next run priorities
- refactoring-specialist.md (will be 77 days by next run — consider adding new AST tooling or patterns)
- test-automator.md (will be 77 days by next run)
- new-project/SKILL.md (will be 91 days by next run — update Docker images when PG 19 reaches GA)
- backend-security-coder.md (will be 60 days by next run)
- debugger.md (will be 60 days by next run)
- php-pro.md (will be 60 days by next run)
- python-pro.md (will be 60 days by next run)

---

## Run: 2026-06-01

### Updated
- **python-pro.md**: Added Python 3.14 stable features — PEP 649 (deferred annotation evaluation), PEP 734 (multiple interpreters), PEP 758 (except without parens), PEP 779 (free-threaded Python officially supported), PEP 784 (compression.zstd), uuid7(), JIT compiler. Added 2026 CVEs: CVE-2026-3298 (asyncio buffer overflow), CVE-2026-4519 (webbrowser.open() injection), CVE-2026-0672 (cookies bypass). Added remote debugging security note. Updated description to 3.14+/3.15.
- **backend-security-coder.md**: Added OWASP Top 10 2026 new categories — A03 Software Supply Chain Failures and Mishandled Exceptions. Updated SSRF entry to note merger into Broken Access Control A01. Updated AI vulnerability stats: 92% of AI codebases have critical vuln (Sherlock Forensics 2026), 35 CVEs/month attributed to AI-generated code.
- **debugger.md**: Added 4 new AI-generated bug patterns — hallucinated APIs, incomplete-context conflicts (43% need production debugging per Lightrun 2026), performance anti-patterns, semantic error dominance (>60% of AI faults).
- **php-pro.md**: Added PHP 8.5 URI extension (Uri\Rfc3986\Uri, Uri\WhatWg\Url replacing parse_url()), closures in constant expressions.

### Skipped (up to date)
- **code-reviewer.md**: Last updated 2026-05-15 (17 days)
- **javascript-pro.md**: Last updated 2026-05-15 (17 days)
- **refactoring-specialist.md**: Last updated 2026-05-15 (17 days)
- **test-automator.md**: Last updated 2026-05-15 (17 days)
- **database-optimizer.md**: Last updated 2026-05-01 (31 days) — PG 18.4 point release is maintenance/security only, no new optimization patterns
- **mobile-pwa-developer.md**: Last updated 2026-05-01 (31 days) — no new PWA APIs or browser features since May update
- **sql-pro.md**: Last updated 2026-05-01 (31 days) — PG 18 and MySQL 9 features already comprehensive, no new dialect features
- **new-project/SKILL.md**: Last updated 2026-05-01 (31 days) — process skill with current tech references, no significant changes needed

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md

### Skipped (template/orchestration)
- lang-guidelines/SKILL.md (meta-skill for generating agents)
- audit-360/SKILL.md (orchestration process)

### Deferred to next run
- None — all 8 evolving files were processed

### Issues
- None

### Next run priorities
- database-optimizer.md (will be 61 days by next run)
- mobile-pwa-developer.md (will be 61 days by next run)
- sql-pro.md (will be 61 days by next run)
- new-project/SKILL.md (will be 61 days by next run)
- code-reviewer.md (will be 47 days by next run)
- javascript-pro.md (will be 47 days by next run)
- refactoring-specialist.md (will be 47 days by next run)
- test-automator.md (will be 47 days by next run)

---

## Run: 2026-05-15 — Post-Audit Incident Updates

Driven by 2026-05-15 incident (bulk `sed` on `catch (e) {` destroyed 13 JS files) and PR #155 / `ksef_daemon` orphan-test incident (7 tests passing CI against deleted code).

### Updated
- **javascript-pro.md**: New sections — Vite/bundler scope isolation checklist (cross-file `window.X`, eslint globals sync, implicit globals → `ReferenceError` in bundles); ES2019 catch binding rule with explicit ban on sed/regex bulk transforms (incident 2026-05-15); `Object.prototype.hasOwnProperty.call` rule.
- **code-reviewer.md**: Added 6th review axis — **Test-Production Contract**: orphan-test scan for DELETE/RENAME/signature/exception changes (`scripts/check_orphan_tests.sh <symbol>`, `grep tests/` patterns). Description and review-process headers updated 5→6 axes.
- **test-automator.md**: New **Pre-Flight** section — before editing tests or after a production change, run (1) orphan scan, (2) filtered sanity check, (3) MANDATORY full suite run (because `failOnWarning`/`failOnRisky` and orphan tests only surface in a full run, never in `--filter`).
- **refactoring-specialist.md**: Added safety rule #6 and new **Bulk Transformations — AST or Not at All** section. Explicit ban on `sed`/`awk`/`perl -pi` for catch bindings, signatures, declarations; allowed list (eslint --fix, jscodeshift, ts-morph, Rector, LibCST). Added Last-updated footer (previously missing).
- **sharp-edges (backup-skills)**: New category 7 — **Tooling Footguns: Bulk Regex/Sed on Source Code**. Codifies the 2026-05-15 catch-binding incident as a sharp-edge anti-pattern.

### Considered but skipped
- **eslint-cleanup skill (new, optional)**: content overlapped with new javascript-pro and refactoring-specialist sections; project-specific (CI free-tier, `sync_eslint_globals.sh`). Can be added later if a dedicated workflow checklist is wanted.

### Issues
- None — all edits are additive guidance, no breaking changes to existing structure.

---

## Run: 2026-05-01

### Updated
- **php-pro.md**: Added PHP 8.4 features (property hooks, asymmetric visibility, PDO driver subclasses, array_find/any/all, new-without-parens), PHP 8.5 features (pipe operator, clone with, array_first/last, #[\NoDiscard]), code examples; updated vulnerability stats to Veracode 2026 (~45%); updated description from 8.3+ to 8.4+/8.5
- **javascript-pro.md**: Updated Node.js LTS from v20+ to v22+ (WebSocket, watch mode, .ts execution, HTTP/3 QUIC); added TypeScript 5.8 features (erasableSyntaxOnly, rewriteRelativeImportExtensions); added ESLint 10 flat config (eslintrc removed Feb 2026); updated Vitest to 4+ (stable browser mode); updated AI vulnerability stats to Veracode 2026
- **backend-security-coder.md**: Added new AI & Agentic Security section covering OWASP Top 10 for Agentic Applications 2026, slopsquatting supply chain attacks, OWASP MCP Top 10, updated vulnerability stats
- **sql-pro.md**: Added PostgreSQL 18 features (async I/O, skip scan, uuidv7, virtual generated columns, temporal constraints, OAuth); added MySQL 9 features (vector data type, enhanced EXPLAIN, WebAuthn)
- **database-optimizer.md**: Added PostgreSQL 18 performance features (async I/O with 3x improvement, skip scan, virtual generated columns, uuidv7)
- **code-reviewer.md**: Added slopsquatting and deprecated config format checks to AI-generated code review table; updated vulnerability stats to Veracode 2026
- **test-automator.md**: Updated Vitest to 4+ (stable browser mode, visual regression testing), Jest to 30, added Playwright component testing
- **mobile-pwa-developer.md**: Updated iOS Safari to 16.4+, added Firefox 143+ PWA support, Workbox 7, manifest-only install prompts, WebGPU/WebNN on-device AI capabilities
- **new-project/SKILL.md**: Updated Docker images (postgres:18, mongo:8, rabbitmq:4), added PostgreSQL 18 feature notes
- **debugger.md**: Added slopsquatting and AI tool supply chain compromise to debugging patterns

### Skipped (up to date)
- **python-pro.md**: Last updated 2026-04-14 (17 days ago, within 30-day threshold)

### Skipped (methodology/stable)
- brainstorming/SKILL.md
- writingplans/SKILL.md
- executingplans/SKILL.md
- systematic-debugging/SKILL.md
- test-driven-development/SKILL.md
- verification-before-completion/SKILL.md

### Deferred to next run
- **refactoring-specialist.md**: Hit 10-file limit; refactoring patterns are relatively stable
- **audit-360/SKILL.md**: Hit 10-file limit; orchestration process, lower priority
- **lang-guidelines/SKILL.md**: Hit 10-file limit; meta-skill for creating agents

### Issues
- None

### Next run priorities
- refactoring-specialist.md (no "Last updated" date, deferred this run)
- audit-360/SKILL.md (no "Last updated" date, deferred this run)
- lang-guidelines/SKILL.md (no "Last updated" date, deferred this run)
- python-pro.md (will be 47+ days old by next monthly run)
