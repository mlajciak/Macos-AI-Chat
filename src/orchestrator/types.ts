/** MA-1 / MA-3 handoff — supervisor ↔ worker (types only; no parallel host yet). */

export type AgentWorkerRole = 'supervisor' | 'cad' | 'eda' | 'sim'

export interface AgentHandoffV0 {
  from: AgentWorkerRole
  to: AgentWorkerRole
  stateDigest: string
  files: string[]
  blockers: string[]
  gateSnapshot?: Record<string, unknown>
}
