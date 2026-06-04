import type { ChatMessage } from './types.js'
import { toOpenRouterMessages, type AgentReplyOptions } from './agent.js'
import { buildEngineeringSystemPrompt } from './engineering-agent.js'
import { streamChatCompletionChunks } from './openrouter-stream.js'
import { AgentStreamParser, type StreamParserEvent } from './stream-parser.js'

export async function* streamAgentReply(
  messages: ChatMessage[],
  options: AgentReplyOptions,
): AsyncGenerator<StreamParserEvent, void, unknown> {
  const parser = new AgentStreamParser()
  for await (const chunk of streamChatCompletionChunks({
    ...options,
    messages: toOpenRouterMessages(messages, {
      systemPrompt: options.includeEngineeringSystemPrompt
        ? buildEngineeringSystemPrompt(options.systemPrompt)
        : options.systemPrompt,
      workspaceContext: options.workspaceContext,
    }),
  })) {
    if (chunk.reasoning) yield* parser.pushReasoning(chunk.reasoning)
    if (chunk.content) yield* parser.push(chunk.content)
  }
  yield* parser.flush()
}
