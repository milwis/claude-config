import { atom, read, update } from 'claude-code'
import type { Color, EngineInterface, Register, RenderChildren } from 'claude-code'

import type { Issue, IssuesSnapshot } from '../types'

const PANE = 'issues'
const STALE_MS = 5 * 60 * 1000

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

const priorityColor = (p: number | null): Color =>
  p === 0 ? 'error' : p === 1 ? 'warning' : p === 2 ? 'suggestion' : 'inactive'

const ageDays = (iso: string, now: number): number =>
  Math.max(0, Math.floor((now - Date.parse(iso)) / 86_400_000))

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
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({ name: 'issues', description: 'Otwiera panel issues i odświeża listę' })
    void $.ui.open({ id: PANE, title: 'Issues' })
    void refresh($)
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
      <Box flexDirection="row">
        <Text bold>{s ? `${s.issues.length} otwartych` : 'Issues'}</Text>
        <Text dimColor>{loading ? '  odświeżam…  ' : '  '}</Text>
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
          <Text color="error" wrap="wrap">{s.error}</Text>
        </Box>
      )
    }

    const rows: RenderChildren[] = []
    let group: number | null | undefined = undefined
    for (const issue of s.issues) {
      if (issue.priority !== group) {
        group = issue.priority
        const count = s.issues.filter(i => i.priority === group).length
        rows.push(
          <Text key={`g${group ?? 'x'}`} bold color={priorityColor(group)}>
            {group === null ? 'Bez priorytetu' : `P${group}`} ({count})
          </Text>,
        )
      }
      rows.push(
        <Box key={`i${issue.number}`} flexDirection="row">
          <Text dimColor>{ageDays(issue.createdAt, now)}d </Text>
          <Link href={issue.url}>
            <Text wrap="truncate-end">#{issue.number} {issue.title}</Text>
          </Link>
        </Box>,
      )
    }

    return (
      <Box flexDirection="column">
        {header}
        {s.issues.length === 0 && <Text dimColor>Brak otwartych issues.</Text>}
        {rows}
      </Box>
    )
  })
}
