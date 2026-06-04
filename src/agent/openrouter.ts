export const OPENROUTER_API_BASE = 'https://openrouter.ai/api/v1'

export type OpenRouterModality =
  | 'text'
  | 'image'
  | 'audio'
  | 'file'
  | 'video'
  | 'embeddings'

export type OpenRouterModel = {
  id: string
  name: string
  description?: string
  context_length?: number
  architecture?: {
    input_modalities?: OpenRouterModality[]
    output_modalities?: OpenRouterModality[]
    tokenizer?: string
    instruct_type?: string | null
  }
  supported_parameters?: string[]
}

export type OpenRouterChatRole = 'user' | 'assistant' | 'system' | 'tool'

export type OpenRouterTextContentPart = {
  type: 'text'
  text: string
}

export type OpenRouterImageContentPart = {
  type: 'image_url'
  image_url: {
    url: string
    detail?: 'auto' | 'low' | 'high'
  }
}

export type OpenRouterFileContentPart = {
  type: 'file'
  file: {
    filename?: string
    file_data?: string
    file_id?: string
  }
}

export type OpenRouterContentPart =
  | OpenRouterTextContentPart
  | OpenRouterImageContentPart
  | OpenRouterFileContentPart

export type OpenRouterChatMessage = {
  role: OpenRouterChatRole
  content: string | OpenRouterContentPart[]
  name?: string
  tool_call_id?: string
}

export type OpenRouterServerTool = {
  type: `openrouter:${string}`
  parameters?: Record<string, unknown>
}

export type OpenRouterFunctionTool = {
  type: 'function'
  function: {
    name: string
    description?: string
    parameters: Record<string, unknown>
  }
}

export type OpenRouterTool = OpenRouterServerTool | OpenRouterFunctionTool

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

export function openRouterHeaders(options: OpenRouterClientOptions): Record<string, string> {
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

export type ListModelsQuery = {
  search?: string
  outputModalities?: OpenRouterModality[]
  requiredInputModalities?: OpenRouterModality[]
  supportedParameters?: string[]
}

export async function listModels(
  options: OpenRouterClientOptions,
  query?: ListModelsQuery,
): Promise<OpenRouterModel[]> {
  const fetchFn = options.fetch ?? fetch
  const base = options.baseUrl ?? OPENROUTER_API_BASE
  const url = new URL(`${base}/models`)
  const outputModalities = query?.outputModalities ?? ['text']
  if (outputModalities.length > 0) {
    url.searchParams.set('output_modalities', outputModalities.join(','))
  }
  if (query?.supportedParameters?.length) {
    url.searchParams.set('supported_parameters', query.supportedParameters.join(','))
  }
  const res = await fetchFn(url.toString(), {
    headers: openRouterHeaders(options),
  })
  if (!res.ok) throw await errorFromResponse(res)
  const json = (await res.json()) as { data?: OpenRouterModel[] }
  let models = json.data ?? []
  const requiredInputs = query?.requiredInputModalities ?? []
  if (requiredInputs.length > 0) {
    models = models.filter(model => {
      const inputs = model.architecture?.input_modalities ?? []
      return requiredInputs.every(modality => inputs.includes(modality))
    })
  }
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
  modalities?: OpenRouterModality[]
  tools?: OpenRouterTool[]
  toolChoice?: unknown
}

export async function chatCompletion(options: ChatCompletionOptions): Promise<string> {
  const fetchFn = options.fetch ?? fetch
  const base = options.baseUrl ?? OPENROUTER_API_BASE
  const res = await fetchFn(`${base}/chat/completions`, {
    method: 'POST',
    headers: openRouterHeaders(options),
    body: JSON.stringify(chatCompletionBody(options)),
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

export function chatCompletionBody(options: ChatCompletionOptions): Record<string, unknown> {
  const body: Record<string, unknown> = {
    model: options.model,
    messages: options.messages,
  }
  if (options.modalities?.length) body.modalities = options.modalities
  if (options.tools?.length) body.tools = options.tools
  if (options.toolChoice !== undefined) body.tool_choice = options.toolChoice
  return body
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
