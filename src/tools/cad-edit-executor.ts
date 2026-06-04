import { handleEditFeature, handleGetParams } from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { resolveScriptCode } from './engine-executor.js'

export async function executeGetParams(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const code = await resolveScriptCode(args, ctx.getFileContent.bind(ctx), ctx.ensureFileContent)
  if (!code) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'code or fileName is required.' }) }
  }
  try {
    const out = await handleGetParams({ code })
    const ok = out.ok
    return {
      success: ok,
      result: JSON.stringify(out, null, 2),
    }
  } catch (e) {
    return {
      success: false,
      result: JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }),
    }
  }
}

export async function executeEditFeature(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const code = await resolveScriptCode(args, ctx.getFileContent.bind(ctx), ctx.ensureFileContent)
  if (!code) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'code or fileName is required.' }) }
  }
  const fileName = typeof args.fileName === 'string' ? args.fileName.trim() : ''
  try {
    const out = await handleEditFeature({ ...args, code })
    if (!out.ok) {
      return { success: false, result: JSON.stringify(out, null, 2) }
    }
    const payload: Record<string, unknown> = { ...out }
    if (out.patchedCode && fileName && args.apply !== false) {
      if (ctx.sandboxEdits) {
        return {
          success: true,
          pending: true,
          result: JSON.stringify(payload, null, 2),
          files: [{ name: fileName, content: out.patchedCode }],
        }
      }
      return {
        success: true,
        result: JSON.stringify(payload, null, 2),
        files: [{ name: fileName, content: out.patchedCode }],
      }
    }
    return { success: true, result: JSON.stringify(payload, null, 2) }
  } catch (e) {
    return {
      success: false,
      result: JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }),
    }
  }
}
