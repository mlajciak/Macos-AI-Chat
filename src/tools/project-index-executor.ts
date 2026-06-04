import {
  buildProjectSymbolIndex,
  parseProjectSymbolIndex,
  PROJECT_SYMBOL_INDEX_REL_PATH,
  serializeProjectSymbolIndex,
  sha256HexFromUtf8,
} from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'

const INDEXABLE = /\.(xyzt|ts|tsx|json|md)$/i

export async function executeRefreshProjectIndex(
  _args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const paths = ctx.listFilePaths().filter(p => INDEXABLE.test(p) && !p.startsWith('.xyzt/agent/'))
  const files: Array<{ path: string; content: string }> = []
  for (const path of paths) {
    const content = ctx.getFileContent(path)
    if (content !== undefined) files.push({ path, content })
  }
  const projectId = ctx.rootPath?.split(/[/\\]/).pop() ?? 'local-project'
  const previousRaw = ctx.getFileContent(PROJECT_SYMBOL_INDEX_REL_PATH)
  const previous = previousRaw ? parseProjectSymbolIndex(previousRaw) ?? undefined : undefined
  const index = buildProjectSymbolIndex({ projectId, files, previous })
  const content = serializeProjectSymbolIndex(index)
  return {
    success: true,
    result: JSON.stringify({
      ok: true,
      fileCount: index.files.length,
      stale_after: index.stale_after,
      sample: index.files.slice(0, 5).map(f => ({
        path: f.path,
        sha256: f.sha256,
        symbolCount: f.symbols.length,
        paramCount: f.params.length,
      })),
    }, null, 2),
    files: [{ name: PROJECT_SYMBOL_INDEX_REL_PATH, content }],
  }
}

/** Collect current file shas for checkpoint drift detection (EA-6). */
export function collectProjectFileShas(ctx: ToolContext): Record<string, string> {
  const shas: Record<string, string> = {}
  for (const path of ctx.listFilePaths()) {
    if (!INDEXABLE.test(path)) continue
    const content = ctx.getFileContent(path)
    if (content !== undefined) shas[path] = sha256HexFromUtf8(content)
  }
  return shas
}
