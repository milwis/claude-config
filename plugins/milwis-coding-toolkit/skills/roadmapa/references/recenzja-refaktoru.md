# Refactor — the reviewer's checklist

Used in step 5 of the `refaktor` skill: one fresh `code-reviewer` reviews the whole refactor branch against the spec
and every point below. The extra axis is **behaviour kept**: the refactor reshapes code, it does not change what the
code does. End each point with its evidence (the command and its result): `R<n>: ok — <evidence>`, `R<n>: F<k>` or
`R<n>: n/d — <why>`. `stanowisko` is the equivalence rig; its verdict for the final SHA is in the supervisor's brief.

1. **Scope.** `git diff --stat <old SHA>..HEAD` touches only the file under refactor, its module and their tests. A change under the rig's directory (mask, scenarios, justifications, `lib/`, scripts, mutants) is REQUEST_CHANGES without further analysis — the one exception is new files in `mutanty/<Class>-po/` (point 21).
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
13. **`strict_types`.** Compare `declare(strict_types=1)` of every target file with the source file of each moved call. A call moved into a strict file stops coercing its arguments (`'12'` → `int` now throws `TypeError`): for every such call show that every caller passes the declared type, or a scenario with a non-matching type gives IDENTYCZNY.
14. **`catch` scope and exits.** A `catch` narrowed or widened (`PDOException` vs `Exception` vs `Throwable`), or an `exit`/`ApiError::send` turned into an exception: every caller from outside the module (other controllers, cron, scripts) gets the same response, status and output as before — name the callers and their path.
15. **Transactions and locks.** Transaction boundaries, lock order (`FOR UPDATE`), write order and the `commit`/`rollBack` point are unchanged line by line; a lock taken in another order or a write moved across `commit` = REQUIRED.
16. **Logs and output order.** Log channel and text are unchanged (`static::class`, `__CLASS__`, `get_class($this)` give another channel name after a move); the order of output, `header()` calls and `http_response_code()` is unchanged.
17. **JSON shape.** Key order in arrays returned as JSON and the `json_encode` flags (`JSON_UNESCAPED_UNICODE`, `JSON_PRESERVE_ZERO_FRACTION`, `JSON_THROW_ON_ERROR`, …) are unchanged.
18. **Float and decimal arithmetic.** The same order of operations and of rounding (`round`, `number_format`, `bcadd`, casts) — bit-identical results; a regrouped sum or a moved rounding = REQUIRED unless a scenario on a rounding boundary gives IDENTYCZNY.
19. **State and connections.** Static state and singletons keep their lifetime; the number of connections and of queries per request is unchanged (the SQL sequence is a channel: a query added, removed, merged or split is a difference even when the data are equal).
20. **Comparisons and defaults.** `==` ↔ `===`, `empty` ↔ `isset` ↔ `=== null`, `?:` ↔ `??` and default parameter values are unchanged for every input type the old code accepted (`'0'`, `''`, `null`, `[]`).
21. **Mutants after the refactor.** `mutanty/<Class>-po/` has exactly the file names of `mutanty/<Class>/` and only added files; for every pair show the same bug in its new place (same operator, same rule, same observable effect, same `# scenariusze:` preamble) — not an easier one (a mutant moved to dead code, to a branch no scenario reaches, or weakened to a cosmetic change = REQUIRED).
