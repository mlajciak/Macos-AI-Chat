import { describe, it, expect, beforeAll } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { initManifold } from 'xyzt-cad'
import { RUNTIME_AGENT_TOOL_NAMES } from 'xyzt-agent-tools'
import { executeTool } from './registry.js'
import { goldenEngineCtx } from './executor-goldens-engine.js'
import { GOLDENS_DIR } from '../lib/paths.js'

type GoldenFixture = {
  tool: string
  input: Record<string, unknown>
  expectKeys: string[]
}

function assertHasKeys(obj: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    expect(Object.prototype.hasOwnProperty.call(obj, key), `missing key ${key}`).toBe(true)
  }
}

describe('executor goldens (TC-3)', () => {
  beforeAll(async () => {
    await initManifold()
  })

  const files = readdirSync(GOLDENS_DIR).filter(
    f => f.endsWith('.json') && !f.includes('transcript'),
  )

  for (const file of files) {
    const fixture = JSON.parse(readFileSync(join(GOLDENS_DIR, file), 'utf8')) as GoldenFixture
    if (!RUNTIME_AGENT_TOOL_NAMES.includes(fixture.tool as (typeof RUNTIME_AGENT_TOOL_NAMES)[number])) {
      it.skip(`${fixture.tool} (${file})`, () => {})
      continue
    }
    it(`${fixture.tool} (${file})`, async () => {
      const ctx = goldenEngineCtx()
      const runKey = {}
      if (fixture.tool !== 'get_capabilities') {
        await executeTool('get_capabilities', {}, ctx, runKey)
      }
      const out = await executeTool(fixture.tool, fixture.input, ctx, runKey)
      expect(out.success, out.result).toBe(true)
      const parsed = JSON.parse(out.result) as Record<string, unknown>
      assertHasKeys(parsed, fixture.expectKeys)
    })
  }
})
