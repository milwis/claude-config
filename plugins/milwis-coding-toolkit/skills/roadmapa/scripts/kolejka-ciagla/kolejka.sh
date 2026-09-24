#!/bin/bash
# Continuous queue (kolejka ciągła) — owner's control script. Rules for the lead:
# ../../references/kolejka-ciagla.md
#
#   kolejka.sh start  [repo]   start the lead in tmux + the watcher (run from the owner's terminal)
#   kolejka.sh stop   [repo]   finish the current issue, then stop
#   kolejka.sh status [repo]   where the queue stands
#   kolejka.sh lista  [repo]   the queue in the order it will be taken
#
# Configuration (environment, read at start):
#   KOLEJKA_SESJA (kolejka), KOLEJKA_LEDGER (docs/plans/kolejka-ciagla-ledger.md), KOLEJKA_MAIN (main),
#   KOLEJKA_ETYKIETA_ZROBIONE (status:zrobione-lokalnie), KOLEJKA_IDLE_MIN (30), KOLEJKA_STALL_MIN (90),
#   KOLEJKA_GRACE_MIN (10), KOLEJKA_MODEL_L2 (opus), KOLEJKA_MODEL_LIDER (session default), KOLEJKA_TYPY / KOLEJKA_POMIJAJ (see wybierz-issue.sh)
set -euo pipefail

SKRYPTY="$(cd "$(dirname "$0")" && pwd)"
INSTRUKCJA="$(cd "$SKRYPTY/../.." && pwd)/references/kolejka-ciagla.md"
CMD="${1:-}"
REPO="$(cd "${2:-.}" && git rev-parse --show-toplevel)"
K="$REPO/.claude/tmp/kolejka-ciagla"
SESJA="${KOLEJKA_SESJA:-kolejka}"

case "$CMD" in
start)
  for t in tmux jq gh claude caffeinate; do command -v "$t" >/dev/null || { echo "Brak narzędzia: $t"; exit 1; }; done
  gh auth status >/dev/null 2>&1 || { echo "gh nie jest zalogowany (gh auth login)"; exit 1; }
  MAIN="${KOLEJKA_MAIN:-main}"
  [ "$(git -C "$REPO" branch --show-current)" = "$MAIN" ] || { echo "Drzewo główne nie stoi na $MAIN"; exit 1; }
  BRUD=$(git -C "$REPO" status --short --untracked-files=no)
  [ -z "$BRUD" ] || { echo "Drzewo główne ma niezacommitowane zmiany — lider scala w tym drzewie:"; echo "$BRUD"; exit 1; }
  tmux has-session -t "$SESJA" 2>/dev/null && { echo "Sesja tmux '$SESJA' już działa (tmux attach -t $SESJA)"; exit 1; }

  mkdir -p "$K"
  rm -f "$K"/{rotuj,pusto,stop,STOP,tura-koniec}
  cat > "$K/config.env" <<EOF
REPO="$REPO"
K="$K"
SKRYPTY="$SKRYPTY"
INSTRUKCJA="$INSTRUKCJA"
SESJA="$SESJA"
MAIN="$MAIN"
LEDGER="${KOLEJKA_LEDGER:-docs/plans/kolejka-ciagla-ledger.md}"
WT="$REPO/.claude/worktrees/kolejka-ciagla"
ETYKIETA_ZROBIONE="${KOLEJKA_ETYKIETA_ZROBIONE:-status:zrobione-lokalnie}"
MODEL_L2="${KOLEJKA_MODEL_L2:-opus}"
IDLE_MIN="${KOLEJKA_IDLE_MIN:-30}"
STALL_MIN="${KOLEJKA_STALL_MIN:-90}"
GRACE_MIN="${KOLEJKA_GRACE_MIN:-10}"
KOLEJKA_TYPY="${KOLEJKA_TYPY:-typ:bug,typ:point-fix,typ:structural,bug}"
KOLEJKA_POMIJAJ="${KOLEJKA_POMIJAJ:-typ:pomysl,enhancement,new_idea,request,typ:analysis,status:odlozone,status:do-scalenia,status:zrobione-lokalnie,tor:remediacja-danych,security-audit-tracker}"
EOF
  # Hooks live only in this file, passed with --settings: no other session in the repo sees them.
  jq -n --arg ss "$SKRYPTY/hook-session-start.sh" --arg st "$SKRYPTY/hook-stop.sh" '{hooks: {
    SessionStart: [{matcher: "startup|clear|compact", hooks: [{type: "command", command: $ss}]}],
    Stop: [{hooks: [{type: "command", command: $st}]}]}}' > "$K/settings.json"
  # The owner's authorisation. The watcher types it verbatim at the start of every cycle; the lead
  # quotes it in ledger row 0. One line — a newline would submit it early.
  [ -f "$K/start-prompt.txt" ] || echo "Kolejka ciągła: weź jedno issue z kolejki bugów wg priorytetu P0→P3 (nowe funkcje pomijasz), rozwiąż je podagentem, scal lokalnie do $MAIN (--no-ff, znacznik [roadmapa]) i zamknij issue na GitHubie. Bez push, bez deployu. Ścieżki i ustawienia wyłącznie ze zmiennych po . .claude/tmp/kolejka-ciagla/config.env. Zasady: $INSTRUKCJA" > "$K/start-prompt.txt"

  tmux new-session -d -s "$SESJA" -n lider -x 220 -y 50 -c "$REPO" \
    "claude --permission-mode auto ${KOLEJKA_MODEL_LIDER:+--model $KOLEJKA_MODEL_LIDER} --settings '$K/settings.json'"
  tmux new-window -d -t "$SESJA" -n watcher -c "$REPO" \
    "caffeinate -dimsu '$SKRYPTY/watcher.sh' '$K/config.env'; echo 'watcher zakończony — Enter zamyka okno'; read"
  echo "Kolejka ruszyła. Podgląd: tmux attach -t $SESJA  (Ctrl-b d = odłącz, Ctrl-b n = okno watchera)"
  echo "Pierwsze issue: $("$SKRYPTY/wybierz-issue.sh" "$REPO" || true)"
  ;;
stop)
  mkdir -p "$K" && touch "$K/STOP"
  echo "STOP ustawiony — lider dokończy bieżące issue, potem watcher się zatrzyma."
  echo "Twardy stop natychmiast: tmux kill-session -t $SESJA  (bieżące issue podejmie odzysk przy następnym starcie)"
  ;;
status)
  tmux has-session -t "$SESJA" 2>/dev/null && echo "sesja: działa ($SESJA)" || echo "sesja: nie działa"
  [ -f "$K/w-toku" ] && echo "w toku: #$(cat "$K/w-toku")" || echo "w toku: -"
  for f in STOP stop pusto rotuj; do [ -f "$K/$f" ] && echo "flaga: $f $(cat "$K/$f")"; done
  L="${KOLEJKA_LEDGER:-docs/plans/kolejka-ciagla-ledger.md}"
  [ -f "$K/config.env" ] && L=$(. "$K/config.env"; echo "$LEDGER")
  echo "--- ledger ($L), ostatnie wiersze:"; grep '^| [0-9]' "$REPO/$L" 2>/dev/null | tail -5 || true
  echo "--- watcher.log:"; tail -5 "$K/watcher.log" 2>/dev/null || true
  echo "--- scalone lokalnie, niewypchnięte:"; git -C "$REPO" log --oneline --merges --grep '\[roadmapa\]' "origin/${KOLEJKA_MAIN:-main}..${KOLEJKA_MAIN:-main}" | head -20
  ;;
lista)
  "$SKRYPTY/wybierz-issue.sh" --lista "$REPO"
  ;;
*)
  sed -n '2,15p' "$0"; exit 1 ;;
esac
