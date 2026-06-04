import { describe, expect, it } from 'vitest'
import { createSession, reduce } from '../src/session.js'

describe('session reducer', () => {
  it('starts empty', () => {
    const s = createSession()
    expect(s.messages).toEqual([])
    expect(s.isStreaming).toBe(false)
  })

  it('appends user then assistant messages', () => {
    let s = createSession()
    s = reduce(s, {
      type: 'send_user',
      id: 'u1',
      content: 'Hello',
      createdAt: 1,
    })
    s = reduce(s, {
      type: 'append_assistant',
      id: 'a1',
      content: 'Hi',
      createdAt: 2,
    })
    expect(s.messages).toHaveLength(2)
    expect(s.messages[0]?.role).toBe('user')
    expect(s.messages[1]?.role).toBe('assistant')
  })

  it('tracks streaming flag', () => {
    let s = createSession()
    s = reduce(s, { type: 'set_streaming', isStreaming: true })
    expect(s.isStreaming).toBe(true)
    s = reduce(s, { type: 'set_streaming', isStreaming: false })
    expect(s.isStreaming).toBe(false)
  })

  it('clears session', () => {
    let s = createSession()
    s = reduce(s, {
      type: 'send_user',
      id: 'u1',
      content: 'x',
      createdAt: 1,
    })
    s = reduce(s, { type: 'clear' })
    expect(s.messages).toEqual([])
  })
})
