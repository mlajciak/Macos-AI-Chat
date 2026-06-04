export type ChatRole = 'user' | 'assistant'

export type ChatMessage = {
  id: string
  role: ChatRole
  content: string
  createdAt: number
}

export type ChatSession = {
  messages: ChatMessage[]
  isStreaming: boolean
}

export type WindowMode = 'compact' | 'expanded'

export type SessionEvent =
  | { type: 'send_user'; content: string; id: string; createdAt: number }
  | { type: 'append_assistant'; content: string; id: string; createdAt: number }
  | { type: 'set_streaming'; isStreaming: boolean }
  | { type: 'clear' }
