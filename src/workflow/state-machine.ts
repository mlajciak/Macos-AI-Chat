import { DESKTOP_AGENT_TOOL_NAMES } from 'xyzt-agent-tools'

const DESKTOP_AGENT_TOOL_SET = new Set<string>(DESKTOP_AGENT_TOOL_NAMES)

export type WorkflowPhase =
  | 'intake'
  | 'preflight'
  | 'plan'
  | 'author'
  | 'validate'
  | 'orient'
  | 'export'
  | 'gate'
  | 'overview'
  | 'complete'

/** Per-file validate tools that count toward ship (not validate_project). */
const SHIP_VALIDATE_TOOLS = new Set([
  'validate_script',
  'verify_eda',
  'run_drc',
  'validate_simulation',
  'run_verify_profile',
])

const ORIENT_TOOLS = new Set(['spatial_thinking', 'orient_cad'])

const MECHANICAL_VERIFY_TOOLS = new Set(['critique_script', 'orient_cad', 'run_verify_profile'])

const EXPORT_TOOLS = new Set([
  'export_step',
  'export_stl',
  'export_gerber_bundle',
  'export_bom',
  'export_project_package',
  'write_artifact',
])

const AUTHOR_TOOLS = new Set([
  'create_cad',
  'create_eda',
  'create_drawing',
  'create_simulation',
  'patch_file',
  'edit_file',
  'delete_file',
])

export const CAD_MUTATOR_TOOLS = new Set([
  'patch_file',
  'edit_file',
  'edit_feature',
  'apply_direct_edit',
  'run_script',
])

const EDA_MUTATOR_TOOLS = new Set(['patch_file', 'edit_file', 'apply_eda_edit', 'edit_board'])

const ARTIFACT_MUTATOR_TOOLS = new Set([
  ...CAD_MUTATOR_TOOLS,
  ...EDA_MUTATOR_TOOLS,
  'create_cad',
  'create_eda',
  'create_drawing',
  'create_simulation',
])

const PREFLIGHT_TOOLS = new Set(['get_capabilities', 'validate_project'])

/** Per-CAD-file OEL gate state (Oriented Engineering Loop). */
export interface CadSpatialFileState {
  validateOk: boolean
  spatialOk: boolean
  critiqueOk: boolean
  meshCount: number
  matesFullyConstrained?: boolean
}

export interface EdaVerifyFileState {
  verifyOk: boolean
}

export interface WorkflowRunState {
  phase: WorkflowPhase
  sawPreflight: boolean
  sawPlan: boolean
  sawValidate: boolean
  sawOrient: boolean
  sawExport: boolean
  sawGate: boolean
  touchedArtifacts: boolean
  deliverablesRequested: boolean
  cadSpatialByFile: Record<string, CadSpatialFileState>
  touchedCadFiles: string[]
  touchedEdaFiles: string[]
  edaVerifyByFile: Record<string, EdaVerifyFileState>
  sawProjectManifestCheck: boolean
  cadLeafCount: number
  /** PEL: multi-file program requires all CAD leaves verified before ship. */
  pelProgramRequired: boolean
  pelCadNodesTotal: number
  pelCadNodesVerified: number
  /** PEL-5: flight/episode program verify before ship on multi-file programs. */
  pelProgramVerifyOk: boolean
}

export function createWorkflowRunState(): WorkflowRunState {
  return {
    phase: 'intake',
    sawPreflight: false,
    sawPlan: false,
    sawValidate: false,
    sawOrient: false,
    sawExport: false,
    sawGate: false,
    touchedArtifacts: false,
    deliverablesRequested: false,
    cadSpatialByFile: {},
    touchedCadFiles: [],
    touchedEdaFiles: [],
    edaVerifyByFile: {},
    sawProjectManifestCheck: false,
    cadLeafCount: 0,
    pelProgramRequired: false,
    pelCadNodesTotal: 0,
    pelCadNodesVerified: 0,
    pelProgramVerifyOk: false,
  }
}

export function isCadXyztFile(fileName: string): boolean {
  return (
    fileName.endsWith('.xyzt') &&
    !fileName.endsWith('.xyzt.eda') &&
    !fileName.endsWith('.xyzt.draft') &&
    !fileName.endsWith('.xyzt.simulation')
  )
}

export function isEdaXyztFile(fileName: string): boolean {
  return fileName.endsWith('.xyzt.eda')
}

export function countCadLeavesFromPaths(paths: string[]): number {
  return paths.filter(isCadXyztFile).length
}

export function spatialReportPasses(parsed: {
  ok?: boolean
  checks?: Array<{ passed?: boolean }>
}): boolean {
  if (parsed.ok !== true) return false
  if (parsed.checks?.some(c => c.passed === false)) return false
  return true
}

/** orient_cad / full OEL pass — spatial checks plus open constraint ledger failures. */
export function orientCadReportPasses(parsed: {
  ok?: boolean
  spatial?: { ok?: boolean; checks?: Array<{ passed?: boolean }> }
  ledger?: {
    criticValid?: boolean
    assertions?: Array<{ status?: string }>
  }
}): boolean {
  if (parsed.ok !== true) return false
  if (parsed.spatial != null && !spatialReportPasses(parsed.spatial)) return false
  const ledger = parsed.ledger
  if (ledger) {
    if (ledger.criticValid === false) return false
    if (ledger.assertions?.some(a => a.status === 'fail')) return false
  }
  return true
}

function cadFileNameFromArgs(toolName: string, args?: Record<string, unknown>): string | undefined {
  const raw = typeof args?.fileName === 'string' ? args.fileName.trim() : ''
  if (!raw) return undefined
  if (toolName.startsWith('create_cad')) return raw.endsWith('.xyzt') ? raw : `${raw.replace(/\.xyzt$/i, '')}.xyzt`
  return raw
}

function defaultCadState(): CadSpatialFileState {
  return { validateOk: false, spatialOk: false, critiqueOk: false, meshCount: 0 }
}

function touchCadFile(files: string[], fileName: string): string[] {
  if (!isCadXyztFile(fileName) || files.includes(fileName)) return files
  return [...files, fileName]
}

function touchEdaFile(files: string[], fileName: string): string[] {
  if (!isEdaXyztFile(fileName) || files.includes(fileName)) return files
  return [...files, fileName]
}

export function recordTouchCadFile(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  return { ...state, touchedCadFiles: touchCadFile(state.touchedCadFiles, fileName) }
}

export function recordTouchEdaFile(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isEdaXyztFile(fileName)) return state
  return { ...state, touchedEdaFiles: touchEdaFile(state.touchedEdaFiles, fileName) }
}

export function recordCadValidateOk(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  const prev = state.cadSpatialByFile[fileName] ?? defaultCadState()
  return {
    ...recordTouchCadFile(state, fileName),
    cadSpatialByFile: {
      ...state.cadSpatialByFile,
      [fileName]: { ...prev, validateOk: true, spatialOk: false, critiqueOk: false },
    },
  }
}

export function recordCadValidateFailed(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  const prev = state.cadSpatialByFile[fileName] ?? defaultCadState()
  return {
    ...recordTouchCadFile(state, fileName),
    cadSpatialByFile: {
      ...state.cadSpatialByFile,
      [fileName]: { ...prev, validateOk: false, spatialOk: false, critiqueOk: false },
    },
  }
}

export function recordCadSpatialOk(
  state: WorkflowRunState,
  fileName: string,
  meshCount = 0,
  opts?: { matesFullyConstrained?: boolean },
): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  const prev = state.cadSpatialByFile[fileName] ?? defaultCadState()
  return {
    ...state,
    cadSpatialByFile: {
      ...state.cadSpatialByFile,
      [fileName]: {
        ...prev,
        spatialOk: true,
        meshCount: meshCount > 0 ? meshCount : prev.meshCount,
        critiqueOk: meshCount <= 1 ? prev.critiqueOk : false,
        matesFullyConstrained: opts?.matesFullyConstrained ?? prev.matesFullyConstrained,
      },
    },
  }
}

/** Constraint-only patch: invalidate spatial verify but not full validate. */
export function recordCadConstraintPatch(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  const prev = state.cadSpatialByFile[fileName] ?? defaultCadState()
  if (!prev.validateOk) return recordTouchCadFile(state, fileName)
  return {
    ...recordTouchCadFile(state, fileName),
    cadSpatialByFile: {
      ...state.cadSpatialByFile,
      [fileName]: { ...prev, spatialOk: false },
    },
  }
}

export function patchUsesRawAssemblyAt(content: string): boolean {
  return /\bat\s*:\s*\[/.test(content)
}

export function patchUsesPlacementConstraint(content: string): boolean {
  return (
    /placementSpec\s*\(/.test(content) ||
    /\.mate\s*\(/.test(content) ||
    /\.coaxial\s*\(/.test(content) ||
    /\.concentric\s*\(/.test(content) ||
    /designContract\s*\(/.test(content)
  )
}

export function recordEdaVerifyOk(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isEdaXyztFile(fileName)) return state
  return {
    ...recordTouchEdaFile(state, fileName),
    edaVerifyByFile: {
      ...state.edaVerifyByFile,
      [fileName]: { verifyOk: true },
    },
  }
}

export function recordEdaMutator(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isEdaXyztFile(fileName)) return state
  const next = recordTouchEdaFile(state, fileName)
  const prev = next.edaVerifyByFile[fileName]
  if (!prev?.verifyOk) return next
  return {
    ...next,
    edaVerifyByFile: {
      ...next.edaVerifyByFile,
      [fileName]: { verifyOk: false },
    },
  }
}

export function recordProjectManifestCheck(
  state: WorkflowRunState,
  cadLeafCount: number,
): WorkflowRunState {
  let next: WorkflowRunState = {
    ...state,
    sawProjectManifestCheck: true,
    cadLeafCount,
  }
  if (cadLeafCount >= 2) {
    next = recordPelPlanScope(next, cadLeafCount)
  }
  return next
}

export function recordPelPlanScope(
  state: WorkflowRunState,
  cadFileCount: number,
): WorkflowRunState {
  if (cadFileCount < 2) {
    return { ...state, pelProgramRequired: false, pelCadNodesTotal: 0, pelCadNodesVerified: 0 }
  }
  return {
    ...state,
    pelProgramRequired: true,
    pelCadNodesTotal: cadFileCount,
    pelCadNodesVerified: 0,
  }
}

export function recordPelProgramVerifyOk(state: WorkflowRunState): WorkflowRunState {
  return { ...state, pelProgramVerifyOk: true, sawGate: true }
}

export function recordPelCadNodeVerified(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!state.pelProgramRequired) return state
  const cad = state.cadSpatialByFile[fileName]
  if (!cad?.critiqueOk) return state
  const verified = Math.min(state.pelCadNodesVerified + 1, state.pelCadNodesTotal)
  return { ...state, pelCadNodesVerified: verified }
}

export function recordCadCritiqueOk(
  state: WorkflowRunState,
  fileName: string,
  meshCount = 0,
): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  const prev = state.cadSpatialByFile[fileName] ?? defaultCadState()
  return {
    ...state,
    cadSpatialByFile: {
      ...state.cadSpatialByFile,
      [fileName]: {
        ...prev,
        critiqueOk: true,
        meshCount: meshCount > 0 ? meshCount : prev.meshCount,
        spatialOk: true,
      },
    },
  }
}

/** Full CAD rewrite — require fresh validate/orient. */
export function recordCadFullMutator(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  return {
    ...recordTouchCadFile(state, fileName),
    cadSpatialByFile: {
      ...state.cadSpatialByFile,
      [fileName]: defaultCadState(),
    },
  }
}

/** After a placement patch, require fresh spatial + critic on multi-body CAD. */
export function recordCadPlacementPatch(state: WorkflowRunState, fileName: string): WorkflowRunState {
  if (!isCadXyztFile(fileName)) return state
  const prev = state.cadSpatialByFile[fileName] ?? defaultCadState()
  if (!prev.validateOk) return recordTouchCadFile(state, fileName)
  return {
    ...recordTouchCadFile(state, fileName),
    cadSpatialByFile: {
      ...state.cadSpatialByFile,
      [fileName]: { ...prev, spatialOk: false, critiqueOk: false },
    },
  }
}

export function cadFileNeedsMechanicalVerify(cad: CadSpatialFileState | undefined): boolean {
  return !!cad?.validateOk && cad.meshCount > 1
}

export interface WorkflowGateResult {
  allowed: boolean
  error?: string
  reminder?: string
}

function gateCadFileMutator(state: WorkflowRunState, fileName: string): WorkflowGateResult | null {
  const cad = state.cadSpatialByFile[fileName]
  if (!cad?.validateOk) {
    return {
      allowed: false,
      error: JSON.stringify({
        ok: false,
        code: 'WORKFLOW_VALIDATE_REQUIRED',
        error: `Run validate_script on "${fileName}" before editing this CAD file.`,
        next_tool: 'validate_script',
        fileName,
        retryable: true,
      }),
      reminder: 'Compile-check the CAD script before mutating geometry.',
    }
  }
  if (!cad.spatialOk) {
    return {
      allowed: false,
      error: JSON.stringify({
        ok: false,
        code: 'WORKFLOW_SPATIAL_REQUIRED',
        error: `Run orient_cad on "${fileName}" before CAD placement or geometry edits.`,
        next_tool: 'orient_cad',
        fileName,
        retryable: true,
      }),
      reminder: 'OEL orient phase required after validate_script on this CAD file.',
    }
  }
  return null
}

export function gateRawAssemblyAtPatch(
  state: WorkflowRunState,
  fileName: string,
  content: string,
): WorkflowGateResult | null {
  const cad = state.cadSpatialByFile[fileName]
  if (!cad?.validateOk) return null
  if (
    patchUsesRawAssemblyAt(content) &&
    !patchUsesPlacementConstraint(content) &&
    cad.matesFullyConstrained !== true
  ) {
    return {
      allowed: false,
      error: JSON.stringify({
        ok: false,
        code: 'WORKFLOW_CONSTRAINT_REQUIRED',
        error: `Use mates/placementSpec on "${fileName}" — raw at:[x,y,z] blocked until mateSolveReport.fullyConstrained.`,
        next_tool: 'orient_cad',
        fileName,
        retryable: true,
      }),
      reminder: 'Declare constraints; engine solves placement.',
    }
  }
  return null
}

function isCadMutatorTool(toolName: string, args?: Record<string, unknown>): boolean {
  if (!CAD_MUTATOR_TOOLS.has(toolName)) return false
  if (toolName !== 'run_script') return true
  const fileName = cadFileNameFromArgs(toolName, args)
  return !!fileName && isCadXyztFile(fileName)
}

function edaFileNameFromArgs(toolName: string, args?: Record<string, unknown>): string | undefined {
  const raw =
    typeof args?.fileName === 'string'
      ? args.fileName.trim()
      : typeof args?.path === 'string'
        ? args.path.trim()
        : typeof args?.edaFile === 'string'
          ? args.edaFile.trim()
          : ''
  if (!raw) return undefined
  if (toolName.startsWith('create_eda')) return raw.endsWith('.xyzt.eda') ? raw : `${raw.replace(/\.xyzt\.eda$/i, '')}.xyzt.eda`
  return raw
}

function isEdaMutatorTool(toolName: string, args?: Record<string, unknown>): boolean {
  if (toolName === 'patch_file') {
    const fileName = edaFileNameFromArgs(toolName, args)
    return !!fileName && isEdaXyztFile(fileName)
  }
  return EDA_MUTATOR_TOOLS.has(toolName)
}

function requiresAuthoringPreflight(toolName: string, args?: Record<string, unknown>): boolean {
  if (AUTHOR_TOOLS.has(toolName)) return true
  if (isCadMutatorTool(toolName, args)) return true
  if (isEdaMutatorTool(toolName, args)) return true
  return false
}

function gateEdaFileMutator(state: WorkflowRunState, fileName: string): WorkflowGateResult | null {
  const verify = state.edaVerifyByFile[fileName]
  if (verify?.verifyOk) return null
  if (!state.touchedEdaFiles.includes(fileName)) return null
  return {
    allowed: false,
    error: JSON.stringify({
      ok: false,
      code: 'WORKFLOW_EDA_VERIFY_REQUIRED',
      error: `Run verify_eda on "${fileName}" before further EDA edits.`,
      next_tool: 'verify_eda',
      fileName,
      retryable: true,
    }),
    reminder: 'EDA placement edits require a passing verify_eda after the last mutation.',
  }
}

export function recordToolUse(
  state: WorkflowRunState,
  toolName: string,
  args?: Record<string, unknown>,
): WorkflowRunState {
  const next = { ...state }
  if (PREFLIGHT_TOOLS.has(toolName)) {
    next.sawPreflight = true
    if (next.phase === 'intake') next.phase = 'preflight'
  }
  if (toolName === 'update_plan' || toolName === 'pel_plan') {
    next.sawPlan = true
    if (next.phase === 'preflight' || next.phase === 'intake') next.phase = 'plan'
  }
  if (toolName === 'pel_plan' || toolName === 'pel_activate_node' || toolName === 'pel_read_digest') {
    next.sawOrient = true
  }
  if (AUTHOR_TOOLS.has(toolName) || ARTIFACT_MUTATOR_TOOLS.has(toolName)) {
    next.touchedArtifacts = true
    if (['intake', 'preflight', 'plan'].includes(next.phase)) next.phase = 'author'
  }
  if (SHIP_VALIDATE_TOOLS.has(toolName)) {
    next.sawValidate = true
    if (next.touchedArtifacts) next.phase = 'validate'
  }
  if (ORIENT_TOOLS.has(toolName)) {
    next.sawOrient = true
    if (next.touchedArtifacts) next.phase = 'orient'
  }
  if (EXPORT_TOOLS.has(toolName)) {
    next.sawExport = true
    next.deliverablesRequested = true
    next.phase = 'export'
  }
  if (MECHANICAL_VERIFY_TOOLS.has(toolName)) {
    next.sawGate = true
    if (next.phase === 'orient' || next.phase === 'validate') next.phase = 'gate'
  }
  if (toolName === 'update_overview' && next.phase !== 'overview') {
    next.phase = 'overview'
  }
  const fileName = cadFileNameFromArgs(toolName, args)
  if (fileName && isCadXyztFile(fileName) && ARTIFACT_MUTATOR_TOOLS.has(toolName)) {
    next.touchedCadFiles = touchCadFile(next.touchedCadFiles, fileName)
  }
  if (fileName && isEdaXyztFile(fileName) && EDA_MUTATOR_TOOLS.has(toolName)) {
    next.touchedEdaFiles = touchEdaFile(next.touchedEdaFiles, fileName)
  }
  return next
}

export function gateToolCall(
  state: WorkflowRunState,
  toolName: string,
  args?: Record<string, unknown>,
): WorkflowGateResult {
  if (toolName === 'patch_file') {
    const fileName = cadFileNameFromArgs(toolName, args)
    if (fileName && isCadXyztFile(fileName)) {
      const content = typeof args?.content === 'string' ? args.content : ''
      const atGate = gateRawAssemblyAtPatch(state, fileName, content)
      if (atGate) return atGate
    }
  }

  if (DESKTOP_AGENT_TOOL_SET.has(toolName)) {
    return { allowed: true }
  }

  if (requiresAuthoringPreflight(toolName, args) && !state.sawPreflight && !PREFLIGHT_TOOLS.has(toolName)) {
    return {
      allowed: false,
      error: JSON.stringify({
        ok: false,
        code: 'WORKFLOW_PREFLIGHT_REQUIRED',
        error:
          'Call get_capabilities (and validate_project when multi-file) before create_cad, patch_file, or other authoring tools.',
        next_tool: 'get_capabilities',
        retryable: true,
      }),
      reminder: 'Principal loop: preflight with real tool JSON before any design authoring.',
    }
  }

  if (
    state.cadLeafCount >= 2 &&
    !state.sawProjectManifestCheck &&
    requiresAuthoringPreflight(toolName, args) &&
    !PREFLIGHT_TOOLS.has(toolName)
  ) {
    return {
      allowed: false,
      error: JSON.stringify({
        ok: false,
        code: 'WORKFLOW_PROJECT_VALIDATE_REQUIRED',
        error: 'Multi-file CAD project: run validate_project after get_capabilities before authoring.',
        next_tool: 'validate_project',
        retryable: true,
      }),
      reminder: 'Preflight manifest check required when multiple CAD leaves exist.',
    }
  }

  if (isCadMutatorTool(toolName, args)) {
    const fileName = cadFileNameFromArgs(toolName, args)
    if (fileName && isCadXyztFile(fileName)) {
      const cadGate = gateCadFileMutator(state, fileName)
      if (cadGate) return cadGate
    }
  }

  if (isEdaMutatorTool(toolName, args)) {
    const fileName = edaFileNameFromArgs(toolName, args)
    if (fileName && isEdaXyztFile(fileName)) {
      const edaGate = gateEdaFileMutator(state, fileName)
      if (edaGate) return edaGate
    }
  }

  if (toolName === 'update_overview') {
    if (state.pelProgramRequired && !state.pelProgramVerifyOk) {
      return {
        allowed: false,
        error: JSON.stringify({
          ok: false,
          code: 'WORKFLOW_PEL_FLIGHT_VERIFY_REQUIRED',
          error:
            'PEL program closure requires pel_verify_program (flight/episode) on all manifest targets before update_overview.',
          next_tool: 'pel_verify_program',
          retryable: true,
        }),
        reminder: 'Run pel_verify_program after all CAD nodes pass OEL mechanical verify.',
      }
    }
    if (state.pelProgramRequired && state.pelCadNodesVerified < state.pelCadNodesTotal) {
      return {
        allowed: false,
        error: JSON.stringify({
          ok: false,
          code: 'WORKFLOW_PEL_PROGRAM_VERIFY_REQUIRED',
          error: `PEL program gate: ${state.pelCadNodesVerified}/${state.pelCadNodesTotal} CAD nodes verified. Run orient_cad + critique on each CAD file, or pel_activate_node per subsystem.`,
          next_tool: 'pel_read_digest',
          retryable: true,
        }),
        reminder: 'Multi-file program: complete OEL verify on all CAD leaves before update_overview.',
      }
    }

    for (const fileName of state.touchedCadFiles) {
      const cad = state.cadSpatialByFile[fileName]
      if (!cad?.validateOk) {
        return {
          allowed: false,
          error: JSON.stringify({
            ok: false,
            code: 'WORKFLOW_VALIDATE_REQUIRED',
            error: `Run validate_script on "${fileName}" before update_overview.`,
            next_tool: 'validate_script',
            fileName,
            retryable: true,
          }),
          reminder: 'Each touched CAD file needs validate_script before ship.',
        }
      }
    }

    for (const fileName of state.touchedEdaFiles) {
      if (!state.edaVerifyByFile[fileName]?.verifyOk) {
        return {
          allowed: false,
          error: JSON.stringify({
            ok: false,
            code: 'WORKFLOW_EDA_VERIFY_REQUIRED',
            error: `Run verify_eda or run_drc on "${fileName}" before update_overview.`,
            next_tool: 'verify_eda',
            fileName,
            retryable: true,
          }),
          reminder: 'Each touched EDA file needs verify_eda before ship.',
        }
      }
    }

    if (
      state.touchedArtifacts &&
      state.touchedCadFiles.length === 0 &&
      state.touchedEdaFiles.length === 0 &&
      !state.sawValidate
    ) {
      return {
        allowed: false,
        error: JSON.stringify({
          ok: false,
          code: 'WORKFLOW_VALIDATE_REQUIRED',
          error:
            'Run validate_script, verify_eda, or validate_simulation before update_overview.',
          retryable: true,
        }),
        reminder: 'Complete validation before updating the project overview.',
      }
    }

    if (state.deliverablesRequested && !state.sawExport && !state.sawGate) {
      return {
        allowed: false,
        error: JSON.stringify({
          ok: false,
          code: 'WORKFLOW_EXPORT_REQUIRED',
          error: 'Export deliverables or run_verify_profile before update_overview.',
          retryable: true,
        }),
      }
    }
    for (const [fileName, cad] of Object.entries(state.cadSpatialByFile)) {
      if (cadFileNeedsMechanicalVerify(cad) && !cad.critiqueOk) {
        return {
          allowed: false,
          error: JSON.stringify({
            ok: false,
            code: 'WORKFLOW_MECHANICAL_VERIFY_REQUIRED',
            error: `Multi-body CAD "${fileName}" requires orient_cad or critique_script before update_overview.`,
            next_tool: 'orient_cad',
            fileName,
            meshCount: cad.meshCount,
            retryable: true,
          }),
          reminder: 'OEL mechanical verify gate: run orient_cad (strict) after spatial orientation.',
        }
      }
    }
  }
  return { allowed: true }
}
