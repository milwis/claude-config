#!/bin/bash
# Added production lines that carry a condition, a branch, a guard or a log: the surface a re-review checks first.
# Each line needs a RED row in the mutant table (both legs of a guard, every entry point that reaches it) or a stated
# reason (equivalent mutant, log text only, covered by row X). Tests, docs and markdown are skipped; comment lines too.
#   nowe-warunki.sh <worktree> <from> [<to>, default HEAD]
# Prints `path:line: code` per line and `nowe-warunki: <n>` last; exit 0 also when n = 0.
WT="${1:?worktree}"
OD="${2:?od (poprzedni tip albo baza)}"
DO="${3:-HEAD}"
git -C "$WT" rev-parse --verify -q "$OD^{commit}" >/dev/null || { echo "nie ma commita $OD" >&2; exit 2; }
git -C "$WT" diff -U0 --no-renames --diff-filter=AM "$OD" "$DO" -- . \
  ':(exclude,glob)**/tests/**' ':(exclude,glob)**/test/**' ':(exclude,glob)**/__tests__/**' \
  ':(exclude,glob)**/*Test.php' ':(exclude,glob)**/*.test.*' ':(exclude,glob)**/*.spec.*' \
  ':(exclude,glob)docs/**' ':(exclude,glob)**/*.md' ':(exclude,glob)vendor/**' ':(exclude,glob)**/*.lock' |
awk '
  /^\+\+\+ / { plik = substr($0, 7); next }
  /^@@ / { split($3, a, ","); nr = substr(a[1], 2) + 0; next }
  /^\+/ {
    kod = substr($0, 2); linia = nr++
    t = kod; sub(/^[ \t]+/, "", t)
    if (t ~ /^(\/\/|#|\*|\/\*)/ || t == "") next
    w = " " kod " "
    if (w ~ /[^A-Za-z0-9_$.>-](if|elseif|switch|catch|match|while|for|foreach) *\(/ ||
        w ~ /[^A-Za-z0-9_$.>-](else|default|finally)[ {:]/ || w ~ /[^A-Za-z0-9_$.>-](case|throw) / ||
        w ~ /&&|\|\||\?\?|\?\.|===|!==|==|!=|<=|>=| < | > | \? / ||
        w ~ /error_log\(|console\.(log|warn|error|info|debug)\(|->(log|debug|info|notice|warning|error|critical|alert|emergency)\(|Log::|logger\(/) {
      printf "%s:%d: %s\n", plik, linia, t; n++
    }
  }
  END { printf "nowe-warunki: %d\n", n + 0 }
'
