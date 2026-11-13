# Refactor — the reviewer's checklist

Used in step 4 of `cykl-refaktoru.md`: one fresh `code-reviewer` reviews the whole refactor branch against the spec
and every point below. The extra axis is **behaviour kept**: the refactor reshapes code, it does not change what the
code does. End each point with its evidence (the command and its result): `R<n>: ok — <evidence>`, `R<n>: F<k>` or
`R<n>: n/d — <why>`. `stanowisko` is the equivalence rig; its verdict for the final SHA is in the supervisor's brief.

1. **Scope.** `git diff --stat <old SHA>..HEAD` touches only the file under refactor, its module and their tests. A change under the rig's directory (mask, scenarios, justifications, `lib/`, scripts, mutants) is REQUEST_CHANGES without further analysis.
2. **Coverage of the change.** For every changed branch name the scenario or the test that executes it. None = REQUIRED.
3. **Error paths.** For every changed `try`/`catch`/`finally`, rollback and lock release compare the old and the new flow line by line; check that the type in `catch` resolves to the same class after a namespace change (the full name, not the short one).
4. **Order of effects.** Read → lock → write → audit → commit unchanged; no object with I/O moved across the transaction boundary.
5. **Output contract.** Status, error code, message text, exception type and JSON shape (an empty list vs an empty object, number types, `null`) unchanged. For every new DTO or presenter compare the raw body of the old and the new code on one empty and one full case.
6. **Permissions.** Every role and visibility gate of the old code has its counterpart in the new code, at the same place relative to the data read; a scenario under a restricted role exists.
7. **Tests.** List removed and changed assertions in existing tests (`git diff -- tests | grep -E '^[-+].*(assert|expect)'`); classify each as re-pointing, tightening or weakening; a weakening without the owner's decision = REQUEST_CHANGES.
8. **Ratchets.** A changed constant, allow-list or exclusion in a measuring script without the owner's decision = REQUEST_CHANGES.
9. **Dead code.** Every removal has proof from execution or a list of callers; "not covered" is not proof.
10. **Defects from before the refactor.** A behaviour defect you find: check it on the old SHA. Identical there → report it as "sprzed refaktoru" for a separate issue and do not block the refactor with it. Absent there → a regression, CRITICAL.
11. **Comments.** New docblocks are true to the code; no refactor chronicle ("extracted from…", portion or issue numbers).
12. **SQL text.** The text of every query stays as it was through the whole refactor (audit N2: the rig runs MySQL, production MariaDB, one time zone). A change to the digest of any query (the rig's `sql` channel) needs the file's database tests run on MariaDB (`scripts/ci-local/run.sh`) with the result pasted; a swap of the time source (`NOW()` ↔ the PHP clock) is REQUIRED unless a scenario runs the database session in a time zone other than PHP's.
