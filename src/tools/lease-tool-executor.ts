import {
  acquireFileLease,
  createEmptyFileLeaseStore,
  FILE_LEASES_REL_PATH,
  parseFileLeaseStore,
  releaseFileLease,
  serializeFileLeaseStore,
} from 'xyzt-cad'
import type { LocalToolResult, ToolContext } from '../types.js'
import { getPersistedLeaseStoreContent, leaseHolderId } from './lease-gate.js'

function loadStore(ctx: ToolContext) {
  const raw = getPersistedLeaseStoreContent(ctx) ?? ctx.getFileContent(FILE_LEASES_REL_PATH)
  return raw ? parseFileLeaseStore(raw) : createEmptyFileLeaseStore()
}

export async function executeFileLeaseTool(
  toolName: string,
  args: Record<string, unknown>,
  ctx: ToolContext,
  runKey: object,
): Promise<LocalToolResult> {
  const path = typeof args.path === 'string' ? args.path.trim() : typeof args.fileName === 'string' ? args.fileName.trim() : ''
  if (!path) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'path or fileName is required' }) }
  }
  const holder = leaseHolderId(ctx, runKey)
  let store = loadStore(ctx)

  if (toolName === 'release_file_lease') {
    store = releaseFileLease(store, path, holder)
    const content = serializeFileLeaseStore(store)
    return {
      success: true,
      result: JSON.stringify({ ok: true, released: path, holderId: holder }),
      files: [{ name: FILE_LEASES_REL_PATH, content }],
    }
  }

  const ttlMs = typeof args.ttlMs === 'number' && args.ttlMs > 0 ? args.ttlMs : undefined
  const acquired = acquireFileLease(store, path, holder, ttlMs)
  store = acquired.store
  const content = serializeFileLeaseStore(store)
  if (!acquired.ok) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        code: 'LEASE_HELD',
        path,
        holderId: acquired.holderId,
        expiresAt: acquired.expiresAt,
      }),
    }
  }
  return {
    success: true,
    result: JSON.stringify({
      ok: true,
      path,
      holderId: holder,
      expiresAt: acquired.lease.expiresAt,
      renewed: acquired.renewed,
    }),
    files: [{ name: FILE_LEASES_REL_PATH, content }],
  }
}
