#!/bin/bash
# SessionStart hook (startup|clear|compact) of the continuous-queue lead. Its stdout becomes the fresh
# lead's context: where the rules are, the owner's authorisation (ledger row 0) and where the queue stands.
# Registered only through the --settings file that kolejka.sh generates, so no other session runs it.
K="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp/kolejka-ciagla"
[ -f "$K/config.env" ] || exit 0
# shellcheck disable=SC1091
. "$K/config.env"

echo "[kolejka ciągła] Ta sesja jest LIDEREM kolejki ciągłej: dokładnie jedno issue, potem koniec tury."
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
