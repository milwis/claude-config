#!/bin/bash
# Regression set for the code reviewer: runs one reviewer definition against the project's known cases (diffs with a
# confirmed bug, and clean diffs) and scores recall and noise. Run before and after every change to the reviewer's
# file, model or effort; keep the change only when the score does not fall.
#   eval-recenzenta.sh [opcje] <repo>
#     --agent <plik>        reviewer definition (default: <repo>/.claude/agents/code-reviewer.md, else the toolkit's)
#     --model <m>           overrides the file's `model:`        --effort <e>   effort (default: high)
#     --tylko <id,id>       only these cases                       --powtorzenia <k>  runs per case (default 1)
#     -j <n>                cases in parallel (default 1)          --etykieta <s> label in the history line
#     --sucho               prepare the clones and print the briefs, run no reviewer
#     --zostaw              keep the clones in $TMPDIR/rv-<token> (default: removed after scoring)
# Cases: <repo>/.claude/eval-recenzenta/przypadki.tsv, tab-separated, `#` starts a comment:
#   id  rodzaj(blad|czysty)  baza  tip  oczekiwane  opis
#   - the reviewed diff is baza..tip; `latki/<id>.patch`, when present, is applied on tip and amended into it
#     (a seeded bug keeps tip's commit message);
#   - spec/<id>.md is the frozen spec the reviewer reads (an issue as it was before the fix; `gh` is blocked);
#   - oczekiwane (blad): a path, or path fragment, that a CRITICAL/REQUIRED finding must name; `-` for czysty.
# Isolation: each case gets a clone of <repo> at tip with every ref deleted, so `git log --all` ends at HEAD and a later
# fix cannot leak in; project settings and CLAUDE.md come from that tree (rules as they were at the time).
# Output: .claude/tmp/eval-recenzenta/<run>/ (reports, JSON, wyniki.tsv) and one line in historia.tsv beside it.
set -u
TU=$(cd "$(dirname "$0")" && pwd)
AGENT="" MODEL="" EFFORT=high TYLKO="" POWT=1 J=1 ETYK="" SUCHO=0 ZOSTAW=0
while [ $# -gt 1 ]; do
  case "$1" in
    --agent) AGENT=$2; shift 2 ;; --model) MODEL=$2; shift 2 ;; --effort) EFFORT=$2; shift 2 ;;
    --tylko) TYLKO=",$2,"; shift 2 ;; --powtorzenia) POWT=$2; shift 2 ;; -j) J=$2; shift 2 ;;
    --etykieta) ETYK=$2; shift 2 ;; --sucho) SUCHO=1; shift ;; --zostaw) ZOSTAW=1; shift ;;
    *) echo "nieznana opcja: $1" >&2; exit 2 ;;
  esac
done
REPO=$(cd "${1:?użycie: eval-recenzenta.sh [opcje] <repo>}" && pwd) || exit 2
E="$REPO/.claude/eval-recenzenta"
[ -s "$E/przypadki.tsv" ] || { echo "brak $E/przypadki.tsv" >&2; exit 2; }
if [ -z "$AGENT" ]; then
  AGENT="$REPO/.claude/agents/code-reviewer.md"; [ -s "$AGENT" ] || AGENT="$TU/../../../agents/code-reviewer.md"
fi
[ -s "$AGENT" ] || { echo "brak pliku recenzenta: $AGENT" >&2; exit 2; }
AGENT=$(cd "$(dirname "$AGENT")" && pwd)/$(basename "$AGENT")
RUN="$REPO/.claude/tmp/eval-recenzenta/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN" || exit 2
# The reviewer as a session agent: body of the file as its prompt, tools and model from its frontmatter.
python3 -I - "$AGENT" "$MODEL" > "$RUN/agent.json" <<'PY' || { echo "nie da się odczytać $AGENT" >&2; exit 2; }
import json, sys
text = open(sys.argv[1], encoding="utf-8").read()
_, front, body = text.split("---", 2)
meta = {}
for line in front.strip().splitlines():
    if ":" in line:
        k, v = line.split(":", 1); meta[k.strip()] = v.strip()
tools = [t.strip() for t in meta.get("tools", "Read, Glob, Grep, Bash").split(",") if t.strip() not in ("", "SendMessage")]
model = sys.argv[2] or meta.get("model", "opus")
print(json.dumps({"eval-recenzent": {"description": meta.get("description", "code reviewer"),
                                     "prompt": body.strip(), "tools": tools, "model": model}}))
PY
MODEL_EF=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["eval-recenzent"]["model"])' "$RUN/agent.json")
AGENT_SHA=$(git hash-object "$AGENT" | cut -c1-9)
printf 'agent\t%s\t%s\nmodel\t%s\neffort\t%s\n' "$AGENT" "$AGENT_SHA" "$MODEL_EF" "$EFFORT" > "$RUN/parametry.tsv"

# One case, one run: clone, brief, reviewer, score. Writes one line to $RUN/wyniki/<id>-<r>.tsv.
przypadek() {
  local ID=$1 RODZ=$2 BAZA=$3 TIP=$4 OCZ=$5 R=$6
  # Paths the reviewer sees carry no case name: an opaque token, the spec and the report inside the clone.
  local NAZWA="$ID-$R" TOK; TOK=$(printf '%s' "$RUN/$ID-$R" | shasum | cut -c1-8)
  local D="${TMPDIR:-/tmp}/rv-$TOK" RAP; RAP="${TMPDIR:-/tmp}/rv-$TOK/.claude/tmp/recenzja.md"
  mkdir -p "$RUN/wyniki"
  git clone -q --no-checkout --shared "$REPO" "$D" 2>"$RUN/$NAZWA.git.log" \
    && git -C "$D" checkout -q --detach "$TIP" 2>>"$RUN/$NAZWA.git.log" \
    || { printf '%s\t%s\tBLAD-KLONU\t-\t-\t-\t-\n' "$NAZWA" "$RODZ" > "$RUN/wyniki/$NAZWA.tsv"; return; }
  if [ -s "$E/latki/$ID.patch" ]; then
    git -C "$D" apply "$E/latki/$ID.patch" 2>>"$RUN/$NAZWA.git.log" \
      && git -C "$D" add -A && git -C "$D" -c user.name=eval -c user.email=eval@localhost commit -q --amend --no-edit 2>>"$RUN/$NAZWA.git.log" \
      || { printf '%s\t%s\tBLAD-LATKI\t-\t-\t-\t-\n' "$NAZWA" "$RODZ" > "$RUN/wyniki/$NAZWA.tsv"; return; }
  fi
  git -C "$D" remote remove origin 2>/dev/null
  git -C "$D" for-each-ref --format='%(refname)' | while IFS= read -r REF; do git -C "$D" update-ref -d "$REF"; done
  git -C "$D" reflog expire --expire=now --all 2>/dev/null
  rm -rf "$D/.claude/eval-recenzenta"   # a tip newer than the case set would carry every case's spec and description
  mkdir -p "$D/.claude/tmp"; local SPEC="$D/.claude/tmp/spec.md"
  cp "$E/spec/$ID.md" "$SPEC" 2>/dev/null || echo "(no spec: review the diff on its own)" > "$SPEC"
  local STAT; STAT=$(git -C "$D" diff --stat "$BAZA" HEAD | tail -40)
  cat > "$RUN/$NAZWA.brief.md" <<EOF
Review the diff \`$BAZA..HEAD\` of the repository in your working directory ($D).

Spec: read $SPEC yourself before anything else — it is the task as it was given; \`gh\` is unavailable
in this review, do not call it. Rules: list \`.claude/rules/\` and read each file whose \`paths:\` match the stat.

\`git diff --stat $BAZA HEAD\`:
$STAT

Write your report to $RAP. Line 1: \`No issues.\` or your verdict line. Then the lines
\`SHA: <git rev-parse HEAD at your start>\`, \`Tier: S|M|L\` and \`Otwarte: <n> CRITICAL, <m> REQUIRED\` (every CRITICAL
and REQUIRED finding below, PLAUSIBLE included), then the report. Change no tracked file; probe copies go under
$D/.claude/tmp/. Your last message is the first line of the report and its path.
EOF
  if [ "$SUCHO" = 1 ]; then printf '%s\t%s\tSUCHO\t-\t-\t-\t%s\n' "$NAZWA" "$RODZ" "$D" > "$RUN/wyniki/$NAZWA.tsv"; return; fi
  ( cd "$D" && claude -p --setting-sources user,project --strict-mcp-config --no-session-persistence \
      --permission-mode "${EVAL_TRYB:-auto}" --effort "$EFFORT" --model "$MODEL_EF" \
      --agents "$(cat "$RUN/agent.json")" --agent eval-recenzent --disallowedTools 'Bash(gh:*)' \
      --output-format json "$(cat "$RUN/$NAZWA.brief.md")" ) > "$RUN/$NAZWA.json" 2> "$RUN/$NAZWA.err"
  local KOSZT CZAS; KOSZT=$(jq -r '.total_cost_usd // "-"' "$RUN/$NAZWA.json" 2>/dev/null); CZAS=$(jq -r '((.duration_ms // 0) / 60000 | floor | tostring) + " min"' "$RUN/$NAZWA.json" 2>/dev/null)
  local WYNIK BLOK
  cp "$RAP" "$RUN/$NAZWA.md" 2>/dev/null; RAP="$RUN/$NAZWA.md"
  # A reviewer that answered with the report instead of writing the file: the answer is the report.
  if [ ! -s "$RAP" ] && jq -r '.result // empty' "$RUN/$NAZWA.json" 2>/dev/null | grep -q -E '^[#*> ]*Otwarte:'; then
    jq -r '.result' "$RUN/$NAZWA.json" > "$RAP"
  fi
  if [ ! -s "$RAP" ]; then WYNIK=BRAK-RAPORTU; BLOK=-
  elif ! grep -q -E '^[#*> ]*Otwarte:' "$RAP"; then WYNIK=BEZ-OTWARTE; BLOK=-   # contract broken: not a 0
  else
    BLOK=$(grep -m1 -E '^[#*> ]*Otwarte:' "$RAP" | grep -oE '[0-9]+' | head -2 | awk '{s += $1} END {print s + 0}')
    if [ "$RODZ" = czysty ]; then
      if [ "$BLOK" = 0 ]; then WYNIK=CZYSTY; else WYNIK=SZUM; fi
    elif [ "$BLOK" = 0 ]; then WYNIK=PUSTY
    else
      # A CRITICAL/REQUIRED finding block runs from its severity line to the next finding or heading.
      if awk -v ocz="$OCZ" '
          /\*\*(CRITICAL|REQUIRED)\*\*/ { w = 1 }
          /\*\*(OPTIONAL|NIT|FYI)\*\*/ || /^#/ { w = 0 }
          w && index($0, ocz) { t = 1 }
          END { exit !t }' "$RAP"; then WYNIK=TRAF; else WYNIK=OBOK; fi
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$NAZWA" "$RODZ" "$WYNIK" "$BLOK" "$KOSZT" "$CZAS" "$OCZ" > "$RUN/wyniki/$NAZWA.tsv"
  [ "$ZOSTAW" = 1 ] || rm -rf "$D"
}

N=0
while IFS=$'\t' read -r ID RODZ BAZA TIP OCZ _; do
  case "$ID" in ''|'#'*) continue ;; esac
  [ -z "$TYLKO" ] || case "$TYLKO" in *",$ID,"*) ;; *) continue ;; esac
  case "$RODZ" in blad|czysty) ;; *) echo "pomijam $ID: rodzaj '$RODZ'" >&2; continue ;; esac
  for R in $(seq 1 "$POWT"); do
    przypadek "$ID" "$RODZ" "$BAZA" "$TIP" "${OCZ:--}" "$R" &
    N=$((N + 1)); [ $((N % J)) -eq 0 ] && wait
  done
done < "$E/przypadki.tsv"
wait

{ printf 'przypadek\trodzaj\twynik\tblokujace\tkoszt_usd\tczas\toczekiwane\n'; cat "$RUN"/wyniki/*.tsv 2>/dev/null; } > "$RUN/wyniki.tsv"
column -t -s $'\t' "$RUN/wyniki.tsv"
# Recall = TRAF / blad; OBOK (blocks, but not on the bug), PUSTY, BEZ-OTWARTE and BRAK-RAPORTU do not count.
# Noise = blocking findings on clean diffs.
PODS=$(awk -F'\t' 'NR > 1 {
    if ($2 == "blad") { b++; if ($3 == "TRAF") t++ }
    if ($2 == "czysty") { c++; if ($4 ~ /^[0-9]+$/) s += $4; if ($3 == "SZUM") cs++ }
    if ($5 ~ /^[0-9.]+$/) k += $5 }
  END { printf "trafione %d/%d, czyste z szumem %d/%d (blokujących %d), koszt %.2f USD", t, b, cs, c, s, k }' "$RUN/wyniki.tsv")
echo "$PODS"
[ "$SUCHO" = 1 ] && { echo "sucho: briefy w $RUN, klony w ostatniej kolumnie (usuń je ręcznie)"; exit 0; }
H="$REPO/.claude/tmp/eval-recenzenta/historia.tsv"
[ -s "$H" ] || printf 'data\tagent_sha\tmodel\teffort\tpowtorzenia\twynik\tetykieta\tkatalog\n' > "$H"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$AGENT_SHA" "$MODEL_EF" "$EFFORT" "$POWT" "$PODS" "${ETYK:--}" "$RUN" >> "$H"
echo "historia: $H"
