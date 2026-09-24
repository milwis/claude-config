#!/bin/bash
# The issue queue (roadmapa) — owner's control script. Rules for the lead: ../references/cykl-lidera.md
#
#   kolejka.sh start  [repo] [--issues 812,815]   start the lead in tmux + the watcher (owner's terminal);
#                                                   without --issues: the bug backlog by priority, no end
#   kolejka.sh stop   [repo]   finish the current issue, then stop
#   kolejka.sh status [repo]   where the queue stands
#   kolejka.sh lista  [repo]   the queue in the order it will be taken (skips with reasons on stderr)
#
# Configuration (environment, read at start):
#   KOLEJKA_SESJA (kolejka), KOLEJKA_LEDGER (docs/plans/kolejka-ledger.md), KOLEJKA_MAIN (main),
#   KOLEJKA_ETYKIETA_ZROBIONE (status:zrobione-lokalnie), KOLEJKA_IDLE_MIN (30), KOLEJKA_STALL_MIN (90),
#   KOLEJKA_GRACE_MIN (10), KOLEJKA_MODEL_L2 (opus), KOLEJKA_MODEL_LIDER (session default),
#   KOLEJKA_TYPY / KOLEJKA_POMIJAJ / KOLEJKA_ODROCZENIA (backlog filter, see wybierz-issue.sh)
set -euo pipefail

SKRYPTY="$(cd "$(dirname "$0")" && pwd)"
INSTRUKCJA="$(cd "$SKRYPTY/.." && pwd)/references/cykl-lidera.md"
CMD="${1:-}"; shift || true
REPO_ARG="."; LISTA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issues) LISTA="$(tr -d ' #' <<<"${2:?--issues wymaga listy numerów, np. 812,815}")"; shift 2 ;;
    *) REPO_ARG="$1"; shift ;;
  esac
done
REPO="$(cd "$REPO_ARG" && git rev-parse --show-toplevel)"
K="$REPO/.claude/tmp/kolejka"
SESJA="${KOLEJKA_SESJA:-kolejka}"
cfg() { (. "$K/config.env" 2>/dev/null; eval "echo \"\${$1:-$2}\""); }

case "$CMD" in
start)
  for t in tmux jq gh claude caffeinate; do command -v "$t" >/dev/null || { echo "Brak narzędzia: $t"; exit 1; }; done
  gh auth status >/dev/null 2>&1 || { echo "gh nie jest zalogowany (gh auth login)"; exit 1; }
  [ -z "$LISTA" ] || [[ "$LISTA" =~ ^[0-9]+(,[0-9]+)*$ ]] || { echo "--issues: same numery po przecinku, np. 812,815"; exit 1; }
  MAIN="${KOLEJKA_MAIN:-main}"
  [ "$(git -C "$REPO" branch --show-current)" = "$MAIN" ] || { echo "Drzewo główne nie stoi na $MAIN"; exit 1; }
  BRUD=$(git -C "$REPO" status --short --untracked-files=no)
  [ -z "$BRUD" ] || { echo "Drzewo główne ma niezacommitowane zmiany — lider scala w tym drzewie:"; echo "$BRUD"; exit 1; }
  tmux has-session -t "$SESJA" 2>/dev/null && { echo "Sesja tmux '$SESJA' już działa (tmux attach -t $SESJA)"; exit 1; }

  mkdir -p "$K"
  rm -f "$K"/{rotuj,pusto,stop,zatrzymaj,tura-koniec,start-prompt.txt}
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
MODEL_L2="${KOLEJKA_MODEL_L2:-opus}"
IDLE_MIN="${KOLEJKA_IDLE_MIN:-30}"
STALL_MIN="${KOLEJKA_STALL_MIN:-90}"
GRACE_MIN="${KOLEJKA_GRACE_MIN:-10}"
KOLEJKA_LISTA="$LISTA"
KOLEJKA_TYPY="${KOLEJKA_TYPY:-typ:bug,typ:point-fix,typ:structural,bug}"
KOLEJKA_POMIJAJ="${KOLEJKA_POMIJAJ:-typ:pomysl,enhancement,new_idea,request,typ:analysis,status:odlozone,status:do-scalenia,status:zrobione-lokalnie,tor:remediacja-danych,security-audit-tracker}"
KOLEJKA_ODROCZENIA="${KOLEJKA_ODROCZENIA:-docs/plans docs/runbook}"
EOF
  # Hooks live only in this file, passed with --settings: no other session in the repo sees them.
  jq -n --arg ss "$SKRYPTY/hook-session-start.sh" --arg st "$SKRYPTY/hook-stop.sh" '{hooks: {
    SessionStart: [{matcher: "startup|clear|compact", hooks: [{type: "command", command: $ss}]}],
    Stop: [{hooks: [{type: "command", command: $st}]}]}}' > "$K/settings.json"
  # The owner's authorisation. The watcher types it verbatim at the start of every cycle; the lead
  # quotes it in ledger row 0. One line — a newline would submit it early.
  if [ -n "$LISTA" ]; then ZRODLO="weź następne issue z listy $LISTA (w tej kolejności)"
  else ZRODLO="weź jedno issue z kolejki bugów wg priorytetu P0→P3 (nowe funkcje pomijasz)"; fi
  echo "Kolejka roadmapa: $ZRODLO, rozwiąż je podagentem, scal lokalnie do $MAIN (--no-ff, znacznik [roadmapa]) i zamknij issue na GitHubie. Bez push, bez deployu. Ścieżki i ustawienia wyłącznie ze zmiennych po . .claude/tmp/kolejka/config.env. Zasady: $INSTRUKCJA" > "$K/start-prompt.txt"

  tmux new-session -d -s "$SESJA" -n lider -x 220 -y 50 -c "$REPO" \
    "claude --permission-mode auto ${KOLEJKA_MODEL_LIDER:+--model $KOLEJKA_MODEL_LIDER} --settings '$K/settings.json'"
  tmux new-window -d -t "$SESJA" -n watcher -c "$REPO" \
    "caffeinate -dimsu '$SKRYPTY/watcher.sh' '$K/config.env'; echo 'watcher zakończony — Enter zamyka okno'; read"
  echo "Kolejka ruszyła. Podgląd: tmux attach -t $SESJA  (Ctrl-b d = odłącz, Ctrl-b n = okno watchera)"
  echo "Pierwsze issue: $("$SKRYPTY/wybierz-issue.sh" "$REPO" 2>/dev/null || true)"
  ;;
stop)
  mkdir -p "$K" && touch "$K/zatrzymaj"
  echo "STOP ustawiony — lider dokończy bieżące issue, potem watcher się zatrzyma."
  echo "Twardy stop natychmiast: tmux kill-session -t $SESJA  (bieżące issue podejmie odzysk przy następnym starcie)"
  ;;
status)
  tmux has-session -t "$SESJA" 2>/dev/null && echo "sesja: działa ($SESJA)" || echo "sesja: nie działa"
  L=$(cfg KOLEJKA_LISTA ""); [ -n "$L" ] && echo "źródło: lista $L" || echo "źródło: backlog bugów P0→P3"
  [ -f "$K/w-toku" ] && echo "w toku: #$(cat "$K/w-toku")" || echo "w toku: -"
  for f in zatrzymaj stop pusto rotuj; do [ -f "$K/$f" ] && echo "flaga: $f $(cat "$K/$f")"; done
  LEDGER=$(cfg LEDGER docs/plans/kolejka-ledger.md); MAIN=$(cfg MAIN main)
  echo "--- ledger ($LEDGER), ostatnie wiersze:"; grep '^| [0-9]' "$REPO/$LEDGER" 2>/dev/null | tail -5 || true
  echo "--- watcher.log:"; tail -5 "$K/watcher.log" 2>/dev/null || true
  echo "--- scalone lokalnie, niewypchnięte:"; git -C "$REPO" log --oneline --merges --grep '\[roadmapa\]' "origin/$MAIN..$MAIN" | head -20
  ;;
lista)
  "$SKRYPTY/wybierz-issue.sh" --lista "$REPO"
  ;;
*)
  sed -n '2,14p' "$0"; exit 1 ;;
esac
