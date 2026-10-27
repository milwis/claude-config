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
#   domkniecie: <glob> [=> <command>]  case-sensitive, whole path; test and docs paths a closure may touch. With a
#                         command ({PLIK} = the test file, {WT}, {REPO}) the path is a test the gate runs
# Closure (v1.7.3): a review or a verification on an ancestor of the tip still counts when every commit after it
# touches only `domkniecie:` paths (never docs/VERIFICATION_ENV.md, CLAUDE.md, .claude/, .github/), removes or edits
# no assertion line and adds no skip. A review with open REQUIRED findings also needs CRITICAL 0 and the line
# `Domknięcie: <a> mutant, <b> docs` with a + b = REQUIRED, plus one record per mutant finding:
#   Mutant-plik: <production path of this branch>
#   Mutant-przed: <one-line literal, exactly once in that file>
#   Mutant-po: <its replacement>
# The gate applies each mutant to the worktree file and runs the delta's test files: red with the mutant, green
# without it; the file is restored and the worktree checked clean.
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
# Every value of a key, in file order; one pair of surrounding backticks and trailing blanks dropped.
wartosci() {
  local V
  grep -E "^[#*> -]*$2:" "$1" 2>/dev/null | sed -E "s/^[#*> -]*$2:[* ]*//; s/[[:space:]]+$//" | while IFS= read -r V; do
    case "$V" in \`*\`) V=${V#\`}; V=${V%\`} ;; esac
    printf '%s\n' "$V"
  done
}
# Runner of the first `domkniecie:` glob matching path $1: its command, `-` for a glob without one, empty for none.
domk_glob() {
  local L G
  while IFS= read -r L; do
    [ -n "$L" ] || continue
    G=${L%% => *}
    # shellcheck disable=SC2053
    if [[ "$1" == $G ]]; then if [ "$G" = "$L" ]; then echo -; else echo "${L#* => }"; fi; return; fi
  done <<<"$DOMK"
}
# Paths changed between two commits, unquoted (Polish letters and spaces stay as they are), renames as delete + add.
zmienione() { git -c core.quotePath=false -C "$WT" diff --no-renames --name-only "$1" "$2"; }
# Empty when the commits from verdict SHA $1 to the tip qualify as a closure, else the reason.
ASERCJA='assert|expect *\(|\.to[A-Z][A-Za-z]*\(|\.(rejects|resolves)\.|should\.'
SKIP='markTestSkipped|markTestIncomplete|\.(skip|only|todo)\(|(^|[^A-Za-z])x(it|describe|test)\(|skip: *true|@group +(skip|disabled)'
domk_delta() {
  local OD P R
  local -a T
  T=()
  OD=$(git -C "$WT" rev-parse --verify -q "${1:-x}^{commit}") || { echo "${1:-?} nie jest commitem"; return; }
  git -C "$WT" merge-base --is-ancestor "$OD" "$TIP" || { echo "${1:0:9} nie jest przodkiem tipu"; return; }
  while IFS= read -r P; do
    case "$P" in docs/VERIFICATION_ENV.md|CLAUDE.md|*/CLAUDE.md|.claude/*|.github/*) echo "delta dotyka $P"; return ;; esac
    R=$(domk_glob "$P")
    [ -n "$R" ] || { echo "delta dotyka $P (poza domkniecie:)"; return; }
    [ "$R" = - ] || T[${#T[@]}]=":(literal)$P"
  done < <(zmienione "$OD" "$TIP")
  [ "${#T[@]}" -gt 0 ] || return
  git -C "$WT" diff --no-renames -U0 "$OD" "$TIP" -- "${T[@]}" | grep -E '^-' | grep -vE '^--- (a/|/dev/null)' | grep -qE "$ASERCJA" \
    && { echo "delta usuwa albo zmienia linię asercji w testach"; return; }
  git -C "$WT" diff --no-renames -U0 "$OD" "$TIP" -- "${T[@]}" | grep -E '^\+' | grep -vE '^\+\+\+ (b/|/dev/null)' | grep -qE "$SKIP" \
    && echo "delta dodaje skip/only w testach"
}
# Commands for the delta's test files that still exist at the tip, one per line.
domk_testy() {
  local P R
  while IFS= read -r P; do
    R=$(domk_glob "$P")
    [ -n "$R" ] && [ "$R" != - ] && [ -f "$WT/$P" ] || continue
    R=${R//\{PLIK\}/$(printf '%q' "$P")}; R=${R//\{WT\}/$WT}; echo "${R//\{REPO\}/$REPO}"
  done < <(zmienione "$1" "$TIP")
}
# Runs each command of $1 in the worktree; exit 0 only when all pass.
domk_uruchom() {
  local C
  while IFS= read -r C; do
    [ -n "$C" ] || continue
    (cd "$WT" && bash -c "$C") </dev/null >>"$LOGD" 2>&1 || return 1
  done <<<"$1"
}
KOPIA=""; KOPIA_DLA=""
przywroc() { if [ -n "$KOPIA_DLA" ]; then cat "$KOPIA" > "$KOPIA_DLA"; KOPIA_DLA=""; fi; }
trap przywroc EXIT
trap 'przywroc; exit 130' INT TERM
# Closure of review $1 on ancestor SHA $2 with $3 REQUIRED: sets POWOD empty when every mutant is proven, else the reason.
domk_recenzji() {
  local REC="$1" OD="$2" REQ="$3" DOM A B I F PRZED PO ILE TESTY_D
  local -a MP MA MB
  POWOD=""
  DOM=$(pole "$REC" 'Domkni(e|ę)cie')
  A=$(grep -oE '[0-9]+ *mutant' <<<"$DOM" | grep -oE '^[0-9]+'); A=${A:-0}
  B=$(grep -oE '[0-9]+ *docs' <<<"$DOM" | grep -oE '^[0-9]+'); B=${B:-0}
  [ $((A + B)) -eq "$REQ" ] || { POWOD="Domknięcie: ${DOM:-brak linii} nie pokrywa $REQ REQUIRED"; return; }
  [ "$(git -C "$WT" rev-parse HEAD)" = "$TIP" ] || { POWOD="worktree nie stoi na tipie"; return; }
  MP=(); MA=(); MB=()
  while IFS= read -r F; do MP[${#MP[@]}]=$F; done < <(wartosci "$REC" Mutant-plik)
  while IFS= read -r F; do MA[${#MA[@]}]=$F; done < <(wartosci "$REC" Mutant-przed)
  while IFS= read -r F; do MB[${#MB[@]}]=$F; done < <(wartosci "$REC" Mutant-po)
  [ "${#MP[@]}" -eq "$A" ] && [ "${#MA[@]}" -eq "$A" ] && [ "${#MB[@]}" -eq "$A" ] \
    || { POWOD="$A mutant w Domknięcie:, a rekordów Mutant-plik/przed/po ${#MP[@]}/${#MA[@]}/${#MB[@]}"; return; }
  if [ "$B" -gt 0 ]; then
    [ -n "$(zmienione "$OD" "$TIP" | while IFS= read -r F; do [ "$(domk_glob "$F")" = - ] && echo "$F"; done)" ] \
      || { POWOD="$B docs w Domknięcie:, a delta nie zmienia dokumentacji"; return; }
  fi
  TESTY_D=$(domk_testy "$OD")
  if [ -n "$TESTY_D" ] && ! domk_uruchom "$TESTY_D"; then POWOD="testy delty czerwone bez mutanta (log $LOGD)"; return; fi
  I=0
  while [ "$I" -lt "$A" ]; do
    F=${MP[$I]}; PRZED=${MA[$I]}; PO=${MB[$I]}; I=$((I + 1))
    [ -n "$TESTY_D" ] || { POWOD="mutant $I: delta nie ma pliku testu, który mógłby go zabić"; return; }
    [ -n "$F" ] && [ -n "$PRZED" ] && [ "$PRZED" != "$PO" ] || { POWOD="mutant $I: pusty albo bez zmiany"; return; }
    zmienione "$(git -C "$WT" merge-base "$MAIN" "$TIP")" "$TIP" | grep -qxF -- "$F" || { POWOD="mutant $I: $F nie jest plikiem tej gałęzi"; return; }
    [ -z "$(domk_glob "$F")" ] || { POWOD="mutant $I: $F to test/docs, nie kod produkcyjny"; return; }
    ILE=$(PRZED="$PRZED" perl -0777 -ne '$n = () = /\Q$ENV{PRZED}\E/g; print $n' "$WT/$F" 2>/dev/null)
    [ "$ILE" = 1 ] || { POWOD="mutant $I: Mutant-przed występuje w $F ${ILE:-0} razy (ma być 1)"; return; }
    KOPIA="$K/bramka-$N-mutant.kopia"; cat "$WT/$F" > "$KOPIA"; KOPIA_DLA="$WT/$F"
    PRZED="$PRZED" PO="$PO" perl -0777 -pe 's/\Q$ENV{PRZED}\E/$ENV{PO}/' "$KOPIA" > "$WT/$F"
    echo "== mutant $I: $F" >>"$LOGD"
    if [ "${F##*.}" = php ] && command -v php >/dev/null && ! php -l "$WT/$F" >/dev/null 2>&1; then
      przywroc; POWOD="mutant $I: $F po mutacji nie przechodzi php -l — mutant składniowy niczego nie dowodzi"; return
    fi
    if domk_uruchom "$TESTY_D"; then przywroc; POWOD="mutant $I na $F zielony — testy delty go nie zabijają (log $LOGD)"; return; fi
    przywroc
  done
  [ -z "$(git -C "$WT" status --short)" ] || POWOD="worktree brudny po mutantach"
}

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
DOMK=$(sed -n 's/^domkniecie: *//p' <<<"$SEKCJA")
LOGD="$K/bramka-$N-domkniecie.log"; : > "$LOGD"

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
  if [ -n "$SHA_R" ] && [ "${TIP#"$SHA_R"}" = "$TIP" ] && [ -n "$OTW" ] && [ -n "$DOMK" ]; then
    # Closure: the review is on an ancestor; the first line is ignored, the two numbers and the delta decide.
    CRIT=${OTW%% *}; REQ=$(awk '{print $2}' <<<"$OTW")
    POWOD=$(domk_delta "$SHA_R")
    if [ -z "$POWOD" ] && [ "$CRIT" != 0 ]; then POWOD="otwarte CRITICAL"; fi
    if [ -z "$POWOD" ] && [ "$REQ" != 0 ]; then domk_recenzji "$REC" "$SHA_R" "$REQ"
    elif [ -z "$POWOD" ]; then
      TESTY_D=$(domk_testy "$SHA_R")
      if [ -n "$TESTY_D" ] && ! domk_uruchom "$TESTY_D"; then POWOD="testy delty czerwone (log $LOGD)"; fi
    fi
    if [ -z "$POWOD" ]; then
      ok "$(basename "$REC") na ${SHA_R:0:9}, potem domknięcie do ${TIP:0:9}: tylko testy/docs, $REQ REQUIRED zamknięte (log $LOGD)"
    else
      brak "$(basename "$REC") recenzuje ${SHA_R:0:9}, a tip to ${TIP:0:9} — nowe commity bez recenzji, domknięcie nie przechodzi: $POWOD"
    fi
  elif [ -z "$SHA_R" ] || [ "${TIP#"$SHA_R"}" = "$TIP" ]; then
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
    elif [ -z "$SHA_W" ]; then brak "$(basename "$WFY") nie ma linii SHA:"
    elif [ "${TIP#"$SHA_W"}" != "$TIP" ]; then ok "weryfikacja $CHCE na ${TIP:0:9}"
    elif [ -z "$DOMK" ]; then brak "$(basename "$WFY") weryfikuje $SHA_W, a tip to ${TIP:0:9}"
    else
      POWOD=$(domk_delta "$SHA_W")
      if [ -z "$POWOD" ]; then ok "weryfikacja $CHCE na ${SHA_W:0:9}, potem tylko testy/docs do ${TIP:0:9}"
      else brak "$(basename "$WFY") weryfikuje $SHA_W, a tip to ${TIP:0:9} — $POWOD"; fi
    fi ;;
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
