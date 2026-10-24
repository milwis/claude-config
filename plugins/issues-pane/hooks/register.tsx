import { atom, read, update } from 'claude-code'
import type { Color, EngineInterface, Register, RenderChildren } from 'claude-code'

import type { Issue, IssuesSnapshot } from '../types'

const PANE = 'issues'
const STALE_MS = 5 * 60 * 1000
// kolejka /roadmapa zamyka issues w innych sesjach — odświeżaj w tle, także gdy ta stoi
const REFRESH_MS = 2 * 60 * 1000

const snapshot = atom({ plugin: 'issues-pane', key: 'snapshot' } as const, null)
const isLoading = atom({ plugin: 'issues-pane', key: 'isLoading' } as const, false)
const working = atom({ plugin: 'issues-pane', key: 'working' } as const, [] as number[])
const frame = atom({ plugin: 'issues-pane', key: 'frame' } as const, 0)

const WORKING_POLL_MS = 20 * 1000
const FRAME_MS = 300
// worktree agenta liczy się jako aktywny, gdy git ruszał jego indeks w tym oknie
const ACTIVE_MS = 10 * 60 * 1000
const WIP_LABEL = 'status:w-trakcie'

type GhIssue = {
  number: number
  title: string
  url: string
  createdAt: string
  labels: { name: string }[]
}

// Etykiety repo: "P0".."P3"; najniższa cyfra wygrywa, brak etykiety = null
const priorityOf = (labels: { name: string }[]): number | null => {
  const found = labels
    .map(l => /^P([0-9])$/i.exec(l.name)?.[1])
    .filter((d): d is string => d !== undefined)
    .map(Number)
  return found.length ? Math.min(...found) : null
}

// Priorytet rosnąco (bez priorytetu na końcu), w ramach priorytetu od najstarszych
const byPriorityThenAge = (a: Issue, b: Issue): number => {
  const pa = a.priority ?? Number.MAX_SAFE_INTEGER
  const pb = b.priority ?? Number.MAX_SAFE_INTEGER
  return pa !== pb ? pa - pb : a.createdAt.localeCompare(b.createdAt)
}

type PriorityStyle = { color: Color; badge: string; name: string }

// Kolory jak etykiety P0-P3 na GitHubie (P3 przyciemnione, żeby było czytelne na jasnym tle)
const PRIORITY: Record<number, PriorityStyle> = {
  0: { color: '#B60205', badge: ' P0 ', name: 'krytyczne' },
  1: { color: '#D93F0B', badge: ' P1 ', name: 'wysokie' },
  2: { color: '#C99A00', badge: ' P2 ', name: 'średnie' },
  3: { color: '#3B7DD8', badge: ' P3 ', name: 'niskie' },
}
const NO_PRIORITY: PriorityStyle = { color: '#6E7781', badge: ' —  ', name: 'bez priorytetu' }

const priorityStyle = (p: number | null): PriorityStyle => (p === null ? undefined : PRIORITY[p]) ?? NO_PRIORITY

// Ikony bez selektora wariantu (U+FE0F) — w terminalu mają stałą szerokość 2 kolumn
const MODULE_ICON: Record<string, string> = {
  faktury: '🧾', korekty: '📝', noty: '📄', ksef: '🏦', fakir: '📤', 'money-vat': '💰',
  platnosci: '💳', zakupy: '🛒', warsztat: '🔧', magazyn: '📦', gps: '📍', kierowcy: '👤',
  pojazdy: '🚚', klienci: '🤝', zlecenia: '📋', terminarz: '📅', ui: '🎨', tabele: '📊',
  analityka: '📈', api: '🔌', security: '🔒', database: '💾', cron: '⏰', sms: '💬',
  testy: '🧪', ddd: '🧩', wspolbieznosc: '🔀',
}

const TYPE_STYLE: Record<string, { icon: string; name: string; color: Color }> = {
  bug: { icon: '🐞', name: 'bug', color: 'error' },
  'point-fix': { icon: '🩹', name: 'poprawka', color: 'success' },
  structural: { icon: '🧱', name: 'strukturalne', color: 'merged' },
  analysis: { icon: '🔍', name: 'analiza', color: 'suggestion' },
  pomysl: { icon: '💡', name: 'pomysł', color: 'warning' },
  test: { icon: '✅', name: 'test', color: 'suggestion' },
}

type Tag = { text: string; color?: Color }

// Pozostałe etykiety repo; nieznane pokazuje fallback 🏷
const LABEL_STYLE: Record<string, Tag> = {
  'srodowisko:web': { text: '🌐 web' },
  'srodowisko:lokalne': { text: '💻 lokalne' },
  'status:odlozone': { text: '⏸ odłożone', color: 'warning' },
  'status:do-scalenia': { text: '🔀 do scalenia', color: 'merged' },
  'status:zrobione-lokalnie': { text: '🏁 zrobione lokalnie', color: 'success' },
  'weryfikacja:reczna': { text: '👀 weryfikacja ręczna', color: 'warning' },
  'tor:remediacja-danych': { text: '🩺 remediacja danych', color: 'warning' },
  'security-audit': { text: '🔒 skan zależności', color: 'error' },
  'security-audit-tracker': { text: '📡 tracker skanu' },
  request: { text: '💡 pomysł', color: 'warning' },
}

// Etykieta → wpis drugiej linii; priorytet pomijany, bo niesie go nagłówek grupy
const tagOf = (label: string): Tag | null => {
  // priorytet niesie nagłówek grupy, pracę agenta — gwiazdka przy tytule
  if (/^P[0-9]$/i.test(label) || label === WIP_LABEL) return null
  if (label.startsWith('modul:')) {
    const m = label.slice('modul:'.length)
    return { text: `${MODULE_ICON[m] ?? '🏷'} ${m}` }
  }
  if (label.startsWith('typ:')) {
    const t = TYPE_STYLE[label.slice('typ:'.length)]
    return t ? { text: `${t.icon} ${t.name}`, color: t.color } : { text: `🏷 ${label}` }
  }
  if (label.startsWith('audyt-360-')) return { text: `🧭 audyt 360 (${label.slice('audyt-360-'.length)})`, color: 'suggestion' }
  return LABEL_STYLE[label] ?? { text: `🏷 ${label}` }
}

// Kolejność w linii: typ, moduły, statusy, środowisko, reszta
const tagRank = (label: string): number =>
  label.startsWith('typ:') || label === 'request' ? 0
    : label.startsWith('modul:') ? 1
      : label.startsWith('status:') || label.startsWith('weryfikacja:') || label.startsWith('tor:') ? 2
        : label.startsWith('srodowisko:') ? 3
          : 4

const withPrefix = (labels: string[], prefix: string): string[] =>
  labels.filter(l => l.startsWith(prefix)).map(l => l.slice(prefix.length))

const ageDays = (iso: string, now: number): number =>
  Math.max(0, Math.floor((now - Date.parse(iso)) / 86_400_000))

const hhmm = (ms: number): string => {
  const d = new Date(ms)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

// Gwiazdka Claude'a jak w spinnerze Claude Code; bez ✳, które w części fontów rysuje się jako emoji na 2 kolumny
const SPIN = ['·', '✢', '✶', '✻', '✽', '✻', '✶', '✢']

// Nad issue pracuje agent, gdy kolejka /roadmapa ma je w pliku w-toku albo worktree gałęzi
// agent/…<numer> był niedawno ruszany przez gita (każde status/add/commit odświeża jego indeks)
// null = nie da się ustalić (poza repo, błąd gita): wtedy nie ruszamy etykiet
const detectWorking = async ($: EngineInterface): Promise<{ root: string; nums: number[] } | null> => {
  const found = new Set<number>()
  let root: string
  try {
    const common = await $.process.run(
      ['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'],
      { timeoutMs: 3000 },
    )
    if (common.exitCode !== 0) return null
    // sesja może stać w worktree, a kolejka trzyma stan w drzewie głównym
    root = common.stdout.trim().replace(/\/\.git\/?$/, '')

    try {
      const n = Number((await $.fs.read(`${root}/.claude/tmp/kolejka/w-toku`)).trim())
      if (Number.isInteger(n) && n > 0) found.add(n)
    } catch {
      // brak pliku = kolejka nic nie robi
    }

    const list = await $.process.run(['git', 'worktree', 'list', '--porcelain'], { timeoutMs: 5000 })
    if (list.exitCode === 0) {
      const now = await $.clock.now()
      for (const block of list.stdout.split('\n\n')) {
        const path = /^worktree (.+)$/m.exec(block)?.[1]
        const nr = /^branch refs\/heads\/agent\/\D*(\d+)/m.exec(block)?.[1]
        if (!path || !nr) continue
        try {
          const gitdir = /^gitdir: (.+)$/m.exec(await $.fs.read(`${path}/.git`))?.[1]?.trim()
          if (!gitdir) continue
          const st = await $.fs.stat(`${gitdir}/index`)
          if (now - st.mtimeMs < ACTIVE_MS) found.add(Number(nr))
        } catch {
          // worktree bez indeksu albo usunięty w międzyczasie
        }
      }
    }
  } catch {
    return null
  }
  return { root, nums: [...found].sort((a, b) => a - b) }
}

// Etykieta niesie informację na inne komputery: ten komputer zakłada ją na issues, nad którymi pracuje
// lokalnie, i zdejmuje tylko te, które sam założył (rejestr w $.store, per repo) — cudzych nie rusza
let labelReady = false
const syncLabels = async ($: EngineInterface, root: string, nums: number[]): Promise<void> => {
  const key = `owned:${root}`
  const stored = await $.store.get(key)
  const owned = new Set<number>(Array.isArray(stored) ? stored.filter((n): n is number => typeof n === 'number') : [])
  const gh = (args: string[]) => $.process.run(['gh', ...args], { timeoutMs: 20_000 })

  for (const n of nums.filter(n => !owned.has(n))) {
    if (!labelReady) {
      const r = await gh(['label', 'create', WIP_LABEL, '--color', 'D97757', '--force',
        '--description', 'Agent pracuje nad tym issue (ustawia mod issues-pane)'])
      if (r.exitCode !== 0) return
      labelReady = true
    }
    if ((await gh(['issue', 'edit', String(n), '--add-label', WIP_LABEL])).exitCode === 0) owned.add(n)
  }
  for (const n of [...owned].filter(n => !nums.includes(n))) {
    if ((await gh(['issue', 'edit', String(n), '--remove-label', WIP_LABEL])).exitCode === 0) owned.delete(n)
  }
  await $.store.set(key, [...owned])
}

let syncing = false
const refreshWorking = async ($: EngineInterface): Promise<void> => {
  const detected = await detectWorking($)
  if (detected === null) return
  const prev = await read($, working)
  if (detected.nums.join() !== prev.join()) await update($, working, () => detected.nums)
  if (syncing) return
  syncing = true
  try {
    await syncLabels($, detected.root, detected.nums)
  } catch {
    // brak gh/sieci: spróbujemy przy następnym cyklu
  } finally {
    syncing = false
  }
}

// lokalnie wykryte ∪ oznaczone etykietą przez inne komputery
const busyOf = (local: number[], s: IssuesSnapshot | null): number[] => [
  ...new Set([...local, ...(s?.issues ?? []).filter(i => (i.labels ?? []).includes(WIP_LABEL)).map(i => i.number)]),
]

const refresh = async ($: EngineInterface): Promise<void> => {
  if (await read($, isLoading)) return
  await update($, isLoading, () => true)

  let next: IssuesSnapshot
  try {
    const r = await $.process.run(
      ['gh', 'issue', 'list', '--state', 'open', '--limit', '500', '--json', 'number,title,url,createdAt,labels'],
      { timeoutMs: 30_000 },
    )
    if (r.exitCode !== 0) {
      next = { issues: [], fetchedAt: await $.clock.now(), error: r.stderr.trim() || `gh exit ${r.exitCode}` }
    } else {
      const raw = JSON.parse(r.stdout) as GhIssue[]
      const issues = raw
        .map((i): Issue => ({
          number: i.number,
          title: i.title,
          url: i.url,
          createdAt: i.createdAt,
          priority: priorityOf(i.labels),
          labels: i.labels.map(l => l.name),
        }))
        .sort(byPriorityThenAge)
      next = { issues, fetchedAt: await $.clock.now(), error: null }
    }
  } catch (err) {
    next = { issues: [], fetchedAt: await $.clock.now(), error: String(err) }
  }

  await update($, snapshot, () => next)
  await update($, isLoading, () => false)
}

const refreshIfStale = async ($: EngineInterface): Promise<void> => {
  const s = await read($, snapshot)
  if (s === null || (await $.clock.now()) - s.fetchedAt > STALE_MS) await refresh($)
}

export const register: Register = on => {
  let poll: { cancel: () => void } | null = null
  let workingPoll: { cancel: () => void } | null = null
  let animation: { cancel: () => void } | null = null

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({ name: 'issues', description: 'Otwiera panel issues i odświeża listę' })
    void $.ui.open({ id: PANE, title: 'Issues' })
    // stan przeżywa przeładowanie moda: flaga z pobierania przerwanego reloadem blokowałaby refresh na zawsze
    await update($, isLoading, () => false)
    void refresh($)
    poll?.cancel()
    poll = $.clock.every(REFRESH_MS, () => void refresh($))
    void refreshWorking($)
    workingPoll?.cancel()
    workingPoll = $.clock.every(WORKING_POLL_MS, () => void refreshWorking($))
    // klatki tylko, gdy ktoś pracuje — inaczej panel się nie przerysowuje
    animation?.cancel()
    animation = $.clock.every(FRAME_MS, async () => {
      if (busyOf(await read($, working), await read($, snapshot)).length > 0) await update($, frame, f => f + 1)
    })
    return result
  })

  on('command.run', { command: 'issues' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Issues' })
    void refresh($)
    return { text: 'Panel issues otwarty, lista się odświeża.' }
  })

  // nowe/zamknięte issues w trakcie pracy — odśwież po turze, gdy lista ma >5 min
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    void refreshIfStale($)
    return result
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Link } = $.ui.resolve(e)
    const s = await read($, snapshot)
    const loading = await read($, isLoading)
    const now = await $.clock.now()
    const busy = busyOf(await read($, working), s)
    const f = await read($, frame)

    const header = (
      // przycisk przy prawej krawędzi: zmiana długości tekstu po lewej go nie przesuwa
      <Box flexDirection="row" width="100%" justifyContent="space-between" marginBottom={1}>
        <Box flexDirection="row">
          <Text bold>📋 {s ? `${s.issues.length} otwartych` : 'Issues'}</Text>
          {busy.length > 0 && <Text color="claude">  · w pracy: {busy.length}</Text>}
          <Text dimColor>{'  '}{loading ? '⟳ odświeżam…' : s ? hhmm(s.fetchedAt) : ''}</Text>
        </Box>
        <Button key="refresh" label="Odśwież" onPress={() => refresh($)} />
      </Box>
    )

    if (s === null) {
      return (
        <Box flexDirection="column">
          {header}
          <Text dimColor>Pobieram listę z GitHuba…</Text>
        </Box>
      )
    }

    if (s.error !== null) {
      return (
        <Box flexDirection="column">
          {header}
          <Text color="error" wrap="wrap">⚠ {s.error}</Text>
        </Box>
      )
    }

    const card = (issue: Issue): RenderChildren => {
      // snapshot sprzed przeładowania moda nie ma jeszcze pola labels
      const labels: string[] = issue.labels ?? []
      const modules = withPrefix(labels, 'modul:')
      const types = withPrefix(labels, 'typ:')
      const type = types.map(t => TYPE_STYLE[t]).find(t => t !== undefined)
      const icon = modules.map(m => MODULE_ICON[m]).find(m => m !== undefined) ?? type?.icon ?? '•'
      const isParked = labels.includes('status:odlozone')
      const tags = [...labels]
        .sort((a, b) => tagRank(a) - tagRank(b))
        .map(tagOf)
        .filter((t): t is Tag => t !== null)
      tags.push({ text: `${ageDays(issue.createdAt, now)} dni` })

      return (
        <Box key={`i${issue.number}`} flexDirection="column" marginBottom={1} paddingLeft={1}>
          <Box flexDirection="row">
            {busy.includes(issue.number) && (
              // stała szerokość: zmiana klatki nie może przesunąć tytułu ani zawinąć wiersza
              <Box width={2} flexShrink={0}>
                <Text color="claude" bold wrap="truncate">{SPIN[f % SPIN.length]}</Text>
              </Box>
            )}
            <Text>{icon} </Text>
            <Link href={issue.url}>
              <Text bold dimColor={isParked} wrap="truncate-end">
                #{issue.number} {issue.title}
              </Text>
            </Link>
          </Box>
          <Box flexDirection="row" flexWrap="wrap" paddingLeft={3}>
            {tags.map((t, i) => (
              <Text key={`t${i}`} color={t.color} dimColor={t.color === undefined}>
                {i > 0 ? ' · ' : ''}{t.text}
              </Text>
            ))}
          </Box>
        </Box>
      )
    }

    const rows: RenderChildren[] = []
    let group: number | null | undefined = undefined
    for (const issue of s.issues) {
      if (issue.priority !== group) {
        group = issue.priority
        const style = priorityStyle(group)
        const count = s.issues.filter(i => i.priority === group).length
        rows.push(
          <Box key={`g${group ?? 'x'}`} flexDirection="row" marginBottom={1}>
            <Text bold color="inverseText" backgroundColor={style.color}>{style.badge}</Text>
            <Text bold color={style.color}> {style.name}</Text>
            <Text dimColor> · {count}</Text>
          </Box>,
        )
      }
      rows.push(card(issue))
    }

    return (
      <Box flexDirection="column">
        {header}
        {s.issues.length === 0 && <Text dimColor>🎉 Brak otwartych issues.</Text>}
        {rows}
      </Box>
    )
  })
}
