import { describe, expect, it } from 'vitest'
import { MAX_ORACLE_REPAIR_ATTEMPTS } from '../loop/oracle-repair-loop.js'

describe('oracle repair loop', () => {
  it('caps attempts at 3', () => {
    expect(MAX_ORACLE_REPAIR_ATTEMPTS).toBe(3)
  })
})
