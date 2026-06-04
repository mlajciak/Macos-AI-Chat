import type { LocalToolResult } from '../types.js'

export function isCadXyztFile(fileName: string): boolean {
  return (
    fileName.endsWith('.xyzt') &&
    !fileName.endsWith('.xyzt.eda') &&
    !fileName.endsWith('.xyzt.draft') &&
    !fileName.endsWith('.xyzt.simulation')
  )
}

const SPATIAL_NUDGE =
  'If tool result lacks orient.gates, call orient_cad before the next patch_file. Use mates/placementSpec — not at:[x,y,z].'

export function appendCadSpatialNudge(fileName: string, result: LocalToolResult): LocalToolResult {
  if (!result.success || !isCadXyztFile(fileName)) return result
  const hint = `\n\n[workflow] ${SPATIAL_NUDGE}`
  if (result.result.includes(SPATIAL_NUDGE)) return result
  return { ...result, result: `${result.result}${hint}` }
}

function orientAlreadySatisfied(parsed: Record<string, unknown>): boolean {
  const orient = parsed.orient
  if (!orient || typeof orient !== 'object') return false
  const gates = (orient as { gates?: { mechanicalOk?: boolean } }).gates
  if (gates?.mechanicalOk === true) return true
  const ok = (orient as { ok?: boolean }).ok
  return ok === true
}

export function appendValidateSpatialNudge(
  fileName: string | undefined,
  result: LocalToolResult,
): LocalToolResult {
  if (!result.success || !fileName || !isCadXyztFile(fileName)) return result
  try {
    const parsed = JSON.parse(result.result) as Record<string, unknown>
    if (parsed.ok !== true) return result
    if (orientAlreadySatisfied(parsed) || parsed.post_write_orient === true) {
      parsed.workflow_reminder =
        'validate ok; orient already satisfied on last write — use patch_file, re-orient only after placement edits.'
      return { ...result, result: JSON.stringify(parsed, null, 2) }
    }
    parsed.workflow_reminder = SPATIAL_NUDGE
    parsed.next_tool = 'orient_cad'
    return { ...result, result: JSON.stringify(parsed, null, 2) }
  } catch {
    return appendCadSpatialNudge(fileName, result)
  }
}
