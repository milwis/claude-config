#!/bin/bash
# Watcher of the queue: after every issue it ends the lead's claude process (/exit) and starts a new one
# in the same tmux pane (lider.sh, the start prompt as its first message) — one issue = one session, each
# visible on its own in /resume and in Remote Control. Replaced /clear in v1.5.35: /clear kept one process
# (one Remote Control session for the whole night) and the plugin version from the moment of start.
# Started by `kolejka.sh start` in the second window of the tmux session, under `caffeinate -ims`: the system
# never sleeps while the watcher lives (pauses included), the display does — no -d/-u (owner, 2026-09-26).
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
# Window before the reset (OKNO_H, default 5 h): the gate is open then. Stopped by the limit earlier in the week,
# the watcher does not exit but pauses until the window opens. The limit used up in the middle of an issue
# (StopFailure rate_limit -> blad-api) = wait for the reset, then a new lead resumes the same issue via w-toku.
# Status issue (STATUS_ISSUE in config.env, empty = off): a closed issue whose body the watcher replaces with
# the queue's state (one sentence + a json block) — the owner's dashboard reads it through a read-only connector.
# Written on every state change and at least every 5 min (KOLEJKA_STATUS_CO_S), pauses included; a gh error
# (no network) never stops the watcher and is logged only when ok/error flips. With DEPLOY_WORKFLOW set, the json
# also carries `deploy`: the commit time of the last successful deploy run, so the dashboard can count issues fixed since.
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
martwy() { [ "$(tmux display-message -p -t "$SESJA:0" '#{pane_dead}' 2>/dev/null)" = 1 ]; }
nowy_cykl() {
  rm -f rotuj pusto
  # remain-on-exit keeps the pane (and its index 0) after claude exits, so respawn has a target.
  tmux set-option -w -t "$SESJA:0" remain-on-exit on
  # /exit lets claude close its Remote Control session cleanly; -k below kills whatever is left.
  if ! martwy; then
    wyslij "/exit"
    for _ in $(seq 30); do martwy && break; sleep 1; done
  fi
  rm -f tura-koniec blad-api
  tmux respawn-pane -k -t "$SESJA:0" -c "$REPO" "'$SKRYPTY/lider.sh' '$K/config.env'"
  STALL_ZGLOSZONY=0
  ST_OD=$(date +%s)
  status_github pracuje
  log "cykl: start (następne issue: $("$SKRYPTY/wybierz-issue.sh" "$REPO" 2>/dev/null || echo '?'))"
}
zakoncz() { rm -f pauza; status_github zatrzymana "$1"; powiadom "$1"; log "watcher: koniec"; exit 0; }
LIMIT_TYG="${LIMIT_TYG:-90}"
OKNO_H="${OKNO_H:-5}"
PLIK_LIMITU="${KOLEJKA_PLIK_LIMITU:-$HOME/.claude/usage/limit-tygodniowy.json}"
odczyt() { v=$(jq -r ".$1 // empty" "$PLIK_LIMITU" 2>/dev/null); v="${v%.*}"; [[ "$v" =~ ^[0-9]+$ ]] && echo "$v"; }

STATUS_ISSUE="${STATUS_ISSUE:-}"
STATUS_CO_S="${KOLEJKA_STATUS_CO_S:-300}"
WERSJA=$(jq -r '.version // empty' "$SKRYPTY/../../../.claude-plugin/plugin.json" 2>/dev/null)
ST_STAN=pracuje; ST_POWOD=""; ST_PAUZA_DO=""; ST_ISSUE=""; ST_ZAPIS=0; ST_WYNIK=""; ST_OD=$(date +%s)
nr_w_toku() { tr -dc 0-9 2>/dev/null < w-toku; }
DEPLOY_WORKFLOW="${DEPLOY_WORKFLOW:-}"; ST_DEPLOY=""
# Last deploy = the head commit of the newest successful DEPLOY_WORKFLOW run (push to main -> Tests -> Deploy): an
# issue closed after that commit's time is fixed locally, not on the server yet. The commit time, not the run's
# start: a push lands minutes before its deploy run. Failures keep the last known value.
odczyt_deployu() {
  [ -n "$DEPLOY_WORKFLOW" ] || return 0
  local run sha t=""
  run=$( ( perl -e 'alarm shift; exec @ARGV' 30 gh run list --workflow "$DEPLOY_WORKFLOW" --status success -L 1 \
    --json headSha,createdAt -q '.[0] | "\(.headSha) \(.createdAt)"' ) 2>/dev/null) || return 0
  sha="${run%% *}"
  [[ "$sha" =~ ^[0-9a-f]{7,40}$ ]] && t=$(git -C "$REPO" show -s --format=%ct "$sha" 2>/dev/null)
  [[ "$t" =~ ^[0-9]+$ ]] || t=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "${run#* }" +%s 2>/dev/null)
  [[ "$t" =~ ^[0-9]+$ ]] && ST_DEPLOY="$t"
  return 0
}
# status_github <stan> [powód] [pauza_do epoch]   stan: pracuje | pauza-okno | pauza-limit | pusto | zatrzymana
status_github() {
  [ -n "$STATUS_ISSUE" ] || return 0
  ST_STAN="$1"; ST_POWOD="${2:-}"; ST_PAUZA_DO="${3:-}"; ST_ISSUE=$(nr_w_toku); ST_ZAPIS=$(date +%s)
  odczyt_deployu
  local zdanie do_kiedy
  do_kiedy=$([ -n "$ST_PAUZA_DO" ] && date -r "$ST_PAUZA_DO" '+%d.%m %H:%M')
  case "$1" in
    pracuje) zdanie="Kolejka pracuje${ST_ISSUE:+ nad #$ST_ISSUE} od $(date -r "$ST_OD" '+%d.%m %H:%M')." ;;
    pusto) zdanie="Kolejka pusta — następne sprawdzenie $do_kiedy.${ST_POWOD:+ $ST_POWOD}" ;;
    zatrzymana) zdanie="Kolejka zatrzymana: $ST_POWOD" ;;
    *) zdanie="Kolejka wstrzymana do $do_kiedy — $ST_POWOD" ;;
  esac
  {
    echo "$zdanie"; echo
    echo "Issue techniczne dashboardu kolejki roadmapa: treść nadpisuje watcher (\`scripts/watcher.sh\`) co ≤ 5 min. Nie edytuj, nie otwieraj, nie etykietuj. Zapis: $(date -r "$ST_ZAPIS" '+%d.%m %H:%M:%S')."
    echo; echo '```json'
    jq -n --arg stan "$1" --arg issue "$ST_ISSUE" --arg od "$ST_OD" --arg pauza_do "$ST_PAUZA_DO" --arg powod "$ST_POWOD" \
      --arg pct "$(odczyt used_percentage)" --arg reset "$(odczyt resets_at)" --arg ts "$ST_ZAPIS" --arg wersja "$WERSJA" --arg deploy "$ST_DEPLOY" \
      'def n: tonumber? // null; {stan: $stan, issue: ($issue | n), od: ($od | n), pauza_do: ($pauza_do | n),
        powod: $powod, limit_pct: ($pct | n), reset: ($reset | n), ts: ($ts | n), deploy: ($deploy | n),
        wersja: (if $wersja == "" then null else $wersja end)}'
    echo '```'
  } > status-github.md
  # perl alarm = a timeout macOS has without coreutils; a hung gh must not hold the loop. The subshell keeps
  # bash's "Alarm clock" job report out of the watcher window.
  if ( perl -e 'alarm shift; exec @ARGV' 30 gh issue edit "$STATUS_ISSUE" --body-file status-github.md >/dev/null 2>status-github.err
       r=$?; [ "$r" = 142 ] && echo "timeout 30 s" >> status-github.err; exit "$r" ) 2>/dev/null; then
    [ "$ST_WYNIK" = ok ] || log "status GitHub (#$STATUS_ISSUE): zapis ok ($1)"
    ST_WYNIK=ok
  else
    [ "$ST_WYNIK" = blad ] || log "status GitHub (#$STATUS_ISSUE): błąd zapisu — $(head -c 200 status-github.err | tr '\n' ' ')"
    ST_WYNIK=blad
  fi
  return 0
}
# Heartbeat: the same state again after STATUS_CO_S, or at once when the lead writes a new w-toku.
status_puls() {
  [ -n "$STATUS_ISSUE" ] || return 0
  if [ $(( $(date +%s) - ST_ZAPIS )) -ge "$STATUS_CO_S" ] || [ "$(nr_w_toku)" != "$ST_ISSUE" ]; then
    status_github "$ST_STAN" "$ST_POWOD" "$ST_PAUZA_DO"
  fi
}
# Sleep until an epoch time; the owner's stop still works (checked every minute). $K/pauza is shown by `status`.
czekaj_do() {
  echo "do $(date -r "$1" '+%a %d.%m %H:%M') — $2" > pauza
  while [ "$(date +%s)" -lt "$1" ]; do
    [ -f zatrzymaj ] || [ -f "$HOME/.claude/relay-state/STOP-roadmapa" ] && zakoncz "Kolejka zatrzymana przez właściciela w trakcie pauzy (kolejka.sh stop)."
    sleep 60
    status_puls
  done
  rm -f pauza
}
# The only place a new issue starts: every path to nowy_cykl goes through here.
nastepny_cykl() {
  local powod reset start
  while powod=$("$SKRYPTY/limit-tygodniowy.sh" "$LIMIT_TYG" "$OKNO_H"); do
    reset=$(odczyt resets_at)
    start=$(( ${reset:-0} - OKNO_H * 3600 ))
    # Pause only with a known reset ahead and a window not yet open; otherwise (no reading, window off) stop.
    if [ -n "$reset" ] && [ "$OKNO_H" -gt 0 ] && [ "$start" -gt "$(date +%s)" ]; then
      powiadom "Kolejka wstrzymana: $powod. Wznowienie $(date -r "$start" '+%a %d.%m %H:%M') ($OKNO_H h przed resetem)."
      status_github pauza-okno "$powod" "$start"
      czekaj_do "$start" "okno przed resetem limitu tygodniowego"
      log "pauza: koniec, okno przed resetem otwarte"
      continue
    fi
    zakoncz "Kolejka zatrzymana: $powod. Bieżące issue dokończone. Start mimo limitu: kolejka.sh start --limit 100"
  done
  nowy_cykl
}
# Transcripts of every session in the repo, including subagents — any write means someone is working.
PROJ="$HOME/.claude/projects/$(echo "$REPO" | sed 's#[/.]#-#g')"
aktywnosc_w_ciagu() { find "$PROJ" -name '*.jsonl' -mmin "-$1" 2>/dev/null | head -1 | grep -q .; }

log "watcher: start (sesja $SESJA, repo $REPO)"
if [ "${2:-}" = "--bez-cyklu" ]; then
  log "watcher: dołączam do pracującego lidera (bez nowego cyklu), limit tygodniowy $LIMIT_TYG%"
else
  # kolejka.sh start has already launched the first lead (lider.sh) after checking the limit.
  log "cykl: start (następne issue: $("$SKRYPTY/wybierz-issue.sh" "$REPO" 2>/dev/null || echo '?'))"
fi
# Attached to a running lead: the cycle started when it took the issue.
[ "${2:-}" = "--bez-cyklu" ] && [ -f w-toku ] && ST_OD=$(stat -f %m w-toku)
status_github pracuje
BEZ_FLAGI=0
STALL_ZGLOSZONY=0

while sleep 20; do
  tmux has-session -t "$SESJA" 2>/dev/null || { log "sesja tmux zniknęła"; status_github zatrzymana "sesja tmux zniknęła"; exit 1; }
  status_puls

  if martwy && [ ! -f tura-koniec ]; then
    # claude exited on its own (crash, owner's /exit): no Stop hook ran, so treat it as a turn without a flag.
    date +%s > tura-koniec
    log "lider: proces claude zakończył się poza cyklem"
  fi

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

  if [ "$(cat blad-api 2>/dev/null)" = rate_limit ]; then
    # The subscription limit ended the lead's turn mid-issue. Weekly one used up (>= 98% at the last reading)
    # = wait for the weekly reset; otherwise the 5-hour one — try again after IDLE_MIN. The new lead resumes
    # the same issue from w-toku, so the gate is skipped: the running issue is always finished, and right
    # after a reset the reading may still be the stale pre-reset one.
    rm -f blad-api
    PCT=$(odczyt used_percentage); RESET=$(odczyt resets_at); TERAZ=$(date +%s)
    if [ "${PCT:-0}" -ge 98 ] && [ -n "$RESET" ] && [ "$RESET" -gt "$TERAZ" ]; then
      CEL=$((RESET + 300)); POWOD="limit tygodniowy wyczerpany w trakcie issue"
    else
      CEL=$((TERAZ + IDLE_MIN * 60)); POWOD="limit API w trakcie issue (${PCT:-?}% tygodniowego — pewnie 5-godzinny)"
    fi
    powiadom "Kolejka: $POWOD — wznowienie tego samego issue $(date -r "$CEL" '+%a %d.%m %H:%M')."
    status_github pauza-limit "$POWOD" "$CEL"
    czekaj_do "$CEL" "$POWOD"
    BEZ_FLAGI=0
    log "pauza: koniec, wznawiam issue $(cat w-toku 2>/dev/null || echo '?') po limicie"
    nowy_cykl
  elif [ -f rotuj ]; then
    rm -f blad-api
    BEZ_FLAGI=0
    log "cykl: koniec issue #$(grep '^| [0-9]' "$REPO/$LEDGER" 2>/dev/null | tail -1 | cut -d'|' -f4 | tr -d ' #')"
    nastepny_cykl
  elif [ -f pusto ]; then
    KOLEJKA_PUSTO_POWOD=$(head -c 200 pusto)
    [ -n "$KOLEJKA_PUSTO_POWOD" ] && powiadom "Kolejka: $KOLEJKA_PUSTO_POWOD"
    BEZ_FLAGI=0
    log "kolejka pusta — czekam $IDLE_MIN min${KOLEJKA_PUSTO_POWOD:+ ($KOLEJKA_PUSTO_POWOD)}"
    rm -f tura-koniec
    # czekaj_do, not a bare sleep: the status heartbeat and the owner's stop keep working while idle.
    CEL=$(( $(date +%s) + IDLE_MIN * 60 ))
    status_github pusto "$KOLEJKA_PUSTO_POWOD" "$CEL"
    czekaj_do "$CEL" "kolejka pusta"
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
