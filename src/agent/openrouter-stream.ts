import { OpenRouterError, openRouterHeaders, OPENROUTER_API_BASE } from './openrouter.js'
import { chatCompletionBody } from './openrouter.js'
import type { ChatCompletionOptions, OpenRouterImageContentPart } from './openrouter.js'

function parseSseDataLine(line: string): string | null {
  const trimmed = line.trim()
  if (!trimmed.startsWith('data:')) return null
  const payload = trimmed.slice(5).trim()
  if (!payload || payload === '[DONE]') return null
  return payload
}

export type ChatCompletionStreamChunk = {
  content?: string
  reasoning?: string
  images?: OpenRouterImageContentPart[]
}

export function extractStreamChunk(payload: string): ChatCompletionStreamChunk | null {
  try {
    const json = JSON.parse(payload) as {
      choices?: {
        delta?: {
          content?: string | null
          reasoning?: string | null
          reasoning_details?: { text?: string; summary?: string }[]
          images?: OpenRouterImageContentPart[]
        }
      }[]
    }
    const delta = json.choices?.[0]?.delta
    if (!delta) return null
    const chunk: ChatCompletionStreamChunk = {}
    if (delta.content) chunk.content = delta.content
    if (delta.reasoning) {
      chunk.reasoning = delta.reasoning
    } else if (delta.reasoning_details?.length) {
      const reasoning = delta.reasoning_details
        .map(detail => detail.text ?? detail.summary ?? '')
        .join('')
      if (reasoning) chunk.reasoning = reasoning
    }
    if (delta.images?.length) chunk.images = delta.images
    if (!chunk.content && !chunk.reasoning && !chunk.images?.length) return null
    return chunk
  } catch {
    return null
  }
}

export async function* streamChatCompletionChunks(
  options: ChatCompletionOptions,
): AsyncGenerator<ChatCompletionStreamChunk, void, unknown> {
  const fetchFn = options.fetch ?? fetch
  const base = options.baseUrl ?? OPENROUTER_API_BASE
  const res = await fetchFn(`${base}/chat/completions`, {
    method: 'POST',
    headers: openRouterHeaders(options),
    body: JSON.stringify({
      ...chatCompletionBody(options),
      stream: true,
    }),
  })

  if (!res.ok) {
    let body: unknown
    try {
      body = await res.json()
    } catch {
      body = await res.text().catch(() => undefined)
    }
    const message =
      typeof body === 'object' &&
      body !== null &&
      'error' in body &&
      typeof (body as { error?: { message?: string } }).error?.message === 'string'
        ? (body as { error: { message: string } }).error.message
        : `OpenRouter request failed (${res.status})`
    throw new OpenRouterError(message, res.status, body)
  }

  if (!res.body) {
    throw new OpenRouterError('OpenRouter returned an empty stream body')
  }

  const reader = res.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split('\n')
      buffer = lines.pop() ?? ''
      for (const line of lines) {
        const payload = parseSseDataLine(line)
        if (!payload) continue
        const chunk = extractStreamChunk(payload)
        if (chunk) yield chunk
      }
    }
    if (buffer.trim()) {
      const payload = parseSseDataLine(buffer)
      if (payload) {
        const chunk = extractStreamChunk(payload)
        if (chunk) yield chunk
      }
    }
  } finally {
    reader.releaseLock()
  }
}

export async function* streamChatCompletion(
  options: ChatCompletionOptions,
): AsyncGenerator<string, void, unknown> {
  for await (const chunk of streamChatCompletionChunks(options)) {
    if (chunk.content) yield chunk.content
  }
}
