import {
  acquireFileLease,
  createEmptyFileLeaseStore,
  FILE_LEASES_REL_PATH,
  isFileWriteTool,
  parseFileLeaseStore,
  resolveLeasePathFromArgs,
  serializeFileLeaseStore,
} from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'

const leaseStoreByProject = new WeakMap<object, { raw: string }>()

function readLeaseStore(ctx: ToolContext): ReturnType<typeof parseFileLeaseStore> {
  let slot = leaseStoreByProject.get(ctx)
  if (!slot) {
    const raw = ctx.getFileContent(FILE_LEASES_REL_PATH)
    slot = { raw: raw ?? '' }
    leaseStoreByProject.set(ctx, slot)
  }
  return slot.raw ? parseFileLeaseStore(slot.raw) : createEmptyFileLeaseStore()
}

function writeLeaseStore(ctx: ToolContext, store: ReturnType<typeof parseFileLeaseStore>): void {
  leaseStoreByProject.set(ctx, { raw: serializeFileLeaseStore(store) })
}

export function leaseHolderId(ctx: ToolContext, runKey: object): string {
  return ctx.agentRunId ?? `run-${String(runKey)}`
}

export function gateFileLease(
  toolName: string,
  args: Record<string, unknown> | undefined,
  ctx: ToolContext,
  runKey: object,
): LocalToolResult | null {
  if (!isFileWriteTool(toolName)) return null
  const path = resolveLeasePathFromArgs(toolName, args)
  if (!path) return null
  const holder = leaseHolderId(ctx, runKey)
  const acquired = acquireFileLease(readLeaseStore(ctx), path, holder)
  writeLeaseStore(ctx, acquired.store)
  if (!acquired.ok) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        code: 'FILE_LEASE_HELD',
        error: `File "${path}" is leased by ${acquired.holderId} until ${acquired.expiresAt}.`,
        path,
        holderId: acquired.holderId,
        expiresAt: acquired.expiresAt,
        retryable: true,
        next_tool: 'acquire_file_lease',
      }),
    }
  }
  return null
}

export function getPersistedLeaseStoreContent(ctx: ToolContext): string | undefined {
  const slot = leaseStoreByProject.get(ctx)
  return slot?.raw || undefined
}

export function leaseFilesFromToolResult(
  ctx: ToolContext,
  files?: Array<{ name: string; content: string }>,
): void {
  if (!files?.length) return
  const holder = leaseHolderId(ctx, ctx)
  let store = readLeaseStore(ctx)
  for (const f of files) {
    if (f.name === FILE_LEASES_REL_PATH) {
      store = parseFileLeaseStore(f.content)
      continue
    }
    const r = acquireFileLease(store, f.name, holder)
    store = r.store
  }
  writeLeaseStore(ctx, store)
}
