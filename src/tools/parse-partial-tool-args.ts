import { applyPatches, type FilePatch } from './apply-patches.js'

/** Parse streaming tool args JSON, or extract known fields from a partial object. */
export function parsePartialToolArgs(partial: string): Record<string, unknown> {
  if (!partial.trim()) return {}
  try {
    const parsed = JSON.parse(partial) as unknown
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>
    }
  } catch {
    /* streaming partial JSON */
  }
  const out: Record<string, unknown> = {}
  const fileName = extractJsonStringField(partial, 'fileName', 1)
  if (fileName) out.fileName = fileName
  const content = extractContentFromPartialArgs(partial)
  if (content) out.content = content
  return out
}

/** Best-effort extract of script `content` from streaming JSON tool arguments. */
export function extractContentFromPartialArgs(partial: string): string | null {
  if (!partial.includes('content')) return null
  try {
    const parsed = JSON.parse(partial) as { content?: unknown }
    if (typeof parsed.content === 'string' && parsed.content.length > 0) return parsed.content
  } catch {
    /* streaming partial JSON */
  }

  return extractJsonStringField(partial, 'content', 1)
}

/** Extract patch hunks from partial streaming JSON (best-effort). */
export function extractPatchesFromPartialArgs(partial: string): FilePatch[] | null {
  if (!partial.includes('patches')) return null
  try {
    const parsed = JSON.parse(partial) as { patches?: unknown }
    if (Array.isArray(parsed.patches)) {
      const out: FilePatch[] = []
      for (const p of parsed.patches) {
        if (p && typeof p === 'object' && 'old' in p && 'new' in p) {
          const row = p as { old?: unknown; new?: unknown }
          if (typeof row.old === 'string' && typeof row.new === 'string') {
            out.push({ old: row.old, new: row.new })
          }
        }
      }
      if (out.length > 0) return out
    }
  } catch {
    /* partial */
  }

  const patches: FilePatch[] = []
  const re = /"old"\s*:\s*"((?:\\.|[^"\\])*)"\s*,\s*"new"\s*:\s*"((?:\\.|[^"\\])*)"/g
  let m: RegExpExecArray | null
  while ((m = re.exec(partial)) !== null) {
    patches.push({
      old: unescapeJsonString(m[1]!),
      new: unescapeJsonString(m[2]!),
    })
  }
  return patches.length > 0 ? patches : null
}

/** Legacy single hunk from edit_file old_content/new_content while streaming. */
export function extractLegacyPatchFromPartialArgs(partial: string): FilePatch | null {
  const old = extractJsonStringField(partial, 'old_content', 1)
  const neu = extractJsonStringField(partial, 'new_content', 1)
  if (old != null && neu != null) return { old, new: neu }
  return null
}

export function previewContentFromPartialArgs(
  base: string,
  partial: string,
  toolName: string,
): string | null {
  const full = extractContentFromPartialArgs(partial)
  if (full) return full

  if (toolName === 'patch_file' || partial.includes('patches')) {
    const patches = extractPatchesFromPartialArgs(partial)
    if (patches?.length) {
      const applied = applyPatches(base, patches)
      if (applied.ok) return applied.content
    }
  }

  const legacy = extractLegacyPatchFromPartialArgs(partial)
  if (legacy) {
    const applied = applyPatches(base, [legacy])
    if (applied.ok) return applied.content
  }

  return null
}

export function extractJsonStringField(partial: string, field: string, minLen: number): string | null {
  const key = `"${field}"`
  const idx = partial.indexOf(key)
  if (idx < 0) return null
  let i = partial.indexOf(':', idx + key.length)
  if (i < 0) return null
  i += 1
  while (i < partial.length && /\s/.test(partial[i]!)) i += 1
  if (partial[i] !== '"') return null
  i += 1

  let out = ''
  let escaped = false
  while (i < partial.length) {
    const c = partial[i]!
    if (escaped) {
      if (c === 'n') out += '\n'
      else if (c === 't') out += '\t'
      else if (c === 'r') out += '\r'
      else out += c
      escaped = false
    } else if (c === '\\') {
      escaped = true
    } else if (c === '"') {
      break
    } else {
      out += c
    }
    i += 1
  }

  return out.length >= minLen ? out : null
}

function unescapeJsonString(s: string): string {
  return s
    .replace(/\\n/g, '\n')
    .replace(/\\t/g, '\t')
    .replace(/\\r/g, '\r')
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\')
}
