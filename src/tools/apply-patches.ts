export interface FilePatch {
  old: string
  new: string
}

export type ApplyPatchesResult =
  | { ok: true; content: string }
  | { ok: false; error: string; patchIndex?: number }

const COMPOUND_EXTS = ['.xyzt.simulation', '.xyzt.draft', '.xyzt.eda', '.xyzt.cad', '.xyzt'] as const

function sanitizePathStem(stem: string): string {
  const cleaned = stem
    .replace(/[/\\?%*:|"<>]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '')
  return cleaned || 'model'
}

function splitCompoundExtension(base: string): { stem: string; ext: string } {
  const lower = base.toLowerCase()
  for (const ext of COMPOUND_EXTS) {
    if (lower.endsWith(ext)) {
      return { stem: base.slice(0, -ext.length), ext: base.slice(-ext.length) }
    }
  }
  return { stem: base, ext: '' }
}

export function applyPatches(base: string, patches: FilePatch[]): ApplyPatchesResult {
  let content = base
  for (let i = 0; i < patches.length; i++) {
    const { old, new: replacement } = patches[i]!
    if (!old) {
      return { ok: false, error: `Patch ${i + 1}: empty old text`, patchIndex: i }
    }
    const idx = content.indexOf(old)
    if (idx < 0) {
      return { ok: false, error: `Patch ${i + 1}: old text not found in file`, patchIndex: i }
    }
    content = content.slice(0, idx) + replacement + content.slice(idx + old.length)
  }
  return { ok: true, content }
}

export function normalizeCreateFileName(toolName: string, fileName: string | undefined): string {
  const raw = typeof fileName === 'string' ? fileName.trim() : ''
  if (!raw) {
    if (toolName === 'create_cad') return 'model.xyzt'
    if (toolName === 'create_eda') return 'board.xyzt.eda'
    if (toolName === 'create_drawing') return 'drawing.xyzt.draft'
    if (toolName === 'create_simulation') return 'simulation.xyzt.simulation'
    return 'model.xyzt'
  }

  const { stem, ext } = splitCompoundExtension(raw)
  const safe = sanitizePathStem(stem) + ext

  if (toolName === 'create_cad' && !safe.toLowerCase().endsWith('.xyzt')) return `${safe}.xyzt`
  if (toolName === 'create_eda' && !safe.toLowerCase().endsWith('.xyzt.eda')) return `${safe}.xyzt.eda`
  if (toolName === 'create_drawing' && !safe.toLowerCase().endsWith('.xyzt.draft')) {
    return `${safe}.xyzt.draft`
  }
  if (toolName === 'create_simulation' && !safe.toLowerCase().endsWith('.xyzt.simulation')) {
    return `${safe}.xyzt.simulation`
  }
  return safe
}

export const FILE_MUTATION_TOOL_NAMES = [
  'create_cad',
  'create_eda',
  'create_drawing',
  'create_simulation',
  'edit_file',
  'patch_file',
  'delete_file',
  'update_overview',
] as const

export const PENDING_FILE_REVIEW_TOOL_NAMES = [
  'edit_feature',
  'apply_direct_edit',
  ...FILE_MUTATION_TOOL_NAMES,
] as const

export function isFileMutationTool(name: string): boolean {
  return (FILE_MUTATION_TOOL_NAMES as readonly string[]).includes(name)
}

export function isPendingFileReviewTool(name: string): boolean {
  return (PENDING_FILE_REVIEW_TOOL_NAMES as readonly string[]).includes(name)
}

export function formatToolExecutionError(toolName: string, err: unknown): string {
  const message = err instanceof Error ? err.message : String(err)
  if (/endsWith|ENOENT|no such file/i.test(message)) {
    return `${toolName} failed: invalid or missing file path.`
  }
  return `${toolName} failed: ${message}`
}
