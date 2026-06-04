import { describe, expect, it } from 'vitest'
import { orientCadReportPasses, spatialReportPasses } from './state-machine.js'

describe('orientCadReportPasses', () => {
  it('passes when spatial and ledger are clean', () => {
    expect(
      orientCadReportPasses({
        ok: true,
        spatial: { ok: true, checks: [{ passed: true }] },
        ledger: { criticValid: true, assertions: [{ status: 'pass' }] },
      }),
    ).toBe(true)
  })

  it('fails when ledger has open failures', () => {
    expect(
      orientCadReportPasses({
        ok: true,
        spatial: { ok: true },
        ledger: { assertions: [{ status: 'fail' }] },
      }),
    ).toBe(false)
  })

  it('fails when spatial checks fail even if ok true', () => {
    expect(
      orientCadReportPasses({
        ok: true,
        spatial: { ok: true, checks: [{ passed: false }] },
      }),
    ).toBe(false)
    expect(spatialReportPasses({ ok: true, checks: [{ passed: false }] })).toBe(false)
  })
})
