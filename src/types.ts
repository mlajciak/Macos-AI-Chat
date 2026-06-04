import type { WorkflowRunState } from './workflow/state-machine.js'

export interface AIMessage {
  role: string
  content: string | AIMessageContentPart[] | null
  tool_call_id?: string
  tool_calls?: Array<{
    id: string
    type: string
    function: { name: string; arguments: string }
  }>
}

export type AIMessageContentPart =
  | { type: 'text'; text: string }
  | { type: 'image_url'; image_url: { url: string } }

export interface ToolCall {
  id: string
  name: string
  args: Record<string, unknown>
}

export type StreamEvent =
  | { type: 'thinking'; content: string }
  | { type: 'thinking_done' }
  | { type: 'token'; content: string }
  | { type: 'budget_exceeded'; message: string; plan?: string }
  | { type: 'connecting'; message: string; byok?: boolean }
  | { type: 'tool_call'; toolCall: ToolCall }
  | {
      type: 'tool_result'
      toolCallId: string
      name: string
      args?: Record<string, unknown>
      result: string
      pending?: boolean
      meshData?: unknown
      measurements?: Record<string, number>
      duration?: number
      files?: Array<{ name: string; content: string }>
      success?: boolean
    }
  | { type: 'tool_progress'; toolCallId: string; partialContent: string }
  | {
      type: 'ask_question'
      questions: Array<{ question: string; context?: string; options?: string[]; multi?: boolean }>
      toolCallId: string
    }

export interface AgentStreamRequest {
  runId?: string
  sandboxEdits?: boolean
  continueFromToolCallId?: string
  toolResult?: string
  agentSurface?: string
  /** `auto` uses server default; otherwise OpenRouter model id. */
  model?: string
  /** When model is `auto` and user has a custom key, OpenRouter model for auto. */
  autoModel?: string
}

export interface LocalToolResult {
  success: boolean
  result: string
  pending?: boolean
  files?: Array<{ name: string; content: string }>
  meshData?: unknown
  measurements?: Record<string, number>
  duration?: number
}

export interface ToolContext {
  listFilePaths: () => string[]
  getFileContent: (name: string) => string | undefined
  ensureFileContent?: (fileName: string) => Promise<string | undefined>
  sandboxEdits: boolean
  rootPath?: string | null
  /** MA-2: ties file leases to an agent run id. */
  agentRunId?: string
  /** Hydrate workflow gates from `.xyzt/agent/workflow/{runId}.json`. */
  readWorkflowSnapshot?: (runId: string) => WorkflowRunState | null
  persistWorkflowSnapshot?: (runId: string, state: WorkflowRunState) => void | Promise<void>
  engineRun: (payload: Record<string, unknown>) => Promise<Record<string, unknown>>
  startSimulationJob?: (request: unknown) => Promise<unknown>
  createSimulationJobRequest?: (
    simulation: import('xyzt-cad').SimulationJsonV0,
    meshes: import('xyzt-cad').MeshData[],
  ) => unknown
  writeBinaryFile?: (path: string, data: Uint8Array, mode: 'direct' | 'sandbox') => Promise<LocalToolResult>
  runScriptInProcess?: (
    code: string,
    params?: Record<string, unknown>,
  ) => Promise<import('xyzt-cad').RunResult>
  searchComponents?: (
    query: string,
    options?: { sources?: string[]; limit?: number },
  ) => Promise<{ results: unknown[]; total: number; error?: string; status?: number }>
  fetchComponentDetails?: (
    componentId: string,
  ) => Promise<Record<string, unknown> | null>
  /** Desktop host: LCSC/JLC placement via xyzt-client (addLine + optional script). */
  placeComponent?: (args: Record<string, unknown>) => Promise<{
    success: boolean
    designator: string
    position: { x: number; y: number }
    rotation: number
    partRef?: string
    addLine?: string
    script?: string
    error?: string
  }>
  /** Desktop host: ngspice on PATH when subprocess backend is registered. */
  ngspiceAvailable?: boolean
}
