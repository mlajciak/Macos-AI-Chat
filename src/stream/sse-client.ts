import type { AgentStreamRequest, AIMessage, StreamEvent } from '../types.js'

interface StreamChunk {
  token?: string
  thinking?: string
  thinking_done?: boolean
  error?: string
  budget_exceeded?: boolean
  plan?: string
  connecting?: boolean
  message?: string
  byok?: boolean
  tool_call?: { id: string; name: string; arguments: Record<string, unknown> }
  tool_result?: {
    id: string
    name: string
    arguments?: Record<string, unknown>
    result: string
    success: boolean
    pending?: boolean
    meshData?: unknown
    measurements?: Record<string, number>
    duration?: number
    files?: Array<{ name: string; content: string }>
  }
  tool_progress?: { id: string; partial_content: string }
}

export interface StreamTransport {
  resolveUrl(): string
  fetch(
    url: string,
    init: { method: string; headers: Record<string, string>; body: string; signal?: AbortSignal },
  ): Promise<Response>
}

export const defaultStreamTransport: StreamTransport = {
  resolveUrl: () => process.env.XYZT_AI_STREAM_URL?.trim() || '/ai/generate',
  fetch: (url, init) => fetch(url, init),
}

function parseAskQuestions(args: Record<string, unknown>) {
  if (Array.isArray(args.questions)) {
    return (args.questions as Array<{ question?: string; context?: string; options?: string[]; multi?: boolean }>)
      .filter(q => !!q.question) as Array<{
      question: string
      context?: string
      options?: string[]
      multi?: boolean
    }>
  }
  if (typeof args.question === 'string' && args.question) {
    return [
      {
        question: args.question,
        context: args.context as string | undefined,
        options: args.options as string[] | undefined,
        multi: args.multi as boolean | undefined,
      },
    ]
  }
  return []
}

function* eventsFromChunk(obj: StreamChunk): Generator<StreamEvent> {
  if (obj.budget_exceeded) {
    yield {
      type: 'budget_exceeded',
      message: obj.error ?? 'Usage limit reached.',
      plan: obj.plan,
    }
    return
  }
  if (obj.connecting) {
    yield {
      type: 'connecting',
      message: obj.message ?? 'Connecting…',
      ...(obj.byok ? { byok: true } : {}),
    }
    return
  }
  if (obj.error) throw new Error(obj.error)
  if (obj.thinking) yield { type: 'thinking', content: obj.thinking }
  if (obj.thinking_done) yield { type: 'thinking_done' }
  if (obj.token) yield { type: 'token', content: obj.token }
  if (obj.tool_call) {
    const { id, name, arguments: args } = obj.tool_call
    yield { type: 'tool_call', toolCall: { id, name, args } }
    if (name === 'ask_user') {
      const validQs = parseAskQuestions(args)
      if (validQs.length > 0) {
        yield { type: 'ask_question', questions: validQs, toolCallId: id }
      }
    }
  }
  if (obj.tool_result) {
    const tr = obj.tool_result
    if (tr.name === 'ask_user' && tr.arguments) {
      const validQs = parseAskQuestions(tr.arguments)
      if (validQs.length > 0) {
        yield { type: 'ask_question', questions: validQs, toolCallId: tr.id }
      }
    }
    yield {
      type: 'tool_result',
      toolCallId: tr.id,
      name: tr.name,
      args: tr.arguments,
      result: tr.result,
      success: tr.success,
      pending: tr.pending,
      meshData: tr.meshData,
      measurements: tr.measurements,
      duration: tr.duration,
      files: tr.files,
    }
  }
  if (obj.tool_progress) {
    yield {
      type: 'tool_progress',
      toolCallId: obj.tool_progress.id,
      partialContent: obj.tool_progress.partial_content,
    }
  }
}

export async function* streamAgentEvents(
  messages: AIMessage[],
  accessToken: string | null,
  signal: AbortSignal | undefined,
  req: AgentStreamRequest,
  transport: StreamTransport = defaultStreamTransport,
  authHeaders: (token: string | null) => Record<string, string> = token => {
    const h: Record<string, string> = { 'Content-Type': 'application/json' }
    if (token) h.Authorization = `Bearer ${token}`
    return h
  },
): AsyncGenerator<StreamEvent> {
  const url = transport.resolveUrl()
  const res = await transport.fetch(url, {
    method: 'POST',
    headers: authHeaders(accessToken),
    body: JSON.stringify({
      messages,
      stream: true,
      agentSurface: req.agentSurface ?? 'desktop_folder',
      clientPersistsMessages: true,
      sandboxEdits: req.sandboxEdits !== false,
      ...(req.runId ? { runId: req.runId } : {}),
      ...(req.continueFromToolCallId ? { continueFromToolCallId: req.continueFromToolCallId } : {}),
      ...(req.toolResult ? { toolResult: req.toolResult } : {}),
      ...(req.model ? { model: req.model } : {}),
      ...(req.autoModel ? { autoModel: req.autoModel } : {}),
    }),
    signal,
  })

  if (res.status === 401) {
    const err = new Error('Authentication required')
    ;(err as Error & { code: string }).code = 'AUTH_REQUIRED'
    throw err
  }
  if (!res.ok) {
    const errText = await res.text().catch(() => '')
    throw new Error(`AI gateway error ${res.status}: ${errText.slice(0, 500)}`)
  }
  if (!res.body) throw new Error('AI stream returned empty body')

  const reader = res.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buffer += decoder.decode(value, { stream: true })
    const lines = buffer.split('\n')
    buffer = lines.pop() ?? ''
    for (const line of lines) {
      if (!line.startsWith('data: ')) continue
      const data = line.slice(6).trim()
      if (data === '[DONE]') return
      try {
        const obj = JSON.parse(data) as StreamChunk
        yield* eventsFromChunk(obj)
      } catch (e) {
        if (e instanceof Error && e.message !== 'Unexpected end of JSON input') throw e
      }
    }
  }
}
