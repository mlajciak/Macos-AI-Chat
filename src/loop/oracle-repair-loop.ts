import type { RepairPayloadV0 } from 'xyzt-cad'
import type { ToolContext } from '../types.js'
import { executeValidateScript, executeVerifyEda } from '../tools/engine-executor.js'
import { executeOrientCad } from '../tools/orient-cad-executor.js'
import { rankRepairActions } from '../repair/ranker.js'
import {
  appendRepairTrace,
  recordRepairAttempt,
  recordRepairEscalate,
  recordRepairSuccess,
} from '../repair/trace.js'

export const MAX_ORACLE_REPAIR_ATTEMPTS = 3

export type OracleRepairTrigger = 'validate_script' | 'orient_cad' | 'verify_eda'

export type OracleRepairCycleResult = {
  payload: RepairPayloadV0 | null
  revalidated: boolean
  attempts: number
  repairable: boolean
}

function parseRepair(raw: unknown): RepairPayloadV0 | null {
  if (!raw || typeof raw !== 'object') return null
  const r = raw as RepairPayloadV0
  return r.version === 0 && r.ok === false ? r : null
}

function extractRepairFromToolResult(resultJson: string): RepairPayloadV0 | null {
  try {
    const parsed = JSON.parse(resultJson) as Record<string, unknown>
    return parseRepair(parsed.repair) ?? parseRepair(parsed.orient && typeof parsed.orient === 'object' ? (parsed.orient as { repair?: RepairPayloadV0 }).repair : null)
  } catch {
    return null
  }
}

async function runOracle(
  trigger: OracleRepairTrigger,
  fileName: string,
  ctx: ToolContext,
  code?: string,
): Promise<{ ok: boolean; repair: RepairPayloadV0 | null; raw: string }> {
  const args = code ? { fileName, code } : { fileName }
  if (trigger === 'validate_script') {
    const out = await executeValidateScript(args, ctx)
    return { ok: out.success, repair: extractRepairFromToolResult(out.result), raw: out.result }
  }
  if (trigger === 'verify_eda') {
    const out = await executeVerifyEda(args, ctx)
    return { ok: out.success, repair: extractRepairFromToolResult(out.result), raw: out.result }
  }
  const out = await executeOrientCad(args, ctx)
  let repair = extractRepairFromToolResult(out.result)
  if (!repair) {
    try {
      const parsed = JSON.parse(out.result) as { repair?: RepairPayloadV0 }
      repair = parseRepair(parsed.repair)
    } catch {
      /* ignore */
    }
  }
  return { ok: out.success, repair, raw: out.result }
}

export async function runOracleRepairCycle(input: {
  trigger: OracleRepairTrigger
  fileName: string
  ctx: ToolContext
  code?: string
  runId?: string
  todoId?: string
  startAttempt?: number
}): Promise<OracleRepairCycleResult> {
  const { trigger, fileName, ctx, code, runId, todoId } = input
  let attempt = input.startAttempt ?? 0
  let lastPayload: RepairPayloadV0 | null = null

  while (attempt < MAX_ORACLE_REPAIR_ATTEMPTS) {
    recordRepairAttempt(trigger)
    const oracle = await runOracle(trigger, fileName, ctx, code)
    if (oracle.ok) {
      recordRepairSuccess(trigger)
      appendRepairTrace({
        runId,
        todoId,
        fileName,
        trigger,
        payloadIn: lastPayload ?? oracle.repair ?? {
          version: 0,
          source: trigger,
          ok: false,
          fileName,
          phase: 'repair',
          failures: [],
          actions: [],
          retryable: true,
          attempt,
        },
        payloadOut: null,
        attempt,
        success: true,
        timestamp: new Date().toISOString(),
      })
      return { payload: null, revalidated: true, attempts: attempt + 1, repairable: false }
    }

    lastPayload = oracle.repair
    if (lastPayload) {
      lastPayload = {
        ...lastPayload,
        attempt,
        actions: await rankRepairActions({ payload: lastPayload, snippet: code }),
      }
    }

    appendRepairTrace({
      runId,
      todoId,
      fileName,
      trigger,
      payloadIn: lastPayload ?? {
        version: 0,
        source: trigger,
        ok: false,
        fileName,
        phase: 'repair',
        failures: [{ code: 'ORACLE_FAILED', message: 'Oracle check failed', severity: 'error' }],
        actions: [],
        retryable: true,
        attempt,
      },
      attempt,
      success: false,
      timestamp: new Date().toISOString(),
    })

    const deterministic = lastPayload?.actions.some(a => a.confidence === 'deterministic' && a.kind === 'rerun_tool')
    if (!deterministic) break
    attempt += 1
  }

  if (lastPayload) {
    recordRepairEscalate(trigger)
    return {
      payload: lastPayload,
      revalidated: false,
      attempts: attempt + 1,
      repairable: lastPayload.retryable,
    }
  }

  return { payload: null, revalidated: false, attempts: attempt, repairable: false }
}
