import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

import { XYZT_CORE_ROOT } from '../lib/paths.js'

const FIX = join(XYZT_CORE_ROOT, 'fixtures/agent')

describe('eda agent fixtures (PR-4)', () => {
  it('eda-prod-01..30 golden shape', () => {
    for (let i = 1; i <= 30; i++) {
      const n = String(i).padStart(2, '0')
      const path = join(FIX, `eda-prod-${n}.json`)
      const raw = JSON.parse(readFileSync(path, 'utf8')) as {
        tool?: string
        input?: Record<string, unknown>
        expectKeys?: string[]
      }
      expect(typeof raw.tool).toBe('string')
      expect(raw.input).toBeTruthy()
      expect(Array.isArray(raw.expectKeys)).toBe(true)
      expect(raw.expectKeys!.length).toBeGreaterThan(0)
    }
  })
})
