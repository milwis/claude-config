# Prompt for `debugger` — PoC reproduction for each P0

Run once per P0 from `audit/REPORT.md`. The agent reproduces and names the cause; it does not fix. Skills do not load inside a subagent, so the rules it needs are lines of the prompt below.

Paste the body below as the `prompt` parameter. Replace `<NNN>` with the P0 number and `<INVENTORY_PATH>` with the path to `audit/INVENTORY.md`.

```
subagent_type: debugger
description: Reproduce P0-<NNN> — <short title>
prompt: |
  You are reproducing **P0-<NNN>** from audit/REPORT.md for the application
  in <INVENTORY_PATH>. You do not fix and you change no tracked file: you
  reproduce, to confirm the P0 is real, not theoretical.

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

  4. CAUSE — describe in 1-2 sentences why the bug occurs (root cause,
     not symptom), with the file:line it sits at.

  5. VERIFY — if you can run the reproducer in a sandbox, run it. Show
     output. Otherwise, describe exactly what to run.

  6. PREVENT — propose a failing test that would have caught this bug in
     CI. Save to audit/repro/P0-<NNN>-test.md.

  RULES:
  - A cause is named only after a reproducer you ran (step 3); until
    then it is labelled INFERRED.
  - 3+ failed reproductions = mark as "theoretical, not reproduced" and
    de-escalate to P1 with note in the report.
  - The repro report carries its evidence (command output,
    request/response); a status without it is THEORETICAL.

  Output: audit/repro/P0-<NNN>.md with:
    - status: REPRODUCED / NOT_REPRODUCED / THEORETICAL
    - reproducer (commands/payload)
    - root cause (1-2 sentences)
    - proposed failing test
    - evidence (logs, output, screenshots)
```
