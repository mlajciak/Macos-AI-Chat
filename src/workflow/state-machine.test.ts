import { describe, expect, it } from 'vitest'
import {
  createWorkflowRunState,
  gateToolCall,
  recordCadCritiqueOk,
  recordCadPlacementPatch,
  recordCadSpatialOk,
  recordCadValidateOk,
  recordEdaMutator,
  recordEdaVerifyOk,
  recordPelPlanScope,
  recordPelProgramVerifyOk,
  recordProjectManifestCheck,
  recordTouchCadFile,
  recordTouchEdaFile,
  recordToolUse,
  patchUsesRawAssemblyAt,
  gateRawAssemblyAtPatch,
} from './state-machine.js'

function withPreflight(state: ReturnType<typeof createWorkflowRunState>) {
  return recordToolUse(state, 'get_capabilities')
}

describe('workflow state machine', () => {
  it('allows desktop folder-agent tools without preflight', () => {
    expect(gateToolCall(createWorkflowRunState(), 'patch_file', { fileName: 'part.xyzt' }).allowed).toBe(true)
    expect(gateToolCall(createWorkflowRunState(), 'create_cad', { fileName: 'part.xyzt' }).allowed).toBe(true)
    expect(gateToolCall(createWorkflowRunState(), 'read_file', { fileName: 'part.xyzt' }).allowed).toBe(true)
  })

  it('blocks authoring before preflight for legacy tools', () => {
    const gate = gateToolCall(createWorkflowRunState(), 'edit_file', { fileName: 'part.xyzt' })
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_PREFLIGHT_REQUIRED')
  })

  it('allows preflight then legacy create via edit_file path', () => {
    const state = withPreflight(createWorkflowRunState())
    const gate = gateToolCall(state, 'edit_file', { fileName: 'part.xyzt' })
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_VALIDATE_REQUIRED')
  })

  it('blocks edit_file on CAD before orient_cad', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordCadValidateOk(state, 'part.xyzt')
    const gate = gateToolCall(state, 'edit_file', { fileName: 'part.xyzt' })
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_SPATIAL_REQUIRED')
  })

  it('patchUsesRawAssemblyAt detects coordinate literals', () => {
    expect(patchUsesRawAssemblyAt("add('b', box(1,1,1), { at: [1,2,3] })")).toBe(true)
  })

  it('gateRawAssemblyAtPatch blocks raw at without fully constrained mates', () => {
    let state = createWorkflowRunState()
    state = recordCadValidateOk(state, 'assy.xyzt')
    state = recordCadSpatialOk(state, 'assy.xyzt', 2, { matesFullyConstrained: false })
    const gate = gateRawAssemblyAtPatch(
      state,
      'assy.xyzt',
      "assembly('A').add('b', box(1,1,1), { at: [1,2,3] })",
    )
    expect(gate?.allowed).toBe(false)
    expect(gate?.error).toContain('WORKFLOW_CONSTRAINT_REQUIRED')
  })

  it('blocks patch_file with raw at: when mates not fully constrained', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordCadValidateOk(state, 'assy.xyzt')
    state = recordCadSpatialOk(state, 'assy.xyzt', 2, { matesFullyConstrained: false })
    const gate = gateToolCall(state, 'patch_file', {
      fileName: 'assy.xyzt',
      content: "assembly('A').add('b', box(1,1,1), { at: [1,2,3] })",
    })
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_CONSTRAINT_REQUIRED')
  })

  it('blocks update_overview without per-file validate after author', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordToolUse(state, 'patch_file', { fileName: 'part.xyzt' })
    state = recordTouchCadFile(state, 'part.xyzt')
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_VALIDATE_REQUIRED')
  })

  it('allows update_overview after validate_script on touched CAD', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordToolUse(state, 'patch_file', { fileName: 'part.xyzt' })
    state = recordCadValidateOk(state, 'part.xyzt')
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(true)
  })

  it('blocks update_overview when EDA touched without verify_eda', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordTouchEdaFile(state, 'board.xyzt.eda')
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_EDA_VERIFY_REQUIRED')
  })

  it('allows update_overview after verify_eda on touched EDA', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordEdaVerifyOk(state, 'board.xyzt.eda')
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(true)
  })

  it('validate_project alone does not satisfy CAD ship', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordToolUse(state, 'patch_file', { fileName: 'part.xyzt' })
    state = recordTouchCadFile(state, 'part.xyzt')
    state = recordToolUse(state, 'validate_project')
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_VALIDATE_REQUIRED')
  })

  it('blocks patch_file after validate until orient_cad for legacy EDA edits', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordEdaVerifyOk(state, 'board.xyzt.eda')
    state = recordEdaMutator(state, 'board.xyzt.eda')
    const gate = gateToolCall(state, 'apply_eda_edit', { fileName: 'board.xyzt.eda' })
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_EDA_VERIFY_REQUIRED')
  })

  it('blocks update_overview on multi-body without critique', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordToolUse(state, 'patch_file', { fileName: 'assy.xyzt' })
    state = recordCadValidateOk(state, 'assy.xyzt')
    state = recordCadSpatialOk(state, 'assy.xyzt', 3)
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_MECHANICAL_VERIFY_REQUIRED')
  })

  it('allows update_overview after critique on multi-body', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordCadValidateOk(state, 'assy.xyzt')
    state = recordCadSpatialOk(state, 'assy.xyzt', 3)
    state = recordCadCritiqueOk(state, 'assy.xyzt', 3)
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(true)
  })

  it('blocks update_overview when PEL program CAD nodes incomplete', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordPelPlanScope(state, 3)
    state = recordPelProgramVerifyOk(state)
    state = recordCadValidateOk(state, 'a.xyzt')
    state = recordCadSpatialOk(state, 'a.xyzt', 2)
    state = recordCadCritiqueOk(state, 'a.xyzt', 2)
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_PEL_PROGRAM_VERIFY_REQUIRED')
  })

  it('blocks update_overview without pel_verify_program on multi-file PEL', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordPelPlanScope(state, 2)
    state = recordPelProgramVerifyOk(state)
    state.pelProgramVerifyOk = false
    state = recordCadValidateOk(state, 'a.xyzt')
    const gate = gateToolCall(state, 'update_overview')
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_PEL_FLIGHT_VERIFY_REQUIRED')
  })

  it('blocks edit_feature before preflight', () => {
    const gate = gateToolCall(createWorkflowRunState(), 'edit_feature', {
      fileName: 'part.xyzt',
      code: 'return box(1)',
    })
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_PREFLIGHT_REQUIRED')
  })

  it('blocks edit_feature on CAD before orient_cad', () => {
    let state = withPreflight(createWorkflowRunState())
    state = recordCadValidateOk(state, 'part.xyzt')
    const gate = gateToolCall(state, 'edit_feature', {
      fileName: 'part.xyzt',
      code: 'return box(1)',
    })
    expect(gate.allowed).toBe(false)
    expect(gate.error).toContain('WORKFLOW_SPATIAL_REQUIRED')
  })
})
