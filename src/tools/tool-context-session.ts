import type { ToolContext } from '../types.js'

export function registerSessionFiles(
  sessionFiles: Map<string, string>,
  files?: Array<{ name: string; content: string }>,
): void {
  if (!files?.length) return
  for (const f of files) {
    if (f.name && typeof f.content === 'string') sessionFiles.set(f.name, f.content)
  }
}

export function toolContextWithSessionFiles(
  ctx: ToolContext,
  sessionFiles: Map<string, string>,
): ToolContext {
  if (sessionFiles.size === 0) return ctx
  return {
    ...ctx,
    listFilePaths() {
      const disk = new Set(ctx.listFilePaths())
      for (const name of sessionFiles.keys()) disk.add(name)
      return [...disk]
    },
    getFileContent(name: string) {
      return sessionFiles.get(name) ?? ctx.getFileContent(name)
    },
    ensureFileContent: ctx.ensureFileContent
      ? async (name: string) => {
          const staged = sessionFiles.get(name)
          if (staged !== undefined) return staged
          return ctx.ensureFileContent!(name)
        }
      : undefined,
  }
}
