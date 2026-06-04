import type { RunResult } from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { engineRunScriptPayload } from './engine-executor.js'

function engineError(res: Record<string, unknown>): string | undefined {
  if (res.type === 'error') return (res.error as string) ?? 'Engine request failed'
  return undefined
}

export async function executeGetMassProperties(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const scriptPayload = await engineRunScriptPayload(args, ctx)
  if (!scriptPayload.ok) return scriptPayload.result

  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    const err = engineError(res)
    if (err) return { success: false, result: JSON.stringify({ ok: false, error: err }) }
    const run = res.result as RunResult | undefined
    if (!run?.success) {
      const errMsg = run && 'error' in run ? (run as { error: string }).error : 'Script run failed'
      return { success: false, result: JSON.stringify({ ok: false, error: errMsg }) }
    }
    const mp = run.massProperties
    if (!mp) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: 'No mass properties in run result (non-assembly script?).' }),
      }
    }
    return {
      success: true,
      result: JSON.stringify(
        {
          ok: true,
          total: mp.total,
          bodies: mp.bodies.map(b => ({ name: b.name, mass: b.mass })),
        },
        null,
        2,
      ),
    }
  } catch (e) {
    return {
      success: false,
      result: JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }),
    }
  }
}

export async function executeSolveJoints(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const scriptPayload = await engineRunScriptPayload(args, ctx)
  if (!scriptPayload.ok) return scriptPayload.result

  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    const err = engineError(res)
    if (err) return { success: false, result: JSON.stringify({ ok: false, error: err }) }
    const run = res.result as RunResult | undefined
    if (!run?.success) {
      const errMsg = run && 'error' in run ? (run as { error: string }).error : 'Script run failed'
      return { success: false, result: JSON.stringify({ ok: false, error: errMsg }) }
    }
    const view = run.assemblyView
    if (!view) {
      return {
        success: false,
        result: JSON.stringify({
          ok: false,
          error: 'No assemblyView in run result (script must return an assembly).',
        }),
      }
    }
    return {
      success: true,
      result: JSON.stringify(
        {
          ok: true,
          joints: view.joints,
          motionSequences: view.motionSequences,
          bodyNames: view.bodyNames,
        },
        null,
        2,
      ),
    }
  } catch (e) {
    return {
      success: false,
      result: JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }),
    }
  }
}
