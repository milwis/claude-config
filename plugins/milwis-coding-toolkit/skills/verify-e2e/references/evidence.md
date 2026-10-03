# verify-e2e — evidence behind the rules

Measurements (`POMIAR`) that justify rules in `../SKILL.md`, referenced as `E<n>`. KonkretnyTMS queue batches; they explain why a rule exists and are not re-checked at run time.

## E1 — Step 2.3 — one connectivity probe

`POMIAR` (KonkretnyTMS batch 3.1, #687): the verifier spent 31 calls / 6M input before returning BLOCKED on a disconnected Chrome MCP; the orchestrator's single probe afterwards answered "not connected" at once; the Playwright re-run then cost 11.6M → 5.5M → 4.2M as the recipe was reused.

## E2 — Step 2.4 — name a file, not a directory

`POMIAR` (KonkretnyTMS batches 2.1–2.2): three verifies briefed with the helper directory used it 0/3 times (two-step curl with cookie jars, `grep -l loginAs` → 0); the one verify briefed with a concrete script (`verify-810.mjs` for #802) copied it 1/1 (`grep -c helpers/login.js probe.mjs` → 1) at 196k against 216k for the from-zero run of the same batch.

## E3 — Step 2.4 — commit the helper

`POMIAR` (KonkretnyTMS batches 3.2–3.3): the same Playwright login+modal script was built from zero three times (#710, #683, then reused for #697); with the path in the brief the reuse run cost 104k / 10 calls against 198k / 118 calls for the from-zero run — a ~90k difference on an identical class of proof, and the from-zero script sat in git-ignored `.claude/tmp/`, so the next batch could not find it.

## E4 — Step 2.5 — measured entry point

`POMIAR` (KonkretnyTMS batch 4.6, #549): the orchestrator had already measured `git grep addManualItem -- js/ views/` → definition + `window.addManualItem` export only, no button — in its own exec row — and still briefed a GUI flow; the verifier spent most of 86 calls / 190k diagnosing two pre-existing blockers on that unreachable path (`.col-md-3` selector, missing `select` argument — both `git blame` before the branch) and returned them as spin-off #784. ≈150k of the 190k bought no evidence about #549, and that was the whole +23% of the batch. The measurement was in the orchestrator's context; the brief did not carry it as scope.

## E5 — Step 3 — every template line filled

`POMIAR` (KonkretnyTMS batch 4.6): zero `mcp__claude-in-chrome__*` calls in the whole session transcript; `grep -c "tests/e2e/helpers"` and `grep -c "page.reload()"` on the verifier's 189-line script = 0 and 0; the verify brief itself was not preserved past a compaction, so whether the helper path was ever in it is unmeasured.

## E6 — Step 3 — commit reusable verifier scripts

`POMIAR` (KonkretnyTMS batch 3.2, #710): the verifier built its Playwright script from scratch in `.claude/tmp/`, fought a stale `dist/` because the brief did not state the bundle flag, and attributed a committed config line to the orchestrator's local edit — 210k / 51 calls, the most expensive verify of the batch; batch 3.1 measured the reuse curve on the same kind of script at 11.6M → 5.5M → 4.2M input per run.
