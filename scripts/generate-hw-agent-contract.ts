/**
 * Regenerate HW engineering agent discipline (run: pnpm generate:contract)
 */
import { writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { DESKTOP_AGENT_TOOL_NAMES, RUNTIME_AGENT_TOOL_NAMES } from 'xyzt-agent-tools'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const modelTools = DESKTOP_AGENT_TOOL_NAMES.join(', ')
const runtimeCount = RUNTIME_AGENT_TOOL_NAMES.length

const discipline = `/** Auto-generated — run: pnpm generate:contract */
export const DESKTOP_CAD_AGENT_DISCIPLINE_BODY = \`<agent_discipline>
HW engineering agent — CAD + EDA + simulation + exports. Tool calls only for artifacts.

0. Planning: ask_user, build_project_run_plan, explain_diagnostics, get_capabilities, list_files, pel_plan, pel_read_digest, read_file, update_plan, validate_project.
1. Author: create_cad | create_eda | create_simulation + patch_file until task met.
2. CAD: placementSpec/mates + designContract + solve(); constrainedSketch for 2D; orient_cad after placement edits.
3. EDA: circuit().constraints({...}) + placement(edaPlacement()); verify_eda after every EDA mutation before update_overview.
4. Simulation: validate_simulation before run_simulation; cite backend diagnostics.
5. Export: export_step | export_gerber_bundle | export_bom | run_verify_profile before ship.
6. Ship: update_overview only when domain gates pass (mechanicalOk, EDA verify, sim validate).

Model tools (${DESKTOP_AGENT_TOOL_NAMES.length}): ${modelTools}
Runtime tools (${runtimeCount}): full stack including validate, export, and analysis tools.
</agent_discipline>\`
`

writeFileSync(join(root, 'src/agent-discipline.generated.ts'), discipline, 'utf8')
console.log(`Wrote agent-discipline.generated.ts (model=${DESKTOP_AGENT_TOOL_NAMES.length}, runtime=${runtimeCount})`)
