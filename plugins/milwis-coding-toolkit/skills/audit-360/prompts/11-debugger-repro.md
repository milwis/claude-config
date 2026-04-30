# Prompt for `debugger` — PoC reproduction for each P0

Run ONCE PER P0 from `audit/REPORT.md`. The 4-phase `systematic-debugging` Iron Law applies — no fix without Phase 1 done.

Paste the body below as the `prompt` parameter. Replace `<NNN>` with the P0 number and `<INVENTORY_PATH>` with the path to `audit/INVENTORY.md`.

```
subagent_type: debugger
description: Reproduce P0-<NNN> — <short title>
prompt: |
  You are reproducing **P0-<NNN>** from audit/REPORT.md for the application
  in <INVENTORY_PATH>. Operate under `systematic-debugging` (4 phases:
  investigate → compare → hypothesize → fix). Iron Law: no fix without
  Phase 1 done.

  IMPORTANT: you do NOT fix. You reproduce — to confirm the P0 is real,
  not theoretical.

  PROCESS (your 6-step root cause analysis):

  1. CAPTURE — read P0-<NNN> from REPORT.md. Note: file, line, hypothetical
     exploit/scenario.

  2. ESTABLISH BASELINE — read the cited code via Read. Does it exist? Has
     the repo version drifted from when the audit ran (commit between)?

  3. ISOLATE — minimal reproducer:
     - SQL injection: concrete payload + endpoint URL
     - XSS: HTML payload + injection flow
     - broken auth: concrete steps (curl commands)
     - logic bug: input → expected vs actual
     Save reproducer to audit/repro/P0-<NNN>.md.

  4. FIX (HYPOTHESIS) — do NOT fix. Describe in 1-2 sentences why the bug
     occurs (root cause, not symptom).

  5. VERIFY — if you can run the reproducer in a sandbox, run it. Show
     output. Otherwise, describe exactly what to run.

  6. PREVENT — propose a failing test that would have caught this bug in
     CI. Save to audit/repro/P0-<NNN>-test.md.

  RULES:
  - systematic-debugging Iron Law: do not skip Phase 1.
  - 3+ failed reproductions = mark as "theoretical, not reproduced" and
    de-escalate to P1 with note in the report.
  - verification-before-completion: do not finalize the repro report
    without evidence (command output, request/response).

  Output: audit/repro/P0-<NNN>.md with:
    - status: REPRODUCED / NOT_REPRODUCED / THEORETICAL
    - reproducer (commands/payload)
    - root cause (1-2 sentences)
    - proposed failing test
    - evidence (logs, output, screenshots)
```
