# Research Query Templates

Use these as WebSearch queries during each research phase. Replace `{lang}` with the actual language/technology name.

**CRITICAL: Dynamic Dates** — All queries below use `{CURRENT_YEAR}` and `{PREVIOUS_YEAR}` as placeholders.
You MUST replace them with the actual current year and previous year based on today's date (provided by the system context).
For example, if today is 2026-04-11: `{CURRENT_YEAR}` = 2026, `{PREVIOUS_YEAR}` = 2025.
NEVER hardcode specific years. Always use the current date to determine the year.

## Phase 1: AI Code Generation Errors

### Primary Queries (execute ALL of these)
1. `common mistakes AI code generation {lang} {PREVIOUS_YEAR} {CURRENT_YEAR}`
2. `LLM code generation errors {lang} hallucination deprecated API {CURRENT_YEAR}`
3. `ChatGPT Copilot Claude common bugs {lang} {CURRENT_YEAR}`
4. `AI generated code pitfalls {lang} anti-patterns {CURRENT_YEAR}`
5. `AI coding assistant mistakes {lang} code review {CURRENT_YEAR}`
6. `{lang} AI generated code security vulnerabilities {CURRENT_YEAR}`

### Secondary Queries (execute if primary results are insufficient)
7. `GitHub Copilot wrong {lang} code examples {CURRENT_YEAR}`
8. `AI code generation {lang} incorrect patterns Stack Overflow {CURRENT_YEAR}`
9. `{lang} deprecated functions AI still uses {CURRENT_YEAR}`
10. `{lang} AI hallucinated libraries functions`

### For Specific Error Types
- `AI {lang} race condition concurrency bugs {CURRENT_YEAR}`
- `AI {lang} memory leak resource management`
- `AI {lang} injection vulnerability generated code {CURRENT_YEAR}`
- `AI {lang} type errors incorrect casting`

## Phase 2: Best Practices & Standards

### Official Sources
1. `{lang} official style guide coding standards {CURRENT_YEAR}`
2. `{lang} official documentation best practices`
3. `{lang} language specification guidelines latest`

### Company Style Guides
4. `{lang} style guide Google latest`
5. `{lang} style guide Microsoft {CURRENT_YEAR}`
6. `{lang} style guide Airbnb latest` (especially for JS/TS/Ruby)
7. `{lang} style guide Meta Facebook`
8. `{lang} coding standards enterprise {CURRENT_YEAR}`

### Community Standards
9. `{lang} best practices {PREVIOUS_YEAR} {CURRENT_YEAR} production`
10. `{lang} linter rules recommended configuration {CURRENT_YEAR}`
11. `{lang} static analysis tools best {CURRENT_YEAR}`
12. `{lang} code formatter official latest`

### Specific Domains
13. `{lang} security best practices OWASP {CURRENT_YEAR}`
14. `{lang} performance optimization guide {CURRENT_YEAR}`
15. `{lang} testing best practices patterns {CURRENT_YEAR}`
16. `{lang} error handling patterns idiomatic`
17. `{lang} concurrency async best practices {CURRENT_YEAR}`
18. `{lang} clean code architecture patterns`
19. `{lang} dependency management best practices {CURRENT_YEAR}`

### Scientific & Research
20. `scientific research code quality {lang} {CURRENT_YEAR}`
21. `empirical study {lang} best practices software engineering {PREVIOUS_YEAR} {CURRENT_YEAR}`
22. `{lang} code quality metrics research paper`
23. `static analysis {lang} bug detection study {CURRENT_YEAR}`

## Phase 3: Idiomatic Patterns

### Core Idioms
1. `idiomatic {lang} patterns examples {CURRENT_YEAR}`
2. `{lang} code review what experts check {CURRENT_YEAR}`
3. `{lang} anti-patterns vs idiomatic code`
4. `writing idiomatic {lang} guide`
5. `{lang} from beginner to expert patterns evolution`

### Language-Specific Terms
Use the language community's own terminology:
- **Python**: "pythonic code", "PEP 8", "zen of python", "python {CURRENT_YEAR} new features"
- **Go**: "effective go", "go proverbs", "go code review comments"
- **Rust**: "rustacean patterns", "rust idioms", "clippy lints", "rust edition {CURRENT_YEAR}"
- **JavaScript/TypeScript**: "clean javascript", "typescript strict mode best practices {CURRENT_YEAR}"
- **Java**: "effective java", "java design patterns", "clean java code", "java {latest_version} features"
- **C++**: "modern C++ idioms", "C++ core guidelines", "effective modern C++"
- **C#**: "C# coding conventions Microsoft", ".NET best practices {CURRENT_YEAR}"
- **Ruby**: "ruby way", "ruby style guide community"
- **Swift**: "swift API design guidelines", "swifty code"
- **Kotlin**: "idiomatic kotlin", "kotlin coding conventions"
- **PHP**: "PSR standards", "modern PHP patterns {CURRENT_YEAR}"

### Comparison Patterns
6. `{lang} do this not that code examples`
7. `{lang} common mistakes developers make {CURRENT_YEAR}`
8. `{lang} code smells specific`
9. `{lang} refactoring patterns`
10. `{lang} clean code examples before after`

## Phase 2+3 Combined: Key Articles to WebFetch

After searching, prioritize fetching these types of pages:
- Official language documentation pages on best practices
- Google/Microsoft/Airbnb style guide pages for the language
- Top-rated Stack Overflow answers about best practices
- Well-known blog posts by language core contributors
- Research papers with concrete findings (not just abstracts)
- Linter documentation (default rules and their rationale)
- Release notes for the latest language/framework versions

## Update-Specific Queries

When updating an existing agent (not creating from scratch), use `{CURRENT_YEAR}` dynamically:

1. `{lang} new features {CURRENT_YEAR}`
2. `{lang} deprecations breaking changes latest version {CURRENT_YEAR}`
3. `{lang} ecosystem changes {CURRENT_YEAR}`
4. `{lang} new best practices emerging patterns {CURRENT_YEAR}`
5. `{lang} AI code generation improvements issues latest {CURRENT_YEAR}`
6. `{lang} new security vulnerabilities CVE {CURRENT_YEAR}`
7. `{lang} framework updates major changes {CURRENT_YEAR}`
8. `{lang} latest version release notes`
9. `{lang} breaking changes migration guide {CURRENT_YEAR}`

## Quality Signals

When evaluating search results, prioritize sources with:
- **High authority**: Official docs, core team members, major companies
- **Recency**: Content from {CURRENT_YEAR} and {PREVIOUS_YEAR} (deprioritize content older than 2 years for rapidly evolving languages)
- **Community validation**: High upvotes, stars, citations
- **Specificity**: Concrete examples over abstract advice
- **Research backing**: Empirical evidence, data-driven conclusions

Deprioritize:
- Generic "top 10 tips" listicles without depth
- Content older than 2 years (for fast-moving ecosystems)
- AI-generated content that's circular (AI writing about AI mistakes without real data)
- Content without examples or evidence
- Paywalled content that can't be accessed
