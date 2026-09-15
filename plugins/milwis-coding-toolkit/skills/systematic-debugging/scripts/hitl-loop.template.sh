#!/usr/bin/env bash
# Human-in-the-loop reproduction loop — last resort when the repro needs a
# human action the agent cannot drive (a physical device, an external portal,
# a browser tool recorded as BLOCKED in docs/VERIFICATION_ENV.md).
# Copy this file, edit the steps between the markers, run it; the user follows
# the prompts in their terminal and the captured answers are printed at the
# end as KEY=VALUE for the agent to parse.
#
#   step "<instruction>"        show instruction, wait for Enter
#   capture VAR "<question>"    show question, read the answer into VAR
#
# `capture` echoes its value back, so capture OBSERVATIONS only; leave signing
# in and anything secret as a `step`.

set -euo pipefail

step() {
  printf '\n>>> %s\n' "$1"
  read -r -p "    [Enter when done] " _
}

capture() {
  local var="$1" question="$2" answer
  printf '\n>>> %s\n' "$question"
  read -r -p "    > " answer
  printf -v "$var" '%s' "$answer"
}

# --- edit below ---------------------------------------------------------

step "Open the app at http://localhost:8080 and sign in as the test user."

capture ERRORED "Click 'Export'. Did it throw an error? (y/n)"

capture ERROR_MSG "Paste the exact error message (or 'none'):"

# --- edit above ---------------------------------------------------------

printf '\n--- Captured ---\n'
printf 'ERRORED=%s\n' "$ERRORED"
printf 'ERROR_MSG=%s\n' "$ERROR_MSG"
