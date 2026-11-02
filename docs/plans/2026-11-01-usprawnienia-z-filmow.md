## Kontekst

Analiza 1.11.2026 trzech materiałów (dwa filmy: weryfikatory „Prove It” oraz review w zespole Claude Code; artykuł pstack part 1) względem toolkitu v1.7.8. Większość już mamy (świeży adversarialny weryfikator, `ab`, CLI + Feature Map z v1.5.49, mutanty w `bramka.sh:24-28`, poziom recenzji po `wrazliwe:` w `bramka.sh:240-245`, delta-only re-review z v1.7.4). Zostały 4 luki. **Każda ma najpierw pomiar; wdrażamy tylko tę, którą pomiar uzasadni** (zasada `retro` i polityki w `UPDATE_LOG.md`: bez POMIAR nie ma reguły).

Plan sesji: wtorek **2026-11-03**, po resecie limitu tokenów. Pliki źródłowe (nieskomitowane, lokalnie w katalogu głównym repo): `transkrypcja.txt` (2 filmy), `pstack_part1`. Nie są potrzebne do wykonania, bo wnioski są niżej.

Koszt całości jest pomijalny względem ~$34k/mies. i mediany ~$52/issue (plan `docs/plans/2026-10-21-weryfikacja-cli-feature-map.md`): weryfikatory to 2% kosztu podagentów, mediana $0,95. Wpływ na jakość to **hipoteza (WNIOSEK)** do potwierdzenia poniższymi pomiarami.

## Zakres (kolejność wykonania: C → B → A → D)

### C. Claim weryfikatora z kryteriów issue, nie z opisu buildera
- **Luka:** `verify-e2e/SKILL.md:68` definiuje `Claim under test` jako „what the builder says now works”. Brief recenzenta zabrania własnego streszczenia (`cykl-lidera.md:300`); odpowiednika dla weryfikatora nie znalazłem.
- **Pomiar najpierw:** próbka ≥ 15 briefów weryfikatora z transkryptów KonkretnyTMS (`~/.claude/projects/<slug>/*.jsonl`, podagenci z „ADVERSARIAL end-to-end verifier”). Porównać `Claim under test` z `## Kryteria` (`K1..Kn`) w `.claude/tmp/kolejka/stan-<N>.md` tego samego issue. Metryka: ile claimów pomija ≥ 1 kryterium. Najpierw sprawdzić, skąd lider bierze brief weryfikatora w praktyce (szablon skilla czy własny tekst).
- **Wdrożyć, jeśli** ≥ 2 z 15 claimów pomija kryterium. Wtedy: `Claim` = `K1..Kn` dosłownie w szablonie `verify-e2e/SKILL.md` Step 3 i w odpowiednim kroku `cykl-lidera.md`. Przy 0–1 z 15: zamknąć punkt z pomiarem, nic nie dopisywać.

### B. `retro`: błędy, które przeszły przez kolejkę
- **Luka:** `retro/SKILL.md` Step 1 ma 4 źródła (ledger, transkrypty, diff, wersja toolkitu), bez issue otwartych po merge. Wideo 2: „incident reviews ask which layer should have caught the issue”.
- **Pomiar najpierw:** lista issue typu bug otwartych po 2026-10-21, których `git blame` / `Fixes` wskazuje na merge `[roadmapa]` (przypadek #1884: fix-induced chain). Reverty odpadają jako sygnał: 2 na 1452 merge'e od 1.08 (`git log --grep='^Revert' -i`).
- **Wdrożyć:** źródło nr 5 w Step 1 `retro` + jedno pole kandydata „warstwa, która miała złapać: triage | recenzja | weryfikacja | bramka”. Jeśli znalezione < 3: tylko zdanie w skillu, bez skryptu.

### A. Audyt weryfikatora zasianym błędem
- **Luka:** mutanty mamy w recenzji i bramce, nigdy na `verify-e2e`. Z planu 21.10: 3 FAIL wobec 256 PASS na 310 weryfikatorów, więc nie wiemy, czy buildery są dobre, czy weryfikator słaby (wideo 1, rozdz. „Audit Prove It”).
- **Procedura:** w worktree wsadzić realistyczny błąd (off-by-one, odwrócony warunek, pominięty guard, zły status HTTP, zamieniona kolumna) w ostatnio zmergowaną zmianę z powierzchnią użytkownika. Odpalić świeżego weryfikatora z oryginalnym briefem, **bez** wskazania błędu. Metryka: wykrywalność = FAIL / liczba mutacji (cel próby: 5 mutacji); zapisać koszt. PASS na zasianym błędzie = poprawka skilla (brief, CLI, Feature Map), nie kolejny akapit reguł.
- **Forma:** tryb w `retro` albo osobny skill z `disable-model-invocation: true` (uruchamia tylko właściciel). Do ustalenia po pierwszej próbie.
- **Ograniczenia środowiska:** tylko worktree, nic nie trafia na `main`; porty 8095–8099; nie w trakcie pracy kolejki (`kolejka.sh status`, `pgrep -f playwright` puste); baza dev, zapisy tylko na `e2e_tmp_*`; produkcja tylko SELECT. Próbka 5 to sygnał, nie statystyka.

### D. Bezpiecznik jakościowy kolejki
- **Luka:** kolejka staje dziś tylko z przyczyn środowiskowych (2× BLOCKED z tą samą przyczyną, `cykl-lidera.md:455`; błąd systemowy, `watcher.sh:264`). Wideo 2: „we don't yet have circuit breakers that tighten approval when those numbers move”.
- **Tylko pomiar:** z ledgera policzyć serie issue z wyczerpanym limitem pętli (review 3/3, verify 3/3) albo zamknięte z `weryfikacja:reczna`. Próg (np. 3 pod rząd → stop do decyzji właściciela) wdrożyć dopiero, jeśli taka seria wystąpiła i skończyła się słabym merge'em. W przeciwnym razie zamknąć punkt z pomiarem.

## Odrzucone w tej analizie (nie wracać bez nowych danych)
Rozdzielenie agenta działającego i oceniającego (podwaja koszt weryfikatora, brak zmierzonej porażki); kasowanie testów jednostkowych na rzecz E2E (bramka mutantów i zapadki); nocny review całego kodu (zjada limit Max, `audit-360` robi to miesięcznie); `REVIEW.md` (`code-reviewer` jest wyjątkiem z v1.7.1); cloud agents i `/swarm` (odrzucone pomiarem 24.09).

## Ograniczenia wykonania
- Polityka z `UPDATE_LOG.md`: bez zmian `model:` we frontmatterze, bez reguł w plikach agentów, skill nie działa w podagencie (reguła dla podagenta = linia briefu), `code-reviewer` nietykany. Etykiety `POMIAR` / `WNIOSEK` obowiązkowe.
- Każdy wdrożony punkt: wpis w `UPDATE_LOG.md` z tym samym POMIAR, bump wersji w `plugin.json` (następna: 1.7.9), commit lokalny na `master`.
- **Bez push** i bez synca do KonkretnyTMS bez zgody właściciela (v1.7.8 też jest tylko lokalnie).

## Definicja gotowe
- [ ] Dla każdego z C, B, A, D: wynik pomiaru zapisany w komentarzu do tego issue (komenda → liczba).
- [ ] Wdrożone tylko punkty, które pomiar uzasadnił; pozostałe zamknięte z jednozdaniowym powodem.
- [ ] `UPDATE_LOG.md` + `plugin.json` zaktualizowane, rozmiary w budżecie (`task-lifecycle/SKILL.md` < 20 000 znaków).
- [ ] Dla A: liczba wykrytych / zasianych i koszt próby podane właścicielowi.
