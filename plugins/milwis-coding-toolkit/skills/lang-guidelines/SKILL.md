---
name: lang-guidelines
description: "Use when a project needs rules for a language or technology: researches AI-coding errors for it and keeps, as candidate path-scoped rules, only those the project shows or has a canonical fix for. Usage - /lang-guidelines <language> [project path]"
---

# Language Guidelines Generator

**Target language/technology:** `$ARGUMENTS` (the first word; an optional second argument is the project to measure against, default: the current repo).

If `$ARGUMENTS` is empty, ask which language or technology.

The toolkit has one goal-only `builder` for every language (`UPDATE_LOG.md`, v1.7.0), and the session that implements a task writes most code itself. A rule reaches either of them only from the project (`CLAUDE.md`, `.claude/rules/*.md` loaded when a matching file is opened, `docs/standards`) or from a brief. So this skill produces one thing: candidate rules for the project's path-scoped rules file, each with a measurement from that project. It writes no agent.

Language knowledge the model already has goes nowhere.

---

## Dates

Never hardcode years. `{CURRENT_YEAR}` and `{PREVIOUS_YEAR}` come from today's date in the system context; use them in every search query and write the actual date in `Last updated`.

## Step 0: Find the rules file

Look in the project's `.claude/rules/` for the file whose `paths:` frontmatter covers this language's files (`git grep -n 'paths:' -A5 -- .claude/rules/`).

- **None → CREATE:** Phase 4 proposes a new file with `paths:` globs for the language and only the B-gap rules.
- **One exists → CHECK:** it holds gotchas, not a style guide. Lines that are model knowledge or that a check already enforces (group A) are proposed for removal, in the same report as the new candidates.

## Phases 1–3: Research

Queries: `references/research-prompts.md` (AI code-generation errors, best practices, idioms). For each error capture: the wrong code, what breaks, the correct form, the source. Prefer official docs, linters' rule lists and core contributors over blog lists. Note the language version each item depends on.

The research is raw material for Phase 4, not content for any file.

## Phase 4: Candidate rules for the project

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

Present the candidates to the owner; add the approved ones to the project's rules files. Never add them to an agent file.

## Phase 5: Validate and report

- [ ] Every candidate has its measurement, precedent and target file
- [ ] Every A/B row cites its check or `file:line`

Report: the rules file (found / proposed new, with its `paths:`), counts per group, the lines proposed for removal, the B-gap candidates with their target files, and the latch proposals.

## Error recovery

WebSearch fails → try other phrasings. WebFetch fails → note and move on. Niche language → state the gaps explicitly.
