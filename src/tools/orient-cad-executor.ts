import type { CadCriticIssue, CadCriticSeverity, RunResult } from 'xyzt-cad'
import {
  buildOrientCadReport,
  buildSpatialThinkingReport,
  mergeOelBlackboardFile,
  oelBlackboardRelativePath,
  parseOelBlackboard,
  serializeOelBlackboard,
} from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { engineRunScriptPayload } from './engine-executor.js'
import { executeCritiqueScript } from './tier-b-executor.js'
import { parseChecksFromArgs } from './spatial-thinking-executor.js'

function parseCritiqueIssues(
  raw: Array<{ code?: string; message?: string; severity?: string }>,
): CadCriticIssue[] {
  return raw.map((issue, i) => ({
    code: issue.code ?? `CRITIQUE_${i}`,
    severity: (issue.severity === 'warning' || issue.severity === 'info'
      ? issue.severity
      : 'error') as CadCriticSeverity,
    message: issue.message ?? 'Critique issue',
  }))
}

function engineError(res: Record<string, unknown>): string | undefined {
  if (res.type === 'error') return (res.error as string) ?? 'Engine request failed'
  return undefined
}

export async function executeOrientCad(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const scriptPayload = await engineRunScriptPayload(args, ctx)
  if (!scriptPayload.ok) return scriptPayload.result

  const focus = typeof args.focus === 'string' ? args.focus : undefined
  const checks = parseChecksFromArgs(args.checks)
  const includePairwise = args.includePairwise !== false
  const runCritique = args.skipCritique !== true
  const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''

  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    const err = engineError(res)
    if (err) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: err, code: 'OEL_RUN_FAILED', retryable: true }, null, 2),
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
            code: 'OEL_RUN_FAILED',
            retryable: true,
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
            fileName,
            spatial: { ok: true, units: 'mm', bodies: [], notes: ['No meshes — EDA/drawing only?'] },
            gates: { compileOk: true, spatialOk: true, mechanicalOk: true, multiBody: false, phase: 'ship' },
            agentHints: ['No mechanical bodies; orient_cad is optional for this script.'],
          },
          null,
          2,
        ),
      }
    }

    const spatial = buildSpatialThinkingReport(run.meshes, {
      focus,
      checks,
      includePairwise,
      designContract: run.designContract ?? null,
    })

    let critiqueInput: Parameters<typeof buildOrientCadReport>[0]['critique']
    let critiqueOk = true
    if (runCritique && run.meshes.length > 1) {
      const critiqueRes = await executeCritiqueScript(
        { ...args, profile: args.profile ?? 'strict' },
        ctx,
      )
      try {
        const parsed = JSON.parse(critiqueRes.result) as {
          ok?: boolean
          profile?: string
          check?: { detail?: string; issues?: Array<{ code?: string; message?: string }> }
          report?: { checks?: Array<{ issues?: Array<{ code?: string; message?: string }> }> }
        }
        critiqueOk = critiqueRes.success !== false && parsed.ok !== false
        const issues =
          parsed.check?.issues ??
          parsed.report?.checks?.flatMap(c => c.issues ?? []) ??
          []
        critiqueInput = {
          ok: critiqueOk,
          profile: parsed.profile ?? 'strict',
          issueCount: issues.length,
          summary: parsed.check?.detail,
          issues: parseCritiqueIssues(issues),
        }
      } catch {
        critiqueOk = critiqueRes.success !== false
        critiqueInput = {
          ok: critiqueOk,
          profile: 'strict',
          issueCount: critiqueOk ? 0 : 1,
        }
      }
    }

    const report = buildOrientCadReport({
      fileName: fileName || 'model.xyzt',
      spatial,
      critique: critiqueInput,
      compileOk: true,
      placementSpec: run.placementSpec ?? null,
      mateSolveReport: run.mateSolveReport ?? null,
    })

    const existingRaw = ctx.getFileContent(oelBlackboardRelativePath())
    const board = parseOelBlackboard(existingRaw ?? '{}')
    const merged = mergeOelBlackboardFile(board, report.fileName, {
      frameGraph: report.frameGraph,
      ledger: report.ledger,
      meshCount: report.frameGraph.bodyCount,
    })

    return {
      success: report.ok,
      result: JSON.stringify(report, null, 2),
      files: [{ name: oelBlackboardRelativePath(), content: serializeOelBlackboard(merged) }],
    }
  } catch (err) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        error: err instanceof Error ? err.message : String(err),
        code: 'OEL_ORIENT_FAILED',
      }),
    }
  }
}
