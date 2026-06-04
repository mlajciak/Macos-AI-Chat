import type { AgentWorkerRole } from './types.js'

const SUPERVISOR_TOOLS = new Set([
  'get_capabilities',
  'validate_project',
  'build_project_run_plan',
  'update_plan',
  'read_file',
  'list_files',
  'ask_user',
  'pel_plan',
  'pel_read_digest',
  'pel_activate_node',
  'update_overview',
  'explain_diagnostics',
])

const EDA_TOOLS = new Set([
  'create_eda',
  'verify_eda',
  'run_drc',
  'apply_eda_edit',
  'edit_board',
  'place_component',
  'lookup_part',
])

const SIM_TOOLS = new Set(['create_simulation', 'validate_simulation', 'run_simulation', 'get_simulation_backends'])

export function workerRoleForTool(toolName: string): AgentWorkerRole {
  if (SUPERVISOR_TOOLS.has(toolName)) return 'supervisor'
  if (EDA_TOOLS.has(toolName)) return 'eda'
  if (SIM_TOOLS.has(toolName)) return 'sim'
  return 'cad'
}

export function parseWorkflowGateHint(result: string | undefined): { code?: string; nextTool?: string } | null {
  if (!result?.trim()) return null
  try {
    const parsed = JSON.parse(result) as { code?: string; next_tool?: string }
    if (!parsed.code?.startsWith('WORKFLOW_')) return null
    return { code: parsed.code, nextTool: parsed.next_tool }
  } catch {
    return null
  }
}
