---
name: lang-guidelines
description: Creates or updates a specialized coding agent for any language/technology. Researches common AI errors and best practices, then generates a comprehensive expert agent. Usage - /lang-guidelines <language or technology>
---

# Language Guidelines Generator

Meta-skill: creates (or updates) a **specialized coding expert agent** for the language or technology in `$ARGUMENTS`.

**Target language/technology:** `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask what language or technology to create guidelines for.

---

## Dynamic Date Handling

**Never hardcode years in search queries or generated agents.** Use the current date from system context.

- `{CURRENT_YEAR}` = current year
- `{PREVIOUS_YEAR}` = current year − 1
- Use `{CURRENT_YEAR}` and `{PREVIOUS_YEAR}` in all WebSearch queries
- Write actual current year in the `Last updated` date

Example: if today is 2026-04-14, search `"Python best practices 2026"`, NOT `"Python best practices 2024"`.

---

## Step 0: Detect Mode (CREATE vs UPDATE)

1. **Check for existing agent** in `~/.claude/agents/`:
   - `{language}-pro.md` (standard name this skill generates)
   - Any other file whose name suggests it covers this language

2. **If agent exists → UPDATE MODE:**
   - Read the existing agent completely
   - Identify `Last updated` date
   - Note which sections exist, which are thin, which may be outdated
   - Research focus: what's new since last update, what's missing
   - Use update-specific queries (see below)
   - Preserve existing content that's still accurate

3. **If no agent exists → CREATE MODE:**
   - Generate from scratch using the template
   - Follow all 5 phases

---

## Phase 1: Research AI Code Generation Errors

Build a catalog of mistakes AI commonly makes in `$ARGUMENTS`.

### Search queries

1. `"common mistakes AI code generation {language} {CURRENT_YEAR}"` + `{PREVIOUS_YEAR}`
2. `"LLM code generation errors {language} hallucination {CURRENT_YEAR}"`
3. `"ChatGPT Copilot Claude common bugs {language} {CURRENT_YEAR}"`
4. `"AI generated code pitfalls {language} latest"`
5. `"AI coding assistant mistakes {language} deprecated API {CURRENT_YEAR}"`
6. `"{language} AI code review common issues {CURRENT_YEAR}"`

### For each error

- **Category** (deprecated API, error handling, security, performance, type system, concurrency)
- **Specific example** of what AI gets wrong
- **Why it's wrong** (what breaks, what's the risk)
- **Correct approach**

### Common categories to investigate

Deprecated/removed APIs, incorrect error handling, security vulnerabilities (injection, XSS, unsafe deserialization), memory leaks, race conditions, type misuse, performance anti-patterns, platform-specific behavior, hallucinated libraries, mixed language versions, incorrect imports.

---

## Phase 2: Research Best Practices

### Search queries

1. `"{language} official style guide coding standards {CURRENT_YEAR}"`
2. `"{language} best practices {PREVIOUS_YEAR} {CURRENT_YEAR}"`
3. `"{language} code quality guidelines production {CURRENT_YEAR}"`
4. `"{language} performance optimization best practices latest"`
5. `"{language} security best practices OWASP {CURRENT_YEAR}"`
6. `"{language} testing best practices patterns {CURRENT_YEAR}"`
7. `"{language} design patterns idiomatic {CURRENT_YEAR}"`
8. `"{language} style guide Google / Microsoft / Airbnb latest"`

### Sources to prioritize

1. Official language documentation
2. Major company style guides (Google, Microsoft, Airbnb, Meta)
3. Community standards (linters, formatters)
4. Authoritative books (Effective X, X in Action)
5. Conference talks and blog posts from core contributors
6. Empirical research papers on code quality
7. What popular linters/analyzers check for

### Categories to cover

Code style, type system, error handling, concurrency, resource management, security, testing, performance, dependencies, architecture, documentation, tooling.

---

## Phase 3: Research Idioms

What makes code truly idiomatic? The patterns separating expert from "works but feels wrong".

### Search queries

1. `"idiomatic {language} patterns examples"`
2. `"{language} code review what experts look for"`
3. `"{language} anti-patterns vs idiomatic"`
4. `"{language} from beginner to expert patterns"`
5. `"pythonic code" / "effective go" / "idiomatic rust"` (use appropriate term)

### Capture

- Idiomatic patterns (with code examples)
- Anti-patterns (common bad habits, especially from other languages)
- Language philosophy (e.g., "one obvious way" for Python)
- Community conventions (unwritten rules)
- Code smells specific to this language

---

## Phase 4: Generate or Update the Agent

### CREATE mode

Use the template at [references/agent-template.md](references/agent-template.md). Target: **~300-400 lines** — comprehensive but tight. No JSON communication protocols, no progress templates, no "integration with other agents" sections — focus on actionable rules and code examples.

### UPDATE mode

1. Read existing agent completely
2. For each section, categorize: still accurate / partially outdated / missing info / incorrect
3. Merge new research into existing sections:
   - Add newly discovered AI errors to Error Prevention
   - Update version-specific advice (e.g., Python 3.12 → 3.13)
   - Add new security vulnerabilities
   - Add new idiomatic patterns
4. Preserve identity — keep same frontmatter `name`, maintain voice and structure
5. Update `Last updated` date

**Update rules:**
- Never delete content unless factually wrong or deprecated
- Never remove entire sections that still apply
- Preserve existing code examples and patterns unless they contain errors
- Apply compression only to cargo-cult ceremony (JSON protocols, progress templates, etc.) if present
- Add new findings alongside old content when unsure

### File path

`~/.claude/agents/{language}-pro.md` where `{language}` is lowercased and hyphenated:
- `Python` → `python`
- `Ruby on Rails` → `ruby-on-rails`
- `TypeScript` → `typescript`
- `React` → `react`, `Next.js` → `nextjs`, `Vue.js` → `vuejs`

### Content requirements (all must be present)

1. **Frontmatter** — 1-sentence description, `model: sonnet`, tools list. New language experts are WRITER agents and land in the Sonnet tier; judgment gates (code-reviewer, backend-security-coder, refactoring-orchestrator) stay on Opus — see the plugin README ("Model class") for the two-tier policy.
2. **Identity & Philosophy** — language's guiding principles
3. **AI Code Generation Error Prevention** (most detailed — at least 10 specific errors with ❌/✅ examples)
4. **Code Style & Conventions** — naming, formatting, imports
5. **Type System & Data Modeling** (if applicable)
6. **Error Handling Patterns**
7. **Concurrency & Async** (if applicable)
8. **Security Best Practices**
9. **Testing Excellence**
10. **Performance Optimization**
11. **Idiomatic Patterns — Do This, Not That**
12. **Framework & Ecosystem** (if applicable)
13. **Code Quality Checklist**

### Writing guidelines

- **Specific to this language** — no generic advice
- **Code examples** for every major point (correct AND incorrect)
- **Imperative language**: "Use X", "Never Y", "Always Z"
- **Cite sources**: "Per the official style guide...", "Google's X style guide..."
- **Opinionated** — clear preferences, not options equally
- **Actionable** — every rule is something the agent can follow when writing code
- **Compact** — no JSON communication protocols, no progress templates, no cargo-cult ceremony

---

## Phase 5: Validate & Report

### Validation

- [ ] All applicable sections present
- [ ] AI Error Prevention has ≥10 specific documented errors
- [ ] Code examples included (≥5 do/don't comparisons)
- [ ] Sources cited
- [ ] Specific to this language, not generic
- [ ] Frontmatter correct
- [ ] File saved to correct path
- [ ] Best practices current

**UPDATE mode additional:**
- [ ] Every valid bullet/example from OLD version exists in NEW
- [ ] If anything was intentionally removed, document why

### Report

**CREATE mode:**
1. Language/technology
2. Agent created at file path
3. Key findings: number of AI errors cataloged, main sources, critical guidelines
4. How to use: available as `subagent_type: "{language}-pro"`
5. How to update: run `/lang-guidelines {language}` again

**UPDATE mode:**
1. Language/technology
2. File path updated
3. Changes: new errors added, sections updated, deprecated content removed, new sources
4. Current state: total errors cataloged, coverage
5. Next update: suggest in 2-3 months or when a new major version releases

---

## Error Recovery

- WebSearch fails → try alternative phrasings
- WebFetch fails → note and move on
- Niche language → do your best with available info, note gaps explicitly
