import { atom, read, update } from 'claude-code'
import type { Color, EngineInterface, Register, RenderChildren } from 'claude-code'

import type { Issue, IssuesSnapshot } from '../types'

const PANE = 'issues'
const STALE_MS = 5 * 60 * 1000
// kolejka /roadmapa zamyka issues w innych sesjach — odświeżaj w tle, także gdy ta stoi
const REFRESH_MS = 2 * 60 * 1000

const snapshot = atom({ plugin: 'issues-pane', key: 'snapshot' } as const, null)
const isLoading = atom({ plugin: 'issues-pane', key: 'isLoading' } as const, false)

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
  if (/^P[0-9]$/i.test(label)) return null
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

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({ name: 'issues', description: 'Otwiera panel issues i odświeża listę' })
    void $.ui.open({ id: PANE, title: 'Issues' })
    void refresh($)
    poll?.cancel()
    poll = $.clock.every(REFRESH_MS, () => void refresh($))
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

    const header = (
      <Box flexDirection="row" marginBottom={1}>
        <Text bold>📋 {s ? `${s.issues.length} otwartych` : 'Issues'}</Text>
        <Text dimColor>{loading ? '  ⟳ odświeżam…  ' : s ? `  ${hhmm(s.fetchedAt)}  ` : '  '}</Text>
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
