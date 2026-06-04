/**
 * Regenerate desktop CAD discipline fragment (run: pnpm --filter xyzt-agent exec tsx scripts/generate-desktop-agent-contract.ts)
 */
import { writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { DESKTOP_AGENT_TOOL_NAMES } from 'xyzt-agent-tools'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const toolList = DESKTOP_AGENT_TOOL_NAMES.join(', ')
const toolCount = DESKTOP_AGENT_TOOL_NAMES.length

const discipline = `/** Auto-generated — run: pnpm exec tsx scripts/generate-desktop-agent-contract.ts */
export const DESKTOP_CAD_AGENT_DISCIPLINE_BODY = \`<agent_discipline>
PEL + OEL — declarative constraints; tool calls only for artifacts:
0. Planning phase tools only until Build: ask_user, build_project_run_plan, explain_diagnostics, get_capabilities, list_files, pel_plan, pel_read_digest, read_file, update_plan, validate_project.
1. After Build: host runs get_capabilities automatically.
2. Authoring: patch_file until task met — no scratch test_*.xyzt. validate on the file you edit.
3. CAD placement: placementSpec/mates + designContract + solve() — never guess at:[x,y,z] or translate for assembly layout. One fixed root. constrainedSketch for 2D.
4. EDA: circuit().constraints({...}) + placement(edaPlacement()) — not hand-written .at(x,y) until verify_eda/placement solve JSON cites coords.
5. orient_cad after placement constraint edits; cite mateSolveReport/ledger — patch_constraint before patch_coord.
6. Multi-body: gates.mechanicalOk before update_overview.

Desktop tool catalog (${toolCount} tools): ${toolList}
</agent_discipline>\`
`

writeFileSync(join(root, 'src/agent-discipline.generated.ts'), discipline, 'utf8')
console.log(`Wrote agent-discipline.generated.ts (${toolCount} tools)`)
