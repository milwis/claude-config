# The refactor cycle — one portion of a god-file refactor

Source: audit of the refactor procedure after the Gutschrift pilot (claude-config #46,
`docs/plans/2026-11-12-audyt-procedury-refaktoru.md`: §3 guidelines, §4 reviewer list, L1/L2/L16–L18/L23/L26, N2,
N5), implemented in toolkit v1.12.0 (#27). The refactor runs under a supervisor; the queue does not chain portions
(that comes only after the first file finished on this gate under supervision, audit §7).

**Goal.** Every portion that lands on the refactor branch is proven to keep behaviour by files the executor did not
write: the equivalence rig (`stanowisko`) run by the gate on the portion's SHA, a frozen measure whose hashes sit in
the KARTA, and a review that applied the refactor checklist point by point. The executor's report says what was
done and why; it is never the source of the verdict.

**Roles.** The *supervisor* writes the KARTA, decides the kind of every portion (`kod` or `zmiana stanowiska`),
accepts deviations from 1:1, and is the stop point for budget and the three-attempts rule. The *executor* does one
portion of one phase. The *reviewer* is a fresh `code-reviewer` with the refactor checklist
(`recenzja-refaktoru.md`). The *owner* decides weakened assertions, raised ratchets and budget overruns.

## The KARTA

One file per refactored file, e.g. `docs/refaktor/<Class>/KARTA.md`, committed by the supervisor when the refactor
starts on the queue's base branch (`$MAIN`, e.g. `main_dev`; key `kolejka:`), so the queue sees the freeze. The gate
reads it from a trusted ref (`--karta=<ref>:<path>`, usually the same branch) and refuses: an absolute path, a ref
that contains the portion's SHA (the portion's own branch), a portion whose own copy of the KARTA differs, and a
KARTA whose text on `kolejka:` differs from the trusted one. Section `## Bramka`, one `key: value` per line:

| key | meaning |
|---|---|
| `plik` | the file under refactor (repo-relative) |
| `stary` | the old SHA: side A of every rig run |
| `kolejka` | the queue's base branch the KARTA is committed on (the freeze is read from there) |
| `status` | `aktywny` while the refactor runs; anything else stops the gate and releases the queue freeze |
| `narzedzia` | the rig's directory (`tests/rownowaznosc`) |
| `stanowisko` | the rig's entry script, repo-relative |
| `slot` | optional: the project's lock wrapper, called `<slot> <abs worktree> <rig args>`; `{REPO}` = main checkout |
| `wzorzec` | optional: the database template passed as `--wzorzec=` |
| `maska`, `scenariusze`, `uzasadnienia` | the file's mask, scenarios and justifications |
| `podstawienia` | optional: the substitution map of phases 2b–4 (#50) |
| `<key>_sha256` | for each of `maska scenariusze uzasadnienia narzedzia [podstawienia]` |
| `raport` | the rig's report directory, with `{KLASA}` and `{ETAP}` |
| `zamrozone` | one glob per line: paths the queue does not merge while the refactor runs (L18) |
| `zapadki` | optional globs of ratchet files (default `tests/Static/**`, `tests/Config/**`, `*Latch*`, `*Ratchet*`, `*Zapadk*`) |
| `scalenie-z`, `static` | N5: the branch for the trial merge and the command run on it (`{WT}` = the merged copy, `{PORCJA}` = the portion's worktree, e.g. to copy `vendor/` and `.env` from it) |
| `przeniesienia` | optional: the substitution check command (below) |
| `budzet-porcji`, `budzet-prob`, `budzet-usd`, `budzet-rund` | L26: portions passed, failed attempts in a row (default 3), USD in total, review rounds per portion |

Required: `plik stary kolejka narzedzia stanowisko maska scenariusze uzasadnienia raport` and the four hashes. When
`static`, `zamrozone` or a `budzet-*` other than `budzet-prob` is missing, the gate skips that check and prints an
`UWAGA` line for it.

Hashes, the same definitions as the rig's own check (KonkretnyTMS patch in the #27 report): a file →
`git show <SHA>:<path> | shasum -a 256`; a directory → `git ls-tree -r <SHA> -- <dir> | shasum -a 256`. The
supervisor computes them on the commit that starts the refactor and recomputes them only after a `zmiana
stanowiska` portion. Three calibration runs old ↔ old (guideline 1) happen before the first hash is written.

**Queue freeze (L18).** The project's `docs/VERIFICATION_ENV.md`, section `## Bramka`, gets
`refaktor-karta: docs/refaktor/*/KARTA.md`. `scripts/zamrozone.sh` lists the `zamrozone:` globs of every active
KARTA, and the KARTA's own path, reading both from the commit of `$MAIN` (not the working tree; a KARTA that sits only
on another branch freezes nothing); `bramka.sh` refuses a queue merge that touches one and `wybierz-issue.sh` skips
an issue that names the file or its class. A P0 fix goes through the supervisor, who carries it into the refactor and adds a scenario for it.
Never merge `main_dev` into the refactor branch.

## A portion, step by step

1. **Supervisor: kind and hook.** The executor's session starts with the hook in its `--settings`, the kind fixed
   there so the session cannot switch it:
   `{"hooks":{"PreToolUse":[{"matcher":"Write|Edit|MultiEdit|NotebookEdit|Bash","hooks":[{"type":"command","command":"bash <toolkit>/skills/roadmapa/scripts/hook-refaktor.sh kod"}]}]}}`.
   In a `kod` portion the hook blocks writes to `tests/rownowaznosc/**` and `**/KARTA.md` (other globs as extra
   arguments): edits, redirects, `tee`/`sponge`, `cp`/`mv`/`rm`, `sed`/`perl` in place, `git checkout|restore`, any
   writer after `cd` into the directory, inline interpreter code (`python -c`, `php -r`, `node -e`, heredocs) that
   names it. Running the rig and its checkers passes. The hook is the first line; the hashes in the gate are the proof. A `zmiana-stanowiska` portion changes only the measure,
   and the supervisor then updates the hashes in the KARTA.
2. **Executor: one phase.** Guidelines 7–20 below. Commit; the tree is clean before the gate.
3. **Executor: its own rig run and the portion report.** One full run on the commit through the project's slot
   (default mode, no `--tylko`/`--kalibracja`/`--mutant-b`); the report (format below) names its directory and
   carries the cost of every attempt so far. This run is the reviewer's input, not the verdict.
4. **Review.** A fresh `code-reviewer`. The brief MUST name the checklist: `Refactor checklist:
   <toolkit>/skills/roadmapa/references/recenzja-refaktoru.md — apply every point`. A review without the
   `Lista-refaktoru:` hash and one `R<n>:` line per point fails the gate. At most `budzet-rund` rounds; round 2
   checks only that round 1's findings are closed; new findings in it go to issues unless they are a regression.
5. **Gate — run by the supervisor**, not the executor (it picks `--karta`, `--recenzja` and `--dziennik`):
   `bramka.sh --refaktor --wt=<worktree> --karta=<ref>:<path> --raport-porcji=<file> --recenzja=<file>`
   (`--sha`, `--od`, `--dziennik` optional; `--od` may only widen the range: it must be an ancestor of the default
   start). Exit 0 = the portion passes; the log line lands in the gate's TSV. The gate needs the rig with the
   network block (`siec` in `raport.json`, KonkretnyTMS #49): a rig without it fails the gate.
6. **On BRAK.** Fix what the line names and run the gate again. After `budzet-prob` failed attempts from the same
   start the gate itself refuses (stop rule): hand the supervisor a description of the obstacle.

## What the gate checks

| check | blocks when |
|---|---|
| tree and SHA | the worktree is not on the portion's SHA, or has uncommitted changes |
| KARTA | missing keys, status not `aktywny`, absolute path or a ref containing the portion, the portion's copy or the copy on `kolejka:` differs from the trusted one, `stary` not a proper ancestor |
| frozen measure (L2) | a hash of mask, scenarios, justifications, tools or substitution map differs from the KARTA |
| budget (L26) | portions or USD over budget, failed attempts ≥ `budzet-prob`, rounds over `budzet-rund`, no `Koszt-USD` |
| rig (L1) | any exit code ≠ 0 (2 RÓŻNICA, 3, 5/6/7, 9, 10, 11, 12, unknown); `werdykt` ≠ IDENTYCZNY; identical ≠ scenarios or 0; `tylko`, `kalibracja`, `mutant_b`, mode ≠ `domyslny`; positive control skipped or with misses; `kod_pokrycia` ≠ 0; `siec.kod` ≠ 0; `stanowisko_sha`/`nowy` ≠ SHA, `stary` ≠ KARTA, uncommitted rig changes; `maska_sha256`/`scenariusze_sha256` ≠ KARTA |
| substitutions (#50) | the `przeniesienia:` command exits ≠ 0 (only when the KARTA has the key) |
| review | another SHA, open CRITICAL/REQUIRED, no checklist hash, a missing `R<n>` |
| deviations (L17) | no `## Odstępstwa od 1:1` section; any line of it (a table row, a list item, prose — except `brak`) without `zgoda nadzorcy RRRR-MM-DD` |
| tests, ratchets, comments (L16, L23) | a listed `A<n>`/`Z<n>`/`K<n>` without its line in the report; weakening, an added skip or a ratchet change without `decyzja właściciela` |
| N5 | `tests/Static` red, or a conflict, on a trial merge with `scalenie-z` in a throw-away worktree |

The gate runs the rig itself, with arguments it builds (`--plik --stary --nowy=<SHA> --etap=<unique>
[--wzorzec]`), through the slot when the KARTA names one, into a fresh report directory. Nothing the executor passes
reaches the rig, and no earlier run is reused: the cost is a second rig run per portion (step 3 and the gate).

## The portion report

```markdown
# Porcja <n>: <phase> — <one line>
Stanowisko: <report directory of your own run> — IDENTYCZNY <i>/<n>, maska_sha256 <12 hex>, scenariusze_sha256 <12 hex>
Koszt-USD: <all attempts of this portion, in total>
Rundy: <review rounds>

## Odstępstwa od 1:1
brak            ← or a table; every row carries "zgoda nadzorcy RRRR-MM-DD"

A1: przepięcie — <why>      ← one line for each A<n>/Z<n>/K<n> the gate lists from od..SHA
Z1: decyzja właściciela <when> — <why>
K1: <where the comment's content now lives>
```

`A<n>` is an assertion statement of an existing test (`assert…(`, `expect…(`, `expectException`, `.toBe(`, …,
read as a whole statement, also across lines) that is gone or changed in od..SHA, or an added skip
(`markTestSkipped`, `.skip(`, …); classify `przepięcie`, `zaostrzenie` or `osłabienie`; a weakening and an added skip
need `decyzja właściciela`. Files are compared without rename detection, so a moved test lists every assertion.
`Z<n>` is any changed line, removed or added, in a ratchet file, one per file (always `decyzja właściciela`). `K<n>` is a removed comment block longer than 5 lines that did not
reappear in the diff. Run the gate once to see the list, then write the lines.

## Guidelines for the executor (audit §3, N2)

Before the first portion:
1. Run the rig old ↔ old three times and start only at 3 × IDENTYCZNY. — Noise found later tempts masking a real difference.
2. Do not change the mask, scenarios, justifications or files under `tests/rownowaznosc/` in a portion with production code; report the need to the supervisor and stop the portion. — Whoever changes the measure and the measured code at once has no proof.
3. For every action write a scenario for every role in the permission map (allowed and refused) and for every error code of the file. — Role gates move most often and show only under the right role.
4. List every entry into the file with grep: routes, crons, scripts, other classes; each gets a scenario or an "out of scope" entry with a reason. — "Unreachable over HTTP" is often reachable from a cron.
5. List the external services the file touches and prepare a stub for each; do not start while the network trap records a connection. — A live call is neither repeatable nor observed.
6. Rewrite tests that read the old file's source as text into behaviour tests before the split, in their own portion, green on the old code. — Otherwise they change together with the code and stop being proof.

In every portion:
7. One portion is one phase: 2a, or 2b, or 3, or 4; never a move together with a content change. — The AST proof works only for a pure move.
8. In 2a move method bodies unchanged, formatting and comments included; tidy up in phase 4. — Every "small fix on the way" switches the structural proof off.
9. In 2b–4, before changing a branch check that a scenario executes it; if none does, first add a scenario or a characterisation test and show it green on the old code. — A change in an unexecuted branch always gives IDENTYCZNY.
10. Change `catch` paths, rollback and lock release only with a test that executes that path. — These are the paths the rig did not cover in the pilot.
11. Keep the order read → lock → write → audit → commit; do not move building objects with I/O before `BEGIN` or after `COMMIT`. — SQL order is behaviour, and changing it creates a race.
12. Do not change the type or text of an exception, a status code, a message text or the JSON shape (`[]` vs `{}`, key order). — The frontend and other classes depend on them, and the comparator does not see all of them.
13. Write every intended deviation from 1:1 into the table "Odstępstwa od 1:1" and stop the portion until the supervisor decides. — A deviation accepted silently never reaches acceptance.
14. Call code dead only from execution (a probe, PHPStan `return.type`, a list of callers from grep), never from missing coverage. — Uncovered means untested, not unused.
15. Do not change assertions in existing tests; if a test must point at the new class, keep the assertion to the letter and record the re-pointing in the report. — Changing an assertion and the code together proves nothing.
16. Do not raise ratchet constants or widen allow-lists; report to the supervisor. — A ratchet raised by the executor is no ratchet.
17. Do not touch files outside the file under refactor and its module, comments included. — Changes on the side blur the scope and the acceptance.
18. When removing a comment longer than 5 lines, name in the report where its content went (module document, incidents, commit). — The pilot lost 6 threads of knowledge this way.
19. Do not write the refactor's history into docblocks ("Extracted from…", portion or issue numbers). — That is a chronicle, not a description of the code; it also reveals the refactor to blind graders.
20. Keep the text of every SQL query unchanged through the whole refactor. A portion that changes a query's digest runs the file's database tests on MariaDB (`scripts/ci-local/run.sh`); a swap of the time source (`NOW()` ↔ the PHP clock) needs a scenario with the database session in another time zone. — The rig runs MySQL in one time zone, production runs MariaDB (N2).

Proof of a portion:
21. Paste `raport.json` of your own run on the current SHA into the report (verdict, scenarios, `maska_sha256`, `scenariusze_sha256`, the directory), never a result from memory or from an earlier commit; the gate's own run decides. — After a compaction a "remembered" result is often another commit's.
22. Never use `--tylko` for proof (the gate does not pass it). — A partial run looks like a full one in a report.
23. The full mutant set runs on every proof; a mutant that no longer applies is fixed in the same portion (a `zmiana stanowiska` portion when it lives under the rig). — IDENTYCZNY without a positive control is not proof.
24. On RÓŻNICA assume a regression first: show the difference and its cause in the code; call it noise only after reproducing it old ↔ old. — Three false greens of the pilot came from trusting the tool.
25. Compare the full suite as the set of red test names against the base (`comm`), not as a count. — A count can match with a different set.
26. After three failed attempts at the same portion stop and give the supervisor a description of the obstacle (the gate enforces it through `budzet-prob`). — Further attempts under pressure end in bypassing the gate.

## Substitution check for phases 2b–4 (#50) — open

Phase 2a is proved by the move checker inside the rig (L15). Phases 2b–4 need the substitution map: KonkretnyTMS
#50 adds `sprawdz-przeniesienia.php --podstawienia=<map>` with JSON output. The gate's hook point is ready:

- `podstawienia: <map path>` and `podstawienia_sha256:` in the KARTA — the map is part of the frozen measure;
- `przeniesienia: <command>` — run on every portion with `{WT} {STARY} {OD} {SHA} {PODSTAWIENIA}` substituted;
  exit ≠ 0 blocks the portion; `.werdykt` from its JSON is shown when present.

Open until #50 lands: the exact command line and the JSON fields (verdict, differences outside the map, use counts,
map hash), agreed through the supervisor. Until then a KARTA without `przeniesienia:` runs 2b–4 only with a
supervisor's review of every portion (audit §7 step 5).

## Out of scope here

Chaining portions through the queue (after the first file on this gate); the blind grading of phase 4 and its new
rubric (audit §6); the owner's acceptance checklist (audit §5) — read it from the audit at acceptance.
