/**
 * Single-source agent tool names for HW engineering agent runtime.
 */

/** Tools exposed to the folder-agent model (minimal authoring surface) */
export const DESKTOP_AGENT_TOOL_NAMES = [
  'read_file',
  'list_files',
  'create_cad',
  'create_eda',
  'create_drawing',
  'create_simulation',
  'patch_file',
] as const

export type DesktopAgentToolName = (typeof DESKTOP_AGENT_TOOL_NAMES)[number]

/** @deprecated Use DESKTOP_AGENT_TOOL_NAMES */
export const AGENT_TOOL_NAMES = DESKTOP_AGENT_TOOL_NAMES

export type AgentToolName = DesktopAgentToolName

export const ENGINE_TOOL_NAMES = [
  'run_script',
  'validate_script',
  'verify_eda',
  'run_drc',
  'edit_board',
  'apply_eda_edit',
  'probe_model',
  'spatial_thinking',
  'orient_cad',
  'pel_plan',
  'pel_activate_node',
  'pel_read_digest',
  'pel_verify_program',
  'refresh_project_index',
  'acquire_file_lease',
  'release_file_lease',
  'run_simulation',
] as const

export const EXPORT_TOOL_NAMES = [
  'export_step',
  'export_stl',
  'export_gerber_bundle',
  'export_bom',
  'export_project_package',
  'write_artifact',
  'run_verify_profile',
] as const

/** Platform-scope tools (xyzt-core handlers, local execution) */
export const PLATFORM_AGENT_TOOL_NAMES = [
  'get_capabilities',
  'get_simulation_backends',
  'explain_diagnostics',
  'validate_project',
  'export_project_package',
  'build_project_run_plan',
  'validate_simulation',
  'run_simulation',
] as const

/** Tier B / analysis tools */
export const TIER_B_AGENT_TOOL_NAMES = [
  'critique_script',
  'analyze_eda',
  'search_step_parts',
  'get_step_part_code',
  'search_components',
  'lookup_part',
  'place_component',
  'get_params',
  'edit_feature',
  'apply_direct_edit',
  'get_mass_properties',
  'solve_joints',
] as const

/** Workspace / orchestration tools */
export const WORKSPACE_AGENT_TOOL_NAMES = [
  'ask_user',
  'update_plan',
  'update_overview',
  'edit_file',
  'delete_file',
  'run_simulation_study',
] as const

/**
 * Full-stack HW agent: every tool `registry.ts` may execute.
 * SSOT for agent-contract-check and runtime allowlist.
 */
export const RUNTIME_AGENT_TOOL_NAMES = [
  ...new Set([
    ...WORKSPACE_AGENT_TOOL_NAMES,
    ...DESKTOP_AGENT_TOOL_NAMES,
    ...ENGINE_TOOL_NAMES,
    ...EXPORT_TOOL_NAMES,
    ...PLATFORM_AGENT_TOOL_NAMES,
    ...TIER_B_AGENT_TOOL_NAMES,
  ]),
] as const

export type RuntimeAgentToolName = (typeof RUNTIME_AGENT_TOOL_NAMES)[number]

/** @deprecated Use PLATFORM_AGENT_TOOL_NAMES */
export const PLATFORM_MCP_TOOL_NAMES = PLATFORM_AGENT_TOOL_NAMES

export interface ToolErrorShape {
  ok: false
  code: string
  error: string
  retryable: boolean
}

export interface GoldenTranscript {
  tool: string
  input: Record<string, unknown>
  expectKeys: string[]
}

export const GOLDEN_TRANSCRIPTS: GoldenTranscript[] = [
  {
    tool: 'patch_file',
    input: { fileName: 'part.xyzt', patches: [{ old: 'box(1,1,1)', new: 'box(10,10,10)' }] },
    expectKeys: ['ok'],
  },
]
