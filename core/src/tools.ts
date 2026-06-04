export type ToolKind = 'thinking'

export type AgentToolCard = {
  id: string
  kind: ToolKind
  title: string
  body: string
}

export const toolTitles: Record<ToolKind, string> = {
  thinking: 'Thinking',
}

export function createToolCard(kind: ToolKind, id: string): AgentToolCard {
  return {
    id,
    kind,
    title: toolTitles[kind],
    body: '',
  }
}
