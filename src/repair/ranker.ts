import type { RepairActionV0, RepairPayloadV0 } from 'xyzt-cad'

export type RepairRankerInput = {
  payload: RepairPayloadV0
  snippet?: string
  diagnostics?: unknown[]
}

export async function rankRepairActions(input: RepairRankerInput): Promise<RepairActionV0[]> {
  const order = { deterministic: 0, heuristic: 1 } as const
  return [...input.payload.actions].sort(
    (a, b) => order[a.confidence] - order[b.confidence],
  )
}
