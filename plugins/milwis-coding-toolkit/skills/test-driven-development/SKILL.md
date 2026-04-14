---
name: test-driven-development
description: "Use when implementing any new feature, bugfix, refactor, or behavior change. Enforces red-green-refactor: failing test first, watch it fail, minimal code to pass, refactor."
---

# Test-Driven Development

**Core:** Write the test first. Watch it fail. Write the minimum code to make it pass. Refactor. Repeat.

**Announce at start:** "I'm using the test-driven-development skill."

---

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote implementation before the test? **Delete it. Start over.** No "keep as reference", no "adapt what I wrote". Implement fresh from the tests.

**Exceptions (require explicit user permission):** throwaway prototypes, generated code, pure config files, one-off migration scripts.

---

## When to Use

**Always** for: new features, bugfixes, refactoring, behavior changes, new endpoints/functions/classes.

**Skip only** with explicit user approval.

---

## Red → Green → Refactor

### RED — Write a Failing Test

One behavior per test. Clear name. Prefer real code over mocks.

```javascript
// Good
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

Requirements:
- One behavior per test (name has "and" → split it)
- Name describes behavior, not "test1"
- Test demonstrates the wished-for API

### Verify RED — Watch It Fail

**Mandatory.** Run the test. Confirm:
1. It fails (not errors out from typo/missing import)
2. Failure message is what you expected
3. It fails because the feature is missing, not because the test is broken

Test passes immediately → you're testing existing behavior; fix the test.
Test errors out → fix the error, re-run until it fails correctly.

### GREEN — Minimal Code

Simplest code that makes the test pass. No premature options, no adjacent refactoring, no "while I'm here".

### Verify GREEN — Watch It Pass

Run new test + full suite. Confirm:
- New test passes
- Other tests still pass
- Output is pristine (no warnings, no unhandled rejections)

New test fails → fix the code, not the test.
Other tests fail → fix them now.

### REFACTOR — Clean Up (only after green)

With the test still green: remove duplication, improve names, extract helpers. **No new behavior** — that requires a new failing test. Re-run full suite; stay green.

---

## Good Tests

| Quality | Good | Bad |
|---|---|---|
| Minimal | One behavior per test | `test('validates email and domain and whitespace')` |
| Named | Behavior in the name | `test('test1')`, `test('works')` |
| Real | Real code where possible | Mocks the subject under test |
| Intent | Shows desired API | Obscures what code should do |

---

## Bugfix Example

**Bug:** Empty email is accepted by the form.

**RED:**
```javascript
test('rejects empty email with "Email required"', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED** → `FAIL expected 'Email required', got undefined`

**GREEN:**
```javascript
function submitForm(data) {
  if (!data.email?.trim()) return { error: 'Email required' };
  // ...
}
```

**Verify GREEN** → `PASS 57/57`

---

## When Stuck

| Problem | Solution |
|---|---|
| Don't know how to test | Write the wished-for API first, or the assertion first. Ask user. |
| Test is too complicated | Design is too complicated. Simplify the interface. |
| Have to mock everything | Too coupled. Use dependency injection. |
| Test setup is huge | Extract helpers. Still huge? Design is wrong. |

---

## Bug Discipline

Bug found? Write a failing test that reproduces it **before** fixing. The test proves the fix works AND prevents regression. Never fix a bug without a test.

See `systematic-debugging` for root-cause investigation that comes *before* the failing test.

---

## Checklist

- [ ] Every new function has a test
- [ ] Each test failed before implementing
- [ ] Each test failed for the expected reason
- [ ] Minimal code to pass each test
- [ ] All tests pass (full suite)
- [ ] Output pristine (no warnings, no unhandled rejections)
- [ ] Tests use real code (mocks only when unavoidable)
- [ ] Edge cases and error paths covered

---

## Final Rule

```
Production code → a test exists for it AND that test failed first
Otherwise      → it is not TDD
```
