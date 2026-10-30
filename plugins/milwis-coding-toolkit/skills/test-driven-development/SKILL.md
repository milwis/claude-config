---
name: test-driven-development
description: "Use when implementing any new feature, bugfix, refactor, or behavior change: a test seen failing first, the minimum code to pass it, refactor while green."
---

# Test-Driven Development

**Goal.** Every behaviour you add or change has a test that failed for the expected reason before the code existed
and passes after it. That test is the proof of the behaviour; code without one is unproven, however right it looks.

**Entry:** about to write or change production behaviour (feature, bugfix, behaviour change, refactor of untested
code).
**Done when:** each new or changed behaviour has its test, each test was seen failing for the expected reason, the
targeted tests pass with clean output, and nothing was added without its own failing test.

**No test first** for copy, CSS, config, docs, generated code, throwaway prototypes and one-off scripts, and for
whatever the project's size classes exempt (`task-lifecycle`, the project's `CLAUDE.md`). A refactor of tested code
keeps its tests green; untested code gets characterization tests before the refactor.

**Code written before its test.** A test written afterwards proves nothing until it has been seen failing: take the
production change out (revert it on a copy, or a mutant that removes it), watch the test go red for the expected
reason, then restore. A test that was never red does not count. Tests shaped after the implementation (mirroring its
structure, mocking the subject, asserting nothing about behaviour) are what a reviewer flags as CRITICAL.

## The cycle

### Red

One behaviour per test, named by the behaviour (a name with "and" is two tests). The expected value is a literal, a
worked example or a spec value. Run it and read the failure: it fails, with the message you expected, because the
behaviour is missing, not from a typo, a missing import or a broken fixture. A test that passes at once tests
behaviour that already exists; change the test.

### Green

The simplest code that passes; nothing the test does not ask for. Write it in the idiom the module already uses: its
error handling, naming, layer, and the canonical service for the concept (a calculator, the service that owns a
table, a validator). When you follow a precedent, cite its `file:line` in the report. When the code you need has no
precedent, or two conflict, say so in the report instead of inventing a third style.

Run the new test plus the targeted set (`task-lifecycle` `references/implementacja.md`, test economy). The full
suite runs once, at the end of the task. The output is clean: no warnings, no unhandled rejections. A new test that
fails means the code is wrong, not the test.

### Refactor

Only while green: duplication, names, helpers, moving toward the conventions of the surrounding module. No new
behaviour, which needs its own failing test. Re-run the targeted set after each step.

**Vertical, not horizontal.** One test, then its code, then the next test. All tests first and all code after tests
the shape you imagined, not the behaviour; each cycle's test responds to what the previous cycle taught you.

## Good tests

| Quality | Good | Bad |
|---|---|---|
| Minimal | One behavior per test | `test('validates email and domain and whitespace')` |
| Named | Behavior in the name | `test('test1')`, `test('works')` |
| Real | Real code where possible | Mocks the subject under test |
| Intent | Shows desired API | Obscures what code should do |
| Independent | Expected value is a known literal / worked example / spec value | **Tautological:** expected value recomputed the way the code computes it (`expect(total(items)).toBe(items.reduce(...))`, a snapshot derived by hand the same way, a constant asserted equal to itself) — passes by construction, stays GREEN under every mutant |

## When stuck

| Problem | Solution |
|---|---|
| Don't know how to test | Write the wished-for API first, or the assertion first. Ask the user. |
| Test is too complicated | Design is too complicated. Simplify the interface. |
| Have to mock everything | Too coupled. Use dependency injection. |
| Test setup is huge | Extract helpers. Still huge? Design is wrong. |

## Bugs

A bug gets a test that reproduces it, seen failing, before the fix, at the seam where the bug happens.
`systematic-debugging` finds the cause that comes before that test.
