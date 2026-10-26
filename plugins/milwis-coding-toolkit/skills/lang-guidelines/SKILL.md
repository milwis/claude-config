---
name: lang-guidelines
description: Creates or checks the goal-only builder agent for a language/technology, and turns researched AI-coding errors for that language into candidate rules for a project — kept only where the project shows the error or already has the canonical way to avoid it. Usage - /lang-guidelines <language or technology> [project path]
---

# Language Guidelines Generator

**Target language/technology:** `$ARGUMENTS` (the first word; an optional second argument is the project to measure against, default: the current repo).

If `$ARGUMENTS` is empty, ask which language or technology.

Since v1.6.0 the toolkit's agents carry a goal and nothing else (`UPDATE_LOG.md`, v1.6.0). A rule reaches a builder only from the project (`CLAUDE.md`, `.claude/rules/*.md` loaded on Read, `docs/standards`) or from the brief. So this skill produces two things, in two places:
1. the agent file — goal-only, from the template, under 3 KB;
2. candidate rules — in the project's path-scoped rules, each with a measurement from that project.

Language knowledge the model already has goes into neither.

---

## Dates

Never hardcode years. `{CURRENT_YEAR}` and `{PREVIOUS_YEAR}` come from today's date in the system context; use them in every search query and write the actual date in `Last updated`.

## Step 0: Detect mode

Look for `{language}-pro.md` (or a file whose name covers the language) in the toolkit source (`plugins/milwis-coding-toolkit/agents/` in `milwis/claude-config`) when agents are vendored — a project's `.claude/agents/` copy is overwritten by the sync — otherwise in the project's `.claude/agents/`.

- **No agent → CREATE:** Phase 4a writes it from the template; Phases 1–3 and 4b run when a project is given.
- **Agent exists → CHECK:** compare it with the template — size under 3 KB, no rule lists, frontmatter `model: sonnet`, tools include `SendMessage`, the "done when" names this language's checks. Fix only what deviates. Then run Phases 1–3 and 4b for the project.

## Phases 1–3: Research

Queries: `references/research-prompts.md` (AI code-generation errors, best practices, idioms). For each error capture: the wrong code, what breaks, the correct form, the source. Prefer official docs, linters' rule lists and core contributors over blog lists. Note the language version each item depends on.

The research is raw material for Phase 4b, not content for the agent.

## Phase 4a: The agent

Write `<agents dir>/{language}-pro.md` from [references/agent-template.md](references/agent-template.md). `{language}` is lowercased and hyphenated (`Ruby on Rails` → `ruby-on-rails`, `Next.js` → `nextjs`). Writers stay on `sonnet`; judgment agents (`code-reviewer`, `backend-security-coder`, `refactoring-orchestrator`) stay on `opus` — the plugin README ("Model class") has the policy.

## Phase 4b: Candidate rules for the project

Classify every researched error against the project, by measurement:

| Group | When | What happens |
|---|---|---|
| **A** | a latch test, a lint rule at error level, a type check or a CI gate already stops it | nothing — cite the check |
| **B** | `CLAUDE.md`, a `.claude/rules` file or a linked standard already says it | nothing — cite `file:line` |
| **B-gap** | the project has the error (a hit) or a canonical way to avoid it (a precedent), and no A/B covers it | a candidate rule |
| **C** | none of the above (no occurrence, no precedent, or the model already gets it right) | dropped |

Measure with fixed strings (`git grep -nF`), and give every 0 a positive control: the same pattern against a line known to match. A 0 without a control is not a measurement. Under zsh, an unexpanded `$VAR` or a regex escape gives a false 0.

Each B-gap candidate carries:
- the rule text in the project's language, one or two sentences, naming the canonical `file:line`;
- the target file: the `.claude/rules/*.md` whose `paths:` cover the code it governs. Never `CLAUDE.md` or an always-loaded file unless the rule applies everywhere and the project's budget latch allows it;
- the measured precedent and violations (command + count);
- whether a latch would be cheaper than prose. A mechanical class gets a latch proposal instead of a rule.

Present the candidates to the owner; add the approved ones to the project's rules files. Never add them to the agent file.

## Phase 5: Validate and report

- [ ] Agent file under 3 KB, no rule lists, frontmatter correct, saved at the right path
- [ ] Every candidate has its measurement, precedent and target file
- [ ] Every A/B row cites its check or `file:line`

Report: the agent path (created / unchanged / fixed: what), counts per group, the B-gap candidates with their target files, and the latch proposals.

## Error recovery

WebSearch fails → try other phrasings. WebFetch fails → note and move on. Niche language → state the gaps explicitly.
