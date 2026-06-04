import { base64ToBytes, bytesToBase64, sha256Hex } from '../lib/bytes.js'
import {
  bomToProjectCsv,
  composeVerifyReport,
  exportFabBundle,
  extractBom,
  initOpenCascade,
  isOpenCascadeLoaded,
  toSTEP,
  type CircuitJson,
  type VerifyProfile,
} from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { runScriptForExport } from './engine-executor.js'

/** Binary STL from indexed triangle mesh. */
function meshToStlBinary(mesh: { vertices: number[]; indices: number[] }): ArrayBuffer {
  const v = mesh.vertices
  const idx = mesh.indices
  const triCount = idx.length / 3
  const buf = new ArrayBuffer(84 + triCount * 50)
  const view = new DataView(buf)
  for (let i = 0; i < 80; i++) view.setUint8(i, 0)
  view.setUint32(80, triCount, true)
  let o = 84
  for (let t = 0; t < triCount; t++) {
    const i0 = idx[t * 3]! * 3
    const i1 = idx[t * 3 + 1]! * 3
    const i2 = idx[t * 3 + 2]! * 3
    const ax = v[i1]! - v[i0]!, ay = v[i1 + 1]! - v[i0 + 1]!, az = v[i1 + 2]! - v[i0 + 2]!
    const bx = v[i2]! - v[i0]!, by = v[i2 + 1]! - v[i0 + 1]!, bz = v[i2 + 2]! - v[i0 + 2]!
    let nx = ay * bz - az * by
    let ny = az * bx - ax * bz
    let nz = ax * by - ay * bx
    const len = Math.hypot(nx, ny, nz) || 1
    nx /= len
    ny /= len
    nz /= len
    view.setFloat32(o, nx, true)
    o += 4
    view.setFloat32(o, ny, true)
    o += 4
    view.setFloat32(o, nz, true)
    o += 4
    for (const vi of [i0, i1, i2]) {
      view.setFloat32(o, v[vi]!, true)
      o += 4
      view.setFloat32(o, v[vi + 1]!, true)
      o += 4
      view.setFloat32(o, v[vi + 2]!, true)
      o += 4
    }
    view.setUint16(o, 0, true)
    o += 2
  }
  return buf
}

function defaultOutPath(tool: string, ext: string): string {
  if (tool === 'export_gerber_bundle') return `dist/fab/xyzt-fab.zip`
  if (tool === 'export_bom') return `dist/bom.csv`
  return `dist/export.${ext}`
}

async function writeBytes(
  ctx: ToolContext,
  path: string,
  data: Uint8Array,
): Promise<LocalToolResult> {
  if (!ctx.writeBinaryFile) {
    const b64 = bytesToBase64(data)
    const hash = await sha256Hex(data)
    return {
      success: true,
      result: JSON.stringify({
        ok: true,
        path,
        sha256: hash,
        bytes: data.length,
        encoding: 'base64',
        data_base64: b64,
        note: 'Host did not persist file; returned inline base64.',
      }),
    }
  }
  return ctx.writeBinaryFile(path, data, ctx.sandboxEdits ? 'sandbox' : 'direct')
}

async function circuitFromArgs(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<{ ok: true; circuit: CircuitJson } | { ok: false; result: LocalToolResult }> {
  const runOut = await runScriptForExport(args, ctx)
  if (!runOut.ok) return runOut
  const cj = runOut.run.circuitJson
  if (!cj?.length) {
    return {
      ok: false,
      result: {
        success: false,
        result: JSON.stringify({
          ok: false,
          error: 'Script did not return a circuit. Use a .xyzt.eda script that returns circuit().',
          code: 'NO_CIRCUIT',
        }),
      },
    }
  }
  return { ok: true, circuit: cj as CircuitJson }
}

export async function executeExportGerberBundle(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const circuitOut = await circuitFromArgs(args, ctx)
  if (!circuitOut.ok) return circuitOut.result

  const createdAt = new Date().toISOString()
  const bundle = exportFabBundle(circuitOut.circuit, { createdAt })
  const outPath = (args.outPath as string) || defaultOutPath('export_gerber_bundle', 'zip')
  const write = await writeBytes(ctx, outPath, bundle.zip)
  if (!write.success) return write

  const payload = {
    ok: true,
    path: outPath,
    sha256: await sha256Hex(bundle.zip),
    bytes: bundle.zip.length,
    manifest: bundle.manifest,
    result: write.result,
  }
  return { success: true, result: JSON.stringify(payload, null, 2) }
}

export async function executeExportBom(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const circuitOut = await circuitFromArgs(args, ctx)
  if (!circuitOut.ok) return circuitOut.result

  const bom = extractBom(circuitOut.circuit)
  const csv = bomToProjectCsv(bom)
  const outPath = (args.outPath as string) || defaultOutPath('export_bom', 'csv')
  if (ctx.sandboxEdits) {
    return {
      success: true,
      pending: true,
      result: JSON.stringify({ ok: true, path: outPath, lineCount: bom.length }),
      files: [{ name: outPath, content: csv }],
    }
  }
  return {
    success: true,
    result: JSON.stringify({ ok: true, path: outPath, lineCount: bom.length }),
    files: [{ name: outPath, content: csv }],
  }
}

export async function executeExportStl(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const runOut = await runScriptForExport(args, ctx)
  if (!runOut.ok) return runOut.result
  const mesh = runOut.run.meshes[0]
  if (!mesh) {
    return {
      success: false,
      result: JSON.stringify({ ok: false, error: 'No mesh in script result', code: 'NO_MESH' }),
    }
  }
  const stlBin = meshToStlBinary({
    vertices: Array.from(mesh.vertices),
    indices: Array.from(mesh.indices),
  })
  const outPath = (args.outPath as string) || defaultOutPath('export_stl', 'stl')
  const write = await writeBytes(ctx, outPath, new Uint8Array(stlBin))
  if (!write.success) return write
  return {
    success: true,
    result: JSON.stringify({
      ok: true,
      path: outPath,
      sha256: await sha256Hex(new Uint8Array(stlBin)),
      bytes: stlBin.byteLength,
    }),
  }
}

export async function executeExportStep(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const { resolveScriptCode } = await import('./engine-executor.js')
  const resolved = await resolveScriptCode(args, ctx.getFileContent, ctx.ensureFileContent)
  if (!resolved) {
    return { success: false, result: 'code or fileName is required.' }
  }

  if (!ctx.runScriptInProcess) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        error: 'STEP export requires in-process script run on this host.',
        code: 'EXPORT_STEP_UNAVAILABLE',
      }),
    }
  }

  if (!isOpenCascadeLoaded()) {
    await initOpenCascade()
  }

  try {
    const run = await ctx.runScriptInProcess(
      resolved,
      (args.params as Record<string, unknown>) ?? {},
    )
    if (!run.success) {
      return {
        success: false,
        result: JSON.stringify({ ok: false, error: run.error, code: 'RUN_FAILED' }),
      }
    }
    const assembly = run._assembly as { _bodies?: Map<string, { shape: import('xyzt-cad').Shape }> } | undefined
    const shapes = assembly?._bodies
      ? [...assembly._bodies.values()].map(e => e.shape)
      : []
    if (!shapes.length) {
      return {
        success: false,
        result: JSON.stringify({
          ok: false,
          error: 'Script must return an Assembly with solids for STEP. Use export_stl for mesh-only output.',
          code: 'NO_SOLIDS',
        }),
      }
    }
    const stepText = await toSTEP(shapes.length === 1 ? shapes[0]! : shapes)
    const outPath = (args.outPath as string) || defaultOutPath('export_step', 'step')
    const bytes = new TextEncoder().encode(stepText)
    const write = await writeBytes(ctx, outPath, bytes)
    if (!write.success) return write
    return {
      success: true,
      result: JSON.stringify({
        ok: true,
        path: outPath,
        sha256: await sha256Hex(bytes),
        bytes: bytes.length,
        bodyCount: shapes.length,
      }),
    }
  } catch (err) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        error: err instanceof Error ? err.message : String(err),
        code: 'EXPORT_STEP_FAILED',
      }),
    }
  }
}

export async function executeWriteArtifact(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const path = args.path as string
  const dataBase64 = args.data_base64 as string
  if (!path || !dataBase64) {
    return { success: false, result: 'path and data_base64 are required.' }
  }
  const data = base64ToBytes(dataBase64)
  return writeBytes(ctx, path, data)
}

export async function executeRunVerifyProfile(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const profile = (args.profile as VerifyProfile) || 'hobby'
  const runOut = await runScriptForExport(args, ctx)
  const input = runOut.ok
    ? { scriptResult: runOut.run, meshes: runOut.run.meshes }
    : { meshes: [] }
  const report = composeVerifyReport(input, profile)
  return {
    success: report.ok,
    result: JSON.stringify(report, null, 2),
  }
}
