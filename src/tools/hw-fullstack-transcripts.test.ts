import { describe, it, expect, beforeAll } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { initManifold } from 'xyzt-cad'
import { executeTool } from './registry.js'
import { goldenEngineCtx } from './executor-goldens-engine.js'
import { GOLDENS_DIR } from '../lib/paths.js'

type TranscriptStep = {
  tool: string
  input: Record<string, unknown>
  expectKeys: string[]
}

async function replayTranscript(fileName: string, expectedId: string) {
  const raw = JSON.parse(readFileSync(join(GOLDENS_DIR, fileName), 'utf8')) as {
    id: string
    steps: TranscriptStep[]
  }
  expect(raw.id).toBe(expectedId)
  const ctx = goldenEngineCtx()
  const runKey = {}
  await executeTool('get_capabilities', {}, ctx, runKey)
  for (const step of raw.steps) {
    if (step.tool === 'get_capabilities') continue
    const out = await executeTool(step.tool, step.input, ctx, runKey)
    expect(out.success, `${step.tool}: ${out.result}`).toBe(true)
    const parsed = JSON.parse(out.result) as Record<string, unknown>
    for (const key of step.expectKeys) {
      expect(Object.prototype.hasOwnProperty.call(parsed, key)).toBe(true)
    }
  }
}

describe('HW full-stack transcript goldens', () => {
  beforeAll(async () => {
    await initManifold()
  })

  it('hw-sim-smoke-transcript.json', async () => {
    await replayTranscript('hw-sim-smoke-transcript.json', 'hw-sim-smoke')
  })

  it('hw-export-bundle-transcript.json', async () => {
    await replayTranscript('hw-export-bundle-transcript.json', 'hw-export-bundle')
  })
})
