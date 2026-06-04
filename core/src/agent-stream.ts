import type { ChatMessage } from './types.js'
import { toOpenRouterMessages, type AgentReplyOptions } from './agent.js'
import { streamChatCompletion } from './openrouter-stream.js'
import { AgentStreamParser, type StreamParserEvent } from './stream-parser.js'

export async function* streamAgentReply(
  messages: ChatMessage[],
  options: AgentReplyOptions,
): AsyncGenerator<StreamParserEvent, void, unknown> {
  const parser = new AgentStreamParser()
  for await (const delta of streamChatCompletion({
    ...options,
    messages: toOpenRouterMessages(messages),
  })) {
    yield* parser.push(delta)
  }
  yield* parser.flush()
}
