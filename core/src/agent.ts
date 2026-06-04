import {
  chatCompletion,
  type OpenRouterChatMessage,
  type OpenRouterClientOptions,
} from './openrouter.js'
import type { ChatMessage } from './types.js'

export function toOpenRouterMessages(messages: ChatMessage[]): OpenRouterChatMessage[] {
  return messages.map(m => ({
    role: m.role,
    content: m.content,
  }))
}

export type AgentReplyOptions = OpenRouterClientOptions & {
  model: string
}

export async function agentReply(
  messages: ChatMessage[],
  options: AgentReplyOptions,
): Promise<string> {
  return chatCompletion({
    ...options,
    messages: toOpenRouterMessages(messages),
  })
}
