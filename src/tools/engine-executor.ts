import {
  buildRepairPayloadFromValidateFailure,
  buildRepairPayloadFromEdaVerify,
} from 'xyzt-cad'
import type { DesktopJobResult, EdaVerifyReport, RunResult, SimulationJsonV0 } from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'

const MAX_PROJECT_BYTES = 2 * 1024 * 1024

function isXyztFile(name: string): boolean {
  if (!name) return false
  return name.endsWith('.xyzt') && !name.endsWith('.xyzt.eda')
}

export function listProjectScriptPaths(paths: string[]): string[] {
  return paths.filter((p): p is string => typeof p === 'string' && p.length > 0).filter(
    p =>
      p.endsWith('.xyzt') ||
      p.endsWith('.xyzt.eda') ||
      p.endsWith('.xyzt.draft') ||
      p.endsWith('.xyzt.simulation'),
  )
}

export async function resolveScriptCode(
  args: Record<string, unknown>,
  getFileContent: (name: string) => string | undefined,
  ensureFileContent?: (name: string) => Promise<string | undefined>,
): Promise<string | null> {
  const inline = args.code as string | undefined
  if (typeof inline === 'string' && inline.trim()) return inline
  const fileName = args.fileName as string | undefined
  if (fileName) {
    const cached = getFileContent(fileName)
    if (cached !== undefined) return cached
    if (ensureFileContent) {
      const loaded = await ensureFileContent(fileName)
      if (loaded !== undefined) return loaded
    }
  }
  return null
}

function engineError(res: Record<string, unknown>): string | undefined {
  if (res.type === 'error') return (res.error as string) ?? 'Engine request failed'
  return undefined
}

export async function buildProjectFiles(
  entryPoint: string | undefined,
  listFilePaths: () => string[],
  getFileContent: (name: string) => string | undefined,
  ensureFileContent?: (name: string) => Promise<string | undefined>,
): Promise<{ projectFiles: Record<string, string>; entryPoint: string } | null> {
  if (!entryPoint) return null
  const paths = listProjectScriptPaths(listFilePaths())
  if (!paths.includes(entryPoint)) return null

  const projectFiles: Record<string, string> = {}
  let total = 0
  for (const p of paths) {
    let content = getFileContent(p)
    if (content === undefined && ensureFileContent) {
      content = await ensureFileContent(p)
    }
    if (content === undefined) continue
    const bytes = new TextEncoder().encode(content).length
    if (total + bytes > MAX_PROJECT_BYTES) break
    projectFiles[p] = content
    total += bytes
  }
  if (!projectFiles[entryPoint]) {
    let main = getFileContent(entryPoint)
    if (main === undefined && ensureFileContent) {
      main = await ensureFileContent(entryPoint)
    }
    if (main === undefined) return null
    projectFiles[entryPoint] = main
  }
  return { projectFiles, entryPoint }
}

function summarizeRunResult(run: RunResult): Record<string, unknown> {
  if (!run.success) {
    return {
      ok: false,
      error: run.error,
      code: 'RUN_FAILED',
      retryable: true,
      logs: run.logs,
    }
  }
  return {
    ok: true,
    meshCount: run.meshes.length,
    hasCircuit: !!run.circuitJson?.length,
    params: run.params?.map(p => ({ name: p.name, type: p.type, value: p.value })) ?? [],
    logs: run.logs,
    durationMs: run.duration,
    meshes: run.meshes.map((m, i) => ({
      name: m.name ?? `Body${i + 1}`,
      triangles: m.indices.length / 3,
      vertices: m.vertices.length / 3,
    })),
    featureIr: run.featureIr ? { stepCount: run.featureIr.steps?.length ?? 0 } : undefined,
  }
}

function summarizeSimulationResult(simulation: SimulationJsonV0): Record<string, unknown> {
  if (simulation.kind === 'fea' && simulation.results) {
    return {
      kind: 'fea',
      maxDisplacement: simulation.results.maxDisplacement,
      maxVonMises: simulation.results.maxVonMises,
    }
  }
  if (simulation.kind === 'cfd' && simulation.results) {
    return {
      kind: 'cfd',
      time: simulation.results.time,
      fieldCount: simulation.results.fields.length,
      minTemperature: simulation.results.summary?.minTemperature,
      maxTemperature: simulation.results.summary?.maxTemperature,
    }
  }
  if (simulation.kind === 'motion') {
    return { kind: 'motion', frameCount: simulation.frames.length }
  }
  return { kind: simulation.kind }
}

export async function engineRunScriptPayload(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<
  | { ok: true; payload: Record<string, unknown>; params: Record<string, unknown> }
  | { ok: false; result: LocalToolResult }
> {
  const fileName = args.fileName as string | undefined
  const code = await resolveScriptCode(args, ctx.getFileContent, ctx.ensureFileContent)
  if (!code && !fileName) {
    return { ok: false, result: { success: false, result: 'code or fileName is required.' } }
  }
  const params = (args.params as Record<string, unknown> | undefined) ?? {}
  const project =
    fileName && isXyztFile(fileName)
      ? await buildProjectFiles(fileName, ctx.listFilePaths, ctx.getFileContent, ctx.ensureFileContent)
      : null
  if (project) {
    return {
      ok: true,
      params,
      payload: {
        type: 'run',
        projectFiles: project.projectFiles,
        entryPoint: project.entryPoint,
        params,
      },
    }
  }
  return {
    ok: true,
    params,
    payload: { type: 'run', code: code ?? '', params },
  }
}

export async function executeValidateScript(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const code = await resolveScriptCode(args, ctx.getFileContent, ctx.ensureFileContent)
  if (!code) {
    return { success: false, result: 'code or fileName is required.' }
  }
  try {
    const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
    const project =
      fileName && isXyztFile(fileName)
        ? await buildProjectFiles(fileName, ctx.listFilePaths, ctx.getFileContent, ctx.ensureFileContent)
        : null
    const res = await ctx.engineRun(
      project
        ? {
            type: 'validate',
            code,
            projectFiles: project.projectFiles,
            entryPoint: project.entryPoint,
          }
        : { type: 'validate', code },
    )
    const err = engineError(res)
    if (err) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: err ?? 'Engine validate failed' }, null, 2),
      }
    }
    const validation =
      (res.validation as { valid: boolean; error?: string; line?: number } | undefined) ??
      (res.type === 'validated'
        ? (res as { validation?: { valid: boolean; error?: string; line?: number } }).validation
        : undefined)
    const payload = {
      ok: validation?.valid ?? false,
      ...validation,
      code: validation?.valid ? undefined : 'VALIDATE_FAILED',
      retryable: !validation?.valid,
      repair: !validation?.valid
        ? buildRepairPayloadFromValidateFailure({
            fileName: typeof args.fileName === 'string' ? args.fileName.trim() || 'model.xyzt' : 'model.xyzt',
            error: validation?.error,
            line: validation?.line,
          })
        : undefined,
    }
    return {
      success: validation?.valid ?? false,
      result: JSON.stringify(payload, null, 2),
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

export async function executeRunScript(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const scriptPayload = await engineRunScriptPayload(args, ctx)
  if (!scriptPayload.ok) return scriptPayload.result

  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    const err = engineError(res)
    if (err) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: err ?? 'Engine run failed' }, null, 2),
      }
    }
    const run = res.result as RunResult | undefined
    if (!run) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: 'No result from engine' }, null, 2),
      }
    }
    const summary = summarizeRunResult(run)
    return {
      success: summary.ok === true,
      result: JSON.stringify(summary, null, 2),
      meshData: run.success ? run.meshes : undefined,
      _runResult: run,
    } as LocalToolResult & { _runResult?: RunResult }
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

export async function executeVerifyEda(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const fileName = args.fileName as string | undefined
  const code = await resolveScriptCode(args, ctx.getFileContent, ctx.ensureFileContent)
  if (!code && !fileName) {
    return { success: false, result: 'code or fileName is required.' }
  }

  const params = (args.params as Record<string, unknown> | undefined) ?? {}
  const project =
    fileName && isXyztFile(fileName)
      ? await buildProjectFiles(fileName, ctx.listFilePaths, ctx.getFileContent, ctx.ensureFileContent)
      : null

  try {
    const res = await ctx.engineRun(
      project
        ? {
            type: 'verify_eda',
            projectFiles: project.projectFiles,
            entryPoint: project.entryPoint,
            params,
          }
        : { type: 'verify_eda', code: code ?? '', params },
    )
    const err = engineError(res)
    if (err) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: err, code: 'VERIFY_EDA_FAILED', retryable: true }, null, 2),
      }
    }
    const report = res.report as EdaVerifyReport | undefined
    if (!report) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: 'No verification report from engine' }, null, 2),
      }
    }
    const fileLabel = fileName?.trim() || 'board.xyzt.eda'
    const repair = !report.ok
      ? buildRepairPayloadFromEdaVerify({ fileName: fileLabel, diagnostics: report.diagnostics })
      : undefined
    const payload = { ok: report.ok, stages: report.stages, diagnostics: report.diagnostics, repair, retryable: !report.ok }
    return {
      success: report.ok,
      result: JSON.stringify(payload, null, 2),
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

export async function executeProbeModel(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const snippet = args.snippet as string | undefined
  if (!snippet?.trim()) {
    return { success: false, result: 'snippet is required.' }
  }

  const fileName = args.fileName as string | undefined
  const inlineCode = args.code as string | undefined
  let baseCode: string | undefined =
    typeof inlineCode === 'string' && inlineCode.trim() ? inlineCode : undefined
  if (!baseCode && fileName) {
    baseCode = (await resolveScriptCode(args, ctx.getFileContent, ctx.ensureFileContent)) ?? undefined
  }

  const params = (args.params as Record<string, unknown> | undefined) ?? {}
  const project =
    fileName && isXyztFile(fileName) && !baseCode
      ? await buildProjectFiles(fileName, ctx.listFilePaths, ctx.getFileContent, ctx.ensureFileContent)
      : null

  try {
    const res = await ctx.engineRun(
      project
        ? {
            type: 'probe',
            snippet,
            projectFiles: project.projectFiles,
            entryPoint: project.entryPoint,
            params,
          }
        : { type: 'probe', snippet, code: baseCode, params },
    )
    const err = engineError(res)
    if (err) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: err, code: 'PROBE_FAILED', retryable: true }, null, 2),
      }
    }
    const payload = {
      ok: true,
      result: res.result,
      logs: res.logs,
      meshSummary: res.meshSummary,
    }
    return {
      success: true,
      result: JSON.stringify(payload, null, 2),
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

export async function executeRunSimulation(
  args: Record<string, unknown>,
  ctx: ToolContext,
  createJobRequest?: (sim: SimulationJsonV0, meshes: import('xyzt-cad').MeshData[]) => unknown,
): Promise<LocalToolResult> {
  const fileName = args.fileName as string
  if (!fileName) {
    return { success: false, result: 'fileName is required.' }
  }
  if (!fileName.toLowerCase().endsWith('.xyzt.simulation')) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        error: 'fileName must be a .xyzt.simulation file',
        code: 'INVALID_SIMULATION_FILE',
      }),
    }
  }

  const scriptPayload = await engineRunScriptPayload({ fileName }, ctx)
  if (!scriptPayload.ok) return scriptPayload.result

  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    const err = engineError(res)
    if (err) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: err, code: 'SIMULATION_SCRIPT_FAILED', retryable: true }, null, 2),
      }
    }
    const run = res.result as RunResult | undefined
    if (!run || !run.success || !run.simulationJson) {
      return {
        success: false,
        result: JSON.stringify({
          ok: false,
          error: 'No simulationJson in script result',
          code: 'NO_SIMULATION_JSON',
        }),
      }
    }

    if (!ctx.startSimulationJob) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: 'Simulation job runner unavailable on this host' }),
      }
    }

    if (!createJobRequest) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: 'createSimulationJobRequest not configured' }),
      }
    }

    const { validateSimulationJson, simulationToResultBundle } = await import('xyzt-cad')
    const pre = validateSimulationJson(run.simulationJson, { engineering: true })
    if (!pre.valid) {
      return {
        success: false,
        result: JSON.stringify({
          ok: false,
          code: 'VALIDATION_FAILED',
          issues: pre.issues,
        }, null, 2),
      }
    }

    const meshes = run.success ? run.meshes : []
    const request = createJobRequest(run.simulationJson, meshes)
    const jobResult = (await ctx.startSimulationJob(request)) as DesktopJobResult
    const ok = jobResult.status === 'success'
    const summary = jobResult.simulation
      ? summarizeSimulationResult(jobResult.simulation)
      : undefined
    const resultBundle =
      ok && jobResult.simulation
        ? simulationToResultBundle(jobResult.simulation, { path: fileName })
        : undefined
    const payload = {
      ok,
      jobId: jobResult.jobId,
      status: jobResult.status,
      summary,
      resultBundle,
      error: jobResult.error,
    }
    return {
      success: ok,
      result: JSON.stringify(payload, null, 2),
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

/** Run script and return raw RunResult for export tools. */
export async function runScriptForExport(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<{ ok: true; run: Extract<RunResult, { success: true }> } | { ok: false; result: LocalToolResult }> {
  const scriptPayload = await engineRunScriptPayload(args, ctx)
  if (!scriptPayload.ok) return { ok: false, result: scriptPayload.result }
  try {
    const res = await ctx.engineRun(scriptPayload.payload)
    const err = engineError(res)
    if (err) {
      return {
        ok: false,
        result: {
          success: false,
          result: JSON.stringify({ ok: false, error: err }, null, 2),
        },
      }
    }
    const run = res.result as RunResult | undefined
    if (!run?.success) {
      return {
        ok: false,
        result: {
          success: false,
          result: JSON.stringify({ ok: false, error: run && 'error' in run ? run.error : 'Run failed' }, null, 2),
        },
      }
    }
    return { ok: true, run }
  } catch (err) {
    return {
      ok: false,
      result: {
        success: false,
        result: JSON.stringify({
          ok: false,
          error: err instanceof Error ? err.message : String(err),
        }),
      },
    }
  }
}
