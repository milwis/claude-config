#!/bin/bash
# Self-test of the refactor gate (bramka.sh --refaktor), the queue's freeze of a file under refactor (L18, bramka.sh
# and wybierz-issue.sh) and hook-refaktor.sh. Builds a throwaway repo whose equivalence rig is a fake: it writes
# raport.json / meta.json / kontrola-dodatnia.json from the case's fixture ($FIKSTURA) and exits with its code. The
# gate, the hook and the queue scripts are the real ones. Exit 0 = every case passed.
#   tests/test-refaktor.sh [regex of case names]
set -u
TU=$(cd "$(dirname "$0")" && pwd)
S="$TU/../scripts"
LISTA="$TU/../references/recenzja-refaktoru.md"
T=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/test-refaktor.XXXXXX")" && pwd -P)
trap 'git -C "$T/repo" worktree prune 2>/dev/null; rm -rf "$T"' EXIT
R="$T/repo"
FILTR="${1:-}"
DOBRZE=0 ZLE=0
g() { git -C "$R" -c user.name=t -c user.email=t@localhost "$@"; }

# ---- the repo: old code, a fake rig, tests with assertions and a ratchet, KARTA on the trusted branch -------------
mkdir -p "$R"/{app,tests/rown/maska,tests/rown/scenariusze,tests/rown/uzasadnienia,tests/rown/mutanty,tests/Unit,tests/Static,docs/refaktor/Plik}
git init -q -b main "$R"
cat > "$R/app/Plik.php" <<'PHP'
<?php
class Plik
{
    /**
     * Rounds the amount the way the old invoice screen did.
     * Line two of the explanation.
     * Line three: why half-up and not banker's rounding.
     * Line four: the incident that taught it.
     * Line five.
     */
    public function kwota(float $a): float
    {
        return round($a, 2);
    }
}
PHP
cat > "$R/app/Inny.php" <<'PHP'
<?php
class Inny {}
PHP
cat > "$R/tests/Unit/PlikTest.php" <<'PHP'
<?php
final class PlikTest
{
    public function testKwota(): void
    {
        $this->assertSame(1.01, (new Plik())->kwota(1.005));
        $this->assertSame(2.0, (new Plik())->kwota(2.0));
    }

    public function testWyjatek(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->assertSame(
            3.0,
            (new Plik())->kwota(3.0)
        );
    }

    public function testBlad(): void
    {
        try { (new Plik())->kwota(-1.0); $this->fail('bez wyjątku'); } catch (\Throwable $e) {}
    }
}
PHP
mkdir -p "$R/tests/Scripts"
cat > "$R/tests/Scripts/test_plik.py" <<'PY'
def test_kwota():
    assert kwota(1) == 2
    assert kwota(
        3) == 3
    x = 1
PY
cat > "$R/tests/Static/ZapadkaTest.php" <<'PHP'
<?php
final class ZapadkaTest
{
    private const LIMIT = 5;
    private const DOZWOLONE = ['app/Plik.php'];
}
PHP
printf '#!/bin/bash\n[ ! -e "$1/ZEPSUTE" ]\n' > "$R/tests/Static/run.sh"
echo 'raport/' > "$R/tests/rown/.gitignore"
echo '{"pomijaj": []}' > "$R/tests/rown/maska/Plik.json"
echo '[{"id": "s1"}, {"id": "s2"}, {"id": "s3"}]' > "$R/tests/rown/scenariusze/Plik.json"
echo '{}' > "$R/tests/rown/uzasadnienia/Plik.json"
echo '# scenariusze: ^s' > "$R/tests/rown/mutanty/1.patch"
cat > "$R/tests/rown/stanowisko.sh" <<'SH'
#!/bin/bash
# Fake rig for the gate's self-test. Fixture $FIKSTURA (JSON): kod (exit code), raport/meta/kd (overrides merged into
# the files), bez_raportu (exit without files), kd_brak (no kontrola-dodatnia.json). Arguments go to $ARGI.
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../.." && pwd)
for a; do case $a in --plik=*) P=${a#*=} ;; --stary=*) ST=${a#*=} ;; --nowy=*) NO=${a#*=} ;; --etap=*) E=${a#*=} ;; esac; done
[ -z "${ARGI:-}" ] || echo "$*" > "$ARGI"
F=${FIKSTURA:-'{}'}
KOD=$(jq -r '.kod // 0' <<<"$F")
[ "$(jq -r '.bez_raportu // false' <<<"$F")" = true ] && exit "$KOD"
KL=$(basename "$P" .php); D="$HERE/raport/$KL-$E"; mkdir -p "$D"
jq -n --arg m "$(shasum -a 256 "$HERE/maska/$KL.json" | cut -d' ' -f1)" --argjson o "$(jq '.raport // {}' <<<"$F")" \
  '{werdykt: "IDENTYCZNY", scenariuszy: 3, identycznych: 3, z_roznica: 0, niemierzalnych: 0, niewaznych: 0,
    tylko: null, maska_sha256: $m} * $o' > "$D/raport.json"
jq -n --arg p "$P" --arg st "$(git -C "$REPO" rev-parse "$ST")" --arg no "$(git -C "$REPO" rev-parse "$NO")" \
  --arg h "$(git -C "$REPO" rev-parse HEAD)" --argjson k "$KOD" \
  --arg sc "$(shasum -a 256 "$HERE/scenariusze/$KL.json" | cut -d' ' -f1)" --argjson o "$(jq '.meta // {}' <<<"$F")" \
  '{plik: $p, stary: $st, nowy: $no, stanowisko_sha: $h, stanowisko_zmiany_niezacommitowane: 0, mutant_b: "",
    kod_pokrycia: 0, kod_wyjscia: $k, kalibracja: 0, tryb: "domyslny", scenariusze_sha256: $sc,
    kontrola_dodatnia: "wykonana: komplet RÓŻNICA", siec: {kod: 0, wpisow: 0}} * $o' > "$D/meta.json"
[ "$(jq -r '.kd_brak // false' <<<"$F")" = true ] \
  || jq -n --argjson o "$(jq '.kd // {}' <<<"$F")" '{mutantow: 1, bledow: 0, wyniki: [{mutant: "1", kod: 2}]} * $o' > "$D/kontrola-dodatnia.json"
exit "$KOD"
SH
mkdir -p "$R/docs"
printf '# env\n\n## Bramka\n\nrefaktor-karta: docs/refaktor/*/KARTA*.md\n' > "$R/docs/VERIFICATION_ENV.md"
# The move checker with a substitution map (#50): a stand-in that records its arguments and exits with the code in
# $T/podst.kod (default 0).
mkdir -p "$R/tests/rown/podstawienia"
echo '{"podstawienia": []}' > "$R/tests/rown/podstawienia/Plik.json"
printf '#!/bin/bash\necho "$*" > "%s/podst.args"\nK=$(cat "%s/podst.kod" 2>/dev/null || echo 0)\necho "{\\"werdykt\\": \\"$([ "$K" = 0 ] && echo czysto || echo roznice)\\"}"\nexit "$K"\n' "$T" "$T" > "$R/tests/rown/sprawdz.sh"
g add -A && g commit -qm stary
STARY=$(g rev-parse HEAD)
h() { git -C "$R" show "$1:$2" | shasum -a 256 | cut -d' ' -f1; }
NARZ=$(git -C "$R" ls-tree -r "$STARY" -- tests/rown | shasum -a 256 | cut -d' ' -f1)
karta() {
  cat <<EOF
# KARTA: app/Plik.php

## Bramka

plik: app/Plik.php
stary: $STARY
kolejka: zaufana
status: aktywny
narzedzia: tests/rown
stanowisko: tests/rown/stanowisko.sh
slot: ${SLOT:-$T/brak-slotu.sh}
maska: tests/rown/maska/Plik.json
scenariusze: tests/rown/scenariusze/Plik.json
uzasadnienia: tests/rown/uzasadnienia/Plik.json
raport: tests/rown/raport/{KLASA}-{ETAP}
maska_sha256: $(h "$STARY" tests/rown/maska/Plik.json)
scenariusze_sha256: $(h "$STARY" tests/rown/scenariusze/Plik.json)
uzasadnienia_sha256: $(h "$STARY" tests/rown/uzasadnienia/Plik.json)
narzedzia_sha256: $NARZ
zamrozone: app/Plik.php
zamrozone: tests/rown/**
budzet-porcji: 3
budzet-prob: 3
budzet-usd: 100
budzet-rund: 2
${DODATEK:-}
EOF
}
karta > "$R/docs/refaktor/Plik/KARTA.md"
g add -A && g commit -qm karta
# Variants of the card live only on the trusted branch (the portion's tree carries the plain KARTA.md).
SLOT="$T/slot.sh" karta > "$R/docs/refaktor/Plik/KARTA-slot.md"
DODATEK=$'scalenie-z: main_dev\nstatic: bash {WT}/tests/Static/run.sh {WT}' karta > "$R/docs/refaktor/Plik/KARTA-n5.md"
DODATEK=$'scalenie-z: main_dev_zle\nstatic: bash {WT}/tests/Static/run.sh {WT}' karta > "$R/docs/refaktor/Plik/KARTA-n5-zle.md"
DODATEK=$'scalenie-z: main_dev_konflikt\nstatic: bash {WT}/tests/Static/run.sh {WT}' karta > "$R/docs/refaktor/Plik/KARTA-n5-konflikt.md"
DODATEK=$'podstawienia: tests/rown/podstawienia/Plik.json\npodstawienia_sha256: 0000' karta > "$R/docs/refaktor/Plik/KARTA-podst.md"
DODATEK=$'podstawienia: tests/rown/podstawienia/Plik.json\npodstawienia_sha256: '"$(h "$STARY" tests/rown/podstawienia/Plik.json)"$'\nprzeniesienia: bash {WT}/tests/rown/sprawdz.sh --od={OD} --nowy={SHA} --podstawienia={PODSTAWIENIA}' karta > "$R/docs/refaktor/Plik/KARTA-przen.md"
DODATEK=$'przeniesienia: bash {WT}/tests/rown/sprawdz.sh' karta > "$R/docs/refaktor/Plik/KARTA-przen-bez-mapy.md"
karta | sed 's/^kolejka: zaufana/kolejka: main/' > "$R/docs/refaktor/Plik/KARTA-poza-kolejka.md"
karta | sed 's/^status: aktywny/status: zakonczony/' > "$R/docs/refaktor/Plik/KARTA-zakonczona.md"
karta | sed '/^zamrozone: app/d' > "$R/docs/refaktor/Plik/KARTA-bez-pliku.md"
mkdir -p "$R/docs/inne" && karta > "$R/docs/inne/KARTA.md"
g checkout -q -b zaufana && g add -A && g commit -qm warianty && g checkout -q main
printf '#!/bin/bash\necho "$*" > "%s/slot.args"\nTREE=$1; shift\ncd "$TREE" && exec bash tests/rown/stanowisko.sh "$@"\n' "$T" > "$T/slot.sh"
# main_dev for the trial merge (N5): a clean change, one that breaks tests/Static, one that conflicts.
g checkout -q -b main_dev main && echo x > "$R/app/Nowy.php" && g add -A && g commit -qm nowy
g checkout -q -b main_dev_zle main && touch "$R/ZEPSUTE" && g add -A && g commit -qm zepsute
g checkout -q -b main_dev_konflikt main && sed -i '' 's/round(\$a, 2)/round($a, 3)/' "$R/app/Plik.php" && g commit -qam konflikt
# The portion: one production change.
g checkout -q -b porcja main && sed -i '' 's/return round/return \\round/' "$R/app/Plik.php" && g commit -qam porcja
PORCJA=$(g rev-parse HEAD)
# A card whose old SHA is the portion itself (nothing to compare), on the trusted branch.
g checkout -q zaufana && karta | sed "s/^stary: .*/stary: $PORCJA/" > "$R/docs/refaktor/Plik/KARTA-stary-sha.md" \
  && g add -A && g commit -qm stary-sha && g checkout -q porcja
N_PKT=$(grep -cE '^[0-9]+\. ' "$LISTA" 2>/dev/null || echo 16)
H_LISTY=$(shasum -a 256 "$LISTA" 2>/dev/null | cut -c1-12)

recenzja() {  # $1 = SHA; LISTA_LINIA=0 drops the checklist lines
  printf 'No issues.\nSHA: %s\nTier: M\nOtwarte: 0 CRITICAL, 0 REQUIRED\n' "$1"
  [ "${LISTA_LINIA:-1}" = 0 ] && return
  echo "Lista-refaktoru: $H_LISTY"
  for i in $(seq 1 "$N_PKT"); do echo "R$i: ok — sprawdzone"; done
}
RAPORT_DOBRY=$'# Porcja\nKoszt-USD: 5\nRundy: 1\n\n## Odstępstwa od 1:1\n\nbrak\n'

# One case: $1 name, $2 expected exit (0 / !0), $3 regex the output must contain; then gate arguments.
# Environment: PREP (shell run in the repo on a fresh branch from the portion, committed when it changes anything),
# FIKSTURA, RAPORT (the portion report's text), REC (review text; default good on the tip), KARTA (ref:path).
przypadek() {
  local NAZWA=$1 OCZ=$2 WZ=$3; shift 3
  [ -z "$FILTR" ] || [[ "$NAZWA" =~ $FILTR ]] || return 0
  g checkout -q -B "c-$NAZWA" porcja
  if [ -n "${PREP:-}" ]; then
    (cd "$R" && eval "$PREP")
    [ "${BRUDNE:-0}" = 1 ] || { g add -A && g commit -qm "prep $NAZWA" >/dev/null; }
  fi
  local TIP; TIP=$(g rev-parse HEAD)
  printf '%s' "${RAPORT:-$RAPORT_DOBRY}" > "$T/raport-$NAZWA.md"
  if [ -n "${REC+x}" ]; then printf '%s\n' "$REC" > "$T/rec-$NAZWA.md"; else recenzja "$TIP" > "$T/rec-$NAZWA.md"; fi
  rm -f "$T/argi"
  local OUT KOD
  OUT=$(ARGI="$T/argi" FIKSTURA="${FIKSTURA:-}" bash "$S/bramka.sh" --refaktor --wt="$R" \
    --karta="${KARTA:-zaufana:docs/refaktor/Plik/KARTA.md}" --raport-porcji="$T/raport-$NAZWA.md" \
    --recenzja="$T/rec-$NAZWA.md" --dziennik="$T/dziennik-$NAZWA.tsv" "$@" 2>&1); KOD=$?
  local OK=1
  if [ "$OCZ" = 0 ]; then [ "$KOD" = 0 ] || OK=0; else [ "$KOD" != 0 ] || OK=0; fi
  local W; while IFS= read -r W; do grep -qE -- "$W" <<<"$OUT" || OK=0; done <<<"${WZ//|||/$'\n'}"
  if [ "${NIE_URUCHOMIONE:-0}" = 1 ] && [ -e "$T/argi" ]; then OK=0; fi
  if [ "$OK" = 1 ]; then DOBRZE=$((DOBRZE + 1)); echo "ok   $NAZWA"
  else ZLE=$((ZLE + 1)); echo "ZLE  $NAZWA (kod $KOD, oczekiwano $OCZ, wzorzec /$WZ/)"; sed 's/^/     | /' <<<"$OUT" | tail -25; fi
  g reset -q --hard && g clean -qfd -e tests/rown/raport
  g checkout -q porcja
}
Z() { unset PREP FIKSTURA RAPORT REC KARTA BRUDNE LISTA_LINIA NIE_URUCHOMIONE; }

# ---- the rig's verdict decides; the executor's report does not -----------------------------------------------
Z; przypadek identyczny 0 'OK +stanowisko: IDENTYCZNY, 3/3 scenariuszy'
Z; przypadek uwaga-klucze-opcjonalne 0 'UWAGA: KARTA bez static:'
Z; FIKSTURA='{"kod": 2, "raport": {"werdykt": "RÓŻNICA", "identycznych": 1, "z_roznica": 2}}'
przypadek roznica 1 'BRAK: stanowisko kod 2'
Z; FIKSTURA='{"kod": 9, "raport": {"werdykt": "NIEWAŻNY"}}';            przypadek niewazny 1 'BRAK: stanowisko kod 9'
Z; FIKSTURA='{"kod": 3, "raport": {"werdykt": "NIEMIERZALNE"}}';        przypadek niemierzalne 1 'BRAK: stanowisko kod 3'
Z; FIKSTURA='{"kod": 10}';                                                przypadek kod10 1 'BRAK: stanowisko kod 10'
Z; FIKSTURA='{"kod": 11, "meta": {"kontrola_dodatnia": "pominieta: --tylko"}}'; przypadek kod11 1 'BRAK: stanowisko kod 11'
Z; FIKSTURA='{"kod": 12, "meta": {"siec": {"kod": 12, "wpisow": 1}}}';  przypadek kod12 1 'BRAK: stanowisko kod 12'
Z; FIKSTURA='{"kod": 13}';                                                przypadek kod13-nowy 1 'BRAK: stanowisko kod 13'
Z; FIKSTURA='{"meta": {"kod_wyjscia": 2}}';                              przypadek meta-kod-inny 1 'BRAK: meta.json kod_wyjscia 2'
Z; FIKSTURA='{"raport": {"werdykt": "RÓŻNICA"}}';                         przypadek werdykt-inny 1 'BRAK: raport.json werdykt RÓŻNICA'
Z; FIKSTURA='{"raport": {"tylko": "^u0"}}';                               przypadek tylko 1 'BRAK: .*--tylko'
Z; FIKSTURA='{"meta": {"kalibracja": 1}}';                                przypadek kalibracja 1 'BRAK: .*--kalibracja'
Z; FIKSTURA='{"meta": {"kontrola_dodatnia": "pominieta: --bez-kontroli-dodatniej"}}'
przypadek bez-kontroli 1 'BRAK: kontrola dodatnia pominieta: --bez-kontroli-dodatniej'
Z; FIKSTURA='{"meta": {"mutant_b": "m.patch"}}';                          przypadek mutant-b 1 'BRAK: .*--mutant-b'
Z; FIKSTURA='{"kd": {"bledow": 1}}';                                      przypadek kd-bledy 1 'BRAK: kontrola dodatnia'
Z; FIKSTURA='{"kd_brak": true}';                                          przypadek kd-brak 1 'BRAK: .*kontrola-dodatnia.json'
Z; FIKSTURA='{"meta": {"siec": {"kod": 12}}}';                            przypadek siec 1 'BRAK: .*sieć'
Z; FIKSTURA='{"meta": {"kod_pokrycia": 10}}';                             przypadek pokrycie 1 'BRAK: .*pokrycia'
Z; FIKSTURA='{"meta": {"stanowisko_sha": "0000000000000000000000000000000000000000"}}'
przypadek stanowisko-sha 1 'BRAK: .*stanowisko_sha'
Z; FIKSTURA='{"meta": {"stanowisko_zmiany_niezacommitowane": 2}}';     przypadek stanowisko-brudne 1 'BRAK: .*niezacommitowane'
Z; FIKSTURA='{"meta": {"nowy": "1111111111111111111111111111111111111111"}}'; przypadek nowy-inny 1 'BRAK: .*nowy'
Z; FIKSTURA='{"meta": {"stary": "1111111111111111111111111111111111111111"}}'; przypadek stary-inny 1 'BRAK: .*stary'
Z; FIKSTURA='{"meta": {"tryb": "odczyty-dump"}}';                         przypadek tryb 1 'BRAK: .*tryb'
Z; FIKSTURA='{"raport": {"maska_sha256": "abc"}}';                        przypadek raport-maska 1 'BRAK: raport.json maska_sha256'
Z; FIKSTURA='{"meta": {"scenariusze_sha256": "abc"}}';                    przypadek raport-scenariusze 1 'BRAK: meta.json scenariusze_sha256'
Z; FIKSTURA='{"raport": {"scenariuszy": 0, "identycznych": 0}}';          przypadek zero-scenariuszy 1 'BRAK: .*scenariuszy'
Z; FIKSTURA='{"bez_raportu": true, "kod": 0}';                            przypadek bez-raportu 1 'BRAK: .*nie zostawiło'
# The gate builds the rig's arguments itself: no --tylko/--kalibracja/--mutant-b can reach it.
Z; przypadek argumenty 0 "stanowisko: bash .*stanowisko.sh --plik=app/Plik.php --stary=$STARY --nowy=$PORCJA"

# ---- frozen measure (L2): no rig run when the tree or a hash is off ---------------------------------------------
Z; PREP='echo "{\"pomijaj\": [\"x\"]}" > tests/rown/maska/Plik.json'; NIE_URUCHOMIONE=1 przypadek maska-zmieniona 1 'BRAK: maska_sha256 .*KARTA|||BRAK: stanowisko nie uruchomione'
Z; PREP='echo "[]" > tests/rown/scenariusze/Plik.json';               przypadek scenariusze-zmienione 1 'BRAK: scenariusze_sha256'
Z; PREP='echo "{\"a\":1}" > tests/rown/uzasadnienia/Plik.json';       przypadek uzasadnienia-zmienione 1 'BRAK: uzasadnienia_sha256'
Z; PREP='echo "# x" >> tests/rown/stanowisko.sh';                     przypadek narzedzia-zmienione 1 'BRAK: narzedzia_sha256'
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-podst.md;                      przypadek podstawienia-brak 1 'BRAK: podstawienia'

# ---- substitution check for 2b–4 (#50), behind the card key `przeniesienia:` -------------------------------------
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-przen.md; rm -f "$T/podst.kod"
przypadek podstawienia-czyste 0 'OK +podstawienia_sha256 = KARTA|||OK +podstawienia od .*: kod 0, werdykt czysto' \
  && { { [ -n "$FILTR" ] && ! [[ podstawienia-czyste =~ $FILTR ]]; } || { grep -q -- "--od=$STARY --nowy=.* --podstawienia=tests/rown/podstawienia/Plik.json" "$T/podst.args" && DOBRZE=$((DOBRZE + 1)) && echo "ok   podstawienia-argumenty" \
       || { ZLE=$((ZLE + 1)); echo "ZLE  podstawienia-argumenty: $(cat "$T/podst.args" 2>/dev/null)"; }; }; }
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-przen.md; echo 1 > "$T/podst.kod"
przypadek podstawienia-roznice 1 'BRAK: podstawienia od .*: kod 1, werdykt roznice'; rm -f "$T/podst.kod"
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-przen-bez-mapy.md;             przypadek przeniesienia-bez-mapy 1 'BRAK: KARTA przeniesienia: bez podstawienia'
Z; PREP='echo "{\"podstawienia\": [\"x\"]}" > tests/rown/podstawienia/Plik.json'; KARTA=zaufana:docs/refaktor/Plik/KARTA-przen.md
przypadek mapa-zmieniona 1 'BRAK: (narzedzia|podstawienia)_sha256'
Z; PREP='echo "zmiana: x" >> docs/refaktor/Plik/KARTA.md';            przypadek karta-w-porcji 1 'BRAK: KARTA .* różni się'
Z; PREP='echo "// x" >> app/Plik.php'; BRUDNE=1;                        NIE_URUCHOMIONE=1 przypadek brudne 1 'BRAK: .*niezacommitowane'
Z; przypadek sha-inny 1 'BRAK: worktree stoi na' --sha="$STARY"
Z; KARTA="zaufana:docs/refaktor/Plik/BRAK.md";                           przypadek karta-brak 1 'BRAK: .*KARTA'

# ---- the review applied the refactor checklist (nadzorca, warunek 1 i 2) -----------------------------------------
Z; LISTA_LINIA=0;                                                         przypadek rec-bez-listy 1 'BRAK: recenzja .*Lista-refaktoru'
Z; REC=$'No issues.\nSHA: 0000000\nOtwarte: 0 CRITICAL, 0 REQUIRED';    przypadek rec-inne-sha 1 'BRAK: recenzja .*SHA'
Z; REC=$(recenzja "$PORCJA" | sed 's/^Otwarte: .*/Otwarte: 0 CRITICAL, 1 REQUIRED/'); przypadek rec-otwarte 1 'BRAK: recenzja .*otwarte'
Z; REC=$(recenzja "$PORCJA" | grep -v '^R2:');                           przypadek rec-bez-punktu 1 'BRAK: recenzja .*R2'
Z; przypadek bez-recenzji 1 'BRAK: recenzja niesprawdzona' --bez-recenzji

# ---- the portion report: deviations (L17), assertions and ratchets (L16), comments (L23), budget (L26) ----------
Z; RAPORT=$'Koszt-USD: 1\n';                                             przypadek bez-tabeli 1 'BRAK: .*Odstępstwa od 1:1'
Z; RAPORT=$'Koszt-USD: 1\n## Odstępstwa od 1:1\n| co | dlaczego |\n|---|---|\n| 4xx zamiast 500 | cli |\n'
przypadek odstepstwo-bez-zgody 1 'BRAK: .*odstępstw.*zgody'
Z; RAPORT=$'Koszt-USD: 1\n## Odstępstwa od 1:1\n| co | zgoda |\n|---|---|\n| 4xx zamiast 500 | zgoda nadzorcy 2026-11-12 |\n'
przypadek odstepstwo-ze-zgoda 0 'OK +odstępstwa od 1:1: 1'
Z; RAPORT=$'Koszt-USD: 1\n## Odstępstwa od 1:1\n- 4xx zamiast 500 pod cli\n';  przypadek odstepstwo-lista 1 'BRAK: 1 z 1 odstępstw'
Z; RAPORT=$'Koszt-USD: 1\n## Odstępstwa od 1:1\n| co | zgoda |\n|---|---|\n| 4xx zamiast 500 | zgoda nadzorcy |\n'
przypadek odstepstwo-bez-daty 1 'BRAK: 1 z 1 odstępstw'
Z; PREP="sed -i '' '/assertSame(2.0/d' tests/Unit/PlikTest.php";       przypadek od-zaweza 1 'BRAK: --od=.* zawęża' --od=HEAD
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-poza-kolejka.md;              przypadek karta-poza-kolejka 1 'BRAK: KARTA .* na gałęzi kolejki main'
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-bez-pliku.md;                 przypadek karta-bez-pliku 1 'BRAK: KARTA na zaufana nie zamraża pliku app/Plik.php'
Z; KARTA=zaufana:docs/inne/KARTA.md;                                     przypadek karta-poza-globem 1 'BRAK: kolejka \(zaufana\) nie widzi KARTY docs/inne/KARTA.md'
Z; przypadek karta-zamraza 0 'OK +KARTA na gałęzi kolejki zaufana — kolejka zamraża app/Plik.php'
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-zakonczona.md;                 NIE_URUCHOMIONE=1 przypadek status-zakonczony 1 'BRAK: KARTA ma status .zakonczony.'
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-stary-sha.md;                  NIE_URUCHOMIONE=1 przypadek stary-rowny-sha 1 'BRAK: stary: .* nie jest właściwym przodkiem'
Z; KARTA="$R/docs/refaktor/Plik/KARTA.md";                              przypadek karta-absolutna 1 'BRAK: KARTA podana ścieżką absolutną'
Z; KARTA="HEAD:docs/refaktor/Plik/KARTA.md";                            przypadek karta-z-porcji 1 'BRAK: ref KARTY HEAD zawiera SHA porcji'
Z; PREP="sed -i '' '/assertSame(2.0/d' tests/Unit/PlikTest.php";       przypadek asercja-bez-wiersza 1 'BRAK: .*A1'
Z; PREP="sed -i '' '/assertSame(2.0/d' tests/Unit/PlikTest.php"; RAPORT="${RAPORT_DOBRY}A1: przepięcie — ten sam przypadek w PlikModulTest"
przypadek asercja-z-wierszem 0 'A1 .*tests/Unit/PlikTest.php'
Z; PREP="sed -i '' '/assertSame(2.0/d' tests/Unit/PlikTest.php"; RAPORT="${RAPORT_DOBRY}A1: osłabienie — prościej"
przypadek oslabienie-bez-decyzji 1 'BRAK: .*A1.*decyzj'
Z; PREP="sed -i '' 's/LIMIT = 5/LIMIT = 6/' tests/Static/ZapadkaTest.php"; RAPORT="${RAPORT_DOBRY}Z1: podniesiona, bo moduł urósł"
przypadek zapadka-bez-decyzji 1 'BRAK: .*Z1.*decyzj'
Z; PREP="sed -i '' 's/LIMIT = 5/LIMIT = 6/' tests/Static/ZapadkaTest.php"; RAPORT="${RAPORT_DOBRY}Z1: decyzja właściciela 2026-11-12"
przypadek zapadka-z-decyzja 0 'Z1 .*ZapadkaTest'
Z; PREP="sed -i '' 's/== 2/== 3/' tests/Scripts/test_plik.py";        przypadek asercja-python 1 'BRAK: .*A1|||A1 .*assert kwota\(1\) == 2'
Z; PREP="sed -i '' 's/x = 1/x = 2/' tests/Scripts/test_plik.py";      przypadek asercja-python-bez-szumu 0 'OK: porcja'
Z; PREP="sed -i '' 's/ \$this->fail([^;]*;//' tests/Unit/PlikTest.php"; przypadek asercja-fail 1 'BRAK: .*A1|||A1 .*fail\('
Z; RAPORT=$'# Porcja\nKoszt-USD: 5\nRundy: 1\n\n## Odstępstwa od 1:1\n\n| 4xx zamiast 500 |\n'
przypadek odstepstwo-tabela-bez-naglowka 1 'BRAK: 1 z 1 odstępstw'
Z; RAPORT=$'# Porcja\nKoszt-USD: 5\nRundy: 1\n\n## Odstępstwa od 1:1\n\n| a — bez zgody |\n| b — zgoda nadzorcy 2026-11-12 |\n'
przypadek odstepstwo-dwa-wiersze-bez-naglowka 1 'BRAK: 1 z 2 odstępstw'
Z; PREP="sed -i '' '/expectException/d' tests/Unit/PlikTest.php";     przypadek asercja-expectexception 1 'BRAK: .*A1|||A1 .*expectException'
Z; PREP="sed -i '' 's/^            3.0,\$/            3.5,/' tests/Unit/PlikTest.php"
przypadek asercja-wieloliniowa 1 'BRAK: .*A1|||A1 .*assertSame\( 3.0, \(new Plik'
Z; PREP="sed -i '' 's/testKwota(): void/testKwota(): void { \$this->markTestSkipped(\"x\"); } public function bylo(): void/' tests/Unit/PlikTest.php"
RAPORT="${RAPORT_DOBRY}A1: przepięcie — x"
przypadek pominiecie-dodane 1 'A1 .*dodane pominięcie|||BRAK: .*A1: osłabienie bez decyzji'
Z; PREP="sed -i '' \"s|\\['app/Plik.php'\\]|['app/Plik.php', 'app/Inny.php']|\" tests/Static/ZapadkaTest.php"
przypadek zapadka-dodana 1 "BRAK: .*Z1|||Z1 .*ZapadkaTest.php: 1 usuniętych, 1 dodanych"
Z; PREP="sed -i '' '4,10d' app/Plik.php";                               przypadek komentarz-bez-wiersza 1 'BRAK: .*K1'
Z; PREP="sed -i '' '4,10d' app/Plik.php"; RAPORT="${RAPORT_DOBRY}K1: do docs/architektura/modul-plik.md"
przypadek komentarz-z-wierszem 0 'K1 .*app/Plik.php'
Z; PREP="sed -n '4,10p' app/Plik.php > app/Kopia.php && sed -i '' '4,10d' app/Plik.php"
przypadek komentarz-przeniesiony 0 'komentarze: 0 usuniętych'
Z; RAPORT=$'## Odstępstwa od 1:1\nbrak\n';                               przypadek bez-kosztu 1 'BRAK: .*Koszt-USD'
Z; RAPORT=$'Koszt-USD: 101\n## Odstępstwa od 1:1\nbrak\n';              przypadek budzet-usd 1 'BRAK: .*budżet USD'
Z; RAPORT=$'Koszt-USD: 1\nRundy: 3\n## Odstępstwa od 1:1\nbrak\n';     przypadek budzet-rund 1 'BRAK: .*rund'
Z; PREP="printf 'd\t%s\t%s\tOK\t0\t1\n' a $STARY b $STARY c $STARY > $T/dziennik-budzet-porcji.tsv"
przypadek budzet-porcji 1 'BRAK: .*budżet porcji'
Z; PREP="printf 'd\t%s\t%s\tBRAK\t2\t1\n' x $STARY y $STARY z $STARY > $T/dziennik-stop.tsv"
NIE_URUCHOMIONE=1 przypadek stop 1 'BRAK: .*reguła stopu'
Z; przypadek dziennik 0 'OK'
if [ -z "$FILTR" ] || [[ dziennik =~ $FILTR ]]; then
  if [ "$(cut -f4 "$T/dziennik-dziennik.tsv" 2>/dev/null)" = OK ]; then DOBRZE=$((DOBRZE + 1)); echo "ok   dziennik-wpis"
  else ZLE=$((ZLE + 1)); echo "ZLE  dziennik-wpis: $(cat "$T/dziennik-dziennik.tsv" 2>/dev/null)"; fi
fi

# ---- the project's slot, and tests/Static on a trial merge with main_dev (N5) -----------------------------------
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-slot.md;                       przypadek slot 0 "stanowisko: bash $T/slot.sh $R --plik"
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-n5.md;                         przypadek n5-zielone 0 'OK +tests/Static na próbnym scaleniu z main_dev'
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-n5-zle.md;                     przypadek n5-czerwone 1 'BRAK: tests/Static na próbnym scaleniu z main_dev_zle'
Z; KARTA=zaufana:docs/refaktor/Plik/KARTA-n5-konflikt.md;                przypadek n5-konflikt 1 'BRAK: .*konflikt'
[ -z "$(git -C "$R" worktree list | sed 1d)" ] && echo "ok   n5-sprzatanie" && DOBRZE=$((DOBRZE + 1)) \
  || { [ -n "$FILTR" ] || { ZLE=$((ZLE + 1)); echo "ZLE  n5-sprzatanie: $(git -C "$R" worktree list)"; }; }

# ---- L18: the queue does not merge or take a file under refactor ----------------------------------------------
kolejka() {  # $1 name, $2 file the branch touches, $3 0 = the freeze line must appear, 1 = must not
  [ -z "$FILTR" ] || [[ "$1" =~ $FILTR ]] || return 0
  g checkout -q -B agent/issue-5 main && echo '// x' >> "$R/$2" && g commit -qam "issue 5"
  mkdir -p "$T/k"
  printf 'WT=%s\nMAIN=main\nK=%s\nREPO=%s\n' "$R" "$T/k" "$R" > "$T/k/config.env"
  local OUT; OUT=$(bash "$S/bramka.sh" "$T/k/config.env" 5 2>&1)
  if grep -qE 'BRAK: plik w refaktorze' <<<"$OUT"; then local W=0; else local W=1; fi
  if [ "$W" = "$3" ]; then DOBRZE=$((DOBRZE + 1)); echo "ok   $1"; else ZLE=$((ZLE + 1)); echo "ZLE  $1"; sed 's/^/     | /' <<<"$OUT"; fi
  g checkout -q main
}
kolejka kolejka-zamrozony app/Plik.php 0
kolejka kolejka-inny app/Inny.php 1
kolejka kolejka-karta docs/refaktor/Plik/KARTA.md 0
if [ -z "$FILTR" ] || [[ kolejka-rename =~ $FILTR ]]; then
  g checkout -q -B agent/issue-5 main && g mv app/Plik.php app/PlikNowy.php && echo '// x' >> "$R/app/PlikNowy.php" && g commit -qam "issue 5"
  OUT=$(bash "$S/bramka.sh" "$T/k/config.env" 5 2>&1)
  if grep -qE 'BRAK: plik w refaktorze' <<<"$OUT"; then DOBRZE=$((DOBRZE + 1)); echo "ok   kolejka-rename"
  else ZLE=$((ZLE + 1)); echo "ZLE  kolejka-rename"; sed 's/^/     | /' <<<"$OUT" | tail -10; fi
  g checkout -q main
fi
if [ -z "$FILTR" ] || [[ wybierz =~ $FILTR ]]; then
  mkdir -p "$T/bin"
  printf '#!/bin/bash\ncat <<JSON\n[{"number":1,"title":"Plik: zaokrąglenie","body":"","labels":[{"name":"typ:bug"},{"name":"P1"}],"createdAt":"2026-01-01"},{"number":2,"title":"Inne","body":"","labels":[{"name":"typ:bug"},{"name":"P1"}],"createdAt":"2026-01-02"},{"number":3,"title":"Raport","body":"dotyczy app/Plik.php","labels":[{"name":"typ:bug"},{"name":"P2"}],"createdAt":"2026-01-03"}]\nJSON\n' > "$T/bin/gh"
  chmod +x "$T/bin/gh"
  OUT=$(PATH="$T/bin:$PATH" bash "$S/wybierz-issue.sh" --lista "$R" 2>&1)
  if grep -q 'pominięto #1: plik w refaktorze' <<<"$OUT" && grep -q 'pominięto #3: plik w refaktorze' <<<"$OUT" && grep -qE $'^P1\t#2\t' <<<"$OUT" \
    && ! grep -qE $'^P[0-9]\t#(1|3)\t' <<<"$OUT"; then DOBRZE=$((DOBRZE + 1)); echo "ok   wybierz-issue"
  else ZLE=$((ZLE + 1)); echo "ZLE  wybierz-issue"; sed 's/^/     | /' <<<"$OUT"; fi
fi

# ---- hook-refaktor.sh: rig paths only in a "zmiana stanowiska" portion ------------------------------------------
hak() {  # $1 name, $2 portion kind, $3 expected exit, $4 tool, $5 JSON tool_input
  [ -z "$FILTR" ] || [[ "$1" =~ $FILTR ]] || return 0
  local KOD
  jq -n --arg t "$4" --argjson i "$5" '{tool_name: $t, tool_input: $i}' | bash "$S/hook-refaktor.sh" "$2" 'tests/rown/**' '**/KARTA.md' >/dev/null 2>&1
  KOD=$?
  if [ "$KOD" = "$3" ]; then DOBRZE=$((DOBRZE + 1)); echo "ok   $1"; else ZLE=$((ZLE + 1)); echo "ZLE  $1 (kod $KOD, oczekiwano $3)"; fi
}
hak hak-write-maska kod 2 Write "{\"file_path\": \"$R/tests/rown/maska/Plik.json\"}"
hak hak-edit-karta kod 2 Edit "{\"file_path\": \"$R/docs/refaktor/Plik/KARTA.md\"}"
hak hak-write-kod kod 0 Write "{\"file_path\": \"$R/app/Plik.php\"}"
hak hak-bash-przekierowanie kod 2 Bash '{"command": "echo {} > tests/rown/maska/Plik.json"}'
hak hak-bash-sed kod 2 Bash '{"command": "sed -i \"\" s/a/b/ tests/rown/lib/x.php"}'
hak hak-bash-checkout kod 2 Bash '{"command": "git checkout main -- tests/rown/maska"}'
hak hak-perl-pi kod 2 Bash '{"command": "perl -pi -e s/a/b/ tests/rown/lib/x.php"}'
hak hak-perl-0pi kod 2 Bash '{"command": "perl -0pi -e s/a/b/ tests/rown/lib/x.php"}'
hak hak-sed-in-place kod 2 Bash '{"command": "sed --in-place s/a/b/ tests/rown/lib/x.php"}'
hak hak-cd-sed kod 2 Bash '{"command": "cd tests/rown && sed -i \"\" s/a/b/ lib/x.php"}'
hak hak-cd-przekierowanie kod 2 Bash '{"command": "cd tests/rown/maska; echo {} > Plik.json"}'
hak hak-cd-odczyt kod 0 Bash '{"command": "cd tests/rown && ls -la 2>&1 > /dev/null"}'
hak hak-python-c kod 2 Bash '{"command": "python3 -c \"open(\u0027tests/rown/maska/Plik.json\u0027,\u0027w\u0027).write(\u0027{}\u0027)\""}'
hak hak-python-heredoc kod 2 Bash '{"command": "python3 - <<EOF\nopen(\"tests/rown/maska/Plik.json\",\"w\")\nEOF"}'
hak hak-php-r kod 2 Bash '{"command": "php -r \"file_put_contents(\u0027tests/rown/maska/Plik.json\u0027, 1);\""}'
hak hak-node-e kod 2 Bash '{"command": "node -e \"require(\u0027fs\u0027).writeFileSync(\u0027tests/rown/x\u0027,\u00271\u0027)\""}'
hak hak-sponge kod 2 Bash '{"command": "jq . tests/rown/maska/Plik.json | sponge tests/rown/maska/Plik.json"}'
hak hak-python-skrypt-odczyt kod 0 Bash '{"command": "python3 scripts/raport.py tests/rown/maska/Plik.json"}'
hak hak-rm-katalog kod 2 Bash '{"command": "rm -rf tests/rown"}'
hak hak-bash-odczyt kod 0 Bash '{"command": "cat tests/rown/maska/Plik.json | jq ."}'
hak hak-stanowisko-uruchomienie kod 0 Bash '{"command": "bash tests/rown/stanowisko.sh --plik=app/Plik.php > /tmp/log"}'
hak hak-php-narzedzie kod 0 Bash '{"command": "php tests/rown/sprawdz-przeniesienia.php --stary=a"}'
hak hak-zmiana-stanowiska zmiana-stanowiska 0 Write "{\"file_path\": \"$R/tests/rown/maska/Plik.json\"}"
hak hak-zla-porcja '' 2 Write "{\"file_path\": \"$R/app/Plik.php\"}"

echo "wynik: $DOBRZE ok, $ZLE źle"
[ "$ZLE" = 0 ]
