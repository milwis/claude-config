#!/bin/bash
# SessionStart hook (startup|clear|compact) of the queue lead. Its stdout becomes the fresh
# lead's context: where the rules are, the owner's authorisation (ledger row 0) and where the queue stands.
# Registered only through the --settings file that kolejka.sh generates, so no other session runs it.
#
# The --settings file applies to the whole lead process, subagents included: a subagent's auto-compaction
# fires SessionStart:compact here too. POMIAR (2026-09-24, KonkretnyTMS, #906): a compacted L3 builder got
# "you are the LEAD", deferred #906 and #909 on GitHub, wrote two ledger rows and the stop flag.
# So: never speak to a subagent (payload carries agent_id), and the text itself tells a subagent to ignore it.
INPUT=$(cat)
[ -n "$(jq -r '.agent_id // empty' <<<"$INPUT" 2>/dev/null)" ] && exit 0
K="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp/kolejka"
[ -f "$K/config.env" ] || exit 0
# shellcheck disable=SC1091
. "$K/config.env"

echo "[kolejka] Jeśli jesteś PODAGENTEM (masz narzędzie SubagentHandback albo zlecenie od orkiestratora/issue-*): IGNORUJ całą tę wiadomość i wróć do swojego zlecenia."
echo "[kolejka] Tylko sesja główna w tmux jest LIDEREM kolejki roadmapa: dokładnie jedno issue, potem koniec tury."
[ -n "${KOLEJKA_LISTA:-}" ] && echo "Źródło: lista właściciela $KOLEJKA_LISTA (koniec listy = stop)." || echo "Źródło: backlog bugów P0→P3 (pusta kolejka = czekanie)."
echo "Zasady (przeczytaj w całości przed pierwszą akcją): $INSTRUKCJA"
echo "Nie wywołuj skilla /roadmapa — wszystko, czego potrzebujesz, jest w pliku zasad."
echo
echo "Konfiguracja:"
sed 's/^/  /' "$K/config.env"
echo
if [ -f "$REPO/$LEDGER" ]; then
  echo "Ledger $LEDGER — wiersz 0 (autoryzacja właściciela):"
  grep -m1 '^| 0 ' "$REPO/$LEDGER" || echo "  (brak wiersza 0 — utwórz go wg zasad)"
  echo "Ostatnie wiersze:"
  grep '^| [0-9]' "$REPO/$LEDGER" | tail -3
else
  echo "Ledger $LEDGER nie istnieje — to pierwszy cykl, utwórz go z wierszem 0 wg zasad."
fi
echo
if [ -f "$K/w-toku" ]; then
  echo "UWAGA: plik w-toku = #$(cat "$K/w-toku") — poprzedni lider skończył w trakcie issue. Zacznij od kroku 1 (odzysk)."
else
  echo "w-toku: brak"
fi
