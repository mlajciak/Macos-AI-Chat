import { describe, expect, it } from 'vitest'
import { canEarlyAbortToolStream, toolStreamArgsReady } from './tool-args-ready.js'

describe('toolStreamArgsReady', () => {
  it('returns false for incomplete create_cad JSON', () => {
    expect(toolStreamArgsReady('create_cad', '{"fileName": "Chair"')).toBe(false)
  })

  it('returns true when create_cad JSON is complete', () => {
    const raw = JSON.stringify({ fileName: 'Chair', content: 'return box(1,2,3);' })
    expect(toolStreamArgsReady('create_cad', raw)).toBe(true)
  })
})

describe('canEarlyAbortToolStream', () => {
  it('allows early abort for create_cad with complete args', () => {
    const pending = new Map([['a', { name: 'create_cad' }]])
    const raw = new Map([['a', JSON.stringify({ fileName: 'X', content: 'return 1;' })]])
    expect(canEarlyAbortToolStream(pending, raw)).toBe(true)
  })

  it('blocks early abort when read_file is pending', () => {
    const pending = new Map([
      ['a', { name: 'create_cad' }],
      ['b', { name: 'read_file' }],
    ])
    const raw = new Map([
      ['a', JSON.stringify({ fileName: 'X', content: 'return 1;' })],
      ['b', JSON.stringify({ fileName: 'X.xyzt' })],
    ])
    expect(canEarlyAbortToolStream(pending, raw)).toBe(false)
  })

  it('rejects prefix-valid read_file JSON during streaming', () => {
    expect(toolStreamArgsReady('read_file', '{"fileName": "Oriental"')).toBe(false)
  })
})
