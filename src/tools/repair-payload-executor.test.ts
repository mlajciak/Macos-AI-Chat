import { describe, it, expect, beforeAll } from 'vitest'
import { initManifold } from 'xyzt-cad'
import { executeValidateScript } from './engine-executor.js'
import { goldenEngineCtx } from './executor-goldens-engine.js'

describe('repair payloads in tool executors', () => {
  beforeAll(async () => {
    await initManifold()
  })

  it('validate_script failure includes structured repair', async () => {
    const ctx = goldenEngineCtx()
    const out = await executeValidateScript({ code: 'return (' }, ctx)
    expect(out.success).toBe(false)
    const parsed = JSON.parse(out.result) as {
      repair?: { version: number; actions: unknown[]; retryable?: boolean }
      retryable?: boolean
    }
    expect(parsed.repair?.version).toBe(0)
    expect(parsed.repair?.actions?.length).toBeGreaterThan(0)
    expect(parsed.retryable).toBe(true)
  })
})
