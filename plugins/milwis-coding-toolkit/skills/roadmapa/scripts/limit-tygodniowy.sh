#!/bin/bash
# Weekly-limit gate of the queue.   limit-tygodniowy.sh <limit-percent>
# Exit 0 + reason on stdout  = do NOT start a new issue (limit reached, or the reading is missing/stale/unreadable).
# Exit 1 + reading on stdout = below the limit, go on.
# The reading comes from ~/.claude/usage/limit-tygodniowy.json, written by the owner's status line — the only place
# Claude Code exposes the weekly usage (`rate_limits.seven_day`). Fail closed: no fresh reading = no new issue.
# A limit of 100 or more switches the gate off.
LIMIT="${1:-90}"
PLIK="${KOLEJKA_PLIK_LIMITU:-$HOME/.claude/usage/limit-tygodniowy.json}"
MAX_WIEK_S="${KOLEJKA_LIMIT_MAX_WIEK_S:-3600}"

[[ "$LIMIT" =~ ^[0-9]+$ ]] || { echo "nieprawidłowy limit tygodniowy: $LIMIT"; exit 0; }
[ "$LIMIT" -ge 100 ] && { echo "limit tygodniowy wyłączony"; exit 1; }
[ -f "$PLIK" ] || { echo "brak odczytu limitu tygodniowego ($PLIK) — status line go nie zapisał"; exit 0; }

# `|`, not a tab: tab is IFS whitespace, so an empty first field would collapse and shift the others.
IFS='|' read -r PCT TS RESET < <(jq -r '[(.used_percentage // "" | tostring), (.ts // 0 | tostring), (.resets_at // "" | tostring)] | join("|")' "$PLIK" 2>/dev/null)
[[ "$TS" =~ ^[0-9]+$ ]] || TS=0
WIEK=$(( $(date +%s) - TS ))
[ "$WIEK" -gt "$MAX_WIEK_S" ] && { echo "odczyt limitu tygodniowego sprzed $((WIEK / 60)) min — nieaktualny"; exit 0; }
PCT="${PCT%.*}"
[[ "$PCT" =~ ^[0-9]+$ ]] || { echo "nieczytelny odczyt limitu tygodniowego ($PLIK)"; exit 0; }
[[ "$RESET" =~ ^[0-9]+$ ]] && RESET=" (reset: $(date -r "$RESET" '+%a %d.%m %H:%M'))" || RESET=""

if [ "$PCT" -ge "$LIMIT" ]; then
  echo "limit tygodniowy ${PCT}% ≥ ${LIMIT}%${RESET}"
  exit 0
fi
echo "limit tygodniowy ${PCT}% < ${LIMIT}%${RESET}"
exit 1
