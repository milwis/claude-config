import { atom, read, update } from 'claude-code'
import type { Color, EngineInterface, Register, SessionContextUsage, SessionRateLimit } from 'claude-code'

import type { SessionInfo } from '../types'

const info = atom({ plugin: 'session-bar', key: 'info' } as const, null)

const BAR_CELLS = 20

// "git@github.com:owner/name.git" / "https://github.com/owner/name.git" → "owner/name"
const repoFromRemote = (remote: string): string | null => {
  const m = remote.match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?\/?$/)
  return m?.[1] ?? null
}

const basename = (path: string): string => path.split('/').filter(Boolean).pop() ?? path

// "claude-opus-5-5[1m]" → "Opus 5.5 [1m]"; nazwy już czytelne zostają bez zmian
const prettyModel = (raw: string): string => {
  const m = raw.match(/^claude-([a-z]+)-(\d+)(?:-(\d+))?(.*)$/i)
  if (!m || !m[1] || !m[2]) return raw
  const family = m[1].charAt(0).toUpperCase() + m[1].slice(1)
  const version = m[3] ? `${m[2]}.${m[3]}` : m[2]
  const suffix = (m[4] ?? '').replace(/^-\d{8}/, '').trim()
  return suffix ? `${family} ${version} ${suffix}` : `${family} ${version}`
}

const kilo = (tokens: number): string => `${Math.round(tokens / 1000)}k`

const fillColor = (percent: number): Color =>
  percent >= 85 ? 'error' : percent >= 60 ? 'warning' : 'success'

const refresh = async (
  $: EngineInterface,
  measured?: { context: SessionContextUsage; rateLimits: SessionRateLimit[] },
): Promise<void> => {
  const usage = measured ?? (await $.session.usage())
  const [repo, model] = await Promise.all([$.session.repo(), $.session.model()])

  let branch: string | null = null
  try {
    const r = await $.process.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'], { timeoutMs: 3000 })
    if (r.exitCode === 0) branch = r.stdout.trim() || null
  } catch {
    branch = null
  }

  const repoName = repo ? (repo.remote ? repoFromRemote(repo.remote) : null) ?? basename(repo.root) : null
  const weekly = usage.rateLimits.find(l => l.kind === 'seven_day')

  const next: SessionInfo = {
    repo: repoName,
    branch,
    model: prettyModel(model),
    contextTokens: usage.context.tokens ?? null,
    contextWindow: usage.context.window,
    weeklyPercent: weekly ? weekly.percentUsed : null,
  }
  await update($, info, () => next)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    return result
  })

  on('session.measure', async ($, e, next) => {
    await refresh($, e)
    return next(e)
  })

  // gałąź mogła się zmienić w trakcie tury (checkout, worktree)
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const s = await read($, info)
    if (e.props.hasSurvey || s === null) {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)

    const percent = s.contextTokens === null || s.contextWindow <= 0
      ? 0
      : Math.min(100, (s.contextTokens / s.contextWindow) * 100)
    const filled = Math.round((percent / 100) * BAR_CELLS)

    return (
      <Box flexDirection="row">
        <Text bold>{s.repo ?? '—'}</Text>
        <Text dimColor> · </Text>
        <Text color="suggestion">{s.branch ?? '—'}</Text>
        <Text dimColor> · </Text>
        <Text color="claude">{s.model}</Text>
        <Text dimColor> · </Text>
        <Text color={fillColor(percent)}>{'█'.repeat(filled)}</Text>
        <Text dimColor>{'░'.repeat(BAR_CELLS - filled)}</Text>
        <Text> {s.contextTokens === null ? '—' : kilo(s.contextTokens)}/{kilo(s.contextWindow)}</Text>
        <Text dimColor> · tydz. </Text>
        <Text color={s.weeklyPercent === null ? 'inactive' : fillColor(s.weeklyPercent)}>
          {s.weeklyPercent === null ? '—' : `${s.weeklyPercent}%`}
        </Text>
      </Box>
    )
  })
}
