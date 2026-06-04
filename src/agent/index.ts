export type {
  ChatMessage,
  ChatRole,
  ChatSession,
  SessionEvent,
  WindowMode,
} from './types.js'
export { createSession, lastUserMessage, reduce } from './session.js'
export {
  OPENROUTER_API_BASE,
  OpenRouterError,
  chatCompletion,
  listModels,
  providerLabel,
  type ChatCompletionOptions,
  type ListModelsQuery,
  type OpenRouterContentPart,
  type OpenRouterChatMessage,
  type OpenRouterChatRole,
  type OpenRouterClientOptions,
  type OpenRouterFileContentPart,
  type OpenRouterFunctionTool,
  type OpenRouterImageContentPart,
  type OpenRouterModality,
  type OpenRouterModel,
  type OpenRouterServerTool,
  type OpenRouterTextContentPart,
  type OpenRouterTool,
} from './openrouter.js'
export {
  agentReply,
  toOpenRouterMessages,
  type AgentMessageOptions,
  type AgentReplyOptions,
} from './agent.js'
export {
  streamAgentReply,
} from './agent-stream.js'
export {
  extractStreamChunk,
  streamChatCompletion,
  streamChatCompletionChunks,
  type ChatCompletionStreamChunk,
} from './openrouter-stream.js'
export {
  AgentStreamParser,
  type StreamParserEvent,
} from './stream-parser.js'
export {
  createToolCard,
  toolTitles,
  type AgentToolCard,
  type ToolKind,
} from './tools.js'
export {
  ENGINEERING_AGENT_SYSTEM_PROMPT,
  buildEngineeringSystemPrompt,
  buildModelingWorkflowBrief,
  buildWorkspaceContext,
  describeWorkspaceFile,
  engineeringToolDefinitions,
  workspaceContextMessage,
  type WorkspaceContext,
  type WorkspaceContextOptions,
  type WorkspaceFileContext,
  type WorkspaceFileSnapshot,
} from './engineering-agent.js'
