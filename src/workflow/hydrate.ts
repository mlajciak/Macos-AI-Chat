import {
  parsePelBoard,
  parsePelRun,
  pelBoardRelativePath,
  pelRunRelativePath,
  type PelRunV0,
} from 'xyzt-cad'
import type { ToolContext } from '../types.js'
import {
  createWorkflowRunState,
  recordPelPlanScope,
  type CadSpatialFileState,
  type WorkflowPhase,
  type WorkflowRunState,
} from './state-machine.js'

function cadStateFromPelGates(
  fileName: string,
  gates: PelRunV0['gates'],
): CadSpatialFileState {
  const mechanical = !!gates.mechanicalByFile[fileName]
  const oriented = !!gates.orientByFile[fileName]
  return {
    validateOk: !!gates.compileByFile[fileName],
    spatialOk: oriented || mechanical,
    critiqueOk: mechanical,
    meshCount: mechanical ? 2 : oriented ? 1 : 0,
  }
}

function workflowPhaseFromPel(phase: PelRunV0['phase']): WorkflowPhase {
  switch (phase) {
    case 'decompose':
      return 'plan'
    case 'author':
      return 'author'
    case 'orient':
      return 'orient'
    case 'verify':
      return 'validate'
    case 'integrate':
      return 'gate'
    case 'ship':
      return 'complete'
    case 'blocked':
      return 'gate'
    default:
      return 'intake'
  }
}

/** Restore workflow gates from persisted PEL/OEL artifacts (FL-1 OEL-1). */
export function hydrateWorkflowFromArtifacts(ctx: ToolContext): WorkflowRunState | null {
  const runRaw = ctx.getFileContent(pelRunRelativePath())
  if (!runRaw) return null
  const pelRun = parsePelRun(runRaw)
  if (!pelRun) return null

  let state = createWorkflowRunState()
  state.phase = workflowPhaseFromPel(pelRun.phase)

  const allFiles = new Set([
    ...Object.keys(pelRun.gates.compileByFile),
    ...Object.keys(pelRun.gates.orientByFile),
    ...Object.keys(pelRun.gates.mechanicalByFile),
  ])
  for (const fileName of allFiles) {
    state.cadSpatialByFile[fileName] = cadStateFromPelGates(fileName, pelRun.gates)
  }
  state.touchedCadFiles = [...allFiles].filter(f => f.endsWith('.xyzt') && !f.endsWith('.xyzt.eda'))

  state.sawPreflight = Object.keys(pelRun.gates.compileByFile).length > 0
    || pelRun.phase !== 'intake'
  state.sawPlan = ['decompose', 'author', 'orient', 'verify', 'integrate', 'ship'].includes(pelRun.phase)
  state.sawValidate = Object.values(pelRun.gates.compileByFile).some(Boolean)
  state.sawOrient = Object.values(pelRun.gates.orientByFile).some(Boolean)
  state.sawGate = Object.values(pelRun.gates.mechanicalByFile).some(Boolean)
    || pelRun.gates.programVerifyOk === true
  state.pelProgramVerifyOk = pelRun.gates.programVerifyOk === true

  const boardRaw = ctx.getFileContent(pelBoardRelativePath())
  if (boardRaw) {
    const board = parsePelBoard(boardRaw)
    const cadCount = board.nodes.filter(n => n.kind === 'cad_file').length
    state = recordPelPlanScope(state, cadCount)
    if (pelRun.phase === 'author' || pelRun.phase === 'orient') {
      state.touchedArtifacts = true
    }
  }

  if (pelRun.status === 'done' && pelRun.phase === 'ship') {
    state.phase = 'complete'
  }

  return state
}
