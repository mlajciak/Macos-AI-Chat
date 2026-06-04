import { isFileMutationTool } from './apply-patches.js'

const EARLY_STREAM_EXECUTE_TOOLS = new Set([
  'create_cad',
  'create_eda',
  'create_drawing',
  'create_simulation',
  'edit_file',
  'patch_file',
  'update_overview',
  'delete_file',
])

export function toolSupportsEarlyStreamExecute(toolName: string): boolean {
  return EARLY_STREAM_EXECUTE_TOOLS.has(toolName)
}

function isCompleteJsonObject(raw: string): boolean {
  const t = raw.trim()
  if (!t.startsWith('{') || !t.endsWith('}')) return false
  try {
    JSON.parse(t)
    return true
  } catch {
    return false
  }
}

/** True when streamed tool arguments are complete JSON safe to execute. */
export function toolStreamArgsReady(toolName: string, raw: string | undefined): boolean {
  if (!raw?.trim() || !isCompleteJsonObject(raw)) return false
  let args: Record<string, unknown>
  try {
    const v = JSON.parse(raw) as unknown
    if (!v || typeof v !== 'object' || Array.isArray(v)) return false
    args = v as Record<string, unknown>
  } catch {
    return false
  }

  if (toolName.startsWith('create_') || toolName === 'edit_file' || toolName === 'update_overview') {
    const content = args.content
    if (typeof content !== 'string' || content.length === 0) return false
    if (toolName === 'update_overview') return true
    const fileName = args.fileName
    return typeof fileName === 'string' && fileName.trim().length > 0
  }

  if (toolName === 'patch_file') {
    const fileName = args.fileName
    const patches = args.patches
    return typeof fileName === 'string' && fileName.trim().length > 0 && Array.isArray(patches) && patches.length > 0
  }

  if (toolName === 'delete_file') {
    const fileName = args.fileName
    return typeof fileName === 'string' && fileName.trim().length > 0
  }

  if (toolName === 'read_file') {
    const fileName = args.fileName
    return typeof fileName === 'string' && fileName.trim().length > 0 && fileName.includes('.')
  }

  if (isFileMutationTool(toolName)) return Object.keys(args).length > 0

  return Object.keys(args).length > 0
}

export function canEarlyAbortToolStream(
  pending: Map<string, { name: string }>,
  argsRawById: Map<string, string>,
): boolean {
  if (pending.size === 0) return false
  for (const [id, tc] of pending) {
    if (!tc.name || !toolSupportsEarlyStreamExecute(tc.name)) return false
    if (!toolStreamArgsReady(tc.name, argsRawById.get(id))) return false
  }
  return true
}

/** @deprecated use canEarlyAbortToolStream */
export function allPendingToolsReady(
  pending: Map<string, { name: string }>,
  argsRawById: Map<string, string>,
): boolean {
  return canEarlyAbortToolStream(pending, argsRawById)
}
