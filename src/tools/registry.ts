import {
  gatePelConnectorsForPatch,
  handleBuildProjectRunPlan,
  handleExplainDiagnostics,
  handleExportProjectPackage,
  handleGetCapabilities,
  handleGetSimulationBackends,
  handleValidateProject,
  handleValidateSimulation,
  parsePelBoard,
  pelBoardRelativePath,
} from 'xyzt-cad'
import { buildFolderProjectManifest } from '../project/folder-manifest.js'
import { DESKTOP_AGENT_TOOL_NAMES, RUNTIME_AGENT_TOOL_NAMES } from 'xyzt-agent-tools'
import type { LocalToolResult, ToolContext } from '../types.js'
import {
  countCadLeavesFromPaths,
  createWorkflowRunState,
  gateToolCall,
  isCadXyztFile,
  isEdaXyztFile,
  recordCadCritiqueOk,
  recordCadFullMutator,
  recordCadPlacementPatch,
  recordCadConstraintPatch,
  patchUsesPlacementConstraint,
  patchUsesRawAssemblyAt,
  recordCadSpatialOk,
  recordCadValidateOk,
  recordCadValidateFailed,
  recordEdaMutator,
  recordEdaVerifyOk,
  recordPelCadNodeVerified,
  recordPelPlanScope,
  recordPelProgramVerifyOk,
  recordProjectManifestCheck,
  recordToolUse,
  orientCadReportPasses,
  spatialReportPasses,
  type WorkflowRunState,
} from '../workflow/state-machine.js'
import { hydrateWorkflowFromArtifacts } from '../workflow/hydrate.js'
import { parseWorkflowSnapshot, workflowSnapshotRelativePath } from '../workflow/workflow-snapshot.js'
import { applyPatches, formatToolExecutionError, normalizeCreateFileName } from './apply-patches.js'
import {
  examplesPathBlockedResult,
  filterExamplesFromFileList,
  isExamplesPath,
} from './block-examples-path.js'
import { resolveProjectFileName } from './resolve-project-file.js'
import {
  executeProbeModel,
  executeRunScript,
  executeRunSimulation,
  executeValidateScript,
  executeVerifyEda,
} from './engine-executor.js'
import { appendCadSpatialNudge, appendValidateSpatialNudge } from './cad-spatial-nudge.js'
import { executeOrientCad } from './orient-cad-executor.js'
import {
  executePelActivateNode,
  executePelPlan,
  executePelReadDigest,
  executePelVerifyProgram,
} from './pel-executor.js'
import { executeRefreshProjectIndex } from './project-index-executor.js'
import { FILE_LEASES_REL_PATH, isFileWriteTool } from 'xyzt-cad'
import { gateFileLease, getPersistedLeaseStoreContent, leaseFilesFromToolResult } from './lease-gate.js'
import { executeSpatialThinking } from './spatial-thinking-executor.js'
import {
  executeAnalyzeEda,
  executeCritiqueScript,
  executeGetStepPartCode,
  executeLookupPart,
  executePlaceComponent,
  executeSearchComponents,
  executeSearchStepParts,
} from './tier-b-executor.js'
import { executeApplyEdaEdit, executeEditBoard, executeRunDrc } from './eda-edit-executor.js'
import { executeGetMassProperties, executeSolveJoints } from './cad-analysis-executor.js'
import { executeEditFeature, executeGetParams } from './cad-edit-executor.js'
import { executeApplyDirectEdit } from './cad-direct-edit-executor.js'
import {
  executeExportBom,
  executeExportGerberBundle,
  executeExportStep,
  executeExportStl,
  executeRunVerifyProfile,
  executeWriteArtifact,
} from './export-executor.js'

const workflowByRun = new WeakMap<object, WorkflowRunState>()

export function getWorkflowState(runKey: object, ctx?: ToolContext): WorkflowRunState {
  let s = workflowByRun.get(runKey)
  if (!s && ctx?.agentRunId) {
    s =
      ctx.readWorkflowSnapshot?.(ctx.agentRunId)
      ?? (() => {
        const raw = ctx.getFileContent(workflowSnapshotRelativePath(ctx.agentRunId!))
        return raw ? parseWorkflowSnapshot(raw) : null
      })()
      ?? undefined
  }
  if (!s) {
    s = (ctx ? hydrateWorkflowFromArtifacts(ctx) : null) ?? createWorkflowRunState()
    workflowByRun.set(runKey, s)
  }
  if (ctx && s.cadLeafCount === 0) {
    const cadLeaves = countCadLeavesFromPaths(ctx.listFilePaths())
    if (cadLeaves > 0) {
      s = { ...s, cadLeafCount: cadLeaves }
      if (cadLeaves >= 2) s = recordPelPlanScope(s, cadLeaves)
      workflowByRun.set(runKey, s)
    }
  }
  return s
}

export function setWorkflowRunState(runKey: object, state: WorkflowRunState): void {
  workflowByRun.set(runKey, state)
}

/** Inline validate after writes — same gate state as explicit validate_script. */
export function applyValidateScriptWorkflow(
  runKey: object,
  fileName: string,
  validationPayload: unknown,
): void {
  if (!isCadXyztFile(fileName)) return
  let wf = getWorkflowState(runKey)
  const parsed =
    validationPayload && typeof validationPayload === 'object'
      ? (validationPayload as { ok?: boolean })
      : {}
  if (parsed.ok === true) {
    wf = recordCadValidateOk(wf, fileName)
  } else {
    wf = recordCadValidateFailed(wf, fileName)
  }
  workflowByRun.set(runKey, wf)
}

function meshCountFromOrientPayload(raw: string): number {
  try {
    const parsed = JSON.parse(raw) as {
      bodies?: unknown[]
      spatial?: { bodies?: unknown[] }
      frameGraph?: { bodyCount?: number }
      oel?: { bodyCount?: number }
    }
    return (
      parsed.frameGraph?.bodyCount ??
      parsed.spatial?.bodies?.length ??
      parsed.bodies?.length ??
      parsed.oel?.bodyCount ??
      0
    )
  } catch {
    return 0
  }
}

/** Inline orient after validate — same gate state as explicit orient_cad. */
export function applyEdaVerifyWorkflow(runKey: object, fileName: string, verifyPayload: unknown): void {
  if (!isEdaXyztFile(fileName)) return
  const parsed =
    verifyPayload && typeof verifyPayload === 'object'
      ? (verifyPayload as { ok?: boolean })
      : {}
  if (parsed.ok !== true) return
  let wf = getWorkflowState(runKey)
  wf = recordEdaVerifyOk(wf, fileName)
  workflowByRun.set(runKey, wf)
}

export function applyOrientCadWorkflow(
  runKey: object,
  fileName: string,
  orientPayload: unknown,
): void {
  if (!isCadXyztFile(fileName)) return
  const parsed =
    orientPayload && typeof orientPayload === 'object'
      ? (orientPayload as {
          ok?: boolean
          gates?: { mechanicalOk?: boolean }
          spatial?: { ok?: boolean; checks?: Array<{ passed?: boolean }> }
          ledger?: {
            criticValid?: boolean
            assertions?: Array<{ status?: string }>
          }
        })
      : null
  if (!parsed || !orientCadReportPasses(parsed)) return
  const meshCount =
    typeof orientPayload === 'string'
      ? meshCountFromOrientPayload(orientPayload)
      : meshCountFromOrientPayload(JSON.stringify(orientPayload))
  let wf = getWorkflowState(runKey)
  wf = recordCadSpatialOk(wf, fileName, meshCount)
  if (meshCount <= 1 || parsed.gates?.mechanicalOk) {
    wf = recordCadCritiqueOk(wf, fileName, meshCount)
    wf = recordPelCadNodeVerified(wf, fileName)
  }
  workflowByRun.set(runKey, wf)
}

async function resolveFileContent(
  fileName: string,
  ctx: ToolContext,
): Promise<string | undefined> {
  const cached = ctx.getFileContent(fileName)
  if (cached !== undefined) return cached
  if (ctx.ensureFileContent) return ctx.ensureFileContent(fileName)
  return undefined
}

function fileWriteResult(
  fileName: string,
  content: string,
  ctx: ToolContext,
): LocalToolResult {
  if (ctx.sandboxEdits) {
    return {
      success: true,
      pending: true,
      result: `Preview ready for "${fileName}". Awaiting user acceptance.`,
      files: [{ name: fileName, content }],
    }
  }
  return {
    success: true,
    result: `Wrote "${fileName}".`,
    files: [{ name: fileName, content }],
  }
}

export async function executeTool(
  toolName: string,
  args: Record<string, unknown>,
  ctx: ToolContext,
  runKey: object = ctx,
): Promise<LocalToolResult> {
  try {
    return await executeToolInner(toolName, args, ctx, runKey)
  } catch (err) {
    return { success: false, result: formatToolExecutionError(toolName, err) }
  }
}

const RUNTIME_AGENT_TOOL_SET = new Set<string>(RUNTIME_AGENT_TOOL_NAMES)

async function executeToolInner(
  toolName: string,
  args: Record<string, unknown>,
  ctx: ToolContext,
  runKey: object,
): Promise<LocalToolResult> {
  if (!RUNTIME_AGENT_TOOL_SET.has(toolName)) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        code: 'TOOL_NOT_ALLOWED',
        error: `Tool "${toolName}" is not available. Model tools: ${DESKTOP_AGENT_TOOL_NAMES.join(', ')}.`,
        retryable: false,
      }),
    }
  }
  const wf = getWorkflowState(runKey, ctx)
  const leaseBlock = gateFileLease(toolName, args, ctx, runKey)
  if (leaseBlock) return leaseBlock
  if (toolName === 'patch_file') {
    const boardRaw = ctx.getFileContent(pelBoardRelativePath())
    const fileName = (args.fileName ?? args.path) as string | undefined
    if (boardRaw && fileName) {
      const connectorGate = gatePelConnectorsForPatch(parsePelBoard(boardRaw), fileName)
      if (connectorGate.blocked) {
        return { success: false, result: connectorGate.error ?? 'PEL connector gate blocked patch_file.' }
      }
    }
  }

  const gate = gateToolCall(wf, toolName, args)
  if (!gate.allowed) {
    return { success: false, result: gate.error ?? 'Workflow gate blocked this tool.' }
  }

  let result: LocalToolResult
  switch (toolName) {
    case 'ask_user':
      result = { success: true, result: 'Question presented to user. Awaiting their response.' }
      break
    case 'update_plan': {
      const title = (args.title as string) ?? 'Plan'
      const todos = Array.isArray(args.todos) ? args.todos.length : 0
      result = { success: true, result: `Plan updated: "${title}" with ${todos} tasks.` }
      break
    }
    case 'update_overview': {
      const content = String(args.content ?? '')
      if (ctx.sandboxEdits) {
        result = {
          success: true,
          pending: true,
          result: 'Overview preview ready. Awaiting user acceptance.',
          files: [{ name: 'README.md', content }],
        }
      } else {
        result = { success: true, result: 'Overview updated.', files: [{ name: 'README.md', content }] }
      }
      break
    }
    case 'list_files': {
      const paths = filterExamplesFromFileList(ctx.listFilePaths())
      result = paths.length
        ? { success: true, result: `Files in project:\n${paths.map(p => `- ${p}`).join('\n')}` }
        : { success: true, result: 'No files in project folder.' }
      break
    }
    case 'read_file': {
      const requested = typeof args.fileName === 'string' ? args.fileName.trim() : ''
      if (!requested) return { success: false, result: 'fileName is required.' }
      if (isExamplesPath(requested)) return examplesPathBlockedResult(requested)
      const paths = ctx.listFilePaths()
      const fileName = resolveProjectFileName(requested, paths) ?? requested
      if (isExamplesPath(fileName)) return examplesPathBlockedResult(fileName)
      const content = await resolveFileContent(fileName, ctx)
      if (content === undefined) {
        return {
          success: false,
          result: JSON.stringify(
            {
              ok: false,
              code: 'FILE_NOT_FOUND',
              requested,
              resolved: fileName,
              availableFiles: paths.slice(0, 60),
              hint: 'Call list_files or use the exact path from create_* / patch_file.',
            },
            null,
            2,
          ),
        }
      }
      result = {
        success: true,
        result: JSON.stringify({ ok: true, fileName, content }, null, 2),
      }
      break
    }
    case 'patch_file': {
      const fileName = args.fileName as string
      const patches = (args.patches as Array<{ old?: string; new?: string }> | undefined) ?? []
      if (!fileName || !patches.length) {
        return { success: false, result: 'patch_file requires fileName and patches.' }
      }
      const current = await resolveFileContent(fileName, ctx)
      if (current === undefined) return { success: false, result: `File "${fileName}" not found.` }
      const normalized = patches
        .filter(p => typeof p.old === 'string' && typeof p.new === 'string')
        .map(p => ({ old: p.old!, new: p.new! }))
      const applied = applyPatches(current, normalized)
      if (!applied.ok) return { success: false, result: applied.error }
      result = appendCadSpatialNudge(fileName, fileWriteResult(fileName, applied.content, ctx))
      break
    }
    case 'create_cad':
    case 'create_eda':
    case 'create_drawing':
    case 'create_simulation':
    case 'edit_file': {
      let fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
      if (toolName.startsWith('create_')) {
        fileName = normalizeCreateFileName(toolName, fileName || undefined)
      } else if (!fileName) {
        return { success: false, result: 'fileName is required.' }
      }
      let content = args.content as string | undefined
      if (toolName === 'edit_file' && args.old_content != null && args.new_content !== undefined) {
        const current = ctx.getFileContent(fileName)
        if (current === undefined) return { success: false, result: `File "${fileName}" not found.` }
        const applied = applyPatches(current, [
          { old: String(args.old_content), new: String(args.new_content) },
        ])
        if (!applied.ok) return { success: false, result: applied.error }
        content = applied.content
      }
      if (!content) return { success: false, result: 'content is required.' }
      result =
        toolName === 'create_cad'
          ? appendCadSpatialNudge(fileName, fileWriteResult(fileName, content, ctx))
          : fileWriteResult(fileName, content, ctx)
      break
    }
    case 'delete_file': {
      const fileName = args.fileName as string
      if (!fileName) return { success: false, result: 'fileName is required.' }
      if (ctx.sandboxEdits) {
        result = {
          success: true,
          pending: true,
          result: `Delete preview for "${fileName}". Awaiting user acceptance.`,
        }
      } else {
        result = { success: true, result: `File "${fileName}" deleted.` }
      }
      break
    }
    case 'validate_script': {
      const fileName = args.fileName as string | undefined
      result = appendValidateSpatialNudge(
        fileName,
        await executeValidateScript(args, ctx),
      )
      break
    }
    case 'verify_eda':
      result = await executeVerifyEda(args, ctx)
      break
    case 'run_drc':
      result = await executeRunDrc(args, ctx)
      break
    case 'edit_board':
      result = await executeEditBoard(args, ctx)
      break
    case 'apply_eda_edit':
      result = await executeApplyEdaEdit(args, ctx)
      break
    case 'probe_model':
      result = await executeProbeModel(args, ctx)
      break
    case 'spatial_thinking':
      result = await executeSpatialThinking(args, ctx)
      break
    case 'orient_cad':
      result = await executeOrientCad(args, ctx)
      break
    case 'pel_plan':
      result = await executePelPlan(args, ctx)
      break
    case 'pel_activate_node':
      result = await executePelActivateNode(args, ctx)
      break
    case 'pel_read_digest':
      result = await executePelReadDigest(args, ctx)
      break
    case 'pel_verify_program':
      result = await executePelVerifyProgram(args, ctx)
      break
    case 'refresh_project_index':
      result = await executeRefreshProjectIndex(args, ctx)
      break
    case 'acquire_file_lease':
    case 'release_file_lease': {
      const { executeFileLeaseTool } = await import('./lease-tool-executor.js')
      result = await executeFileLeaseTool(toolName, args, ctx, runKey)
      break
    }
    case 'run_simulation':
      if (!ctx.createSimulationJobRequest) {
        return {
          success: false,
          result: JSON.stringify({ ok: false, error: 'Simulation job runner unavailable' }),
        }
      }
      result = await executeRunSimulation(args, ctx, ctx.createSimulationJobRequest)
      break
    case 'run_script':
      result = await executeRunScript(args, ctx)
      break
    case 'get_capabilities':
      result = { success: true, result: JSON.stringify(handleGetCapabilities(), null, 2) }
      break
    case 'get_simulation_backends':
      result = {
        success: true,
        result: JSON.stringify(
          handleGetSimulationBackends({
            webgpu_available: true,
            ngspice_available: ctx.ngspiceAvailable === true,
            openfoam_available: false,
          }),
          null,
          2,
        ),
      }
      break
    case 'explain_diagnostics':
      result = { success: true, result: JSON.stringify(handleExplainDiagnostics(args), null, 2) }
      break
    case 'validate_project': {
      const manifestArgs =
        args.json != null || args.manifest != null
          ? args
          : {
              json: buildFolderProjectManifest(
                ctx.listFilePaths(),
                ctx.getFileContent,
                ctx.rootPath,
              ),
            }
      const out = handleValidateProject(manifestArgs as Record<string, unknown>)
      const valid = (out as { valid?: boolean }).valid === true
      result = { success: valid, result: JSON.stringify(out, null, 2) }
      break
    }
    case 'validate_simulation': {
      const out = handleValidateSimulation(args)
      const valid = (out as { valid?: boolean }).valid === true
      result = { success: valid, result: JSON.stringify(out, null, 2) }
      break
    }
    case 'run_simulation_study': {
      const { handleRunSimulation } = await import('xyzt-cad')
      const json = args.json ?? args.study
      if (json == null) {
        result = { success: false, result: JSON.stringify({ ok: false, error: 'json study required' }) }
        break
      }
      const out = handleRunSimulation({ json, project_id: args.project_id }) as {
        envelope?: { id?: string; status: string; summary?: unknown }
        error?: string
      }
      const ok = out.envelope?.status === 'ok'
      result = {
        success: ok,
        result: JSON.stringify({ ok, jobId: out.envelope?.id, envelope: out.envelope, error: out.error }, null, 2),
      }
      break
    }
    case 'export_project_package': {
      const manifestArgs =
        args.json != null || args.manifest != null
          ? args
          : {
              json: buildFolderProjectManifest(
                ctx.listFilePaths(),
                ctx.getFileContent,
                ctx.rootPath,
              ),
            }
      const out = handleExportProjectPackage(manifestArgs as Record<string, unknown>)
      result = { success: true, result: JSON.stringify(out, null, 2) }
      break
    }
    case 'build_project_run_plan': {
      const manifestArgs =
        args.json != null || args.manifest != null
          ? args
          : {
              json: buildFolderProjectManifest(
                ctx.listFilePaths(),
                ctx.getFileContent,
                ctx.rootPath,
              ),
            }
      const out = handleBuildProjectRunPlan(manifestArgs as Record<string, unknown>)
      result = { success: true, result: JSON.stringify(out, null, 2) }
      break
    }
    case 'export_step':
      result = await executeExportStep(args, ctx)
      break
    case 'export_stl':
      result = await executeExportStl(args, ctx)
      break
    case 'export_gerber_bundle':
      result = await executeExportGerberBundle(args, ctx)
      break
    case 'export_bom':
      result = await executeExportBom(args, ctx)
      break
    case 'write_artifact':
      result = await executeWriteArtifact(args, ctx)
      break
    case 'run_verify_profile':
      result = await executeRunVerifyProfile(args, ctx)
      break
    case 'critique_script':
      result = await executeCritiqueScript(args, ctx)
      break
    case 'analyze_eda':
      result = await executeAnalyzeEda(args, ctx)
      break
    case 'search_step_parts':
      result = executeSearchStepParts(args)
      break
    case 'get_step_part_code':
      result = executeGetStepPartCode(args)
      break
    case 'search_components':
      result = await executeSearchComponents(args, ctx)
      break
    case 'lookup_part':
      result = await executeLookupPart(args, ctx)
      break
    case 'place_component':
      result = await executePlaceComponent(args, ctx)
      break
    case 'get_params':
      result = await executeGetParams(args, ctx)
      break
    case 'edit_feature':
      result = await executeEditFeature(args, ctx)
      break
    case 'apply_direct_edit':
      result = await executeApplyDirectEdit(args, ctx)
      break
    case 'get_mass_properties':
      result = await executeGetMassProperties(args, ctx)
      break
    case 'solve_joints':
      result = await executeSolveJoints(args, ctx)
      break
    default:
      return { success: false, result: `Unknown tool: ${toolName}` }
  }

  let nextWf = wf

  const meshCountFromResult = (raw: string): number => {
    try {
      const parsed = JSON.parse(raw) as {
        bodies?: unknown[]
        spatial?: { bodies?: unknown[] }
        frameGraph?: { bodyCount?: number }
        oel?: { bodyCount?: number }
      }
      return (
        parsed.frameGraph?.bodyCount ??
        parsed.spatial?.bodies?.length ??
        parsed.bodies?.length ??
        parsed.oel?.bodyCount ??
        0
      )
    } catch {
      return 0
    }
  }

  if (toolName === 'validate_project' && result.success) {
    const cadLeaves = countCadLeavesFromPaths(ctx.listFilePaths())
    nextWf = recordProjectManifestCheck(nextWf, cadLeaves)
  }
  if (toolName === 'validate_script' && result.success) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    if (fileName) {
      try {
        const parsed = JSON.parse(result.result) as { ok?: boolean }
        if (parsed.ok === true) nextWf = recordCadValidateOk(nextWf, fileName)
      } catch {
        /* malformed — do not advance workflow */
      }
    }
  }
  if (toolName === 'spatial_thinking' && result.success) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    if (fileName) {
      try {
        const parsed = JSON.parse(result.result) as {
          ok?: boolean
          checks?: Array<{ passed?: boolean }>
        }
        if (spatialReportPasses(parsed)) {
          nextWf = recordCadSpatialOk(nextWf, fileName, meshCountFromResult(result.result))
        }
      } catch {
        /* malformed — do not advance workflow */
      }
    }
  }
  if (toolName === 'orient_cad' && result.success) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    if (fileName) {
      try {
        const parsed = JSON.parse(result.result) as {
          ok?: boolean
          gates?: { mechanicalOk?: boolean }
          spatial?: { ok?: boolean; checks?: Array<{ passed?: boolean }> }
          ledger?: {
            criticValid?: boolean
            assertions?: Array<{ status?: string }>
          }
        }
        if (orientCadReportPasses(parsed)) {
          const meshCount = meshCountFromResult(result.result)
          const matesFullyConstrained =
            (parsed as { mateSolveReport?: { fullyConstrained?: boolean } }).mateSolveReport
              ?.fullyConstrained === true
          nextWf = recordCadSpatialOk(nextWf, fileName, meshCount, { matesFullyConstrained })
          if (meshCount <= 1 || parsed.gates?.mechanicalOk) {
            nextWf = recordCadCritiqueOk(nextWf, fileName, meshCount)
            nextWf = recordPelCadNodeVerified(nextWf, fileName)
          }
        }
      } catch {
        /* malformed — do not advance workflow */
      }
    }
  }
  if (toolName === 'critique_script' && result.success) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    if (fileName) {
      try {
        const parsed = JSON.parse(result.result) as { ok?: boolean }
        if (parsed.ok === true) {
          nextWf = recordCadCritiqueOk(nextWf, fileName)
          nextWf = recordPelCadNodeVerified(nextWf, fileName)
        }
      } catch {
        /* malformed — do not advance workflow */
      }
    }
  }
  if ((toolName === 'verify_eda' || toolName === 'run_drc') && result.success) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    const edaFile =
      fileName && isEdaXyztFile(fileName)
        ? fileName
        : typeof args.path === 'string' && isEdaXyztFile(args.path.trim())
          ? args.path.trim()
          : ''
    if (edaFile) {
      try {
        const parsed = JSON.parse(result.result) as { ok?: boolean }
        if (parsed.ok === true) nextWf = recordEdaVerifyOk(nextWf, edaFile)
      } catch {
        /* malformed — do not advance workflow */
      }
    }
  }
  if (toolName === 'pel_plan' && result.success) {
    try {
      const parsed = JSON.parse(result.result) as { board?: { nodes?: Array<{ kind?: string }> } }
      const cadCount =
        parsed.board?.nodes?.filter(n => n.kind === 'cad_file').length ?? 0
      nextWf = recordPelPlanScope(nextWf, cadCount)
    } catch {
      /* ignore */
    }
  }
  if (toolName === 'edit_file' && result.success) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    if (fileName && isCadXyztFile(fileName)) {
      nextWf = recordCadFullMutator(nextWf, fileName)
    } else if (fileName && isEdaXyztFile(fileName)) {
      nextWf = recordEdaMutator(nextWf, fileName)
    }
  }
  if (
    (toolName === 'patch_file' || toolName === 'apply_eda_edit' || toolName === 'edit_board') &&
    result.success
  ) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    if (fileName && isCadXyztFile(fileName)) {
      const content = typeof args.content === 'string' ? args.content : ''
      nextWf =
        patchUsesPlacementConstraint(content) && !patchUsesRawAssemblyAt(content)
          ? recordCadConstraintPatch(nextWf, fileName)
          : recordCadPlacementPatch(nextWf, fileName)
    } else if (fileName && isEdaXyztFile(fileName)) {
      nextWf = recordEdaMutator(nextWf, fileName)
    }
  }
  if (
    (toolName === 'edit_feature' || toolName === 'apply_direct_edit') &&
    result.success
  ) {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    if (fileName && isCadXyztFile(fileName)) {
      nextWf = recordCadPlacementPatch(nextWf, fileName)
    }
  }
  if (result.success && (result.files?.length || isFileWriteTool(toolName))) {
    leaseFilesFromToolResult(ctx, result.files)
    const storeRaw = getPersistedLeaseStoreContent(ctx)
    if (storeRaw) {
      const base = result.files ?? []
      result = {
        ...result,
        files: [
          ...base.filter(f => f.name !== FILE_LEASES_REL_PATH),
          { name: FILE_LEASES_REL_PATH, content: storeRaw },
        ],
      }
    }
  }
  if (toolName === 'pel_verify_program' && result.success) {
    try {
      const parsed = JSON.parse(result.result) as { ok?: boolean }
      if (parsed.ok === true) nextWf = recordPelProgramVerifyOk(nextWf)
    } catch {
      /* malformed verify result — do not advance workflow */
    }
  }
  const finalWf = recordToolUse(nextWf, toolName, args)
  workflowByRun.set(runKey, finalWf)
  if (ctx.agentRunId && ctx.persistWorkflowSnapshot) {
    void ctx.persistWorkflowSnapshot(ctx.agentRunId, finalWf)
  }
  return result
}
