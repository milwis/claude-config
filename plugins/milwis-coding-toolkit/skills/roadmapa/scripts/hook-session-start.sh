#!/bin/bash
# SessionStart hook (startup|clear|compact) of the queue lead. Its stdout becomes the fresh
# lead's context: where the rules are, the owner's authorisation (ledger row 0) and where the queue stands.
# Registered only through the --settings file that kolejka.sh generates, so no other session runs it.
#
# The --settings file applies to the whole lead process, subagents included: a subagent's auto-compaction
# fires SessionStart:compact here too. POMIAR (2026-09-24, KonkretnyTMS, #906): a compacted L3 builder got
# "you are the LEAD", deferred #906 and #909 on GitHub, wrote two ledger rows and the stop flag.
# v1.5.29 exited on agent_id in the payload. POMIAR (2026-09-25 07:17, KonkretnyTMS #973): the builder build-973-1
# (sonnet, depth 2) compacted and still got this text — the SessionStart:compact payload of a subagent does NOT carry
# agent_id. So `compact` is silent for everyone: the lead is /cleared after every issue and never compacts in practice
# (113–122k of 300k over the first night), while a subagent told "you are the LEAD" does damage on GitHub and main.
# The compact payload is logged (hook-compact.log) so the discriminator can be measured before compact is re-enabled.
INPUT=$(cat)
[ -n "$(jq -r '.agent_id // empty' <<<"$INPUT" 2>/dev/null)" ] && exit 0
K="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp/kolejka"
[ -f "$K/config.env" ] || exit 0
if [ "$(jq -r '.source // empty' <<<"$INPUT" 2>/dev/null)" = "compact" ]; then
  jq -c --arg ts "$(date '+%F %T')" --arg env "$(env | grep -o '^CLAUDE[A-Z_]*' | sort | tr '\n' ' ')" \
    '{ts: $ts, payload: ., env: $env}' <<<"$INPUT" >> "$K/hook-compact.log" 2>/dev/null
  exit 0
fi
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
