export type StepEntity = {
  id: number
  type: string
  params: string
}

export type StepParseResult = {
  header: string
  data: string
  entities: Map<number, StepEntity>
  warnings: string[]
}

function extractSection(content: string, name: string): string {
  const re = new RegExp(`${name};([\\s\\S]*?)ENDSEC;`, 'i')
  const m = content.match(re)
  return m?.[1]?.trim() ?? ''
}

function findMatchingParen(s: string, openIdx: number): number {
  let depth = 0
  let inString = false
  for (let i = openIdx; i < s.length; i++) {
    const c = s[i]
    if (inString) {
      if (c === "'") inString = false
      continue
    }
    if (c === "'") {
      inString = true
      continue
    }
    if (c === '(') depth++
    else if (c === ')') {
      depth--
      if (depth === 0) return i
    }
  }
  return -1
}

export function parseStepEntities(content: string): StepParseResult {
  const warnings: string[] = []
  const header = extractSection(content, 'HEADER')
  const data = extractSection(content, 'DATA')
  const entities = new Map<number, StepEntity>()

  if (!data) {
    warnings.push('No DATA section found in STEP file')
    return { header, data, entities, warnings }
  }

  const entityRe = /#(\d+)\s*=\s*([A-Z0-9_]+)\s*\(/gi
  let m: RegExpExecArray | null
  while ((m = entityRe.exec(data)) !== null) {
    const id = Number.parseInt(m[1]!, 10)
    const type = m[2]!
    const openParen = data.indexOf('(', m.index)
    if (openParen < 0) continue
    const closeParen = findMatchingParen(data, openParen)
    if (closeParen < 0) {
      warnings.push(`Unclosed entity #${id} (${type})`)
      continue
    }
    if (entities.has(id)) {
      warnings.push(`Duplicate entity #${id}`)
    }
    const params = data.slice(openParen + 1, closeParen)
    entities.set(id, { id, type, params })
    entityRe.lastIndex = closeParen + 1
  }

  return { header, data, entities, warnings }
}

/** Pull first quoted string from STEP parameter list. */
export function firstQuotedString(params: string): string | null {
  const m = params.match(/'([^']*)'/)
  return m ? m[1]! : null
}

/** Pull all #ref integers from params. */
export function refIds(params: string): number[] {
  const ids: number[] = []
  const re = /#(\d+)/g
  let m: RegExpExecArray | null
  while ((m = re.exec(params)) !== null) {
    ids.push(Number.parseInt(m[1]!, 10))
  }
  return ids
}
