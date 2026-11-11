---
name: eval-recenzenta
description: "Regression set for the code-reviewer: run a reviewer definition against the project's known cases (diffs with a confirmed bug, clean diffs) and score recall and noise. Run before and after every change to code-reviewer.md, the reviewer's model or its effort; keep the change only when the score holds."
disable-model-invocation: true
---

# Eval recenzenta (the reviewer's regression set)

**Core:** a change to the reviewer is measured on the same cases before and after, not judged from one run in the queue. `POMIAR` (KonkretnyTMS, memory `recenzje-petla-v172`): the reviewer file said MEDIUM instead of REQUIRED for a fix line without a RED mutant from 2026-09-24 to 2026-10-26, and nothing noticed it for a month.

**Entry:** a planned change to `agents/code-reviewer.md` (toolkit or a project copy), to the reviewer's `model:`, or to the queue's effort for it.
**Stop:** the history has a line for the old definition and one for the new, run on the same cases, and the change is kept or dropped by the rule below.

## Cases — `<repo>/.claude/eval-recenzenta/`

- `przypadki.tsv`: `id  rodzaj  baza  tip  oczekiwane  opis` (tabs). `rodzaj` is `blad` or `czysty`; the reviewed diff is `baza..tip`; `oczekiwane` is the path a CRITICAL/REQUIRED finding must name (`-` for clean).
- `spec/<id>.md`: the task as it was given, before the fix. Comments written after the tip are left out: they can name the bug.
- `latki/<id>.patch`: optional, a seeded bug applied on tip and amended into it.

Sources of cases, strongest first: a real defect the reviewer missed and something later caught (an escape from `retro`, a later review round, a `regressed.` outcome), confirmed in the code; a one-line behaviour mutation on a line the branch added (easier than a real bug: it says less about recall); a clean diff, one review round with `No issues.` and no later bug pointing at it. Every new escape that `retro` attributes to review becomes a case. Keep about a third of the cases clean: recall bought with noise is not a gain.

## Run

```bash
S=<toolkit>/skills/eval-recenzenta/scripts/eval-recenzenta.sh
"$S" --etykieta "przed: <change>" <repo>                     # current definition
"$S" --agent <new file> --etykieta "po: <change>" <repo>     # the candidate, same cases
"$S" --sucho <repo>                                          # clones and briefs only, no reviewer, no cost
```

Options: `--model`, `--effort` (default `high`), `--tylko id,id`, `--powtorzenia k`, `-j n`, `--zostaw`. Each case runs in a clone at tip with every ref deleted (a later fix cannot leak through `git log --all`), with the project's settings and `CLAUDE.md` from that tree, `gh` blocked, and the brief of the queue's step 6. A run costs about one queue review per case; run it while the queue is idle or in the pre-reset window.

## Reading the score

- `TRAF`: a blocking finding names the expected path. `OBOK`: it blocks, but on something else (read it: a second real bug becomes a case). `PUSTY`: no blocking finding. `CZYSTY` / `SZUM`: a clean case without or with blocking findings.
- **Keep the change** when hits do not fall and blocking findings on clean cases do not rise. A difference of one case in one run is noise: rerun the differing cases with `--powtorzenia 3` before deciding.
- The result goes into the `UPDATE_LOG.md` entry of the change as `POMIAR` with both history lines.
