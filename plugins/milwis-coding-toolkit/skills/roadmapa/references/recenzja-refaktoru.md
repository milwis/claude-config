# Refactor portion — the reviewer's checklist

Source: audit of the refactor procedure (claude-config #46, `docs/plans/2026-11-12-audyt-procedury-refaktoru.md` §4, point 17 from N2),
added in toolkit v1.12.0 (#27). The brief of a refactor portion names this file; `code-reviewer` applies every point.
The extra axis is **behaviour kept**: the portion moves or reshapes code, it does not change what the code does.
APPROVE needs every point. End each point with its evidence (the command and its result).

**Output contract (the refactor gate reads it, `bramka.sh --refaktor`).** After `Otwarte:`, the line
`Lista-refaktoru: <first 12 hex of shasum -a 256 of this file>`, then one line per point, in order:
`R<n>: ok — <evidence>`, `R<n>: F<k>` (the finding it raised) or `R<n>: n/d — <why it does not apply>`.
A missing point line fails the gate. A refactor portion whose brief does not name this file is CRITICAL
`brief without the refactor checklist`: report it and review against this list anyway.

The project words: `KARTA` is the file's card (hashes of the mask, scenarios, justifications and rig tools, the
frozen paths, the budget), `stanowisko` is the equivalence rig, `raport.json`/`meta.json` its verdict files, phase
2a is a pure move, 2b–4 change the code's shape.

1. **Scope.** `git diff --stat` of the portion touches only the file under refactor, its module and their tests. A change under the rig's directory (mask, scenarios, justifications, `lib/`, scripts, mutants) outside a portion marked "zmiana stanowiska" is REQUEST_CHANGES without further analysis.
2. **Phase.** The portion declares one phase. In 2a run the move checker (`sprawdz-przeniesienia.php`) yourself and paste its result. In 2b–4 check every difference against the substitution map, not a sample.
3. **Proof.** Read `raport.json` and `meta.json` for the portion's SHA yourself; compare `maska_sha256` and `scenariusze_sha256` with the KARTA; reject a run with `--tylko`, `--kalibracja`, `--mutant-b`, a skipped positive control, or a run on another SHA.
4. **Positive control.** The full mutant set applied and every mutant gave RÓŻNICA. Add at least two mutants of your own on lines the portion changed and run them on the rig (`--mutant-b`), not only on PHPUnit.
5. **Coverage of the change.** For every changed branch in 2b–4 name the scenario or the test that executes it. None = REQUIRED.
6. **Error paths.** For every changed `try`/`catch`/`finally`, rollback and lock release compare the old and the new flow line by line; check that the type in `catch` resolves to the same class after a namespace change (the full name, not the short one).
7. **Order of effects.** Read → lock → write → audit → commit unchanged; no object with I/O moved across the transaction boundary.
8. **Output contract.** Status, error code, message text, exception type and JSON shape (an empty list vs an empty object, number types, `null`) unchanged. For every new DTO or presenter compare the raw body of the old and the new code on one empty and one full case.
9. **Permissions.** Every role and visibility gate of the old code has its counterpart in the new code, at the same place relative to the data read; a scenario under a restricted role exists.
10. **Tests.** List removed and changed assertions in existing tests (`git diff -- tests | grep -E '^[-+].*(assert|expect)'`); classify each as re-pointing, tightening or weakening; a weakening without the owner's decision = REQUEST_CHANGES.
11. **Ratchets.** A changed constant, allow-list or exclusion in a measuring script without the owner's decision = REQUEST_CHANGES.
12. **Dead code.** Every removal has proof from execution or a list of callers; "not covered" is not proof.
13. **Deviations.** The table "Odstępstwa od 1:1" in the portion report matches the diff; confirm each deviation by running the old and the new code on the same input; a deviation missing from the table = REQUEST_CHANGES.
14. **Defects from before the refactor.** A behaviour defect you find: check it on the old SHA. Identical there → report it as "sprzed refaktoru" for a separate issue and do not block the portion with it. Absent there → a regression, CRITICAL.
15. **Comments.** Removed blocks longer than 5 lines have their destination named in the portion report; new docblocks are true to the code; no refactor chronicle ("extracted from…", portion or issue numbers).
16. **Size.** Count the portion's size from the number of changed branches, not from `--stat`: a pure 600-line move with a green move check is small, 40 lines in 2b are medium.
17. **SQL text.** The text of every query stays as it was through the whole refactor (audit N2: the rig runs MySQL, production MariaDB, one time zone). A portion that changes the digest of any query (the rig's `sql` channel) needs the file's database tests run on MariaDB (`scripts/ci-local/run.sh`) with the result pasted; a swap of the time source (`NOW()` ↔ the PHP clock) is REQUIRED unless a scenario runs the database session in a time zone other than PHP's.
