import { OpenRouterError, openRouterHeaders, OPENROUTER_API_BASE } from './openrouter.js'
import type { ChatCompletionOptions } from './openrouter.js'

function parseSseDataLine(line: string): string | null {
  const trimmed = line.trim()
  if (!trimmed.startsWith('data:')) return null
  const payload = trimmed.slice(5).trim()
  if (!payload || payload === '[DONE]') return null
  return payload
}

function extractDeltaContent(payload: string): string | null {
  try {
    const json = JSON.parse(payload) as {
      choices?: { delta?: { content?: string | null } }[]
    }
    const piece = json.choices?.[0]?.delta?.content
    if (piece == null || piece === '') return null
    return piece
  } catch {
    return null
  }
}

export async function* streamChatCompletion(
  options: ChatCompletionOptions,
): AsyncGenerator<string, void, unknown> {
  const fetchFn = options.fetch ?? fetch
  const base = options.baseUrl ?? OPENROUTER_API_BASE
  const res = await fetchFn(`${base}/chat/completions`, {
    method: 'POST',
    headers: openRouterHeaders(options),
    body: JSON.stringify({
      model: options.model,
      messages: options.messages,
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
        const delta = extractDeltaContent(payload)
        if (delta) yield delta
      }
    }
    if (buffer.trim()) {
      const payload = parseSseDataLine(buffer)
      if (payload) {
        const delta = extractDeltaContent(payload)
        if (delta) yield delta
      }
    }
  } finally {
    reader.releaseLock()
  }
}
