import { applyBoardEdit, verifyEda, isEdaVerifyProfile } from 'xyzt-cad'
import type { CircuitJson } from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { executeVerifyEda } from './engine-executor.js'

export async function executeRunDrc(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const withProfile = { ...args, profile: 'layout' }
  const out = await executeVerifyEda(withProfile, ctx)
  try {
    const parsed = JSON.parse(out.result) as { diagnostics?: Array<{ stage: string }> }
    const drcOnly = (parsed.diagnostics ?? []).filter(d => d.stage === 'drc')
    return {
      success: out.success,
      result: JSON.stringify({ ok: out.success, drc: drcOnly }, null, 2),
    }
  } catch {
    return out
  }
}

export async function executeApplyEdaEdit(
  args: Record<string, unknown>,
  _ctx: ToolContext,
): Promise<LocalToolResult> {
  const cj = args.circuit_json as CircuitJson | undefined
  const edit = args.edit as Parameters<typeof applyBoardEdit>[1] | undefined
  if (!cj?.length || !edit) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'circuit_json and edit required' }) }
  }
  const result = applyBoardEdit(cj, edit)
  const ok = !result.diagnostics.some(d => d.severity === 'error')
  return {
    success: ok,
    result: JSON.stringify({ ok, circuit: result.circuit, diagnostics: result.diagnostics }, null, 2),
  }
}

export async function executeEditBoard(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  return executeApplyEdaEdit(args, ctx)
}

export function verifyEdaWithProfile(
  circuit: CircuitJson,
  profile?: string,
): ReturnType<typeof verifyEda> {
  const p = profile && isEdaVerifyProfile(profile) ? profile : 'fab'
  return verifyEda(circuit, { profile: p })
}
