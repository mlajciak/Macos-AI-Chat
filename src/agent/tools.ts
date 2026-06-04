export type ToolKind =
  | 'thinking'
  | 'workspace_context'
  | 'read_file'
  | 'describe_file'
  | 'generate_image'
  | 'generate_3d_asset'
  | 'render_asset'
  | 'validate_asset'
  | 'run_workspace_command'

export type AgentToolCard = {
  id: string
  kind: ToolKind
  title: string
  body: string
}

export const toolTitles: Record<ToolKind, string> = {
  thinking: 'Thinking',
  workspace_context: 'Workspace context',
  read_file: 'Read file',
  describe_file: 'Describe engineering file',
  generate_image: 'Generate image reference',
  generate_3d_asset: 'Generate 3D asset',
  render_asset: 'Render asset',
  validate_asset: 'Validate asset',
  run_workspace_command: 'Run workspace command',
}

export function createToolCard(kind: ToolKind, id: string): AgentToolCard {
  return {
    id,
    kind,
    title: toolTitles[kind],
    body: '',
  }
}
