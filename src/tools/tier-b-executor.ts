import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { composeVerifyReport, critiqueScriptResult, buildRepairPayloadFromVerifyReport, buildRepairPayloadFromCriticIssues } from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { engineRunScriptPayload } from './engine-executor.js'
import { executeVerifyEda } from './engine-executor.js'

const __dir = dirname(fileURLToPath(import.meta.url))

interface MechPart {
  id: string
  category: string
  standard: string
  name: string
  sizes: Record<string, Record<string, number>>
  dimensions: string[]
  units: string
}

let mechPartsCache: MechPart[] | null = null

function loadMechParts(): MechPart[] {
  if (mechPartsCache) return mechPartsCache
  const candidates = [
    join(__dir, '../../data/mechanical-parts.json'),
    join(__dir, '../../vendor/xyzt-core/data/mechanical-parts.json'),
    join(__dir, '../../../xyzt/infra/data/mechanical-parts.json'),
  ]
  for (const p of candidates) {
    try {
      const db = JSON.parse(readFileSync(p, 'utf8')) as { parts: MechPart[] }
      mechPartsCache = db.parts ?? []
      return mechPartsCache
    } catch {
      /* try next */
    }
  }
  mechPartsCache = []
  return mechPartsCache
}

export async function executeCritiqueScript(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const scriptPayload = await engineRunScriptPayload(args, ctx)
  if (!scriptPayload.ok) return scriptPayload.result

  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    if (res.type === 'error') {
      return { success: false, result: JSON.stringify({ ok: false, error: res.error }) }
    }
    const run = res.result as import('xyzt-cad').RunResult | undefined
    if (!run?.success) {
      const errMsg = run && 'error' in run ? run.error : 'Script run failed'
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: errMsg }),
      }
    }
    const profile = (args.profile as string) === 'flight' ? 'flight' : 'strict'
    const report = composeVerifyReport(
      { scriptResult: run as import('xyzt-cad').ScriptResult },
      profile as 'strict',
    )
    const critique = report.checks.find(c => c.id === 'critique_script')
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() || 'model.xyzt' : 'model.xyzt'
    const criticReport = critiqueScriptResult(run as import('xyzt-cad').ScriptResult, run.designContract, profile as 'strict')
    const repair =
      buildRepairPayloadFromVerifyReport({ fileName, report }) ??
      (criticReport.valid
        ? null
        : buildRepairPayloadFromCriticIssues({
            fileName,
            issues: criticReport.issues,
          }))
    return {
      success: critique?.ok !== false,
      result: JSON.stringify(
        { ok: critique?.ok !== false, profile, check: critique, report, repair, retryable: critique?.ok === false },
        null,
        2,
      ),
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

export async function executeAnalyzeEda(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const out = await executeVerifyEda(args, ctx)
  let parsed: Record<string, unknown> = { raw: out.result }
  try {
    parsed = JSON.parse(out.result) as Record<string, unknown>
  } catch {
    /* keep raw */
  }
  return {
    success: out.success,
    result: JSON.stringify(
      {
        ok: out.success,
        summary: parsed,
        tool: 'analyze_eda',
      },
      null,
      2,
    ),
  }
}

export function executeSearchStepParts(args: Record<string, unknown>): LocalToolResult {
  const query = String(args.query ?? '').toLowerCase()
  const category = typeof args.category === 'string' ? args.category : undefined
  const parts = loadMechParts()
  const results: Array<{ id: string; name: string; standard: string; category: string }> = []
  for (const part of parts) {
    if (category && category !== 'all' && part.category !== category) continue
    const hay = `${part.name} ${part.standard} ${part.id}`.toLowerCase()
    if (!query || hay.includes(query)) {
      results.push({ id: part.id, name: part.name, standard: part.standard, category: part.category })
      if (results.length >= 20) break
    }
  }
  return {
    success: true,
    result: JSON.stringify({ ok: true, count: results.length, parts: results }, null, 2),
  }
}

export function executeGetStepPartCode(args: Record<string, unknown>): LocalToolResult {
  const partId = String(args.partId ?? args.id ?? '')
  if (!partId) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'partId is required' }) }
  }
  const part = loadMechParts().find(p => p.id === partId)
  if (!part) {
    return { success: false, result: JSON.stringify({ ok: false, error: `Part "${partId}" not found` }) }
  }
  const stepRelativePath = `xyzt-components/step-parts/step/${partId}.step`
  return {
    success: true,
    result: JSON.stringify(
      {
        ok: true,
        partId,
        name: part.name,
        standard: part.standard,
        stepRelativePath,
        usage:
          'Load STEP bytes with readProjectFile when the asset is in the project. Do not use fetch in .xyzt scripts.',
        example:
          'const data = readProjectFile("STEP_PATH"); return importInterchangeAsComponent(data, "step")',
      },
      null,
      2,
    ),
  }
}

export async function executeSearchComponents(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  if (!ctx.searchComponents) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        code: 'COMPONENT_API_UNAVAILABLE',
        error: 'Component search is not configured in this host.',
      }),
    }
  }
  const query = String(args.query ?? args.search_term ?? '').trim()
  if (!query) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'query is required' }) }
  }
  try {
    const sources =
      typeof args.sources === 'string'
        ? args.sources.split(',').map(s => s.trim())
        : undefined
    const res = await ctx.searchComponents(query, { sources, limit: 20 })
    if (res.error) {
      return {
        success: false,
        result: JSON.stringify({
          ok: false,
          code: res.error,
          status: res.status,
          total: res.total,
          results: res.results,
        }),
      }
    }
    return {
      success: true,
      result: JSON.stringify({ ok: true, total: res.total, results: res.results }, null, 2),
    }
  } catch (e) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        error: e instanceof Error ? e.message : String(e),
      }),
    }
  }
}

export async function executeLookupPart(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const id = String(args.componentId ?? args.partId ?? '').trim()
  if (!id) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'componentId is required' }) }
  }
  if (!ctx.fetchComponentDetails) {
    return {
      success: false,
      result: JSON.stringify({ ok: false, code: 'COMPONENT_API_UNAVAILABLE' }),
    }
  }
  try {
    const detail = await ctx.fetchComponentDetails(id)
    if (!detail) {
      return { success: false, result: JSON.stringify({ ok: false, error: `Component "${id}" not found` }) }
    }
    return { success: true, result: JSON.stringify({ ok: true, component: detail }, null, 2) }
  } catch (e) {
    return {
      success: false,
      result: JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }),
    }
  }
}

export async function executePlaceComponent(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const componentId = String(args.componentId ?? '').trim()
  const designator = String(args.designator ?? args.reference ?? 'U1').trim()
  const edaFile = String(args.fileName ?? args.edaFile ?? '').trim()
  if (!componentId) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'componentId is required' }) }
  }

  if (ctx.placeComponent) {
    try {
      const placed = await ctx.placeComponent({
        ...args,
        componentId,
        designator,
        fileName: edaFile || undefined,
      })
      if (!placed.success) {
        return {
          success: false,
          result: JSON.stringify({
            ok: false,
            componentId,
            designator,
            error: placed.error ?? 'Placement failed',
          }),
        }
      }
      const files: LocalToolResult['files'] = []
      if (placed.script && edaFile) {
        files.push({ name: edaFile, content: placed.script })
      }
      return {
        success: true,
        result: JSON.stringify(
          {
            ok: true,
            placed: true,
            componentId,
            designator: placed.designator,
            partRef: placed.partRef,
            addLine: placed.addLine,
            position: placed.position,
            rotation: placed.rotation,
            edaFile: edaFile || undefined,
            next_tool: placed.script && edaFile ? 'patch_file' : 'verify_eda',
          },
          null,
          2,
        ),
        files: files.length ? files : undefined,
        pending: !!(placed.script && edaFile && ctx.sandboxEdits),
      }
    } catch (e) {
      return {
        success: false,
        result: JSON.stringify({
          ok: false,
          error: e instanceof Error ? e.message : String(e),
        }),
      }
    }
  }

  return {
    success: true,
    result: JSON.stringify(
      {
        ok: true,
        placed: false,
        componentId,
        designator,
        suggested_eda_patch: {
          designator,
          componentId,
          edaFile: edaFile || undefined,
        },
        next_tool: 'patch_file',
        next_step:
          'Call lookup_part for symbol/footprint, then patch_file on the .xyzt.eda file with the component record.',
      },
      null,
      2,
    ),
  }
}
