import type { ChatMessage, ChatSession, SessionEvent } from './types.js'

export function createSession(): ChatSession {
  return { messages: [], isStreaming: false }
}

export function reduce(session: ChatSession, event: SessionEvent): ChatSession {
  switch (event.type) {
    case 'send_user':
      return {
        ...session,
        messages: [
          ...session.messages,
          {
            id: event.id,
            role: 'user',
            content: event.content,
            createdAt: event.createdAt,
          },
        ],
      }
    case 'append_assistant':
      return {
        ...session,
        messages: [
          ...session.messages,
          {
            id: event.id,
            role: 'assistant',
            content: event.content,
            createdAt: event.createdAt,
          },
        ],
      }
    case 'set_streaming':
      return { ...session, isStreaming: event.isStreaming }
    case 'clear':
      return createSession()
    default: {
      const _exhaustive: never = event
      return _exhaustive
    }
  }
}

export function lastUserMessage(messages: ChatMessage[]): ChatMessage | undefined {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i]!.role === 'user') return messages[i]
  }
  return undefined
}
