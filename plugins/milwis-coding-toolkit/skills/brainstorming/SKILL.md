---
name: brainstorming
description: "Use before new features, modules, or changes touching 3+ modules. NOT for bugfixes, typos, config tweaks. Scales: LIGHT (2-3 questions) for medium changes, FULL (3-phase session) for new features."
---

# Brainstorming

Turn an idea into a validated design through collaborative dialogue. Effort scales with complexity — never more process than the change deserves.

**Announce at start:** "I'm using the brainstorming skill."

---

## Step 0: Pick the Complexity Tier

| Tier | When | Process | Time |
|------|------|---------|------|
| **SKIP** | Bugfix, typo, column add, copy change, config tweak | Straight to implementation | 0 |
| **LIGHT** | Modify existing feature, add field with logic, new endpoint for existing entity | 2-3 focused questions → recommendation | 5 min |
| **FULL** | New module, new integration, cross-module feature, architectural change, >3 modules | 3-phase session (Diverge → Converge → Ship) | 15-30 min |

**Unsure → start LIGHT, escalate to FULL the moment hidden complexity emerges.**

---

## Two Mandatory Gates (LIGHT and FULL, before any direction is chosen)

### Gate A — Variant Question

Ask early: **"Is this a variant of an operation that already exists?"** — correction, reversal, batch, offline, delete/cancel, import-update, second document type, single-vs-bulk, analytics/reporting consumer, mobile/PWA twin.

If yes: the Explore dispatch MUST return the main path's implementation and its guards BEFORE any design choice. The default design is **reuse the canon**; every divergence gets a stated reason in the one-pager. A variant rebuilt from scratch — missing the guards/formulas the main path already has — is the most expensive regression class in this codebase.

### Gate B — Regulated-Domain Gate (tax, financial reporting, legal thresholds, compliance documents)

If the feature touches a regulated computation or a compliance document, exploration MUST produce a fact-pack first:

- Extract governing rules from official sources vendored in the repo (schemas, standards, spec documents, regulator examples) — **never from memory**. Record each rule as: ID, source (file + section/line), threshold values, edge cases.
- List every rule you could NOT source — these become questions for the user, never defaults to guess. Regulation-from-memory is a top source of domain defects: `>=` vs `>` thresholds, wrong rounding anchor, wrong document classification, a period split on the wrong event.
- When code comments/docs contradict each other about a data convention (timezone, encoding, sign) → resolve by PHYSICAL evidence (DDL, actual stored values, a runtime probe), never by the majority of comments. One false comment can poison an entire subsystem for every author who reads it afterward.

---

## Explore Dispatch Rules (every exploration, both tiers)

Dispatch an Explore agent with a prompt that:
- Lists specific facts to find ("list all order statuses defined in code", not "explore the invoice flow")
- Requires `file:line` for every fact reported
- Ends with: **"Report ONLY what you found in code. Do not infer, assume, or add probable values."**

---

## LIGHT Process

1. Dispatch Explore (rules above; include the Gate A canon lookup when it fires)
2. Ask 2-3 focused questions — one at a time, prefer multiple choice
3. Propose ONE recommended approach with brief reasoning
4. User agrees → hand off: multi-step work goes to `writing-plans`; a 1-2 step change may be implemented directly
5. Record the decision as a comment in the plan

---

## FULL Process

### Phase 1: DIVERGE — Explore

**First:** dispatch Explore (rules above) and run both Gates.

Reframe as "How Might We…":
- "Add a vignette module" → "HMW: how might we track vignettes so drivers and the dispatcher know what is expiring?"

Sharpening questions (one at a time, prefer multiple choice):
- Who uses this? What is their workflow today?
- What does success look like?
- What constraints? (tech, time, data, permissions)

Generate 3-5 approach variants using different lenses:
- **Inversion:** what if we solved the opposite problem?
- **Simplification:** the minimum that delivers value?
- **Constraint removal:** if no tech constraints existed?
- **Existing pattern:** what similar thing already exists in the codebase?

### Phase 2: CONVERGE — Pick a direction

Cluster variants into 2-3 directions. Evaluate each:

| Criterion | Question |
|---|---|
| Value | Real problem? How often used? |
| Feasibility | How many files? Time? Dependencies? |
| Consistency | Fits existing patterns? |

Surface hidden assumptions — and for each: how would we verify it?

**Lead with your recommendation** and explain why.

### Phase 3: SHIP — Document

Present the design in sections of 200-300 words, checking in after each — never the whole design at once.

One-pager contents:
1. **Problem** — what and for whom
2. **Kierunek** — chosen approach and why
3. **Assumptions** — list, each with a validation test
4. **Scope MVP** — what's IN
5. **"Not Doing" list** — what's explicitly OUT (prevents scope creep; the most valuable section)
6. **Ryzyka** — what could go wrong

---

## After the Design

- Write the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Ask: "Ready to create the implementation plan with `writing-plans`?"

---

## Key Principles

- **One question at a time** — don't overwhelm
- **Multiple choice preferred** — easier to answer
- **YAGNI ruthlessly** — especially in the MVP
- **"Not Doing" list mandatory for FULL**
- **Verify before asserting** — NEVER present codebase facts (statuses, enums, schemas, workflows) without grep/read first. Guessing = confabulation.
- **Existing pattern first** — grep before inventing
- **Incremental validation** — sections, not the whole design at once

---

## Red Flags

- Building something that already exists → grep first
- Design requires >20 files → break into phases
- No clear user → who asked for this?
- "Nice to have" creeping into MVP → move to "Not Doing"
- Presenting codebase facts (statuses, fields, enums) without grep/read → confabulation risk
- Regulated rule cited without a repo source → back to Gate B
