export type Issue = {
  number: number
  title: string
  url: string
  createdAt: string
  priority: number | null
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
