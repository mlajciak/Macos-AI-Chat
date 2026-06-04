import { describe, expect, it } from 'vitest'
import { registerSessionFiles, toolContextWithSessionFiles } from './tool-context-session.js'
import type { ToolContext } from '../types.js'

function stubCtx(disk: Record<string, string>): ToolContext {
  return {
    listFilePaths: () => Object.keys(disk),
    getFileContent: name => disk[name],
    sandboxEdits: true,
    engineRun: async () => ({}),
    ensureFileContent: async name => disk[name],
  }
}

describe('toolContextWithSessionFiles', () => {
  it('prefers session files over disk', () => {
    const session = new Map<string, string>()
    registerSessionFiles(session, [{ name: 'a.xyzt', content: 'staged' }])
    const ctx = toolContextWithSessionFiles(stubCtx({ 'a.xyzt': 'disk' }), session)
    expect(ctx.getFileContent('a.xyzt')).toBe('staged')
    expect(ctx.listFilePaths().sort()).toEqual(['a.xyzt'])
  })

  it('ensureFileContent returns session first', async () => {
    const session = new Map<string, string>([['b.xyzt', 'from-session']])
    const ctx = toolContextWithSessionFiles(stubCtx({}), session)
    await expect(ctx.ensureFileContent!('b.xyzt')).resolves.toBe('from-session')
  })
})
