import { appendFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import type { RepairPayloadV0 } from 'xyzt-cad'

export type RepairTraceV0 = {
  runId?: string
  todoId?: string
  fileName: string
  trigger: string
  payloadIn: RepairPayloadV0
  payloadOut?: RepairPayloadV0 | null
  attempt: number
  success: boolean
  timestamp: string
}

const METRICS: Record<string, number> = {}

export function repairMetricsSnapshot(): Record<string, number> {
  return { ...METRICS }
}

function bump(key: string): void {
  METRICS[key] = (METRICS[key] ?? 0) + 1
}

export function appendRepairTrace(trace: RepairTraceV0, traceDir?: string): void {
  if (process.env.XYZT_REPAIR_TRACE !== '1') return
  const dir = traceDir ?? join(process.cwd(), '.xyzt.agent', 'repair-traces')
  mkdirSync(dir, { recursive: true })
  const file = join(dir, 'repair.jsonl')
  appendFileSync(file, `${JSON.stringify(trace)}\n`, 'utf8')
}

export function recordRepairAttempt(source: string): void {
  bump(`repair_attempt_total:${source}`)
}

export function recordRepairSuccess(source: string): void {
  bump(`repair_success_total:${source}`)
}

export function recordRepairEscalate(source: string): void {
  bump(`repair_escalate_total:${source}`)
}
