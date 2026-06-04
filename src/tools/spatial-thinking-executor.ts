import type { RunResult, SpatialCheckV0 } from 'xyzt-cad'
import {
  buildSpatialFrameGraph,
  buildSpatialThinkingReport,
  mergeOelBlackboardFile,
  oelBlackboardRelativePath,
  parseOelBlackboard,
  serializeOelBlackboard,
} from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { engineRunScriptPayload } from './engine-executor.js'

export function parseChecksFromArgs(raw: unknown): SpatialCheckV0[] | undefined {
  if (!Array.isArray(raw)) return undefined
  const checks: SpatialCheckV0[] = []
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue
    const c = item as Record<string, unknown>
    const type = c.type as string
    const partA = c.partA as string
    const partB = c.partB as string
    if (!partA || !partB) continue
    if (type === 'gap') {
      checks.push({
        type: 'gap',
        partA,
        partB,
        min: typeof c.min === 'number' ? c.min : undefined,
        max: typeof c.max === 'number' ? c.max : undefined,
      })
    } else if (type === 'contact') {
      checks.push({
        type: 'contact',
        partA,
        partB,
        tolerance: typeof c.tolerance === 'number' ? c.tolerance : undefined,
      })
    } else if (type === 'within') {
      checks.push({ type: 'within', partA, partB })
    } else if (type === 'overlap') {
      checks.push({ type: 'overlap', partA, partB })
    }
  }
  return checks.length ? checks : undefined
}

function engineError(res: Record<string, unknown>): string | undefined {
  if (res.type === 'error') return (res.error as string) ?? 'Engine request failed'
  return undefined
}

export async function executeSpatialThinking(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const scriptPayload = await engineRunScriptPayload(args, ctx)
  if (!scriptPayload.ok) return scriptPayload.result

  const focus = typeof args.focus === 'string' ? args.focus : undefined
  const checks = parseChecksFromArgs(args.checks)
  const includePairwise = args.includePairwise !== false

  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    const err = engineError(res)
    if (err) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: err, code: 'SPATIAL_RUN_FAILED', retryable: true }, null, 2),
      }
    }
    const run = res.result as RunResult | undefined
    if (!run?.success) {
      return {
        success: false,
        result: JSON.stringify(
          {
            ok: false,
            error: run?.error ?? 'Script run failed',
            code: 'SPATIAL_RUN_FAILED',
            retryable: true,
            logs: run?.logs,
          },
          null,
          2,
        ),
      }
    }
    if (!run.meshes.length) {
      return {
        success: true,
        result: JSON.stringify(
          {
            ok: true,
            focus,
            units: 'mm',
            bodies: [],
            notes: ['No meshes in run result (EDA/drawing-only script?).'],
          },
          null,
          2,
        ),
      }
    }
    const report = buildSpatialThinkingReport(run.meshes, {
      focus,
      checks,
      includePairwise,
      designContract: run.designContract ?? null,
    })
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : 'model.xyzt'
    const frameGraph = buildSpatialFrameGraph(fileName, report)
    const existingRaw = ctx.getFileContent(oelBlackboardRelativePath())
    const board = parseOelBlackboard(existingRaw ?? '{}')
    const merged = mergeOelBlackboardFile(board, fileName, {
      frameGraph,
      meshCount: frameGraph.bodyCount,
    })
    return {
      success: true,
      result: JSON.stringify({ ...report, oel: { frameGraphId: fileName, bodyCount: frameGraph.bodyCount } }, null, 2),
      files: [{ name: oelBlackboardRelativePath(), content: serializeOelBlackboard(merged) }],
    }
  } catch (err) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        error: err instanceof Error ? err.message : String(err),
      }),
    }
  }
}
