import type { RepairPayloadV0 } from 'xyzt-cad'
import type { AgentWorkerRole } from './types.js'

export interface GateRouteHint {
  worker: AgentWorkerRole
  nextTool?: string
  note?: string
  repair?: RepairPayloadV0
}

export function parseGateRepair(gateError: string): RepairPayloadV0 | undefined {
  try {
    const parsed = JSON.parse(gateError) as { repair?: RepairPayloadV0 }
    if (parsed.repair?.version === 0 && parsed.repair.ok === false) return parsed.repair
  } catch {
    /* not JSON */
  }
  return undefined
}

/** Map WORKFLOW_* gate codes to suggested worker + next tool (supervisor MVP). */
export function routeGateBlock(gateError: string): GateRouteHint | null {
  const repair = parseGateRepair(gateError)
  if (gateError.includes('WORKFLOW_PREFLIGHT_REQUIRED')) {
    return { worker: 'supervisor', nextTool: 'get_capabilities', note: 'preflight', repair }
  }
  if (gateError.includes('WORKFLOW_VALIDATE_REQUIRED')) {
    return { worker: 'cad', nextTool: 'validate_script', note: 'per-file validate', repair }
  }
  if (gateError.includes('WORKFLOW_SPATIAL_REQUIRED')) {
    return { worker: 'cad', nextTool: 'orient_cad', note: 'OEL orient', repair }
  }
  if (gateError.includes('WORKFLOW_EDA_VERIFY_REQUIRED')) {
    return { worker: 'eda', nextTool: 'verify_eda', note: 'eda verify', repair }
  }
  if (gateError.includes('WORKFLOW_PEL')) {
    return { worker: 'supervisor', nextTool: 'pel_plan', note: 'pel program', repair }
  }
  if (gateError.includes('FILE_LEASE_HELD')) {
    return { worker: 'supervisor', nextTool: 'acquire_file_lease', note: 'lease', repair }
  }
  return repair ? { worker: 'supervisor', repair } : null
}
