export type {
  ChatMessage,
  ChatRole,
  ChatSession,
  SessionEvent,
  WindowMode,
} from './types.js'
export { createSession, lastUserMessage, reduce } from './session.js'
export {
  demoReply,
  demoReplyText,
  fixtures,
  pickFaqAnswer,
  resetFaqRotation,
  type DemoFixtures,
} from './demo-agent.js'
