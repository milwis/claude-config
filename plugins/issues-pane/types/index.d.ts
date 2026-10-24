export type Issue = {
  number: number
  title: string
  url: string
  createdAt: string
  priority: number | null
  labels: string[]
}

export type IssuesSnapshot = {
  issues: Issue[]
  fetchedAt: number
  error: string | null
}

declare module 'claude-code' {
  interface PluginState {
    'issues-pane': { snapshot: IssuesSnapshot | null; isLoading: boolean }
  }
}
