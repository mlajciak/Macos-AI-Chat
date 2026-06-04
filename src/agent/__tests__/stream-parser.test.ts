import { describe, expect, it } from 'vitest'
import { AgentStreamParser } from '../stream-parser.js'

describe('AgentStreamParser', () => {
  it('emits text when no think tags', () => {
    const parser = new AgentStreamParser()
    const events = parser.push('Hello world')
    expect(events).toEqual([{ type: 'text_delta', delta: 'Hello world' }])
  })

  it('parses thinking block then text', () => {
    const parser = new AgentStreamParser()
    const open = ['<', 'think', '>'].join('')
    const close = ['<', '/', 'think', '>'].join('')
    const events = [
      ...parser.push(`${open}plan steps${close}`),
      ...parser.push('Answer'),
    ]
    expect(events[0]?.type).toBe('thinking_start')
    expect(events.some(e => e.type === 'thinking_delta')).toBe(true)
    expect(events.some(e => e.type === 'thinking_end')).toBe(true)
    expect(events.at(-1)).toEqual({ type: 'text_delta', delta: 'Answer' })
  })

  it('handles tags split across chunks', () => {
    const parser = new AgentStreamParser()
    const open = ['<', 'think', '>'].join('')
    const close = ['<', '/', 'think', '>'].join('')
    const events = [
      ...parser.push(open.slice(0, 2)),
      ...parser.push(open.slice(2) + 'hidden' + close + 'done'),
    ]
    expect(events.some(e => e.type === 'thinking_start')).toBe(true)
    expect(events.some(e => e.type === 'text_delta' && e.delta === 'done')).toBe(true)
  })

  it('wraps reasoning chunks in a thinking card', () => {
    const parser = new AgentStreamParser()
    const events = [
      ...parser.pushReasoning('Step one. '),
      ...parser.pushReasoning('Step two.'),
      ...parser.push('Final'),
    ]
    expect(events[0]?.type).toBe('thinking_start')
    expect(events.filter(e => e.type === 'thinking_delta')).toHaveLength(2)
    expect(events.some(e => e.type === 'thinking_end')).toBe(true)
    expect(events.at(-1)).toEqual({ type: 'text_delta', delta: 'Final' })
  })
})
