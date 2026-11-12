export type SessionInfo = {
  repo: string | null
  branch: string | null
  model: string
  contextTokens: number | null
  contextWindow: number
  weeklyPercent: number | null
}

declare module 'claude-code' {
  interface PluginState {
    'pasek': { info: SessionInfo | null }
  }
}
