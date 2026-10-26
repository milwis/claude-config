#!/bin/bash
# The merge gate of the queue: decides from files and git, not from the lead's judgement, whether
# agent/issue-<N> may be merged. Called by scal.sh; the lead may run it alone to see what is missing.
#   bramka.sh <config.env> <N>
# Prints one line per check (OK / BRAK: <why>) and exits 0 only when every check passes.
#
# The verdict files are written by fresh subagents (the lead's Write/Edit on them is blocked by hook-pre-tool.sh):
#   $K/recenzja-<N>-<k>.md     code-reviewer, round k: first line `No issues.` or its verdict line, and lines
#                              `SHA: <reviewed tip>`, `Tier: S|M|L` and `Otwarte: <n> CRITICAL, <m> REQUIRED`
#                              (every CRITICAL and REQUIRED finding of the report, PLAUSIBLE ones included)
#   $K/weryfikacja-<N>-<k>.md  verifier, round k: first line `VERDICT: PASS|FAIL|BLOCKED`, and `SHA: <verified tip>`
#   $K/raport-<N>.md           the lead: first line `done.`, and one line `Weryfikacja: PASS|BLOCKED — …|n/a — …`
# Optional, from the project's docs/VERIFICATION_ENV.md, section `## Bramka`:
#   testy: <command>      run in the worktree, {WT} = its absolute path; exit 0 = pass; keep it under 5 minutes
#   wrazliwe: <glob>      one per line, case-insensitive, matched against each changed path and its basename;
#                         a diff that hits one needs a review of tier M or L
#   powierzchnia: <glob>  same matching; paths a user or a client reaches (UI, endpoints). A diff that hits one
#                         cannot pass with `Weryfikacja: n/a` — it needs a verifier's PASS or BLOCKED
# shellcheck disable=SC1090
. "$1"
N="${2:?numer issue}"
GALAZ="agent/issue-$N"
BLAD=0
ok() { echo "OK    $*"; }
brak() { echo "BRAK: $*"; BLAD=1; }
# Newest round file for a prefix: highest k that exists.
# Changed paths of the branch that match one of the globs in $1 (one per line), space-separated.
trafione() {
  local P G T=""
  [ -n "$1" ] || return 0
  shopt -s nocasematch
  while IFS= read -r P; do
    while IFS= read -r G; do
      [ -n "$G" ] || continue
      # shellcheck disable=SC2053
      if [[ "$P" == $G || "${P##*/}" == $G ]]; then T="$T $P"; break; fi
    done <<<"$1"
  done < <(git -C "$WT" diff --name-only "$MAIN...$GALAZ")
  shopt -u nocasematch
  echo "$T"
}
ostatni() { local k f=""; for k in 1 2 3 4 5 6 7 8 9; do [ -s "$K/$1-$N-$k.md" ] && f="$K/$1-$N-$k.md"; done; echo "$f"; }
# Value of a `Klucz: wartość` line (first match, leading markup ignored).
pole() { grep -m1 -E "^[#*> ]*$2:" "$1" 2>/dev/null | sed -E "s/^[#*> ]*$2:[* ]*//"; }

TIP=$(git -C "$WT" rev-parse --verify -q "$GALAZ") || { echo "BRAK: gałąź $GALAZ nie istnieje"; exit 1; }
ILE=$(git -C "$WT" rev-list --count "$MAIN..$GALAZ")
[ "$ILE" -gt 0 ] && ok "$ILE commitów ponad $MAIN, tip ${TIP:0:9}" || brak "gałąź nie ma commitów ponad $MAIN"
[ -z "$(git -C "$WT" status --short)" ] && ok "worktree czysty" || brak "worktree ma niezacommitowane zmiany"
[ "$(git -C "$WT" rev-parse HEAD)" = "$TIP" ] || [ "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" = HEAD ] \
  || brak "worktree stoi na innej gałęzi niż $GALAZ"

# Project section `## Bramka` of docs/VERIFICATION_ENV.md.
SEKCJA=$(awk '/^## Bramka/{f=1;next} /^## /{f=0} f' "$REPO/docs/VERIFICATION_ENV.md" 2>/dev/null)
WRAZLIWE=$(trafione "$(sed -n 's/^wrazliwe: *//p' <<<"$SEKCJA")")
POWIERZCHNIA=$(trafione "$(sed -n 's/^powierzchnia: *//p' <<<"$SEKCJA")")

R="$K/raport-$N.md"
if [ "$(head -1 "$R" 2>/dev/null | tr -d '[:space:]')" = "done." ]; then ok "raport: done."; else brak "raport $R nie zaczyna się od done."; fi
WER=$(grep -m1 -E '^[#*> ]*Weryfikacja:' "$R" 2>/dev/null | sed -E 's/^[#*> ]*Weryfikacja:[* ]*//')

# Review: the newest round covers exactly this tip and leaves nothing CRITICAL or REQUIRED.
REC=$(ostatni recenzja)
if [ -z "$REC" ]; then
  brak "brak recenzji ($K/recenzja-$N-<k>.md)"
else
  SHA_R=$(pole "$REC" SHA | awk '{print $1}')
  PIERWSZA=$(head -1 "$REC")
  # Two numbers on one fixed line, not a scan of the prose: a finding written without emoji or bold still counts.
  OTW=$(pole "$REC" Otwarte | grep -oE '[0-9]+' | tr '\n' ' ')
  if [ -z "$SHA_R" ] || [ "${TIP#"$SHA_R"}" = "$TIP" ]; then
    brak "$(basename "$REC") recenzuje ${SHA_R:-?}, a tip to ${TIP:0:9} — nowe commity bez recenzji"
  elif grep -q 'CHANGES REQUIRED' <<<"$PIERWSZA"; then
    brak "$(basename "$REC"): $PIERWSZA"
  elif [ "$OTW" = "0 0 " ]; then
    ok "$(basename "$REC"): 0 CRITICAL, 0 REQUIRED na ${TIP:0:9}"
  elif [ -z "$OTW" ]; then
    brak "$(basename "$REC") nie ma linii Otwarte: <n> CRITICAL, <m> REQUIRED"
  else
    brak "$(basename "$REC"): otwarte CRITICAL/REQUIRED ($(pole "$REC" Otwarte))"
  fi
fi

# Verification: what the lead's report claims must be what the newest verifier file says, on this tip.
WFY=$(ostatni weryfikacja)
VERD=""; [ -n "$WFY" ] && VERD=$(head -1 "$WFY" | grep -oE 'PASS|FAIL|BLOCKED' | head -1)
case "$WER" in
  PASS*|BLOCKED*)
    CHCE=${WER%%[^A-Z]*}
    SHA_W=$(pole "$WFY" SHA | awk '{print $1}')
    if [ -z "$WFY" ]; then brak "raport mówi Weryfikacja: $CHCE, a nie ma pliku weryfikacji"
    elif [ "$VERD" != "$CHCE" ]; then brak "raport mówi $CHCE, $(basename "$WFY") mówi ${VERD:-?}"
    elif [ -z "$SHA_W" ] || [ "${TIP#"$SHA_W"}" = "$TIP" ]; then brak "$(basename "$WFY") weryfikuje ${SHA_W:-?}, a tip to ${TIP:0:9}"
    else ok "weryfikacja $CHCE na ${TIP:0:9}"; fi ;;
  n/a*)
    if [ "$VERD" = FAIL ]; then brak "raport mówi n/a, a ostatnia weryfikacja to FAIL"
    elif [ -n "$POWIERZCHNIA" ]; then brak "raport mówi n/a, a diff dotyka powierzchni ($(cut -c1-200 <<<"$POWIERZCHNIA")) — potrzebny weryfikator: PASS albo BLOCKED"
    else ok "weryfikacja n/a (${WER#n/a})"; fi ;;
  *) brak "raport nie ma linii Weryfikacja: PASS / BLOCKED — … / n/a — …" ;;
esac

# Sensitive paths need a review of tier M or L.
if [ -n "$WRAZLIWE" ]; then
  TIER=$(pole "$REC" Tier | grep -oE '^[SML]')
  case "$TIER" in
    M|L) ok "ścieżki wrażliwe, recenzja tier $TIER:$(cut -c1-200 <<<"$WRAZLIWE")" ;;
    *) brak "ścieżki wrażliwe ($(cut -c1-200 <<<"$WRAZLIWE")), a recenzja ma tier ${TIER:-?} — potrzebny M albo L" ;;
  esac
fi
TESTY=$(sed -n 's/^testy: *//p' <<<"$SEKCJA" | head -1)
if [ -n "$TESTY" ]; then
  LOG="$K/bramka-$N.log"
  if (cd "$WT" && bash -c "${TESTY//\{WT\}/$WT}") > "$LOG" 2>&1; then ok "testy bramki (log $LOG)"
  else brak "testy bramki czerwone — $(tail -3 "$LOG" | tr '\n' ' ' | cut -c1-300) (log $LOG)"; fi
fi

exit $BLAD
