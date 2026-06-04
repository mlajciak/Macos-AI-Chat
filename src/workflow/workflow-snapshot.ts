import type { WorkflowRunState } from './state-machine.js'

export const WORKFLOW_SNAPSHOT_DIR = '.xyzt/agent/workflow'

export function workflowSnapshotRelativePath(runId: string): string {
  return `${WORKFLOW_SNAPSHOT_DIR}/${runId}.json`
}

export function serializeWorkflowSnapshot(state: WorkflowRunState): string {
  return JSON.stringify({ version: 0, state })
}

export function parseWorkflowSnapshot(raw: string): WorkflowRunState | null {
  try {
    const parsed = JSON.parse(raw) as { version?: number; state?: WorkflowRunState }
    if (!parsed.state || typeof parsed.state !== 'object') return null
    return parsed.state
  } catch {
    return null
  }
}
