#!/bin/bash
# The refactor gate (audit 2026-11-12, L1/L2/L16/L17/L23/L26/N5; claude-config #27). Decides from git and from the
# equivalence rig's own files whether one portion of a file refactor passes. The executor's report is not a source of
# the verdict: the gate runs the rig itself on the portion's SHA and reads raport.json / meta.json.
#   bramka.sh --refaktor --wt=<worktree> --karta=<ref>:<path> --raport-porcji=<file> (--recenzja=<file> | --bez-recenzji)
#             [--sha=<SHA, default HEAD>] [--od=<SHA>] [--dziennik=<file>]
# Prints one line per check (OK / BRAK: <why>, UWAGA for listed items) and exits 0 only when every check passes.
#
# --karta  the file's card, KARTA.md, read from a trusted ref (the branch the supervisor commits it to), never from the
#          portion: `<ref>:<path>`, or an absolute path to a file outside the repo. Its section `## Bramka` has one
#          `klucz: wartość` per line (format and meaning: ../references/cykl-refaktoru.md §KARTA). {REPO} in a value is
#          the main checkout of the repo (parent of the git common dir).
# --od     where the portion starts (the lists of L16/L23 cover od..SHA); default: the last SHA this gate passed in the
#          log, else `stary:` of the card.
# --dziennik  TSV log of the gate (date, SHA, od, OK|BRAK, rig exit code, Koszt-USD); default
#          {REPO}/.claude/tmp/refaktor/<class>.tsv. Budget and the stop rule (L26) count from it.
#
# Order: tree and card → hashes, budget and stop rule → (only when those pass) the rig and the substitution check →
# review → portion report → lists of removed assertions, ratchet changes and comment blocks → trial merge with tests/Static (N5).
set -u
# awk printf follows LC_NUMERIC: "5,00" in pl_PL compares as a string and breaks the USD budget.
export LC_NUMERIC=C
TU=$(cd "$(dirname "$0")" && pwd)
LISTA="$TU/../references/recenzja-refaktoru.md"
WT="" KARTA_ARG="" SHA_ARG="" OD_ARG="" RAPORT_P="" REC="" BEZ_REC=0 DZIENNIK=""
for a; do
  case "$a" in
    --refaktor) ;;
    --wt=*) WT=${a#*=} ;; --karta=*) KARTA_ARG=${a#*=} ;; --sha=*) SHA_ARG=${a#*=} ;; --od=*) OD_ARG=${a#*=} ;;
    --raport-porcji=*) RAPORT_P=${a#*=} ;; --recenzja=*) REC=${a#*=} ;; --bez-recenzji) BEZ_REC=1 ;;
    --dziennik=*) DZIENNIK=${a#*=} ;;
    *) echo "nieznana opcja: $a (nagłówek $0)" >&2; exit 2 ;;
  esac
done
[ -n "$WT" ] && [ -n "$KARTA_ARG" ] && [ -n "$RAPORT_P" ] || { sed -n '2,22p' "$0" >&2; exit 2; }
WT=$(cd "$WT" 2>/dev/null && pwd) || { echo "BRAK: worktree $WT nie istnieje"; exit 1; }
BLAD=0 PRZED=0
ok() { echo "OK    $*"; }
NBRAK=0
brak() { echo "BRAK: $*"; BLAD=1; NBRAK=$((NBRAK + 1)); }
# A failure before the rig run: the rig is not started (it costs minutes and would measure the wrong thing).
brak0() { brak "$@"; PRZED=1; }
G() { git -C "$WT" "$@"; }
REPO=$(dirname "$(G rev-parse --path-format=absolute --git-common-dir)")

# ---- tree and card ----------------------------------------------------------------------------------------------
HEAD=$(G rev-parse HEAD)
SHA=$(G rev-parse --verify -q "${SHA_ARG:-HEAD}^{commit}") || { echo "BRAK: --sha=$SHA_ARG nie jest commitem"; exit 1; }
[ "$HEAD" = "$SHA" ] && ok "SHA porcji ${SHA:0:9}" || brak0 "worktree stoi na ${HEAD:0:9}, a SHA porcji to ${SHA:0:9}"
if [ -z "$(G status --porcelain)" ]; then ok "drzewo czyste"
else brak0 "drzewo ma niezacommitowane zmiany — stanowisko mierzyłoby co innego niż SHA porcji"; fi

KARTA_SCIEZKA="" KARTA_REF=""
case "$KARTA_ARG" in
  /*) KARTA_TXT=$(cat "$KARTA_ARG" 2>/dev/null) ;;
  *:*) KARTA_REF=${KARTA_ARG%%:*}; KARTA_SCIEZKA=${KARTA_ARG#*:}; KARTA_TXT=$(G show "$KARTA_REF:$KARTA_SCIEZKA" 2>/dev/null) ;;
  *) KARTA_TXT="" ;;
esac
[ -n "$KARTA_TXT" ] || { echo "BRAK: KARTA $KARTA_ARG nie istnieje (podaj <zaufany ref>:<ścieżka> albo ścieżkę absolutną)"; exit 1; }
SEKCJA=$(awk '/^## Bramka/{f=1;next} /^## /{f=0} f' <<<"$KARTA_TXT")
kv() { sed -n "s/^$1: *//p" <<<"$SEKCJA" | head -1 | sed -E 's/[[:space:]]+$//' | sed "s|{REPO}|$REPO|g"; }
kvs() { sed -n "s/^$1: *//p" <<<"$SEKCJA" | sed -E 's/[[:space:]]+$//'; }
PLIK=$(kv plik) STARY_K=$(kv stary) STAN=$(kv stanowisko) SLOT=$(kv slot) WZORZEC=$(kv wzorzec)
RAPORT_TPL=$(kv raport) SCAL=$(kv scalenie-z) STATIC=$(kv static)
KLASA=$(basename "$PLIK"); KLASA=${KLASA%.*}
BRAKI=""
for k in plik stary narzedzia stanowisko maska scenariusze uzasadnienia raport maska_sha256 scenariusze_sha256 uzasadnienia_sha256 narzedzia_sha256; do
  [ -n "$(kv "$k")" ] || BRAKI="$BRAKI $k"
done
if [ -n "$BRAKI" ]; then echo "BRAK: KARTA $KARTA_ARG bez kluczy:$BRAKI (sekcja ## Bramka)"; exit 1; fi
[ "$(kv status)" = aktywny ] || brak0 "KARTA ma status '$(kv status)', nie 'aktywny' — refaktor tego pliku nie biegnie"
if [ -n "$KARTA_SCIEZKA" ] && G cat-file -e "$SHA:$KARTA_SCIEZKA" 2>/dev/null; then
  [ "$(G show "$SHA:$KARTA_SCIEZKA")" = "$KARTA_TXT" ] \
    || brak0 "KARTA $KARTA_SCIEZKA w SHA porcji różni się od zaufanej ($KARTA_REF) — kartę zmienia nadzorca, nie porcja"
fi
STARY=$(G rev-parse --verify -q "$STARY_K^{commit}") || { echo "BRAK: stary: $STARY_K z KARTY nie jest commitem"; exit 1; }
if [ "$STARY" = "$SHA" ] || ! G merge-base --is-ancestor "$STARY" "$SHA"; then
  brak0 "stary: ${STARY:0:9} z KARTY nie jest właściwym przodkiem SHA porcji"
fi

# ---- frozen measure (L2): mask, scenarios, justifications, substitution map and rig tools as the card says --------
skrot() {  # sha256 of a file at SHA; of `git ls-tree -r` for a directory; empty when absent
  case "$(G cat-file -t "$SHA:$1" 2>/dev/null)" in
    tree) G ls-tree -r "$SHA" -- "$1" | shasum -a 256 | cut -d' ' -f1 ;;
    blob) G show "$SHA:$1" | shasum -a 256 | cut -d' ' -f1 ;;
  esac
}
KLUCZE="maska scenariusze uzasadnienia narzedzia"
[ -z "$(kv podstawienia)" ] || KLUCZE="$KLUCZE podstawienia"
for k in $KLUCZE; do
  P=$(kv "$k"); CHCE=$(kv "${k}_sha256"); JEST=$(skrot "$P")
  if [ -z "$JEST" ]; then brak0 "$k: $P nie istnieje w SHA porcji"
  elif [ "$JEST" != "$CHCE" ]; then brak0 "${k}_sha256 $P = ${JEST:0:12}…, KARTA: ${CHCE:0:12}… — zmiana poza porcją „zmiana stanowiska” (nadzorca aktualizuje KARTĘ)"
  else ok "${k}_sha256 = KARTA ($P)"; fi
done

# ---- budget and the stop rule (L26) -------------------------------------------------------------------------------
DZIENNIK=${DZIENNIK:-$REPO/.claude/tmp/refaktor/$KLASA.tsv}
mkdir -p "$(dirname "$DZIENNIK")" && touch "$DZIENNIK"
OSTATNI_OK=$(awk -F'\t' -v s="$SHA" '$4 == "OK" && $2 != s {x = $2} END {print x}' "$DZIENNIK")
if [ -n "$OD_ARG" ]; then OD=$(G rev-parse --verify -q "$OD_ARG^{commit}") || { echo "BRAK: --od=$OD_ARG nie jest commitem"; exit 1; }
elif [ -n "$OSTATNI_OK" ] && G merge-base --is-ancestor "$OSTATNI_OK" "$SHA" 2>/dev/null; then OD=$(G rev-parse "$OSTATNI_OK")
else OD=$STARY; fi
PORCJI=$(awk -F'\t' -v s="$SHA" '$4 == "OK" && $2 != s {u[$2] = 1} END {print length(u)}' "$DZIENNIK")
B=$(kv budzet-porcji)
if [ -n "$B" ] && [ "$PORCJI" -ge "$B" ]; then brak0 "budżet porcji wyczerpany: $PORCJI przeszło, KARTA budzet-porcji: $B — stop, decyzja nadzorcy"
elif [ -n "$B" ]; then ok "budżet porcji: $PORCJI z $B"; fi
PROB=$(awk -F'\t' -v o="$OD" '$3 == o {n = ($4 == "BRAK") ? n + 1 : 0} END {print n + 0}' "$DZIENNIK")
B=$(kv budzet-prob); B=${B:-3}
[ "$PROB" -lt "$B" ] || brak0 "reguła stopu: $PROB nieudanych prób porcji od ${OD:0:9} (KARTA budzet-prob: $B) — oddaj nadzorcy opis przeszkody"
KOSZT=$(sed -nE 's/^[-*> ]*Koszt-USD:[* ]*([0-9]+([.,][0-9]+)?).*/\1/p' "$RAPORT_P" 2>/dev/null | head -1 | tr , .)
[ -n "$KOSZT" ] || brak "raport porcji bez linii Koszt-USD: <liczba> (koszt porcji ze wszystkich prób, L26)"
B=$(kv budzet-usd)
if [ -n "$B" ] && [ -n "$KOSZT" ]; then
  RAZEM=$(awk -F'\t' -v s="$SHA" -v k="$KOSZT" '$4 == "OK" && $2 != s {t += $6} END {printf "%.2f", t + k}' "$DZIENNIK")
  if awk -v r="$RAZEM" -v b="$B" 'BEGIN {exit !(r > b)}'; then brak "budżet USD przekroczony: $RAZEM > $B (KARTA budzet-usd) — stop, decyzja nadzorcy"
  else ok "budżet USD: $RAZEM z $B"; fi
fi
RUNDY=$(sed -nE 's/^[-*> ]*Rundy:[* ]*([0-9]+).*/\1/p' "$RAPORT_P" 2>/dev/null | head -1)
B=$(kv budzet-rund)
if [ -n "$B" ] && [ -n "$RUNDY" ] && [ "$RUNDY" -gt "$B" ]; then brak "rund recenzji $RUNDY > $B (KARTA budzet-rund) — nowe znaleziska idą do issues, decyzja nadzorcy"; fi

# ---- the rig (L1): run by the gate on the portion's SHA, arguments built here -------------------------------------
KOD_ST=-
opis_kodu() {
  case "$1" in
    1) echo "błąd wywołania albo środowiska" ;; 2) echo "RÓŻNICA" ;; 3) echo "NIEMIERZALNE" ;;
    5|6|7) echo "odmowa kontroli przed przebiegiem" ;; 9) echo "NIEWAŻNY" ;; 10) echo "bramka pokrycia niedomknięta" ;;
    11) echo "brak dowodu czułości" ;; 12) echo "NIEWAŻNY: sieć" ;; *) echo "kod nieznany bramce" ;;
  esac
}
if [ "$PRZED" = 1 ]; then
  brak "stanowisko nie uruchomione — najpierw braki wyżej"
else
  # A fresh report directory per run: a stale raport.json from an earlier run must never be read as this one's.
  ETAP="bramka-${SHA:0:9}-$(date +%s)-$$"
  RD="$WT/$(sed "s|{KLASA}|$KLASA|g; s|{ETAP}|$ETAP|g" <<<"$RAPORT_TPL")"
  rm -rf "$RD"
  ARGS=(--plik="$PLIK" --stary="$STARY" --nowy="$SHA" --etap="$ETAP")
  [ -z "$WZORZEC" ] || ARGS+=(--wzorzec="$WZORZEC")
  if [ -n "$SLOT" ] && [ -f "$SLOT" ]; then CMD=(bash "$SLOT" "$WT" "${ARGS[@]}"); else CMD=(bash "$WT/$STAN" "${ARGS[@]}"); fi
  LOG="$(dirname "$DZIENNIK")/$KLASA-$ETAP.log"
  echo "INFO  stanowisko: ${CMD[*]} (log $LOG)"
  (cd "$WT" && "${CMD[@]}") </dev/null >"$LOG" 2>&1; KOD_ST=$?
  RJ="$RD/raport.json" MJ="$RD/meta.json"
  if [ ! -s "$RJ" ] || [ ! -s "$MJ" ]; then
    brak "stanowisko kod $KOD_ST nie zostawiło raport.json/meta.json w $RD — $(tail -3 "$LOG" | tr '\n' ' ' | cut -c1-300)"
  else
    N0=$NBRAK
    r() { jq -r "$1" "$RJ" 2>/dev/null; }
    m() { jq -r "$1" "$MJ" 2>/dev/null; }
    [ "$KOD_ST" = 0 ] || brak "stanowisko kod $KOD_ST ($(opis_kodu "$KOD_ST")) — każdy kod ≠ 0 blokuje porcję (log $LOG)"
    [ "$(m '.kod_wyjscia')" = 0 ] || brak "meta.json kod_wyjscia $(m '.kod_wyjscia')"
    [ "$(r '.werdykt')" = IDENTYCZNY ] || brak "raport.json werdykt $(r '.werdykt')"
    SC=$(r '.scenariuszy // 0') ID=$(r '.identycznych // 0')
    { [ "$SC" -gt 0 ] && [ "$SC" = "$ID" ]; } 2>/dev/null || brak "raport.json: identycznych $ID z $SC scenariuszy"
    [ "$(r '.tylko')" = null ] || brak "raport.json tylko=$(r '.tylko') — przebieg częściowy (--tylko) nie jest dowodem"
    [ "$(m '.kalibracja')" = 0 ] || brak "meta.json kalibracja=$(m '.kalibracja') — przebieg --kalibracja nie jest dowodem porcji"
    [ -z "$(m '.mutant_b // ""')" ] || brak "meta.json mutant_b=$(m '.mutant_b') — przebieg z --mutant-b nie jest dowodem"
    [ "$(m '.tryb')" = domyslny ] || brak "meta.json tryb $(m '.tryb') — dowodem porcji jest tryb domyslny"
    KD=$(m '.kontrola_dodatnia')
    case "$KD" in wykonana*) ;; *) brak "kontrola dodatnia $KD" ;; esac
    if [ ! -s "$RD/kontrola-dodatnia.json" ]; then brak "kontrola dodatnia: brak kontrola-dodatnia.json w $RD"
    else
      MUT=$(jq -r '.mutantow // 0' "$RD/kontrola-dodatnia.json") BLM=$(jq -r '.bledow // 1' "$RD/kontrola-dodatnia.json")
      { [ "$MUT" -gt 0 ] && [ "$BLM" = 0 ]; } 2>/dev/null || brak "kontrola dodatnia: $BLM z $MUT mutantów bez RÓŻNICA (kontrola-dodatnia.json)"
    fi
    [ "$(m '.kod_pokrycia')" = 0 ] || brak "meta.json kod_pokrycia $(m '.kod_pokrycia') — bramka pokrycia (L4) niedomknięta"
    [ "$(m '.siec.kod')" = 0 ] || brak "meta.json siec.kod $(m '.siec.kod') — NIEWAŻNY: sieć (pułapka L3) albo brak bloku siec"
    [ "$(m '.stanowisko_sha')" = "$SHA" ] || brak "meta.json stanowisko_sha $(m '.stanowisko_sha' | cut -c1-9) ≠ SHA porcji ${SHA:0:9}"
    [ "$(m '.stanowisko_zmiany_niezacommitowane')" = 0 ] || brak "meta.json stanowisko_zmiany_niezacommitowane $(m '.stanowisko_zmiany_niezacommitowane')"
    [ "$(m '.nowy')" = "$SHA" ] || brak "meta.json nowy $(m '.nowy' | cut -c1-9) ≠ SHA porcji ${SHA:0:9}"
    [ "$(m '.stary')" = "$STARY" ] || brak "meta.json stary $(m '.stary' | cut -c1-9) ≠ stary: z KARTY ${STARY:0:9}"
    [ "$(r '.maska_sha256')" = "$(kv maska_sha256)" ] || brak "raport.json maska_sha256 $(r '.maska_sha256' | cut -c1-12)… ≠ KARTA"
    [ "$(m '.scenariusze_sha256')" = "$(kv scenariusze_sha256)" ] || brak "meta.json scenariusze_sha256 $(m '.scenariusze_sha256' | cut -c1-12)… ≠ KARTA"
    [ "$NBRAK" != "$N0" ] || ok "stanowisko: IDENTYCZNY, $ID/$SC scenariuszy, kontrola dodatnia $MUT/$MUT RÓŻNICA, maska i scenariusze = KARTA ($RD)"
  fi
fi

# ---- substitution check for phases 2b–4 (L5, KonkretnyTMS #50) — behind the card key `przeniesienia:` -------------
# The card's command runs the move checker with the substitution map on od..SHA; exit ≠ 0 = differences outside the
# map or an error → the portion is blocked. Placeholders: {WT} {STARY} {OD} {SHA} {PODSTAWIENIA} (the map's path).
# The map's hash is checked above (podstawienia_sha256). The JSON fields are not yet agreed with #50: the gate shows
# `.werdykt` when present and judges by the exit code only.
PRZEN=$(kv przeniesienia)
if [ -n "$PRZEN" ] && [ "$PRZED" = 0 ]; then
  if [ -z "$(kv podstawienia)" ]; then brak "KARTA przeniesienia: bez podstawienia: i podstawienia_sha256: — mapa jest częścią dowodu"
  else
    C=${PRZEN//\{WT\}/$WT}; C=${C//\{STARY\}/$STARY}; C=${C//\{OD\}/$OD}; C=${C//\{SHA\}/$SHA}; C=${C//\{PODSTAWIENIA\}/$(kv podstawienia)}
    LOGP="$(dirname "$DZIENNIK")/$KLASA-${SHA:0:9}-podstawienia"
    (cd "$WT" && bash -c "$C") </dev/null >"$LOGP.json" 2>"$LOGP.err"; KP=$?
    WP=$(jq -r '.werdykt // empty' "$LOGP.json" 2>/dev/null)
    if [ "$KP" = 0 ]; then ok "podstawienia od ${OD:0:9}: kod 0${WP:+, werdykt $WP} ($LOGP.json)"
    else brak "podstawienia od ${OD:0:9}: kod $KP${WP:+, werdykt $WP} — różnice poza mapą albo błąd ($LOGP.json, $(tail -2 "$LOGP.err" | tr '\n' ' ' | cut -c1-200))"; fi
  fi
fi

# ---- review: on this SHA, nothing open, the refactor checklist applied point by point -----------------------------
pole() { grep -m1 -E "^[#*> -]*$2:" "$1" 2>/dev/null | sed -E "s/^[#*> -]*$2:[* ]*//; s/[[:space:]]+$//"; }
if [ "$BEZ_REC" = 1 ]; then brak "recenzja niesprawdzona (--bez-recenzji) — porcja nie przechodzi bez recenzji"
elif [ ! -s "$REC" ]; then brak "recenzja $REC nie istnieje"
else
  SR=$(pole "$REC" SHA | awk '{print $1}')
  OTW=$(pole "$REC" Otwarte | grep -oE '[0-9]+' | tr '\n' ' ')
  H_LISTY=$(shasum -a 256 "$LISTA" | cut -c1-12)
  N_PKT=$(grep -cE '^[0-9]+\. ' "$LISTA")
  if [ -z "$SR" ] || [ "${#SR}" -lt 7 ] || [ "${SHA#"$SR"}" = "$SHA" ]; then brak "recenzja $(basename "$REC") recenzuje SHA ${SR:-?}, a SHA porcji to ${SHA:0:9}"
  elif head -1 "$REC" | grep -q 'CHANGES REQUIRED' || [ "$OTW" != "0 0 " ]; then brak "recenzja $(basename "$REC"): otwarte CRITICAL/REQUIRED ($(pole "$REC" Otwarte))"
  elif [ "$(pole "$REC" Lista-refaktoru | cut -c1-12)" != "$H_LISTY" ]; then
    brak "recenzja $(basename "$REC") bez linii Lista-refaktoru: $H_LISTY (ma: '$(pole "$REC" Lista-refaktoru)') — brief porcji musi podać ścieżkę $LISTA"
  else
    BEZ=""; for i in $(seq 1 "$N_PKT"); do grep -qE "^[-*> ]*R$i:[* ]*[^[:space:]]" "$REC" || BEZ="$BEZ R$i"; done
    if [ -n "$BEZ" ]; then brak "recenzja $(basename "$REC") bez punktów listy refaktoru:$BEZ"
    else ok "recenzja na ${SHA:0:9}: 0 CRITICAL, 0 REQUIRED, lista refaktoru $N_PKT/$N_PKT ($H_LISTY)"; fi
  fi
fi

# ---- portion report: deviations from 1:1 (L17) ---------------------------------------------------------------------
if [ ! -s "$RAPORT_P" ]; then brak "raport porcji $RAPORT_P nie istnieje"
else
  ODST=$(awk '/^#+[[:space:]]*Odstępstwa od 1:1/{f=1;next} /^#/{f=0} f' "$RAPORT_P")
  if ! grep -qE '^#+[[:space:]]*Odstępstwa od 1:1' "$RAPORT_P"; then
    brak "raport porcji bez sekcji „## Odstępstwa od 1:1” (L17; pusta = linia „brak”)"
  else
    WIERSZE=$(grep -E '^[[:space:]]*\|' <<<"$ODST" | grep -vE '^[[:space:]]*\|[-:| ]+\|?[[:space:]]*$' | sed 1d)
    ILE=$(grep -c . <<<"$WIERSZE")
    BEZZ=$(grep . <<<"$WIERSZE" | grep -vic 'zgoda nadzorcy')
    if [ "$BEZZ" -gt 0 ]; then brak "$BEZZ z $ILE odstępstw od 1:1 bez zgody nadzorcy — każde odstępstwo zatrzymuje porcję do jego decyzji (wiersz z „zgoda nadzorcy <kiedy>”)"
    else ok "odstępstwa od 1:1: $ILE"; fi
  fi
fi

# ---- removed or changed assertions, ratchet changes (L16), removed comment blocks > 5 lines (L23) ------------------
ZAPADKI=$(kvs zapadki); [ -n "$ZAPADKI" ] || ZAPADKI=$'tests/Static/**\ntests/Config/**\n*Latch*\n*Ratchet*\n*Zapadk*'
POZYCJE=$(G -c core.quotePath=false diff --no-renames -U0 "$OD" "$SHA" | ZAPADKI="$ZAPADKI" python3 -I -c '
import os, re, subprocess, sys, fnmatch
od, wt = sys.argv[1], sys.argv[2]
zap = [z for z in os.environ["ZAPADKI"].splitlines() if z.strip()]
test_re = re.compile(r"(^|/)(tests?|__tests__)/|\.(test|spec)\.[A-Za-z]+$|Test\.php$")
asercja = re.compile(r"assert|expect *\(|\.to[A-Z][A-Za-z]*\(|\.(rejects|resolves)\.|should\.")
stala = re.compile(r"const |=> *[0-9]|exclude|pomijaj|[A-Z_]{3,} *= *[0-9]")
koment = re.compile(r"^\s*(/\*|\*|//|#)")
def istnial(p):
    return subprocess.run(["git", "-C", wt, "cat-file", "-e", od + ":" + p], capture_output=True).returncode == 0
def zapadka(p):
    return any(fnmatch.fnmatch(p, z) or fnmatch.fnmatch(os.path.basename(p), z) for z in zap)
plik, usuniete, dodane, bloki = None, [], [], []
blok = []
def zamknij():
    global blok
    if len(blok) > 5: bloki.append((plik, blok))
    blok = []
for l in sys.stdin.read().splitlines():
    if l.startswith("diff --git"): zamknij(); plik = None; continue
    if l.startswith("--- "): plik = l[6:] if l.startswith("--- a/") else None; continue
    if l.startswith("+++ "): plik = l[6:] if l.startswith("+++ b/") else plik; continue
    if l.startswith("@@"): zamknij(); continue
    if l.startswith("-"):
        usuniete.append((plik, l[1:]))
        if koment.match(l[1:]): blok.append(l[1:].strip())
        else: zamknij()
    elif l.startswith("+"):
        zamknij(); dodane.append(l[1:].strip())
zamknij()
dodane_txt = "\n".join(dodane)
a = z = k = 0
for p, t in usuniete:
    if p is None: continue
    if test_re.search(p) and istnial(p) and asercja.search(t):
        a += 1; print(f"A{a}\t{p}\t{t.strip()[:160]}")
for p, t in usuniete:
    if p is None: continue
    if zapadka(p) and stala.search(t):
        z += 1; print(f"Z{z}\t{p}\t{t.strip()[:160]}")
for p, b in bloki:
    if "\n".join(b) in dodane_txt: continue  # moved, not lost
    k += 1; print(f"K{k}\t{p}\t{len(b)} linii: {b[0][:80]} … {b[-1][:40]}")
' "$OD" "$WT")
NA=$(grep -c '^A' <<<"$POZYCJE"); NZ=$(grep -c '^Z' <<<"$POZYCJE"); NK=$(grep -c '^K' <<<"$POZYCJE")
echo "INFO  od ${OD:0:9} do ${SHA:0:9}: asercje usunięte/zmienione: $NA, zapadki: $NZ, komentarze: $NK usuniętych (> 5 linii)"
BEZ="" SLABE=""
while IFS=$'\t' read -r ID P TXT; do
  [ -n "$ID" ] || continue
  echo "UWAGA $ID $P: $TXT"
  W=$(grep -m1 -E "^[-*> ]*$ID:" "$RAPORT_P" 2>/dev/null)
  case "$ID" in
    A*) if ! grep -qE "$ID:[* ]*(przepięcie|zaostrzenie|osłabienie)" <<<"$W"; then BEZ="$BEZ $ID"
        elif grep -q 'osłabienie' <<<"$W" && ! grep -qiE 'decyzj[aię] właściciela' <<<"$W"; then SLABE="$SLABE $ID: osłabienie bez decyzji właściciela;"; fi ;;
    Z*) if [ -z "$W" ]; then BEZ="$BEZ $ID"
        elif ! grep -qiE 'decyzj[aię] właściciela' <<<"$W"; then SLABE="$SLABE $ID: zmiana zapadki bez decyzji właściciela;"; fi ;;
    K*) grep -qE "$ID:[* ]*[^[:space:]]" <<<"$W" || BEZ="$BEZ $ID" ;;
  esac
done <<<"$POZYCJE"
[ -z "$BEZ" ] || brak "raport porcji bez wierszy dla:$BEZ — A<n>: przepięcie|zaostrzenie|osłabienie — powód; Z<n>: … decyzja właściciela; K<n>: miejsce docelowe treści"
[ -z "$SLABE" ] || brak "$SLABE"
[ -n "$BEZ$SLABE" ] || ok "asercje, zapadki i komentarze: $((NA + NZ + NK)) pozycji z wierszem w raporcie"

# ---- tests/Static on a trial merge with the base branch (N5), in a throwaway worktree -----------------------------
if [ -n "$STATIC" ] && [ "$PRZED" = 0 ]; then
  TMPW=$(mktemp -d "${TMPDIR:-/tmp}/bramka-n5.XXXXXX"); rmdir "$TMPW"
  sprzataj() { G worktree remove --force "$TMPW" >/dev/null 2>&1; rm -rf "$TMPW"; G worktree prune 2>/dev/null; }
  trap sprzataj EXIT
  if [ -z "$SCAL" ] || ! G rev-parse --verify -q "$SCAL^{commit}" >/dev/null; then brak "KARTA static: bez poprawnego scalenie-z: ($SCAL)"
  elif ! G worktree add -q --detach "$TMPW" "$SHA" >/dev/null 2>&1; then brak "N5: nie da się założyć worktree $TMPW"
  elif ! git -C "$TMPW" -c user.name=bramka -c user.email=bramka@localhost merge -q --no-edit --no-ff "$SCAL" >/dev/null 2>&1; then
    brak "tests/Static: próbne scalenie z $SCAL daje konflikt ($(git -C "$TMPW" diff --name-only --diff-filter=U | tr '\n' ' ')) — porcja rozjechała się z $SCAL"
  else
    C=${STATIC//\{WT\}/$TMPW}; C=${C//\{PORCJA\}/$WT}
    LOGS="$(dirname "$DZIENNIK")/$KLASA-${SHA:0:9}-static.log"
    if (cd "$TMPW" && bash -c "$C") </dev/null >"$LOGS" 2>&1; then ok "tests/Static na próbnym scaleniu z $SCAL (log $LOGS)"
    else brak "tests/Static na próbnym scaleniu z $SCAL czerwone — $(tail -3 "$LOGS" | tr '\n' ' ' | cut -c1-300) (log $LOGS)"; fi
  fi
  sprzataj; trap - EXIT
fi

if [ "$BLAD" = 0 ]; then W=OK; else W=BRAK; fi
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$SHA" "$OD" "$W" "$KOD_ST" "${KOSZT:-0}" >> "$DZIENNIK"
echo "$W: porcja ${SHA:0:9} (dziennik $DZIENNIK)"
exit $BLAD
