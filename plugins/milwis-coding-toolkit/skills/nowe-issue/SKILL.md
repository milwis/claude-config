---
name: nowe-issue
description: "Use whenever a new GitHub issue must be created — a bug found during work, a spin-off from NOWE PROBLEMY, an audit finding, a `too-big.` report, or a large problem the owner wants broken down. Sizes every issue so ONE agent running task-lifecycle (the roadmapa queue, or a single Claude Code web session) can finish it; a bigger problem becomes an umbrella plus several or a dozen independent portions. Every issue gets the mandatory label axes, read live from the repo: modul:*, P0-P3, srodowisko:web|lokalne, typ:*. Checks duplicates first, writes measured anchors into the body, validates labels after creation with scripts/sprawdz-etykiety.sh."
---

# Nowe issue — one issue = one task-lifecycle run

**Core:** an issue is a work order for ONE fresh agent running `task-lifecycle` with no owner at hand — the
roadmapa queue's L2 or a single Claude Code web session. If that agent cannot finish it in one run, the
issue is wrong, not the agent: split it before it is created, never after it fails.

**Announce at start:** "I'm using the nowe-issue skill."

## 1. Read the repo's labels — never from memory

```bash
gh label list --limit 300 --json name,description -q '.[] | [.name, .description] | @tsv' | sort
```

Mandatory axes (the taxonomy of KonkretnyTMS, measured 2026-09-26 — 142 open issues, 50 without `srodowisko:*`):

| axis | how many | values | how to choose |
|---|---|---|---|
| **module** | ≥ 1 | `modul:*` (api, database, faktury, ksef, money-vat, security, ui, warsztat, zlecenia, …) | from the paths the change touches; one per module actually changed, not per module mentioned |
| **priority** | exactly 1 | `P0` krytyczny — blocks deploy / production broken / data loss / exploitable now · `P1` wysoki — this cycle: wrong money/VAT, visible bug without a workaround · `P2` średni — planned · `P3` niski — can wait | from the consequence for the user, not the size of the fix |
| **environment** | exactly 1 | `srodowisko:web` · `srodowisko:lokalne` | §4 |
| **type** | exactly 1 | `typ:bug` defect · `typ:point-fix` point repair · `typ:structural` fixes a whole class · `typ:test` tests/regression only · `typ:analysis` analysis/decision, no code (also the umbrella, §3) · `typ:pomysl` new functionality — owner decides | §5 for what the queue takes |

Labels set **only in special cases**: `tor:remediacja-danych` — repairing existing production data (human
decision; always its own issue, `srodowisko:lokalne`). **Never set at creation:** `status:*` (the lifecycle and
the queue own them), `security-audit`, `security-audit-tracker` (automation only), `audyt-*` (the audit
tooling), `request` (deprecated → `typ:pomysl`).

No fitting `modul:*` → ask the owner (propose a name + description); never invent a label, and never create
one without the owner's OK. A repo without these axes at all (only GitHub defaults) → show the owner the
`gh label create` commands for the taxonomy above and stop until they agree.

## 2. Before writing: duplicate check and anchors

1. **Duplicate:** `gh issue list --state all --search "<2-3 distinctive words>" --json number,title,state,labels`.
   An open duplicate gets a comment with the new evidence instead of a new issue; a closed one that regressed
   is a new issue that links it.
2. **Anchors from THIS session.** Every `file:line`, count and claim in the body comes from a command run
   now, quoted with its date and branch/SHA (`POMIAR (<command>, main <sha>, 2026-09-26): …`). Mark
   conclusions `WNIOSEK`. A `0` counts only with a positive control. The agent solving the issue starts from
   these anchors; a false anchor is one it pays to unlearn (`task-lifecycle` Step 0.3).
3. **No open decisions.** A builder stops on ambiguity (`ambiguous. ask:`) and the queue defers the issue. If
   the fix needs a choice (business rule, option A vs B, data semantics), either the owner decides now and the
   decision goes into the body, or the decision becomes its own `typ:analysis` issue that the implementation
   depends on.

## 3. Size: does it fit one task-lifecycle run?

It fits ONLY when **all** hold:

1. **One claim, one proof.** One sentence "after this, X holds"; every acceptance criterion is one command or
   one `verify-e2e` observation.
2. **task-lifecycle class Small or Standard.** Large (needs design, 3+ modules, more than 3 implementation
   steps in money/VAT/regulated code) is a plan, not an issue → split, or `brainstorming` → `writingplans` with
   the owner.
3. **Envelope:** about ≤ 10 files and ≤ 400 changed lines (the `code-reviewer` M tier — beyond it the review
   gets shallower) and at most 2 layers (migration + backend, or backend + frontend). Basis: one builder per
   layer at ≤ ~60 tool calls; one builder across three layers cost 2.7× (`task-lifecycle` Step 1, `POMIAR`
   #687). Reference split: the #437 portions — 10–19 moved call sites in 2–3 controllers each.
4. **Mergeable alone.** `main` stays green after merging just this issue — tests, latches, static analysis,
   and no half-built screen.
5. **Self-contained.** The body carries everything; the agent never needs the conversation that produced it.

Too small is also wrong: several Trivial/Small fixes in the SAME files with ONE verification surface are one
issue (the bundle rule), not several.

### Splitting — preference order

1. **By unit of one repeating pattern** (files, controllers, tables, call sites), balanced counts, disjoint
   files → portions run in parallel or in any order.
2. **By layer in dependency order** for shape changes: migration expand → backend → frontend → contract
   (`migration` skill); each step leaves `main` working.
3. **Safety net first:** a characterization test or latch as its own `typ:test` portion when the refactor has
   no proof of unchanged behaviour.
4. **By vertical slice** for functionality: each slice visible and verifiable on its own.
5. **Pull out what the queue cannot do:** production data repair (`tor:remediacja-danych`), owner decisions
   (`typ:analysis`), and — to maximise web work — the pure-logic part (`srodowisko:web`) apart from the
   wiring that needs the dev DB or a browser (`srodowisko:lokalne`).

Never split by work phase of one change (analysis / code / tests of the same thing — the tests belong to the
change) or so that an intermediate state breaks `main`.

### Umbrella

A split creates one **umbrella** first, then the portions in dependency order:

- umbrella: `typ:analysis` (it carries no code, and the queue's backlog source skips `typ:analysis`),
  priority of the problem, every `modul:*` of its portions, `srodowisko:lokalne`; body = template §6b;
- portions: title prefixed `[#<umbrella>]`, the umbrella's priority unless a portion is clearly less urgent;
- after creating the portions, edit the umbrella's checklist with their numbers (`gh issue edit --body-file`).

**Order in the queue = creation order.** The backlog picker sorts P0→P3, then oldest first, so same-priority
portions created in dependency order are taken in that order. A portion that depends on another states it in
§ Zależności — if the prerequisite was deferred, the agent reports `BLOCKED` instead of building on a missing
base.

## 4. Environment: web or local

`srodowisko:web` ONLY when all hold — otherwise `srodowisko:lokalne`:

- the acceptance criteria are provable by tests and static checks **without the dev database** (no test that
  needs live data is the proof);
- **no user-facing surface changes**, so `task-lifecycle` Step 4 (`verify-e2e`) has nothing to verify in a
  browser;
- **no production**, no local-only integrations or secrets (KSeF test env, GPS/Ruptela, SMS gateway, `.env`
  values), no owner decision during the work.

When unsure → `lokalne`. The error is asymmetric: a web agent that cannot verify ships an unverified change;
a local issue that could have been web only waits for the machine. A web result is still checked locally
before merge (the label's own description).

## 5. What the queue takes

The roadmapa backlog source takes open issues with `typ:bug` / `typ:point-fix` / `typ:structural` and a
priority, P0→P3 then oldest; it skips `typ:pomysl`, `typ:analysis`, `status:odlozone`/`do-scalenia`/
`zrobione-lokalnie`, `tor:remediacja-danych` (`roadmapa/scripts/wybierz-issue.sh`). So `typ:test` and
`typ:pomysl` issues reach an agent only through `kolejka.sh start --issues …` or a manual web session — say so
in the report when you create them.

## 6. Body templates (Polish — the repo's issue language)

Write the body to a file; an inline multi-line `--body` breaks in zsh (`roadmapa` `POMIAR` batch 2.4).

### 6a. Issue / portion

```markdown
<1–2 zdania: co jest źle i skąd to wiadomo. Dla porcji: „Porcja parasola **#<P>**. Jedno issue = jeden przebieg `/task-lifecycle`.”>

## Zakres

POMIAR (`<komenda>`, `main` <sha>, <data>): <tabela / `plik:linia` / liczby>

Poza zakresem: <czego nie ruszać — pliki innych porcji, sąsiednie defekty (osobne issue)>

## Co zrobić

1. **Triage na HEAD** — <komenda, która potwierdza albo obala problem>; rozjazd z Zakresem zgłoś w raporcie.
2. <krok z kotwicą `plik:linia` i wzorcem/kanonem do skopiowania + test, który go pilnuje>
3. **Testy:** <który test RED→GREEN; dowód mutacyjny: <mutant> → RED>; zapadki liczników/korpusu testów: <filtr>.

## Kryteria odbioru

- <każde sprawdzalne jedną komendą albo jedną obserwacją verify-e2e>

## Środowisko

`srodowisko:<web|lokalne>` — <czego wymaga dowód: baza dev? UI? nic z tego?>

## Zależności

<„brak” albo: Zależy od #<A>. Jeśli #<A> jest otwarte — NIE zaczynaj, zgłoś `BLOCKED: czeka na #<A>`.>

## Współbieżność

<wspólne pliki z innymi porcjami i kto rozstrzyga konflikt — albo „brak wspólnych plików”>
```

### 6b. Umbrella

```markdown
<problem, źródło (audyt / issue / raport), skala: POMIAR z komendą>

Parasol — nie do realizacji wprost (`typ:analysis`, kolejka go nie bierze). Pracę niosą porcje poniżej;
każda = jeden przebieg `/task-lifecycle`.

## Porcje

- [ ] #<a> — <tytuł> (`srodowisko:web`)
- [ ] #<b> — <tytuł> (`srodowisko:lokalne`, zależy od #<a>)

Kolejność: <a → b; c, d niezależne>

## Definicja ukończenia

<pomiar, który pokazuje, że cały problem zniknął — np. `BUDGET = 0` w zapadce>. Parasol zamyka właściciel, gdy wszystkie porcje są zamknięte.
```

## 7. Create, then validate

**Confirmation.** In a session with the owner: when the result is more than one issue, first show one table
(`# | tytuł | typ | P | modul | srodowisko | zależy od`) and create after their OK; a single issue the owner
asked for is created directly. The roadmapa lead creates spin-offs without asking — its start prompt
authorises it.

```bash
D=.claude/tmp/issues; mkdir -p "$D"          # scratch for bodies; never committed
gh issue create --title "<tytuł>" --body-file "$D/<slug>.md" \
  --label "<typ:*>" --label "<P*>" --label "<modul:*>" --label "<srodowisko:*>"
```

After the last one — the validator, then fix whatever it lists (`gh issue edit <n> --add-label …`):

```bash
<skill dir>/scripts/sprawdz-etykiety.sh <n1> <n2> …    # exit 1 = an issue misses an axis
<skill dir>/scripts/sprawdz-etykiety.sh --otwarte      # backlog audit: every open issue missing an axis
```

## 8. Report

One list: `#<n> <title> — <labels>`, the umbrella first; for a queue-able split the command
`kolejka.sh start --issues <a>,<b>,…` in dependency order; which portions are web-ready; which need
`--issues` because the backlog source skips their type (§5).

## Integration

- `task-lifecycle` — the consumer: its Step 0 classes are the sizing target; its `too-big. split:` token is
  input for this skill.
- `roadmapa` — the lead creates spin-offs from `NOWE PROBLEMY` under these rules (`references/cykl-lidera.md`
  step 6).
- `migration` — the order of layer portions for shape changes.
