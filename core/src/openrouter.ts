export const OPENROUTER_API_BASE = 'https://openrouter.ai/api/v1'

export type OpenRouterModel = {
  id: string
  name: string
  description?: string
  context_length?: number
}

export type OpenRouterChatRole = 'user' | 'assistant' | 'system'

export type OpenRouterChatMessage = {
  role: OpenRouterChatRole
  content: string
}

export type OpenRouterClientOptions = {
  apiKey: string
  baseUrl?: string
  fetch?: typeof fetch
  appReferrer?: string
  appTitle?: string
}

export class OpenRouterError extends Error {
  readonly status?: number
  readonly body?: unknown

  constructor(message: string, status?: number, body?: unknown) {
    super(message)
    this.name = 'OpenRouterError'
    this.status = status
    this.body = body
  }
}

function openRouterHeaders(options: OpenRouterClientOptions): Record<string, string> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${options.apiKey}`,
    'Content-Type': 'application/json',
  }
  if (options.appReferrer) headers['HTTP-Referer'] = options.appReferrer
  if (options.appTitle) headers['X-Title'] = options.appTitle
  return headers
}

async function errorFromResponse(res: Response): Promise<OpenRouterError> {
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
  return new OpenRouterError(message, res.status, body)
}

export async function listModels(
  options: OpenRouterClientOptions,
  query?: { search?: string },
): Promise<OpenRouterModel[]> {
  const fetchFn = options.fetch ?? fetch
  const base = options.baseUrl ?? OPENROUTER_API_BASE
  const url = new URL(`${base}/models`)
  url.searchParams.set('output_modalities', 'text')
  const res = await fetchFn(url.toString(), {
    headers: openRouterHeaders(options),
  })
  if (!res.ok) throw await errorFromResponse(res)
  const json = (await res.json()) as { data?: OpenRouterModel[] }
  const models = json.data ?? []
  const q = query?.search?.trim().toLowerCase()
  if (!q) return models
  return models.filter(m => {
    const haystack = `${m.id} ${m.name} ${m.description ?? ''}`.toLowerCase()
    return haystack.includes(q)
  })
}

export type ChatCompletionOptions = OpenRouterClientOptions & {
  model: string
  messages: OpenRouterChatMessage[]
}

export async function chatCompletion(options: ChatCompletionOptions): Promise<string> {
  const fetchFn = options.fetch ?? fetch
  const base = options.baseUrl ?? OPENROUTER_API_BASE
  const res = await fetchFn(`${base}/chat/completions`, {
    method: 'POST',
    headers: openRouterHeaders(options),
    body: JSON.stringify({
      model: options.model,
      messages: options.messages,
    }),
  })
  if (!res.ok) throw await errorFromResponse(res)
  const json = (await res.json()) as {
    choices?: { message?: { content?: string | null } }[]
  }
  const content = json.choices?.[0]?.message?.content
  if (content == null || content === '') {
    throw new OpenRouterError('OpenRouter returned an empty completion')
  }
  return content
}

export function providerLabel(modelId: string): string {
  const slash = modelId.indexOf('/')
  if (slash <= 0) return 'OpenRouter'
  const provider = modelId.slice(0, slash)
  return provider
    .split(/[-_]/)
    .map(part => (part ? part[0]!.toUpperCase() + part.slice(1) : ''))
    .join(' ')
}
