import { describe, it, expect, beforeAll } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { initManifold } from 'xyzt-cad'
import { executeTool, getWorkflowState } from './registry.js'
import { goldenEngineCtx } from './executor-goldens-engine.js'
import { GOLDENS_DIR } from '../lib/paths.js'

const TRANSCRIPT_PATH = join(GOLDENS_DIR, 'vx-r2-mechanical-transcript.json')

type TranscriptStep = {
  tool: string
  input: Record<string, unknown>
  expectKeys: string[]
}

describe.skip('VX-R2 mechanical transcript (PEL-1) — legacy full tool chain', () => {
  beforeAll(async () => {
    await initManifold()
  })

  it('replays subsystem mechanical tool chain', async () => {
    const raw = JSON.parse(readFileSync(TRANSCRIPT_PATH, 'utf8')) as {
      id: string
      steps: TranscriptStep[]
    }
    expect(raw.id).toBe('vx-r2-mechanical')
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
    const wf = getWorkflowState(runKey, ctx)
    expect(wf.sawValidate || wf.sawGate).toBe(true)
  })
})
