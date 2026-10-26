#!/bin/bash
# Lists the project's path-scoped rules files (.claude/rules/*.md with `paths:`) whose globs match a file changed on
# agent/issue-<N>. A reviewer reads a diff and opens few files, so these rules reach it only when its brief names
# them (POMIAR, KonkretnyTMS: 22 of 235 queue reviews had them attached).
# Then the changed paths that hit a `wrazliwe:` glob of the `## Bramka` section in docs/VERIFICATION_ENV.md, matched
# exactly as bramka.sh matches them: the reviewer must know them, because the gate wants tier M or L for such a diff.
#   reguly.sh <config.env> <N>
# shellcheck disable=SC1090
. "$1"
N="${2:?numer issue}"
ZMIENIONE=$(git -C "$WT" diff --name-only "$MAIN...agent/issue-$N")
ZMIENIONE="$ZMIENIONE" python3 -I - "$WT" <<'PY'
import re, sys, glob, os
zmienione = [l.strip() for l in os.environ["ZMIENIONE"].splitlines() if l.strip()]
def wzorzec(g):
    r, i = "", 0
    while i < len(g):
        if g.startswith("**/", i): r += "(?:.*/)?"; i += 3
        elif g.startswith("**", i): r += ".*"; i += 2
        elif g[i] == "*": r += "[^/]*"; i += 1
        elif g[i] == "?": r += "[^/]"; i += 1
        else: r += re.escape(g[i]); i += 1
    return re.compile(r + "$")
for plik in sorted(glob.glob(os.path.join(sys.argv[1], ".claude/rules/*.md"))):
    tekst = open(plik, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---", tekst, re.S)
    if not m: continue
    globy, w_paths = [], False
    for linia in m.group(1).splitlines():
        if re.match(r"paths:\s*$", linia): w_paths = True; continue
        if w_paths and re.match(r"\s+-\s+", linia):
            globy.append(re.sub(r"^\s+-\s+", "", linia).strip().strip("\"'")); continue
        w_paths = False
    traf = [z for z in zmienione if any(wzorzec(g).match(z) for g in globy)]
    if traf: print(os.path.relpath(plik, sys.argv[1]) + "  (" + ", ".join(traf[:3]) + (" …" if len(traf) > 3 else "") + ")")
PY
GLOBY=$(awk '/^## Bramka/{f=1;next} /^## /{f=0} f' "$REPO/docs/VERIFICATION_ENV.md" 2>/dev/null | sed -n 's/^wrazliwe: *//p')
[ -n "$GLOBY" ] || exit 0
shopt -s nocasematch
TRAF=""
while IFS= read -r P; do
  [ -n "$P" ] || continue
  while IFS= read -r G; do
    [ -n "$G" ] || continue
    # shellcheck disable=SC2053
    if [[ "$P" == $G || "${P##*/}" == $G ]]; then TRAF="$TRAF$P"$'\n'; break; fi
  done <<<"$GLOBY"
done <<<"$ZMIENIONE"
if [ -n "$TRAF" ]; then
  echo "Ścieżki wrażliwe projektu (## Bramka) — recenzja co najmniej tier M:"
  printf '%s' "$TRAF" | sed 's/^/  /'
fi
