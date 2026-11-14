#!/usr/bin/env bash
# usuniete-symbole.sh — odwołania do funkcji i metod, które refaktor usunął albo wyniósł z pliku
# (skill `refaktor`: raport sesji refaktoru i krok 5a orkiestratora).
#
#   usuniete-symbole.sh <S> <F> <plik> [<plik>…]      (z korzenia repo; pliki z S, np. plik refaktoru)
#
# Dla każdego pliku (klasa = nazwa pliku bez .php) i każdej `function nazwa(` zdefiniowanej w nim na S, a nie na F:
#   - USUNIĘTA (nazwy nie definiuje nic w php/ na F) → szukana sama nazwa (`git grep -w -F`);
#   - WYNIESIONA (nazwę definiuje inna klasa na F) → szukane `Klasa::nazwa` (stare odwołanie kwalifikowane).
# Zakres: docs/, tests/, php/ na F, bez docs/plans, docs/audyty, fable_*, tests/rownowaznosc. Trafienie to pozycja
# do oceny „historia czy stan bieżący”: opis stanu bieżącego, który wskazuje starą metodę, jest do poprawki.
# Kontrola dodatnia: definicja każdej znalezionej nazwy musi dać się znaleźć tym samym grepem w pliku na S;
# brak = narzędzie ślepe (kod 3). Bez `\b` w wyrażeniach: na macOS `git grep -E '…\b'` daje fałszywe zero.
# Kody: 0 brak trafień, 1 są trafienia (lista na stdout), 3 kontrola dodatnia nie przeszła, 64 złe wywołanie.
set -euo pipefail

[ $# -ge 3 ] || { echo "Użycie: $0 <S> <F> <plik> [<plik>…]" >&2; exit 64; }
S="$1"; F="$2"; shift 2
for r in "$S" "$F"; do
    git rev-parse --verify --quiet "$r^{commit}" >/dev/null || { echo "Nieznany commit: $r" >&2; exit 64; }
done

funkcje() { sed -nE 's/.*function[[:space:]]+&?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1/p' | { grep -v '^__' || true; } | sort -u; }
ZAKRES=(docs tests php ':(exclude)docs/plans' ':(exclude)docs/audyty' ':(exclude,glob)**/fable_*' ':(exclude)tests/rownowaznosc')

wzorce=()   # elementy: "<wzorzec>|<opis>"
for p in "$@"; do
    git cat-file -e "$S:$p" 2>/dev/null || { echo "Brak pliku na $S: $p" >&2; exit 64; }
    klasa="$(basename "$p" .php)"
    przed="$(git show "$S:$p" | funkcje)"
    po="$( (git show "$F:$p" 2>/dev/null || true) | funkcje)"
    for n in $(comm -23 <(printf '%s\n' "$przed") <(printf '%s\n' "$po")); do
        git grep -q -w -F -e "$n" "$S" -- "$p" || { echo "KONTROLA DODATNIA: brak definicji $n w $p na $S" >&2; exit 3; }
        if git grep -q -E "function[[:space:]]+&?${n}[[:space:]]*\\(" "$F" -- php; then
            wzorce+=("$klasa::$n|wyniesiona z $klasa")
        else
            wzorce+=("$n|usunięta")
        fi
    done
done

echo "metod usuniętych albo wyniesionych: ${#wzorce[@]}"
[ ${#wzorce[@]} -gt 0 ] || exit 0

trafien=0
for w in "${wzorce[@]}"; do
    wz="${w%%|*}"; opis="${w#*|}"
    wynik="$(git grep -n -w -F -e "$wz" "$F" -- "${ZAKRES[@]}" || true)"
    [ -n "$wynik" ] || continue
    echo "## $wz ($opis)"
    printf '%s\n' "$wynik" | sed "s|^$F:||"
    trafien=$((trafien + $(printf '%s\n' "$wynik" | wc -l)))
done
echo "trafień: $trafien"
[ "$trafien" -eq 0 ] || exit 1
