export * from './types.js'
export { runLocalAgentStream, MAX_TOOL_ITERATIONS } from './loop/tool-execution-loop.js'
export { streamAgentEvents, defaultStreamTransport, type StreamTransport } from './stream/sse-client.js'
export {
  applyEdaVerifyWorkflow,
  applyOrientCadWorkflow,
  applyValidateScriptWorkflow,
  executeTool,
  getWorkflowState,
  setWorkflowRunState,
} from './tools/registry.js'
export { routeGateBlock, type GateRouteHint } from './orchestrator/route.js'
export { runSupervisedAgentStream, type SupervisedStreamOptions } from './orchestrator/supervised-stream.js'
export { workerRoleForTool, parseWorkflowGateHint } from './orchestrator/worker-role.js'
export type { AgentHandoffV0, AgentWorkerRole } from './orchestrator/types.js'
export { buildFolderProjectManifest } from './project/folder-manifest.js'
export {
  applyPatches,
  normalizeCreateFileName,
  formatToolExecutionError,
  isFileMutationTool,
  isPendingFileReviewTool,
  FILE_MUTATION_TOOL_NAMES,
  PENDING_FILE_REVIEW_TOOL_NAMES,
} from './tools/apply-patches.js'
export { mergeToolArgs, mergeToolArgsForExecute } from './tools/merge-tool-args.js'
export {
  toolStreamArgsReady,
  toolSupportsEarlyStreamExecute,
  canEarlyAbortToolStream,
  allPendingToolsReady,
} from './tools/tool-args-ready.js'
export { resolveProjectFileName } from './tools/resolve-project-file.js'
export {
  parsePartialToolArgs,
  extractContentFromPartialArgs,
  extractPatchesFromPartialArgs,
  extractLegacyPatchFromPartialArgs,
  previewContentFromPartialArgs,
  extractJsonStringField,
} from './tools/parse-partial-tool-args.js'
export {
  createWorkflowRunState,
  gateToolCall,
  orientCadReportPasses,
  recordPelProgramVerifyOk,
  recordToolUse,
  spatialReportPasses,
  type WorkflowPhase,
  type WorkflowRunState,
} from './workflow/state-machine.js'
export {
  parseWorkflowSnapshot,
  serializeWorkflowSnapshot,
  workflowSnapshotRelativePath,
  WORKFLOW_SNAPSHOT_DIR,
} from './workflow/workflow-snapshot.js'
export { buildUserMessageContent, userMessage } from './multimodal/adapter.js'
export { DESKTOP_CAD_AGENT_DISCIPLINE } from './agent-discipline.js'
export {
  outputLooksLikeUndeliveredScript,
  shouldAbortReasoningWithoutTools,
  WORKFLOW_REASONING_BUDGET_NUDGE,
  WORKFLOW_TOOL_ONLY_NUDGE,
} from './workflow/script-output-guard.js'
export { createToolContext, type DesktopToolContextOptions } from './host/create-tool-context.js'
export {
  resolveScriptCode,
  executeValidateScript,
  executeRunScript,
  executeVerifyEda,
  executeProbeModel,
  executeRunSimulation,
  buildProjectFiles,
} from './tools/engine-executor.js'
