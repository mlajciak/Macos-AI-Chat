import { describe, it, expect, beforeAll } from 'vitest'
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { initManifold } from 'xyzt-cad'
import { executeOrientCad } from './orient-cad-executor.js'
import { goldenEngineCtx } from './executor-goldens-engine.js'
import { orientCadReportPasses } from '../workflow/state-machine.js'

import { GOLDENS_DIR } from '../lib/paths.js'

const FIXTURE = join(GOLDENS_DIR, 'oel-spatial-fail-transcript.json')

describe('OEL spatial-fail golden', () => {
  beforeAll(async () => {
    await initManifold()
  })

  it('orient_cad returns spatial + ledger; failed checks block orientCadReportPasses', async () => {
    const fixture = JSON.parse(readFileSync(FIXTURE, 'utf8')) as {
      tool: string
      input: Record<string, unknown>
      expectKeys: string[]
    }
    const out = await executeOrientCad(fixture.input, goldenEngineCtx())
    const parsed = JSON.parse(out.result) as {
      ok?: boolean
      spatial?: { checks?: Array<{ passed?: boolean }> }
      ledger?: { assertions?: Array<{ status?: string }> }
    }
    for (const key of fixture.expectKeys) {
      expect(Object.prototype.hasOwnProperty.call(parsed, key)).toBe(true)
    }
    const failedCheck = parsed.spatial?.checks?.some(c => c.passed === false) === true
    const ledgerFail = parsed.ledger?.assertions?.some(a => a.status === 'fail') === true
    if (parsed.ok === false || failedCheck || ledgerFail) {
      expect(orientCadReportPasses(parsed)).toBe(false)
    } else {
      expect(orientCadReportPasses({ ok: true, spatial: { ok: true, checks: [{ passed: false }] } })).toBe(
        false,
      )
    }
  })
})
