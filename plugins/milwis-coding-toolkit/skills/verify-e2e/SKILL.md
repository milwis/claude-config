---
name: verify-e2e
description: "Use after implementing any user-facing change (GUI, API endpoint, CLI, cron, agent) — verifies the change on the SURFACE the user interacts with, in a fresh isolated subagent, producing visual/response evidence. GUI → browser + screenshots, API → real HTTP request, CLI/cron → real execution. Complements verification-before-completion (which gates commands/tests); this skill gates the user surface."
---

# Verify E2E (surface-level verification in an isolated subagent)

**Core:** A change is verified on the surface where the user meets it — pixels, HTTP responses, CLI output — not only by tests. The verifier is a FRESH subagent with isolated context, instructed to falsify the "done" claim, and it must produce evidence artifacts.

**Announce at start:** "I'm using the verify-e2e skill."

---

## Why a fresh subagent (non-negotiable)

The model that implemented a change has an incentive to defend it. Smarter models are also better at *pretending* work is complete (see Fable 5 system card — deception under goal pressure). An isolated-context verifier:

- has not seen the implementation process, so it cannot rationalize gaps,
- is prompted adversarially ("try to prove this does NOT work"),
- reports back to the orchestrator, which can confront the builder with failures.

Never verify in the same context that built the change. Never accept the builder's own "it works" as evidence.

---

## Step 1: Determine the surface

| Change touches | Surface | Verification method | Evidence |
|---|---|---|---|
| GUI / frontend / template | Pixels | Drive a real browser (Claude-in-Chrome MCP or Playwright MCP) against the local env: log in, navigate, exercise the feature | Screenshots at each step; GIF recording for multi-step flows |
| API endpoint | HTTP | Send a real request (`curl`/HTTP client) with realistic payload; include at least one negative case (bad input, missing auth) | Full request + response (status, headers, body) |
| CLI / script / cron | Process | Execute with test data; check exit code, output, side effects (DB rows, files) | Command + full output + before/after state |
| DB migration | Schema + data | Run against dev DB; inspect schema and affected rows | DDL diff + row samples before/after |
| Agent / skill / prompt | Behavior | Invoke the agent/skill on a representative task | Transcript excerpt + produced artifact |
| Library / internal module | Consumer | Run the real consumer through one integration path (not just unit tests) | Consumer output |

A change can have multiple surfaces (endpoint + GUI that calls it) — verify the **outermost** one the user touches; inner surfaces are covered transitively unless the change is inner-only.

---

## Step 2: Environment check (before dispatching the verifier)

1. Read `docs/VERIFICATION_ENV.md` in the project root (if present) — it lists local URLs, test accounts, tokens, tools, and known gaps.
2. If the environment needed for this surface is **missing** (no test account, no API key, no browser tool, no fake data):
   - **Do NOT improvise.** Do NOT downgrade to "tests pass, so it works."
   - Return status **BLOCKED** with the exact list of what is missing.
   - Append the gap to the `## Gaps / backlog` section of `docs/VERIFICATION_ENV.md` (create the file if absent).
3. First time verifying a new area? Ask explicitly: *"What would I need to verify changes in this area end-to-end?"* — and record the answer in `VERIFICATION_ENV.md`. The environment compounds: every gap closed makes all future verifications stronger.

---

## Step 3: Dispatch the verifier subagent

Prompt template (fill the brackets):

```
You are an ADVERSARIAL end-to-end verifier with no prior context.
Claim under test: "[what the builder says now works, 1-2 sentences]"
Change summary: [files touched / feature description — NOT the diff rationale]
Surface: [GUI at <url> / API <method+path> / CLI <command> / ...]
Environment: [from VERIFICATION_ENV.md: URL, test login, tokens, tools]

Your job is to try to PROVE THE CLAIM FALSE:
1. Exercise the happy path exactly as a user would.
2. Exercise at least one edge/negative case relevant to the change.
3. Capture evidence at every step (screenshots / responses / output).
4. Check for collateral damage: does the surrounding page/endpoint still work?

Save evidence to [scratchpad or .verify/ dir — never commit binaries].
Return EXACTLY this structure:
- VERDICT: PASS | FAIL | BLOCKED
- Evidence: list of artifact paths, each with a one-line description
- Steps performed: numbered, factual
- Deviations: anything that surprised you, even if VERDICT=PASS
- If FAIL: precise repro steps + expected vs actual
- If BLOCKED: exact missing prerequisite(s)
```

Noisy tool-calling (browser automation) stays in the subagent — the orchestrator's context receives only the verdict and evidence paths.

---

## Step 4: Act on the verdict

- **PASS** → attach evidence paths to the completion report. Only now may "done" be claimed (`verification-before-completion` still applies to the wording).
- **FAIL** → this is Stop-the-Line. Hand the verifier's repro steps to a builder subagent (or `systematic-debugging` for non-obvious causes). Re-verify after the fix with a **new** fresh verifier. Cap: 3 verify-fix cycles, then stop and report to the user.
- **BLOCKED** → report the missing prerequisites to the user verbatim and record them in `VERIFICATION_ENV.md`. A BLOCKED verification is never silently skipped — the final report must say "verified: NO (blocked on X)".

---

## Evidence rules

- Evidence artifacts (screenshots, GIFs, response dumps) go to the session scratchpad or a git-ignored `.verify/` directory — never into commits.
- The final report references artifacts by path with one-line descriptions.
- Screenshots must show the actual feature state, not just "page loaded".
- For multi-step GUI flows prefer a GIF/recording — the user reviews recordings faster than prose.

---

## Integration

- `verification-before-completion` — inner gate (commands, tests, exit codes). verify-e2e is the outer gate (user surface). Both must pass before "done".
- `task-lifecycle` — calls this skill as its verification stage.
- `executing-plans` — final group of a plan includes this skill for user-facing changes.
- `systematic-debugging` — invoked when FAIL has a non-obvious cause.
