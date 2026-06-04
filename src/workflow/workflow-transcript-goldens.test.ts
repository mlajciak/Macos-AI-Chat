import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { GOLDENS_DIR } from '../lib/paths.js'
import {
  createWorkflowRunState,
  gateToolCall,
  recordCadFullMutator,
  recordCadSpatialOk,
  recordCadValidateOk,
  recordEdaVerifyOk,
  recordToolUse,
} from '../workflow/state-machine.js'

const goldensDir = GOLDENS_DIR

type GateStep = {
  tool: string
  args?: Record<string, unknown>
  expectAllowed?: boolean
  expectCode?: string
  expectOk?: boolean
}

function withPreflight() {
  let state = createWorkflowRunState()
  state = recordToolUse(state, 'get_capabilities', {})
  return state
}

function applyStepEffect(state: ReturnType<typeof withPreflight>, step: GateStep) {
  if (step.tool === 'validate_script' && step.expectOk) {
    return recordCadValidateOk(state, String(step.args?.fileName ?? ''))
  }
  if ((step.tool === 'orient_cad' || step.tool === 'spatial_thinking') && step.expectOk) {
    return recordCadSpatialOk(state, String(step.args?.fileName ?? ''), 1)
  }
  if (step.tool === 'verify_eda' && step.expectOk) {
    return recordEdaVerifyOk(state, String(step.args?.fileName ?? ''))
  }
  if (step.tool === 'patch_file') {
    return recordCadFullMutator(state, String(step.args?.fileName ?? ''))
  }
  return recordToolUse(state, step.tool, step.args ?? {})
}

function replayGateSteps(steps: GateStep[]) {
  let state = withPreflight()
  for (const step of steps) {
    if (step.expectAllowed !== undefined) {
      const gate = gateToolCall(state, step.tool, step.args)
      expect(gate.allowed).toBe(step.expectAllowed)
      if (step.expectCode) {
        const err = gate.error ?? ''
        expect(err.includes(step.expectCode) || err.includes('"code"')).toBe(true)
        if (gate.error) expect(gate.error).toContain(step.expectCode)
      }
      if (gate.allowed) state = applyStepEffect(state, step)
      continue
    }
    state = applyStepEffect(state, step)
  }
  return state
}

describe('workflow transcript goldens from packages/xyzt-agent-tools', () => {
  it.skip('oel-two-file-bracket-transcript.json gate chain — legacy OEL gates', () => {
    const raw = JSON.parse(
      readFileSync(join(goldensDir, 'oel-two-file-bracket-transcript.json'), 'utf8'),
    ) as { steps: GateStep[] }
    replayGateSteps(raw.steps)
  })

  it('eda-lcsc-place-verify-transcript.json gate chain', () => {
    const raw = JSON.parse(
      readFileSync(join(goldensDir, 'eda-lcsc-place-verify-transcript.json'), 'utf8'),
    ) as { steps: GateStep[] }
    const state = replayGateSteps(raw.steps)
    expect(gateToolCall(state, 'update_overview').allowed).toBe(true)
  })
})
