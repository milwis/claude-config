---
name: brainstorming
description: "Use before new features, modules, or changes touching 3+ modules. NOT for bugfixes, typos, config tweaks. Scales: LIGHT (2-3 questions) for medium changes, FULL (3-phase session) for new features."
---

# Brainstorming

Turn ideas into designs through collaborative dialogue. Scales with complexity.

**Announce at start:** "I'm using the brainstorming skill."

---

## Step 0: Determine Complexity Tier

| Tier | When | Process | Time |
|------|------|---------|------|
| **SKIP** | Bugfix, typo, column add, copy change, config tweak | Straight to implementation | 0 |
| **LIGHT** | Modify existing feature, add field with logic, new endpoint for existing entity | 2-3 focused questions → recommendation | 5 min |
| **FULL** | New module, new integration, cross-module feature, architectural change, >3 modules | 3-phase process | 15-30 min |

**Unsure → start LIGHT, escalate to FULL if complexity emerges.**

---

## LIGHT Process

1. **Explore current state** — dispatch Explore agent with a prompt that:
   - Lists specific facts to find (e.g. "list all order statuses defined in code", not "explore the invoice flow")
   - Requires file:line references for every fact reported
   - Ends with: "Report ONLY what you found in code. Do not infer, assume, or add probable values."
2. Ask 2-3 focused questions (one at a time, prefer multiple choice)
3. Propose recommended approach with brief reasoning
4. User agrees → proceed to writing-plans
5. Save decision as comment in the plan

---

## FULL Process

### Phase 1: DIVERGE — Explore

**First:** dispatch Explore agent (same rules as LIGHT step 1 — specific questions, file:line refs required, no inference).

Reframe as "How Might We...":
- "Dodaj moduł winiet" → "HMW: jak śledzić winiety tak, żeby kierowcy i dyspozytor wiedzieli co wygasa?"

Sharpening questions (one at a time, prefer multiple choice):
- Who uses this? Workflow today?
- What does success look like?
- What constraints? (tech, time, data, permissions)

Generate 3-5 approach variants using different lenses:
- **Inversion:** opposite problem?
- **Simplification:** minimum that delivers value?
- **Constraint removal:** if no tech constraints?
- **Existing pattern:** what similar thing already exists in codebase?

### Phase 2: CONVERGE — Pick a direction

Cluster into 2-3 directions. For each, evaluate:

| Kryterium | Pytanie |
|---|---|
| Wartość | Realny problem? Jak często używane? |
| Wykonalność | Ile plików? Czas? Zależności? |
| Spójność | Pasuje do istniejących wzorców? |

Surface hidden assumptions — for each: how to verify?

**Lead with your recommendation** and explain why.

### Phase 3: SHIP — Document

Present design in sections of 200-300 words, check after each.

One-pager contents:
1. **Problem** — what and for whom
2. **Kierunek** — chosen approach and why
3. **Założenia** — list with validation tests
4. **Scope MVP** — what's IN
5. **"Not Doing" list** — what's explicitly OUT (prevents scope creep; most valuable part)
6. **Ryzyka** — what could go wrong

---

## Regulated-Domain Gate (tax, financial reporting, legal thresholds, compliance documents)

If the feature touches a regulated computation or a compliance document, Phase 1 MUST produce a fact-pack before any direction is chosen:

- Extract the governing rules from official sources vendored in the repo (schemas, standards, spec documents, regulator examples) — not from memory. Record each rule as: ID, source (file + section/line), threshold values, edge cases.
- Explicitly list every rule you could NOT source — these are questions for the user, never defaults to guess. Implementing a regulation from memory is a top source of domain defects: thresholds `>=` vs `>`, wrong rounding anchor, wrong document classification, a period split on the wrong event.
- When code comments/docs contradict each other about a data convention (timezone, encoding, sign) → resolve by PHYSICAL evidence (DDL, actual stored values, a runtime probe), never by the majority of comments. A single false comment can poison an entire subsystem for every author who reads it afterward.

## Variant Question (mandatory in LIGHT and FULL)

Ask early: **"Is this a variant of an operation that already exists?"** (correction, reversal, batch, offline, delete/cancel, import-update, second document, analytics/reporting consumer, mobile/PWA twin). If yes, the Explore dispatch must return the main path's implementation and its guards BEFORE any design choice. The default design is "reuse the canon"; every divergence needs a stated reason in the one-pager.

---

## After the Design

- Write validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Ask: "Ready to create implementation plan with writing-plans?"

---

## Key Principles

- **One question at a time** — don't overwhelm
- **Multiple choice preferred** — easier to answer
- **YAGNI ruthlessly** — especially from MVP
- **"Not Doing" list mandatory for FULL**
- **Verify before asserting** — NEVER present codebase facts (statuses, enums, schemas, workflows) without grep/read first. Guessing = confabulation.
- **Existing pattern first** — grep before inventing
- **Incremental validation** — sections, not whole design at once

---

## Red Flags

- Building something that exists (grep first!)
- Design requires >20 files → break into phases
- No clear user → who asked for this?
- "Nice to have" creeping into MVP → move to "Not Doing"
- Presenting codebase facts (statuses, fields, enums) without grep/read → confabulation risk
