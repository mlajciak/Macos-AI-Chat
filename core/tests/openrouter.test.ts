import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  OpenRouterError,
  chatCompletion,
  listModels,
  providerLabel,
} from '../src/openrouter.js'

const originalFetch = globalThis.fetch

afterEach(() => {
  globalThis.fetch = originalFetch
  vi.restoreAllMocks()
})

describe('listModels', () => {
  it('returns models from the API', async () => {
    globalThis.fetch = vi.fn(async () =>
      Response.json({
        data: [{ id: 'openai/gpt-4o', name: 'GPT-4o' }],
      }),
    ) as typeof fetch

    const models = await listModels({ apiKey: 'sk-test' })
    expect(models).toEqual([{ id: 'openai/gpt-4o', name: 'GPT-4o' }])
    expect(globalThis.fetch).toHaveBeenCalledWith(
      'https://openrouter.ai/api/v1/models?output_modalities=text',
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: 'Bearer sk-test' }),
      }),
    )
  })

  it('filters models by search query', async () => {
    globalThis.fetch = vi.fn(async () =>
      Response.json({
        data: [
          { id: 'openai/gpt-4o', name: 'GPT-4o' },
          { id: 'anthropic/claude-3.5-sonnet', name: 'Claude 3.5 Sonnet' },
        ],
      }),
    ) as typeof fetch

    const models = await listModels({ apiKey: 'sk-test' }, { search: 'claude' })
    expect(models.map(m => m.id)).toEqual(['anthropic/claude-3.5-sonnet'])
  })

  it('throws OpenRouterError on failure', async () => {
    globalThis.fetch = vi.fn(async () =>
      Response.json({ error: { message: 'Invalid key' } }, { status: 401 }),
    ) as typeof fetch

    await expect(listModels({ apiKey: 'bad' })).rejects.toBeInstanceOf(
      OpenRouterError,
    )
  })
})

describe('chatCompletion', () => {
  it('returns assistant text', async () => {
    globalThis.fetch = vi.fn(async () =>
      Response.json({
        choices: [{ message: { content: 'Hello from the model' } }],
      }),
    ) as typeof fetch

    const text = await chatCompletion({
      apiKey: 'sk-test',
      model: 'openai/gpt-4o',
      messages: [{ role: 'user', content: 'Hi' }],
    })
    expect(text).toBe('Hello from the model')
  })
})

describe('providerLabel', () => {
  it('title-cases the provider segment', () => {
    expect(providerLabel('anthropic/claude-3.5-sonnet')).toBe('Anthropic')
  })
})
