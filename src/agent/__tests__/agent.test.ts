import { afterEach, describe, expect, it, vi } from 'vitest'
import { agentReply, toOpenRouterMessages } from '../agent.js'
import type { ChatMessage } from '../types.js'

const originalFetch = globalThis.fetch

afterEach(() => {
  globalThis.fetch = originalFetch
  vi.restoreAllMocks()
})

describe('toOpenRouterMessages', () => {
  it('maps chat roles and content', () => {
    const messages: ChatMessage[] = [
      { id: '1', role: 'user', content: 'Hi', createdAt: 0 },
      { id: '2', role: 'assistant', content: 'Hey', createdAt: 1 },
    ]
    expect(toOpenRouterMessages(messages)).toEqual([
      { role: 'user', content: 'Hi' },
      { role: 'assistant', content: 'Hey' },
    ])
  })
})

describe('agentReply', () => {
  it('calls chat completions with the thread', async () => {
    globalThis.fetch = vi.fn(async (_url, init) => {
      const body = JSON.parse(String(init?.body))
      expect(body.model).toBe('openai/gpt-4o-mini')
      expect(body.messages).toHaveLength(1)
      return Response.json({
        choices: [{ message: { content: 'Done' } }],
      })
    }) as typeof fetch

    const reply = await agentReply(
      [{ id: '1', role: 'user', content: 'Plan a bracket', createdAt: 0 }],
      { apiKey: 'sk-test', model: 'openai/gpt-4o-mini' },
    )
    expect(reply).toBe('Done')
  })
})
