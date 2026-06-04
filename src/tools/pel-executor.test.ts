import { describe, expect, it } from 'vitest'
import { executePelPlan } from './pel-executor.js'
import type { ToolContext } from '../types.js'

function stubCtx(disk: Record<string, string>, rootPath = '/proj/demo'): ToolContext {
  return {
    listFilePaths: () => Object.keys(disk),
    getFileContent: name => disk[name],
    sandboxEdits: true,
    rootPath,
    engineRun: async () => ({}),
    ensureFileContent: async name => disk[name],
  }
}

describe('executePelPlan', () => {
  it('builds PEL board from folder files when project.manifest.json is absent', async () => {
    const ctx = stubCtx({
      'part.xyzt': 'cube(10)',
      'board.xyzt.eda': '{}',
    })
    const out = await executePelPlan({}, ctx)
    expect(out.success).toBe(true)
    const parsed = JSON.parse(out.result) as { ok?: boolean; board?: { nodes?: unknown[] } }
    expect(parsed.ok).toBe(true)
    expect(parsed.board?.nodes?.length).toBeGreaterThan(0)
  })
})
