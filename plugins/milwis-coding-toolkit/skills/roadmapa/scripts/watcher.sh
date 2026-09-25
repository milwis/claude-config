#!/bin/bash
# Watcher of the queue: after every issue it clears the lead's context and starts the next
# cycle by typing into the lead's tmux pane, exactly as the owner would (/clear, then the start prompt).
# Started by `kolejka.sh start` in the second window of the tmux session, under caffeinate.
#
# Flags written by the LEAD in $K (the watcher never guesses the lead's state from the screen):
#   rotuj  — issue finished (merged, deferred or closed), start the next cycle
#   pusto  — no open bug in the queue, wait $IDLE_MIN and look again
#   stop   — stop condition, content = reason; the watcher notifies and exits
# plus tura-koniec from the Stop hook. A flag counts only together with tura-koniec, so the watcher
# never clears a lead that is still working.
# Owner's controls: $K/zatrzymaj (or `kolejka.sh stop`) = finish the current issue, then exit.
# Weekly limit: before every new issue the watcher reads ~/.claude/usage/limit-tygodniowy.json (written by the
# owner's status line — the only place Claude Code exposes the weekly usage) and stops at >= LIMIT_TYG percent.
# The running issue is always finished; a missing or stale reading also stops (fail closed). LIMIT_TYG=100 = off.
#   watcher.sh <config.env> [--bez-cyklu]   --bez-cyklu: attach to a running lead without sending a new cycle
# Flag names must differ in more than case — macOS file systems are case-insensitive (`STOP` = `stop`).
set -uo pipefail
# shellcheck disable=SC1090
. "$1"
cd "$K" || exit 1

log() { echo "$(date '+%F %T') $*" >> "$K/watcher.log"; }
powiadom() {
  log "POWIADOMIENIE: $1"
  osascript -e "display notification \"${1//\"/\'}\" with title \"Kolejka roadmapa\"" 2>/dev/null
}
wyslij() { tmux send-keys -t "$SESJA:0" -l "$1"; sleep 1; tmux send-keys -t "$SESJA:0" Enter; }
nowy_cykl() {
  rm -f rotuj pusto
  wyslij "/clear"
  sleep 5
  rm -f tura-koniec
  wyslij "$(cat start-prompt.txt)"
  STALL_ZGLOSZONY=0
  log "cykl: start (następne issue: $("$SKRYPTY/wybierz-issue.sh" "$REPO" 2>/dev/null || echo '?'))"
}
zakoncz() { powiadom "$1"; log "watcher: koniec"; exit 0; }
LIMIT_TYG="${LIMIT_TYG:-92}"
# The only place a new issue starts: every path to nowy_cykl goes through here.
nastepny_cykl() {
  local powod
  if powod=$("$SKRYPTY/limit-tygodniowy.sh" "$LIMIT_TYG"); then
    zakoncz "Kolejka zatrzymana: $powod. Bieżące issue dokończone. Start mimo limitu: kolejka.sh start --limit 100"
  fi
  nowy_cykl
}
# Transcripts of every session in the repo, including subagents — any write means someone is working.
PROJ="$HOME/.claude/projects/$(echo "$REPO" | sed 's#[/.]#-#g')"
aktywnosc_w_ciagu() { find "$PROJ" -name '*.jsonl' -mmin "-$1" 2>/dev/null | head -1 | grep -q .; }

log "watcher: start (sesja $SESJA, repo $REPO)"
if [ "${2:-}" = "--bez-cyklu" ]; then
  log "watcher: dołączam do pracującego lidera (bez nowego cyklu), limit tygodniowy $LIMIT_TYG%"
else
  sleep 10          # let the claude UI come up before typing
  nastepny_cykl
fi
BEZ_FLAGI=0
STALL_ZGLOSZONY=0

while sleep 20; do
  tmux has-session -t "$SESJA" 2>/dev/null || { log "sesja tmux zniknęła"; exit 1; }

  if [ ! -f tura-koniec ]; then
    # The lead is working (or hung). A subagent on a Large issue may run for hours — only notify.
    if [ "$STALL_ZGLOSZONY" = 0 ] && ! aktywnosc_w_ciagu "$STALL_MIN"; then
      powiadom "Brak aktywności od $STALL_MIN min — sprawdź sesję: tmux attach -t $SESJA"
      STALL_ZGLOSZONY=1
    fi
    continue
  fi

  if [ -f stop ]; then zakoncz "Lider zatrzymał kolejkę: $(cat stop)"; fi
  if [ -f zatrzymaj ] || [ -f "$HOME/.claude/relay-state/STOP-roadmapa" ]; then
    [ -f rotuj ] || [ -f pusto ] && zakoncz "Kolejka zatrzymana przez właściciela (kolejka.sh stop)."
  fi

  if [ -f rotuj ]; then
    BEZ_FLAGI=0
    log "cykl: koniec issue #$(grep '^| [0-9]' "$REPO/$LEDGER" 2>/dev/null | tail -1 | cut -d'|' -f4 | tr -d ' #')"
    nastepny_cykl
  elif [ -f pusto ]; then
    KOLEJKA_PUSTO_POWOD=$(head -c 200 pusto)
    [ -n "$KOLEJKA_PUSTO_POWOD" ] && powiadom "Kolejka: $KOLEJKA_PUSTO_POWOD"
    BEZ_FLAGI=0
    log "kolejka pusta — czekam $IDLE_MIN min${KOLEJKA_PUSTO_POWOD:+ ($KOLEJKA_PUSTO_POWOD)}"
    rm -f tura-koniec
    sleep $((IDLE_MIN * 60))
    nastepny_cykl
  else
    # Turn ended without a flag: the lead asked something, hit an error, or was interrupted.
    # Give it $GRACE_MIN (a background notification may wake it), then restart the cycle once;
    # the second time in a row means something systemic — stop and wait for the owner.
    WIEK=$(( $(date +%s) - $(cat tura-koniec) ))
    [ "$WIEK" -lt $((GRACE_MIN * 60)) ] && continue
    aktywnosc_w_ciagu "$GRACE_MIN" && continue
    BEZ_FLAGI=$((BEZ_FLAGI + 1))
    [ "$BEZ_FLAGI" -ge 2 ] && zakoncz "Lider drugi raz z rzędu skończył turę bez flagi — kolejka stoi, zajrzyj: tmux attach -t $SESJA"
    powiadom "Lider skończył turę bez flagi — restartuję cykl (odzysk przez w-toku)."
    nastepny_cykl
  fi
done
