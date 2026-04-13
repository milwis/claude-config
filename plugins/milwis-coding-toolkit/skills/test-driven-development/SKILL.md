---
name: test-driven-development
description: "Use when implementing any new feature, bugfix, refactor, or behavior change — BEFORE writing implementation code. Enforces red-green-refactor discipline: write a failing test first, watch it fail for the right reason, then write minimal code to make it pass. Exceptions (throwaway prototypes, config files, generated code) require explicit user permission."
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write the minimum code to make it pass. Refactor. Repeat.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Announce at start:** "I'm using the test-driven-development skill."

**Violating the letter of these rules violates the spirit of these rules.**

---

## When to Use

**Always:**
- New features
- Bugfixes
- Refactoring
- Behavior changes
- New endpoints / functions / classes

**Exceptions (require explicit user permission):**
- Throwaway prototypes / spike solutions
- Generated code
- Pure configuration files
- One-off migration scripts

Thinking "skip TDD just this once"? **Stop. That's rationalization.** Read the rationalization table below.

---

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote implementation before the test? **Delete it. Start over.**

- Don't "keep it as reference" — you will adapt it, and that's tests-after.
- Don't "look at it while writing tests" — same thing.
- Don't sunk-cost-fallacy your way into keeping unverified code.

Implement fresh from the tests. Period. No exceptions without the user's explicit permission.

---

## Red-Green-Refactor

```
┌──────────┐      ┌──────────┐      ┌────────────┐
│   RED    │ ───▶ │  GREEN   │ ───▶ │  REFACTOR  │ ───┐
│ failing  │      │ minimal  │      │  clean up  │    │
│   test   │      │   code   │      │ stay green │    │
└──────────┘      └──────────┘      └────────────┘    │
      ▲                                               │
      └───────────────────────────────────────────────┘
                       next test
```

### RED — Write a Failing Test

One minimal test, one behavior, clear name.

**Good:**
```javascript
test('retries failed operation 3 times before giving up', async () => {
  let attempts = 0;
  const op = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(op);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```

**Bad:**
```javascript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('ok');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```
Vague name, tests the mock not the code, obscures intent.

**Requirements:**
- One behavior per test
- Name that describes the behavior, not "test1"
- Prefer real code over mocks (mocks only when unavoidable)
- Test demonstrates the wished-for API

### Verify RED — Watch It Fail

**Mandatory. Never skip.** (This is the `verification-before-completion` gate applied to tests.)

Run the test. Confirm:
1. It **fails** (not errors out due to typo / missing import)
2. The failure message is what you expected
3. It fails because the feature is missing, not because the test is broken

**Test passes immediately?** You're testing existing behavior. Fix the test.
**Test errors?** Fix the error, re-run until it fails *correctly*.

### GREEN — Minimal Code

Write the *simplest* code that makes the test pass. Nothing more.

**Good:**
```javascript
async function retryOperation(fn) {
  for (let i = 0; i < 3; i++) {
    try { return await fn(); }
    catch (e) { if (i === 2) throw e; }
  }
}
```

**Bad (YAGNI violation):**
```javascript
async function retryOperation(fn, options = {
  maxRetries: 3,
  backoff: 'exponential',
  onRetry: null,
  jitter: true,
}) { /* ... */ }
```

Don't add options nobody asked for. Don't refactor adjacent code. Don't "improve" beyond what the test requires.

### Verify GREEN — Watch It Pass

**Mandatory.** Run the test + the full suite. Confirm:
- New test passes
- Other tests still pass
- Output is pristine (no warnings, no "unhandled rejection", no console spam)

**New test fails?** Fix the code, not the test.
**Other tests fail?** Fix them now. Don't move on.

### REFACTOR — Clean Up (Only After Green)

With the test still green, clean up:
- Remove duplication
- Improve names
- Extract helpers

**Do not add new behavior in refactor.** If a new behavior is needed, write a new failing test first.

After refactor: re-run the full suite. Stay green.

### Repeat

Next behavior → next failing test.

---

## Good Tests

| Quality | Good | Bad |
|---|---|---|
| **Minimal** | One behavior per test | `test('validates email and domain and whitespace')` |
| **Named** | Behavior in the name | `test('test1')`, `test('it works')` |
| **Real** | Uses real code where possible | Mocks the thing under test |
| **Shows intent** | Demonstrates the desired API | Obscures what the code should do |

If the name contains "and", split the test.

---

## Why Order Matters

**"I'll write tests after to verify it works."**
Tests written after code pass immediately. Passing immediately proves nothing — you don't know if the test can catch bugs. Test-first forces you to see it fail, which proves it actually tests something.

**"I already manually tested all edge cases."**
Manual testing is ad-hoc: no record, can't re-run, easy to forget under pressure. "It worked when I tried it" ≠ "it is covered".

**"Deleting X hours of work is wasteful."**
Sunk cost fallacy. The time is already gone. Your real choice: rewrite with TDD (high confidence), or keep it and add tests after (low confidence, likely bugs lurking). The "waste" is shipping code you can't trust.

**"Tests-after achieve the same goals — it's spirit not ritual."**
No. Tests-after answer "what does this do?". Tests-first answer "what *should* this do?". Tests-after are biased by the implementation — you test what you built, not what's required. Tests-first force edge-case discovery before you write code.

---

## Rationalizations — All Wrong

| Excuse | Reality |
|---|---|
| "Too simple to need a test" | Simple code breaks. The test takes 30 seconds. |
| "I'll write tests after" | Passing-immediately tests prove nothing. |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost. Keeping unverified code is debt. |
| "Keep as reference, then write tests" | You'll adapt it. That's tests-after. |
| "Need to explore first" | Fine. Throw away the spike, then TDD. |
| "Hard to test = need to skip" | Hard to test = hard to use. Simplify the design. |
| "TDD slows me down" | TDD is faster than debugging. |
| "Manual test is faster" | Manual doesn't prove edge cases and doesn't re-run. |
| "Existing code has no tests" | You're improving it. Add tests for what you touch. |
| "This is different because..." | No it isn't. |

---

## Red Flags — STOP and Start Over

- Code written before the test
- Test added "later"
- Test passes immediately
- You can't explain *why* the test failed
- "Keep as reference" / "adapt existing code"
- "Already spent X hours"
- "TDD is dogmatic, I'm being pragmatic"
- "I'll just this once..."

All of these mean: **delete the implementation, start over with a failing test**.

---

## Example: Bugfix

**Bug:** Empty email is accepted by the form.

**RED:**
```javascript
test('rejects empty email with "Email required"', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED:**
```
$ npm test
FAIL  expected 'Email required', got undefined
```

**GREEN:**
```javascript
function submitForm(data) {
  if (!data.email?.trim()) return { error: 'Email required' };
  // ...
}
```

**Verify GREEN:**
```
$ npm test
PASS  57/57
```

**REFACTOR:** Extract a `validateRequired(field, label)` helper if two more fields need the same check. Re-run, stay green.

---

## When Stuck

| Problem | Solution |
|---|---|
| Don't know how to test | Write the wished-for API first. Write the assertion first. Ask the user. |
| Test is too complicated | Design is too complicated. Simplify the interface. |
| Have to mock everything | Code is too coupled. Use dependency injection. |
| Test setup is huge | Extract helpers. Still huge? The design is wrong. |

---

## Debugging Integration

**Bug found? Write a failing test that reproduces it *before* fixing.** Then follow the TDD cycle. The test proves the fix works AND prevents regression.

**Never fix a bug without a test.** Otherwise you have no way to know it stays fixed.

See also: `systematic-debugging` skill for the root-cause investigation process that comes *before* the failing test.

---

## Verification Checklist

Before marking the work complete:

- [ ] Every new function / method has a test
- [ ] I watched each test fail before implementing
- [ ] Each test failed for the *expected* reason (missing feature, not typo)
- [ ] I wrote minimal code to pass each test
- [ ] All tests pass (full suite, not just the new ones)
- [ ] Output is pristine (no warnings, no unhandled rejections)
- [ ] Tests use real code (mocks only when unavoidable)
- [ ] Edge cases and error paths are covered

Can't tick all boxes? You skipped TDD. Start over.

---

## Final Rule

```
Production code → a test exists for it AND that test failed first
Otherwise      → it is not TDD
```

No exceptions without the user's explicit permission.
