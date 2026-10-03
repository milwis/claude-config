# task-lifecycle — evidence behind the rules

Measurements (`POMIAR` / MEASURED) that justify the rules in `../SKILL.md`. Each entry is referenced from the rule as `E<n>`. Numbers are from KonkretnyTMS queue batches unless stated otherwise; they explain why a rule exists and are not re-checked at run time.

## E1 — Step 0 — Trivial (test-only DIRECT)

MEASURED (KonkretnyTMS batch 2.3): a 2-line latch addition done inline with the probe cost ~2k tokens; the same work through a builder subagent costs a 40k spawn minimum.

## E2 — Step 0 — Small builder call budget

`POMIAR` (batch 3.1, #685): a Small builder (one model line + tests) made 83 calls / 22.9M input, ~40% of them measuring `AUTO_INCREMENT` on 8 tables and reading a controller — two valid spin-off issues, produced in the most expensive context available.

## E3 — Step 0 — Small narrow review

`POMIAR` (batch 3.1): narrow review of #685 cost 2.6M / 11 calls and still produced a valid P3 outside the diff; a full review of a Standard diff in the same batch cost 11.8M.

## E4 — Step 0 — task context block

`POMIAR` batch 3.1: three such false alarms, see `roadmapa` § Measurement discipline

## E5 — Step 1 — narrow builders per layer

`POMIAR` (batch 3.1, #687): one builder across three layers and three kinds of tests — 124 calls, 40.4M input, 2.7× the cost of a comparable single-layer builder at the same context size (#685: 83 calls, 22.9M).

## E6 — Step 1 — write-first

`POMIAR` (KonkretnyTMS batch 2.2, #802): builder-1 read ~15 files and stopped at 170,708 tokens — 17% of a 1M window, 17 calls, below the 45% hook threshold, no hook message — with no edit; builder-2 with the same findings in the brief and "start by writing" finished in 107 calls. The cost sat in the ordering, not in the task.

## E7 — Step 1 — copy pattern carries its latch

`POMIAR` (batch 2.4, #580): the builder copied the mechanism without the per-tree test → P1 finding + one review round,

## E8 — Step 1 — two-sided verification briefs

A confirmation-shaped brief was measured (2026-08-29/30) to make a subagent confirm a false thesis while holding its disproof in its own context.

## E9 — Step 1 — mutant table per property

`POMIAR` (batch 3.1, #730): the builder showed two RED mutants, both on the one working branch, and never mutated the brief's other requirements ("file composition of the frozen debt", "threshold per tree"); the reviewer's three control mutants found three vacuous branches, and the fixer cost 13.6M.

## E10 — Step 1 — mutant executed, not narrated

`POMIAR` (batch 3.2, #714): the builder spent most of 91 calls fitting the probe script to a cron entry point, then reported "MUTANT RED #2" as a conclusion; the reviewer had to execute the mutant itself.

## E11 — Step 1 — docblock cap scope

`POMIAR` (KonkretnyTMS batches 4.7 and 4.8): two consecutive annexes recorded "the docblock cap did not hold" (24, then 40 lines) from the whole-diff form and proposed no change, while the production paths of both diffs took **0** added comment lines (`git show f84e92fc8 -- php`, `git show 6fc38710b -- php scripts`); an unscoped check turns a held rule into a standing violation report

## E12 — Step 1 — docblock cap and template test

`POMIAR` (batch 3.3, #697): a 38-line docblock on a 3-line function became a P3 and an inline cut; the builder's first-in-repo test loading real Bootstrap in jsdom cost ~79 calls to discover the CJS/`window.bootstrap` branch and the `FocusTrap` race — inherent once, ~60k avoidable on every repeat that gets the path.

## E13 — Step 1 — live-DB own fixture

`POMIAR` (KonkretnyTMS batch 4.8, #516): the builder's live-DB test skipped on `purchase_invoices` being empty; the opus review (50 calls, 13 mutants) and the fixer both passed it, the end-of-batch full suite went red on `FixtureLotterySkipLatchTest`, and the repair (own row, transaction, rollback) was a 194k fixer spawn plus a second full-suite run — the whole +32% of that batch. Batch 4.7 had the same latch red for the opposite move (a removed skip), fixed inline for ≈10k; the class is cheap when caught by the builder and expensive when caught by the suite.

## E14 — Step 1 — documented precedent

`POMIAR` (batch 3.1, #687): a builder stopped on exactly such a documented idiom; hard rule 6 forbade resuming it, so the stop cost a fresh spawn (~50k prefix) on top of the 19M already spent.

## E15 — Step 1 — classifier-safe block

`POMIAR` (batch 3.2, #714): two verifiers bounced on `cp`/`rm`, one switched to `mv` and a log artefact (`logs-report/latest.txt`) disappeared — 2–4 wasted calls per bounce, and a lost artefact on top.

## E16 — Step 1 — brief checklist

`POMIAR` (KonkretnyTMS batch 4.6): the docblock cap (added in 3.3) was in none of the batch's briefs and three new tests shipped 14-, 33- and 59-line docblocks; the batch's annex marked four rules "not applied", and every one of them was a rule absent from the brief, not a rule the subagent read and ignored.

## E17 — Step 1 — report walks numbered items

`POMIAR` (batch 2.4, #580): the builder silently dropped the probes the brief asked for; the omission was caught by the orchestrator's grep, not by the review — in #579 the same per-item requirement in the brief made the builder report it.

## E18 — Step 1 — re-execute reported numbers

`POMIAR` (KonkretnyTMS batch 4.8): of three load-bearing `POMIAR` sentences in a writing subagent's report, one was false (`0 hits` where the real count was 2) and one incomplete (3 files against 5); two control commands at ≈ 0 tokens caught both, and the subagent's verdict was still correct — a wrong number in a right verdict is the one that survives review.

## E19 — Step 2.2 — orchestrator probes fixer surface

`POMIAR` (KonkretnyTMS batch 8.5, #486): two of three review rounds were exactly this — fixer-1 added a `checkBalance` guard tested only for `status=0` (R2 found 4xx-with-body as P2), fixer-2 added a `Circuit OPEN` log line with no test (R3's mutant stayed GREEN); each round cost a review (117–143k) plus a fixer (205–253k) ≈ 350k, and the three probes G1 ran inline after R3 cost ≈ 2k each. The builder's table rule (Step 1) had held; the fixer briefs simply did not carry it.

## E20 — Step 2.2 — probe copy depth

`POMIAR` batch 2.5, one wasted call

## E21 — Step 2.2 — comment-only inline fix

`POMIAR` (KonkretnyTMS batch 2.2, #802): three comment-only P3s (`php/config`, `sql/migrations`, a test docblock — 26 lines in 3 files) went to a fixer because the exception as written stopped at 10 lines and read as tests-only; the spawn cost 216k tokens, the same three edits inline cost ≈ 3k.

## E22 — Step 2.2 — inline fix-up economics

`POMIAR` (batch 3.3): three such P3s (a `TRIM()` parity fix, one test for an unlatched guard member with its probe, a docblock cut) done inline for ≈ 8k total; batch 3.2 paid 140k + 175k for two fixer spawns of the same class — zero fixer spawns was the whole measured −18% of batch 3.3. `POMIAR` (batch 3.2): two cosmetic P3s in #735 went to a fresh fixer — 140k / 27 calls, most of them re-reading context — while a one-line test correction in #714 done inline cost ≈ 2k (`98782e004`); 70× for the same class of change.

## E23 — Step 2.2 — inline vs fixer, batches 2.4/2.5

`POMIAR` (batch 2.4): three such fix-ups done inline cost ≈ 25k tokens; the same three through fresh fixer subagents would have cost ≥ 300k. `POMIAR` (batch 2.5): six such fix-ups across three issues, each ≤ ~15 lines with the reviewer's `file:line` and proposed diff in hand, all inline — estimated ≥ 240k saved against six fixer spawns; `podagent-piszacy-tanszy-niz-inline` is about writing from scratch, not about a 10-line correction with the location already known.

## E24 — Step 2 — test-run economy

`POMIAR` (KonkretnyTMS batches 4.7 and 4.8): the same corpus latch went red at the full suite in two consecutive batches — once for a removed skip (≈10k inline), once for an added data-dependent skip (194k fixer + second suite run); neither builder, reviewer nor fixer ran it, because nothing in the diff pointed at it. `POMIAR` (KonkretnyTMS batch 2.2, #802): 26 route edits shipped without `scripts/generate-api-route-inventory.php`; `ApiRouteInventoryFreshnessLatchTest` was the single delta of the end-of-batch suite against the baseline (58 vs 57 names), a parity-check block and a closing commit. `POMIAR` (KonkretnyTMS batch 7.6, #408): the builder removed three CRUD routes and ratcheted the one counter latch the project's `CLAUDE.md` names (`WriteRoute*` 252→249); the two it does not name (`PermissionMatrixSnapshotTest` admin 29→26, `ControllerRawPdoBudgetLatchTest` 31→24 / BUDGET 447→440) went red only at the end-of-batch full suite — `git grep -c createGroup` on both files gave 0, an opus review had passed the diff — and cost a second full-suite run (≈15 min wall) plus a closing commit (≈20k). `POMIAR` (KonkretnyTMS batch 3.4, #688): the builder ran `tests/Repositories` for a change in `Repositories/`, eight mocks in `tests/Services` and `tests/Controllers` went red at the end-of-batch full suite, and the regression cycle (fixer + opus review over the >50-line threshold) cost ≈ 316k — the whole +14% of that batch.

## E25 — Step 4 — verify brief entry point

`POMIAR` (KonkretnyTMS batch 4.6, #549): the grep showing "no button" sat in the orchestrator's exec row; the brief did not carry it, and ≈150k of a 190k verify went to two pre-existing blockers on the unreachable path.

## E26 — Hard rule 5 — third report = defect in the rule

`POMIAR` (KonkretnyTMS batches 3.3, 4.6, 4.7, 4.8): the docblock cap was recorded as broken in four annexes, escalating 24 → 40 lines, each time filed as an instance of an existing rule; the rule had been added to ten agent overlays and every brief, and the last two verdicts were measuring the test-file header that the rule itself designates as the destination.

## E27 — Hard rule 6 — never resume

MEASURED (2026-09-13, batch of 5 issues, 32 subagents, 503M cache-read tokens): the builder resumed for three review iterations cost 94M input tokens over 497 turns and finally overflowed its context mid-iteration; the fresh builder spawned to finish that same iteration did more work for 24M. Resuming a 240k-context reviewer for a 15-tool-call sign-off cost ~25M; a fresh diff-only reviewer would cost ~3M. A resumed agent pays its whole accumulated context on every turn.

## E28 — Hard rule 7 — SendMessage by name

MEASURED (same batch): task-notifications of subagents spawned by a nested orchestrator landed with the top-level session, not the spawner — every builder report had to be relayed by hand, doubling the reading and stalling one issue for 3 h.
