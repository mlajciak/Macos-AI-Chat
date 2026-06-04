import { describe, it, expect, beforeAll } from 'vitest'
import { readFileSync } from 'node:fs'
import { initManifold } from 'xyzt-cad'
import { executeTool } from './registry.js'
import { goldenEngineCtx } from './executor-goldens-engine.js'
import { GOLDENS_DIR } from '../lib/paths.js'
import { join } from 'node:path'

const TRANSCRIPT_PATH = join(GOLDENS_DIR, 'rp-1-electromechanical-transcript.json')

type TranscriptStep = {
  tool: string
  input: Record<string, unknown>
  expectKeys: string[]
}

describe('RP-1 electromechanical transcript', () => {
  beforeAll(async () => {
    await initManifold()
  })

  it('replays RP-1 bracket tool chain', async () => {
    const raw = JSON.parse(readFileSync(TRANSCRIPT_PATH, 'utf8')) as {
      id: string
      steps: TranscriptStep[]
    }
    expect(raw.id).toBe('rp-1-electromechanical')
    const ctx = goldenEngineCtx()
    const runKey = {}
    for (const step of raw.steps) {
      const out = await executeTool(step.tool, step.input, ctx, runKey)
      expect(out.success, `${step.tool}: ${out.result}`).toBe(true)
      const parsed = JSON.parse(out.result) as Record<string, unknown>
      for (const key of step.expectKeys) {
        expect(Object.prototype.hasOwnProperty.call(parsed, key)).toBe(true)
      }
    }
  })
})
