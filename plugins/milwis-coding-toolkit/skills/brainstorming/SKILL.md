---
name: brainstorming
description: "Use before new features, new modules, or changes touching 3+ modules. NOT for bugfixes, typos, config tweaks, or simple field additions. Scales: LIGHT (2-3 questions, quick decision) for medium changes, FULL (3-phase design session) for new features/integrations."
---

# Brainstorming Ideas Into Designs

## Overview

Help turn ideas into fully formed designs through collaborative dialogue.
This skill scales with task complexity — from a quick sanity check to a full design session.

**Announce at start:** "I'm using the brainstorming skill."

## Step 0: Determine Complexity Tier

**Before anything else, assess the task:**

| Tier | When | Process | Time |
|------|------|---------|------|
| **SKIP** | Bugfix, typo, column add, copy change, config tweak | Go straight to implementation — brainstorming adds no value | 0 min |
| **LIGHT** | Modify existing feature, add field with logic, change workflow step, new endpoint for existing entity | Quick validation (Phase 2 only) — 2-3 questions, one recommendation, proceed | 5 min |
| **FULL** | New module/entity, new integration, cross-module feature, architectural change, >3 modules touched | Full 3-phase process | 15-30 min |

**If unsure → start LIGHT, escalate to FULL if complexity emerges.**

---

## LIGHT Process (medium changes)

1. Check current project state (files, docs, recent commits)
2. Ask 2-3 focused questions (one at a time, prefer multiple choice)
3. Propose your recommended approach with brief reasoning
4. If user agrees → proceed to implementation planning
5. Save decision as comment in the plan, not a separate doc

---

## FULL Process (new features, integrations, architectural changes)

### Phase 1: DIVERGE — Explore the problem space

**Reframe the problem:**
- Restate as "How Might We..." question (forces user-centric thinking)
- Example: "Dodaj moduł winiet" → "HMW: Jak możemy śledzić winiety pojazdów tak, żeby kierowcy i dyspozytor wiedzieli co wygasa?"

**Ask sharpening questions (one at a time, prefer multiple choice):**
- Who uses this? What's their workflow today?
- What does success look like? How will we know it works?
- What constraints exist? (tech, time, data, permissions)

**Generate 3-5 approach variants** using different lenses:
- **Inversion:** What if we solved the opposite problem?
- **Simplification:** What's the absolute minimum that delivers value?
- **Constraint removal:** If we had no tech constraints, what would we build?
- **Existing pattern:** What similar thing already exists in the codebase?

### Phase 2: CONVERGE — Pick a direction

**Cluster approaches into 2-3 directions.** For each, evaluate:

| Kryterium | Pytanie |
|-----------|---------|
| **Wartość dla użytkownika** | Czy rozwiązuje realny problem? Jak często będzie używane? |
| **Wykonalność** | Ile plików? Ile czasu? Jakie zależności? |
| **Spójność** | Czy pasuje do istniejących wzorców w codebase? |

**Surface hidden assumptions:**
- "Zakładamy że tabela X ma kolumnę Y" → sprawdź
- "Zakładamy że użytkownik ma uprawnienia Z" → sprawdź
- Dla każdego założenia: jak je zweryfikować?

**Lead with your recommendation** and explain why.

### Phase 3: SHIP — Document the decision

Present design in sections of 200-300 words, checking after each section.
Cover: architecture, components, data flow, error handling, testing.

**Produce a one-pager with:**
1. **Problem** — co rozwiązujemy i dla kogo
2. **Kierunek** — wybrany approach i dlaczego
3. **Założenia** — lista z testami walidacyjnymi
4. **Scope MVP** — co WCHODZI do pierwszej wersji
5. **"Not Doing" list** — co JAWNIE pomijamy (zapobiega scope creep)
6. **Ryzyka** — co może pójść nie tak

---

## After the Design

**Documentation:**
- Write the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Commit the design document to git

**Implementation (if continuing):**
- Ask: "Ready to set up for implementation?"
- Use writingplans skill to create detailed implementation plan

---

## Key Principles

- **One question at a time** — don't overwhelm
- **Multiple choice preferred** — easier to answer than open-ended
- **YAGNI ruthlessly** — remove unnecessary features, especially from MVP
- **"Not Doing" list is mandatory for FULL** — the most valuable part of a design
- **Existing pattern first** — always check what's already in the codebase before inventing
- **Incremental validation** — present design in sections, validate each

## Red Flags — Stop and Reassess

- Building something that exists (grep first!)
- Design requires >20 files changed → break into phases
- No clear user for the feature → who asked for this?
- "Nice to have" items creeping into MVP → move to "Not Doing"
- Assumptions about DB schema without checking → verify first
