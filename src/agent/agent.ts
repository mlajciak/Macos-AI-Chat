import {
  chatCompletion,
  type OpenRouterChatMessage,
  type OpenRouterClientOptions,
  type OpenRouterModality,
  type OpenRouterTool,
} from './openrouter.js'
import type { ChatMessage } from './types.js'
import {
  buildEngineeringSystemPrompt,
  workspaceContextMessage,
  type WorkspaceContext,
} from './engineering-agent.js'

export type AgentMessageOptions = {
  systemPrompt?: string
  workspaceContext?: WorkspaceContext
}

export function toOpenRouterMessages(
  messages: ChatMessage[],
  options: AgentMessageOptions = {},
): OpenRouterChatMessage[] {
  const prepared: OpenRouterChatMessage[] = []
  const systemPrompt = options.systemPrompt?.trim()
  if (systemPrompt) {
    prepared.push({ role: 'system', content: systemPrompt })
  }
  const contextMessage = options.workspaceContext
    ? workspaceContextMessage(options.workspaceContext)
    : null
  if (contextMessage) prepared.push(contextMessage)
  prepared.push(...messages.map(m => ({
    role: m.role,
    content: m.content,
  })))
  return prepared
}

export type AgentReplyOptions = OpenRouterClientOptions & {
  model: string
  systemPrompt?: string
  workspaceContext?: WorkspaceContext
  modalities?: OpenRouterModality[]
  tools?: OpenRouterTool[]
  toolChoice?: unknown
  includeEngineeringSystemPrompt?: boolean
}

export async function agentReply(
  messages: ChatMessage[],
  options: AgentReplyOptions,
): Promise<string> {
  return chatCompletion({
    ...options,
    messages: toOpenRouterMessages(messages, {
      systemPrompt: options.includeEngineeringSystemPrompt
        ? buildEngineeringSystemPrompt(options.systemPrompt)
        : options.systemPrompt,
      workspaceContext: options.workspaceContext,
    }),
  })
}
