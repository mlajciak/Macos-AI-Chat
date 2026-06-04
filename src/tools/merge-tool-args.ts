import { parsePartialToolArgs } from './parse-partial-tool-args.js'

/** Merge streamed partial JSON tool arguments with a parsed tool_call event payload. */
export function mergeToolArgs(
  eventArgs: Record<string, unknown>,
  rawJson?: string,
): Record<string, unknown> {
  if (!rawJson?.trim()) return eventArgs

  let parsed: Record<string, unknown> = {}
  try {
    const value = JSON.parse(rawJson) as unknown
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      parsed = value as Record<string, unknown>
    }
  } catch {
    parsed = parsePartialToolArgs(rawJson)
  }

  const out = { ...parsed }
  for (const [key, value] of Object.entries(eventArgs)) {
    if (value === undefined || value === null) continue
    if (typeof value === 'string' && value === '' && typeof parsed[key] === 'string' && parsed[key]) {
      continue
    }
    out[key] = value
  }
  return out
}

/** Args for tool execution — only complete JSON, never partial field extraction. */
export function mergeToolArgsForExecute(
  eventArgs: Record<string, unknown>,
  rawJson?: string,
): Record<string, unknown> {
  if (!rawJson?.trim()) return { ...eventArgs }
  try {
    const value = JSON.parse(rawJson) as unknown
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      const parsed = value as Record<string, unknown>
      const out = { ...parsed }
      for (const [key, val] of Object.entries(eventArgs)) {
        if (val === undefined || val === null) continue
        if (typeof val === 'string' && val === '' && typeof parsed[key] === 'string' && parsed[key]) {
          continue
        }
        out[key] = val
      }
      return out
    }
  } catch {
    /* incomplete streamed JSON */
  }
  return { ...eventArgs }
}
