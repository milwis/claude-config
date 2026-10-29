#!/bin/bash
# The issue queue (roadmapa) — owner's control script. Rules for the lead: ../references/cykl-lidera.md
#
#   kolejka.sh start  [repo] [--issues 812,815 | --parasol 1875] [--limit 92] [--okno 5]
#                              start the lead in tmux (a new claude session per issue) + the watcher (owner's terminal); without --issues: the bug
#                              backlog by priority, no end; --parasol: the portions of that umbrella in its `## Porcje` order,
#                              strictly (a deferred portion stops the queue); a portion whose body names a plan on main
#                              skips triage (porcje-parasola.sh, cykl-lidera.md step 4); --limit: stop before a new issue at this weekly usage %
#                              (default 92, 100 = off); --okno: in the last N hours before the weekly reset the limit
#                              is lifted, and a queue stopped by the limit pauses until then (default 5, 0 = off)
#   kolejka.sh stop   [repo]   finish the current issue, then stop
#   kolejka.sh status [repo]   where the queue stands
#   kolejka.sh lista  [repo]   the queue in the order it will be taken (skips with reasons on stderr)
#   kolejka.sh watcher [repo] [--limit 92] [--okno 5]   replace the watcher of a running queue without a new cycle
#                              (after a toolkit update); the lead keeps working
#
# Configuration (environment, read at start):
#   KOLEJKA_SESJA (kolejka), KOLEJKA_LEDGER (docs/plans/kolejka-ledger.md), KOLEJKA_MAIN (main),
#   KOLEJKA_ETYKIETA_ZROBIONE (status:zrobione-lokalnie), KOLEJKA_ETYKIETA_RECZNA (weryfikacja:reczna — merged
#   issues whose surface verification ended BLOCKED, for the owner to check by hand), KOLEJKA_IDLE_MIN (30), KOLEJKA_STALL_MIN (90),
#   KOLEJKA_GRACE_MIN (10), KOLEJKA_MODEL_LIDER (opus — the lead implements), KOLEJKA_MODEL_TRIAGE (opus),
#   KOLEJKA_EFFORT (high), KOLEJKA_LIMIT_TYG (92), KOLEJKA_OKNO_H (5),
#   KOLEJKA_AUTOCOMPACT (350000 — CLAUDE_CODE_AUTO_COMPACT_WINDOW of the queue processes only; the owner's interactive
#   sessions keep their own value),
#   KOLEJKA_TYPY / KOLEJKA_ZATWIERDZONY / KOLEJKA_POMIJAJ / KOLEJKA_ODROCZENIA (backlog filter, see wybierz-issue.sh),
#   KOLEJKA_STATUS_ISSUE (number of the closed status issue the watcher writes for the dashboard; unset = found
#   by its title, set empty = off), KOLEJKA_DEPLOY_WORKFLOW (workflow whose last successful run = the last deploy, for
#   the dashboard's "fixed since deploy"; unset = deploy.yml when the repo has it, set empty = off)
set -euo pipefail

SKRYPTY="$(cd "$(dirname "$0")" && pwd)"
INSTRUKCJA="$(cd "$SKRYPTY/.." && pwd)/references/cykl-lidera.md"
CMD="${1:-}"; shift || true
REPO_ARG="."; LISTA=""; PARASOL=""; LIMIT_ARG=""; OKNO_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issues) LISTA="$(tr -d ' #' <<<"${2:?--issues wymaga listy numerów, np. 812,815}")"; shift 2 ;;
    --parasol) PARASOL="$(tr -d ' #' <<<"${2:?--parasol wymaga numeru issue parasolowego, np. 1875}")"; shift 2 ;;
    --limit) LIMIT_ARG="${2:?--limit wymaga procentu, np. 92}"; shift 2 ;;
    --okno) OKNO_ARG="${2:?--okno wymaga liczby godzin, np. 5}"; shift 2 ;;
    *) REPO_ARG="$1"; shift ;;
  esac
done
REPO="$(cd "$REPO_ARG" && git rev-parse --show-toplevel)"
K="$REPO/.claude/tmp/kolejka"
SESJA="${KOLEJKA_SESJA:-kolejka}"
cfg() { (. "$K/config.env" 2>/dev/null; eval "echo \"\${$1:-$2}\""); }
LIMIT_TYG="${LIMIT_ARG:-${KOLEJKA_LIMIT_TYG:-92}}"
[[ "$LIMIT_TYG" =~ ^[0-9]+$ ]] || { echo "--limit: liczba procent, np. 92 (100 = bez limitu)"; exit 1; }
OKNO_H="${OKNO_ARG:-${KOLEJKA_OKNO_H:-5}}"
[[ "$OKNO_H" =~ ^[0-9]+$ ]] || { echo "--okno: liczba godzin przed resetem, np. 5 (0 = bez okna)"; exit 1; }
TYTUL_STATUSU="Kolejka — status (nie ruszać)"
# The closed status issue (see watcher.sh): KOLEJKA_STATUS_ISSUE if set (empty = off), else found by exact title.
status_issue() {
  if [ -n "${KOLEJKA_STATUS_ISSUE+x}" ]; then echo "$KOLEJKA_STATUS_ISSUE"; return; fi
  (cd "$REPO" && gh issue list --state closed --search "\"$TYTUL_STATUSU\" in:title" --json number,title \
    --jq ".[] | select(.title == \"$TYTUL_STATUSU\") | .number" 2>/dev/null | grep -xE '[0-9]+' | head -1) || true
}
deploy_workflow() {
  if [ -n "${KOLEJKA_DEPLOY_WORKFLOW+x}" ]; then echo "$KOLEJKA_DEPLOY_WORKFLOW"
  elif [ -f "$REPO/.github/workflows/deploy.yml" ]; then echo deploy.yml; fi
}
numer_statusu() { local s; s=$(cfg STATUS_ISSUE ""); if [ -n "$s" ]; then echo "#$s"; else echo "wyłączone"; fi; }

case "$CMD" in
start)
  for t in tmux jq gh claude caffeinate; do command -v "$t" >/dev/null || { echo "Brak narzędzia: $t"; exit 1; }; done
  gh auth status >/dev/null 2>&1 || { echo "gh nie jest zalogowany (gh auth login)"; exit 1; }
  [ -z "$LISTA" ] || [[ "$LISTA" =~ ^[0-9]+(,[0-9]+)*$ ]] || { echo "--issues: same numery po przecinku, np. 812,815"; exit 1; }
  [ -z "$PARASOL" ] || [[ "$PARASOL" =~ ^[0-9]+$ ]] || { echo "--parasol: jeden numer issue parasolowego, np. 1875"; exit 1; }
  [ -z "$PARASOL" ] || [ -z "$LISTA" ] || { echo "--issues albo --parasol, nie oba"; exit 1; }
  MAIN="${KOLEJKA_MAIN:-main}"
  [ "$(git -C "$REPO" branch --show-current)" = "$MAIN" ] || { echo "Drzewo główne nie stoi na $MAIN"; exit 1; }
  BRUD=$(git -C "$REPO" status --short --untracked-files=no)
  [ -z "$BRUD" ] || { echo "Drzewo główne ma niezacommitowane zmiany — lider scala w tym drzewie:"; echo "$BRUD"; exit 1; }
  tmux has-session -t "$SESJA" 2>/dev/null && { echo "Sesja tmux '$SESJA' już działa (tmux attach -t $SESJA)"; exit 1; }
  if POWOD=$("$SKRYPTY/limit-tygodniowy.sh" "$LIMIT_TYG" "$OKNO_H"); then
    echo "Nie startuję: $POWOD. Start mimo limitu: kolejka.sh start --limit 100"; exit 1
  fi

  AUTOCOMPACT="${KOLEJKA_AUTOCOMPACT:-350000}"
  if ! [[ "$AUTOCOMPACT" =~ ^[0-9]+$ ]] || [ "$AUTOCOMPACT" -lt 100000 ] || [ "$AUTOCOMPACT" -gt 1000000 ]; then
    echo "KOLEJKA_AUTOCOMPACT=$AUTOCOMPACT poza zakresem 100000–1000000 (CLAUDE_CODE_AUTO_COMPACT_WINDOW)."; exit 1
  fi

  mkdir -p "$K"
  rm -f "$K"/{rotuj,pusto,stop,zatrzymaj,tura-koniec,blad-api,pauza,start-prompt.txt,parasol.tsv}
  # The umbrella's portions, resolved once: the list in its order and, per portion, the plan that replaces triage.
  if [ -n "$PARASOL" ]; then
    "$SKRYPTY/porcje-parasola.sh" "$REPO" "$PARASOL" "$MAIN" > "$K/parasol.tsv" || { rm -f "$K/parasol.tsv"; exit 1; }
    LISTA=$(cut -f1 "$K/parasol.tsv" | paste -sd, -)
  fi
  cat > "$K/config.env" <<EOF
REPO="$REPO"
K="$K"
SKRYPTY="$SKRYPTY"
INSTRUKCJA="$INSTRUKCJA"
SESJA="$SESJA"
MAIN="$MAIN"
LEDGER="${KOLEJKA_LEDGER:-docs/plans/kolejka-ledger.md}"
WT="$REPO/.claude/worktrees/kolejka"
ETYKIETA_ZROBIONE="${KOLEJKA_ETYKIETA_ZROBIONE:-status:zrobione-lokalnie}"
ETYKIETA_RECZNA="${KOLEJKA_ETYKIETA_RECZNA:-weryfikacja:reczna}"
MODEL_LIDER="${KOLEJKA_MODEL_LIDER:-opus}"
MODEL_TRIAGE="${KOLEJKA_MODEL_TRIAGE:-opus}"
EFFORT="${KOLEJKA_EFFORT:-high}"
AUTOCOMPACT="$AUTOCOMPACT"
IDLE_MIN="${KOLEJKA_IDLE_MIN:-30}"
STALL_MIN="${KOLEJKA_STALL_MIN:-90}"
GRACE_MIN="${KOLEJKA_GRACE_MIN:-10}"
LIMIT_TYG="$LIMIT_TYG"
OKNO_H="$OKNO_H"
KOLEJKA_LISTA="$LISTA"
KOLEJKA_PARASOL="$PARASOL"
KOLEJKA_TYPY=""${KOLEJKA_TYPY:-typ:bug,typ:point-fix,typ:structural,typ:test,bug}"
KOLEJKA_ZATWIERDZONY="${KOLEJKA_ZATWIERDZONY:-pomysl:zatwierdzony}"
KOLEJKA_POMIJAJ="${KOLEJKA_POMIJAJ:-enhancement,new_idea,request,typ:analysis,pomysl:do-analizy,pomysl:odlozony,status:odlozone,status:do-scalenia,status:zrobione-lokalnie,tor:remediacja-danych,security-audit-tracker}"
KOLEJKA_ODROCZENIA="${KOLEJKA_ODROCZENIA:-docs/plans docs/runbook}"
STATUS_ISSUE="$(status_issue)"
DEPLOY_WORKFLOW="$(deploy_workflow)"
EOF
  # Hooks live only in this file, passed with --settings: no other session in the repo sees them. Its env overrides
  # the same variable from the owner's user settings (docs: settings, env — the higher-precedence file wins per
  # variable; --settings sits above user settings). The window: the lead implements and compacts (v1.7.2). POMIAR
  # (2026-10-26, KonkretnyTMS, 32 issues): the trigger fires at window − ~31k, the summary is ~4k, the lead starts at
  # ~93k; a lead that grows 382–481k per issue compacts 2.2–2.8× at 300k and 1.5–1.9× at 350k, at the same cost (±10%).
  jq -n --arg ss "$SKRYPTY/hook-session-start.sh" --arg st "$SKRYPTY/hook-stop.sh" \
    --arg sf "$SKRYPTY/hook-stop-failure.sh" --arg pt "$SKRYPTY/hook-pre-tool.sh" --arg okno "$AUTOCOMPACT" '{
    env: {CLAUDE_CODE_AUTO_COMPACT_WINDOW: $okno}, hooks: {
    SessionStart: [{matcher: "startup|clear|compact", hooks: [{type: "command", command: $ss}]}],
    PreToolUse: [{matcher: "Bash|Write|Edit|MultiEdit|NotebookEdit", hooks: [{type: "command", command: $pt}]}],
    Stop: [{hooks: [{type: "command", command: $st}]}],
    StopFailure: [{hooks: [{type: "command", command: $sf}]}]}}' > "$K/settings.json"
  # The owner's authorisation. lider.sh passes it verbatim as the first message of every lead session;
  # the lead quotes it in ledger row 0. One line.
  if [ -n "$PARASOL" ]; then ZRODLO="weź następną porcję parasola #$PARASOL z listy $LISTA (ściśle w tej kolejności; porcja z planem w \$K/parasol.tsv idzie ścieżką planu, bez triage)"
  elif [ -n "$LISTA" ]; then ZRODLO="weź następne issue z listy $LISTA (w tej kolejności)"
  else ZRODLO="weź jedno issue z backlogu wg priorytetu P0→P3: bugi, braki testów i pomysły zatwierdzone przez właściciela (pomysl:zatwierdzony); pomysły bez tej etykiety pomijasz"; fi
  echo "Kolejka roadmapa: $ZRODLO, rozwiąż je sam w worktree kolejki (triage, recenzja i weryfikacja to świeże podagenty), scal lokalnie do $MAIN przez scal.sh (bramka, --no-ff, znacznik [roadmapa]) i zamknij issue na GitHubie. Bez push, bez deployu. Model triage: ${KOLEJKA_MODEL_TRIAGE:-opus}. Ścieżki i ustawienia wyłącznie ze zmiennych po . .claude/tmp/kolejka/config.env. Zasady: $INSTRUKCJA" > "$K/start-prompt.txt"

  # One claude process per issue: the watcher replaces it (respawn-pane) after every issue.
  tmux new-session -d -s "$SESJA" -n lider -x 220 -y 50 -c "$REPO" "'$SKRYPTY/lider.sh' '$K/config.env'"
  tmux set-option -w -t "$SESJA:0" remain-on-exit on
  tmux new-window -d -t "$SESJA" -n watcher -c "$REPO" \
    "caffeinate -ims '$SKRYPTY/watcher.sh' '$K/config.env'; echo 'watcher zakończony — Enter zamyka okno'; read"
  echo "Kolejka ruszyła. Podgląd: tmux attach -t $SESJA  (Ctrl-b d = odłącz, Ctrl-b n = okno watchera)"
  [ -z "$PARASOL" ] || awk -F'\t' -v p="$PARASOL" 'NR == 1 {print "Porcje parasola #" p ":"}
    {print "  #" $1 " — " ($2 == "-" ? "triage (porcja nie wskazuje planu na main)" : "plan " $2 ", bez triage")}' "$K/parasol.tsv"
  echo "Pierwsze issue: $("$SKRYPTY/wybierz-issue.sh" "$REPO" 2>/dev/null || true)"
  echo "$("$SKRYPTY/limit-tygodniowy.sh" "$LIMIT_TYG" "$OKNO_H") — po przekroczeniu kolejka czeka na okno $OKNO_H h przed resetem"
  ;;
watcher)
  tmux has-session -t "$SESJA" 2>/dev/null || { echo "Sesja tmux '$SESJA' nie działa"; exit 1; }
  [ -f "$K/config.env" ] || { echo "Brak $K/config.env"; exit 1; }
  # A queue started before the limit/window/status issue existed lacks the key in its config: add it (or replace
  # on the flag). The status issue is looked up only when missing.
  STATUS_ISSUE=""; grep -q '^STATUS_ISSUE=' "$K/config.env" || STATUS_ISSUE="$(status_issue)"
  for PARA in "LIMIT_TYG:$LIMIT_TYG:$LIMIT_ARG" "OKNO_H:$OKNO_H:$OKNO_ARG" "STATUS_ISSUE:$STATUS_ISSUE:" \
      "DEPLOY_WORKFLOW:$(deploy_workflow):${KOLEJKA_DEPLOY_WORKFLOW:-}"; do
    IFS=: read -r KLUCZ WART ARG <<<"$PARA"
    if grep -q "^$KLUCZ=" "$K/config.env"; then
      [ -n "$ARG" ] && sed -i '' "s/^$KLUCZ=.*/$KLUCZ=\"$WART\"/" "$K/config.env"
    else
      echo "$KLUCZ=\"$WART\"" >> "$K/config.env"
    fi
  done
  # A replacement, not a stop: the old watcher's hard-stop trap must not write "zatrzymana" over the new one.
  touch "$K/podmiana-watchera"
  tmux kill-window -t "$SESJA:watcher" 2>/dev/null || true
  tmux new-window -d -t "$SESJA" -n watcher -c "$REPO" \
    "caffeinate -ims '$SKRYPTY/watcher.sh' '$K/config.env' --bez-cyklu; echo 'watcher zakończony — Enter zamyka okno'; read"
  echo "Watcher podmieniony (lider pracuje dalej). Limit tygodniowy: $(cfg LIMIT_TYG 92)%, okno przed resetem: $(cfg OKNO_H 5) h, issue statusu: $(numer_statusu)"
  ;;
stop)
  mkdir -p "$K" && touch "$K/zatrzymaj"
  echo "STOP ustawiony — lider dokończy bieżące issue, potem watcher się zatrzyma."
  echo "Twardy stop natychmiast: tmux kill-session -t $SESJA  (bieżące issue podejmie odzysk przy następnym starcie)"
  ;;
status)
  tmux has-session -t "$SESJA" 2>/dev/null && echo "sesja: działa ($SESJA)" || echo "sesja: nie działa"
  L=$(cfg KOLEJKA_LISTA ""); P=$(cfg KOLEJKA_PARASOL "")
  if [ -n "$P" ]; then echo "źródło: parasol #$P, porcje $L"; elif [ -n "$L" ]; then echo "źródło: lista $L"; else echo "źródło: backlog bugów P0→P3"; fi
  [ -f "$K/w-toku" ] && echo "w toku: #$(cat "$K/w-toku")" || echo "w toku: -"
  echo "$("$SKRYPTY/limit-tygodniowy.sh" "$(cfg LIMIT_TYG 92)" "$(cfg OKNO_H 5)")"
  echo "issue statusu (dashboard): $(numer_statusu)"
  for f in zatrzymaj stop pusto rotuj pauza blad-api; do [ -f "$K/$f" ] && echo "flaga: $f $(cat "$K/$f")"; done
  LEDGER=$(cfg LEDGER docs/plans/kolejka-ledger.md); MAIN=$(cfg MAIN main)
  echo "--- ledger ($LEDGER), ostatnie wiersze:"; grep '^| [0-9]' "$REPO/$LEDGER" 2>/dev/null | tail -5 || true
  echo "--- watcher.log:"; tail -5 "$K/watcher.log" 2>/dev/null || true
  echo "--- scalone lokalnie, niewypchnięte:"; git -C "$REPO" log --oneline --merges --grep '\[roadmapa\]' "origin/$MAIN..$MAIN" | head -20
  R=$(cfg ETYKIETA_RECZNA weryfikacja:reczna)
  echo "--- do ręcznego sprawdzenia (etykieta $R; zdejmij ją po sprawdzeniu):"
  (cd "$REPO" && gh issue list --state all --label "$R" --json number,title -q '.[] | "#\(.number) \(.title)"' 2>/dev/null) || echo "(gh niedostępne)"
  ;;
lista)
  "$SKRYPTY/wybierz-issue.sh" --lista "$REPO"
  ;;
*)
  sed -n '2,20p' "$0"; exit 1 ;;
esac
