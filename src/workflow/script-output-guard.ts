/** Shown when the model wrote script in chat/thinking instead of tool calls. */
export const WORKFLOW_TOOL_ONLY_NUDGE = `[workflow] Stop drafting script in reasoning. Call tools: get_capabilities → create_cad (minimal stub ok) → patch_file until the design is complete. Assemblies: use /xyzt + /xyzt-make-cad-model API reference. Reasoning: ≤2 sentences — no code.`

/** Shown when reasoning ran long without any tool call. */
export const WORKFLOW_REASONING_BUDGET_NUDGE = `[workflow] No tools yet. get_capabilities → create_cad → patch_file iterations until done. For assemblies/gearboxes: assembly() + lib.spurGear per /xyzt-make-cad-model — do not plan the full design only in thinking.`

/** Abort as soon as script patterns appear (chars). */
export const REASONING_SCRIPT_PATTERN_MIN_CHARS = 48

/** Soft cap when thinking mentions tools but never calls them. */
export const REASONING_SCRIPT_ABORT_CHARS = 320

/** Hard cap: abort when thinking is mostly planning with no tools. */
export const REASONING_PLANNING_ABORT_CHARS = 1200

const CONVERSATIONAL_FILLER =
  /\b(maybe|perhaps|i think|i'll|let me|sure|great|happy to|of course|here's|basically|simply put|in summary|to summarize)\b/i

export function outputLooksLikeConversationalFiller(text: string): boolean {
  const t = text.trim()
  if (t.length < 24) return false
  if (CONVERSATIONAL_FILLER.test(t)) return true
  if (/^(sure|ok|okay|great|thanks|hello|hi)\b/i.test(t)) return true
  return false
}

export function outputLooksLikeUndeliveredScript(text: string): boolean {
  const t = text.trim()
  if (t.length < 40) return false
  if (looksLikeXyztScriptBody(t)) return true
  if (/```[\s\S]*?(?:let|const|return|box\(|cylinder\(|assembly\(|sketch\(|\.xyzt|function\s)/i.test(t)) {
    return true
  }
  if (/\bpatch_file\b/i.test(t) && /"patches"\s*:/.test(t)) return true
  return false
}

/** True when extended thinking contains CAD/EDA script drafting (not brief engineering notes). */
export function looksLikeXyztScriptBody(text: string): boolean {
  if (/\b(let|const)\s+\w+\s*=/.test(text) && /\b(box|cylinder|extrude|subtract|translate|return|assembly|sketch|union|difference)\b/.test(text)) {
    return true
  }
  if (/\breturn\s+(body|box|cylinder|assembly|drawing\(|circuit\(|simulation\()/i.test(text)) {
    return true
  }
  if (/\bfunction\s+\w+\s*\(/.test(text) && /\b(return|box|cylinder|union|subtract)\b/.test(text)) {
    return true
  }
  if (/\bparam\s*\(\s*['"]/i.test(text) || /\bParam\.number\s*\(/.test(text)) return true
  if (/\b(designContract|motionSequence)\s*\(/.test(text)) return true
  if (/\bfor\s*\(\s*let\s+\w+/.test(text) && /\b(Math\.PI|translate|rotate|union|subtract)\b/.test(text)) {
    return true
  }
  if (/\w+\s*=\s*\w+\.(union|subtract|translate|rotate)\(/.test(text)) return true
  if (/\bassembly\s*\(/.test(text) && /\.add\s*\(/.test(text)) return true
  if (/\bsketch\s*\(/.test(text) && /\bextrude\s*\(/.test(text)) return true
  if (/```(?:js|javascript|xyzt)?\s*[\s\S]{24,}/i.test(text)) return true
  return false
}

/**
 * Abort an in-flight thinking stream so the loop can nudge tool-first workflow.
 * Called while tokens accumulate and before any tool_call arrives.
 */
export function shouldAbortReasoningWithoutTools(
  thinkingText: string,
  hasPendingTools: boolean,
): boolean {
  if (hasPendingTools) return false
  const t = thinkingText
  if (t.length >= REASONING_SCRIPT_PATTERN_MIN_CHARS && looksLikeXyztScriptBody(t)) return true
  if (t.length < REASONING_SCRIPT_ABORT_CHARS) return false
  if (looksLikeXyztScriptBody(t)) return true
  if (t.length >= REASONING_PLANNING_ABORT_CHARS) return true
  if (t.length >= REASONING_SCRIPT_ABORT_CHARS && /\b(create_cad|patch_file|validate_script|get_capabilities)\b/i.test(t)) {
    return true
  }
  return false
}
