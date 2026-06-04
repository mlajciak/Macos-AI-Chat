import { describe, expect, it } from 'vitest'
import { routeGateBlock } from './route.js'

describe('orchestrator routeGateBlock', () => {
  it('routes spatial gate to orient_cad', () => {
    const hint = routeGateBlock('WORKFLOW_SPATIAL_REQUIRED: run orient_cad first')
    expect(hint?.worker).toBe('cad')
    expect(hint?.nextTool).toBe('orient_cad')
  })

  it('routes EDA verify to verify_eda', () => {
    const hint = routeGateBlock('WORKFLOW_EDA_VERIFY_REQUIRED')
    expect(hint?.worker).toBe('eda')
    expect(hint?.nextTool).toBe('verify_eda')
  })

  it('returns null for unknown codes', () => {
    expect(routeGateBlock('SOME_OTHER_ERROR')).toBeNull()
  })
})
