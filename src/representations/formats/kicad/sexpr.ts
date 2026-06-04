export type SExpr = string | number | SExpr[]

export class SExprParseError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'SExprParseError'
  }
}

export function parseSExpr(input: string): SExpr {
  const tokens = tokenize(input)
  const [tree, rest] = parseTokens(tokens, 0)
  if (rest < tokens.length) {
    throw new SExprParseError(`Unexpected tokens after root at index ${rest}`)
  }
  return tree
}

function tokenize(input: string): string[] {
  const tokens: string[] = []
  let i = 0
  while (i < input.length) {
    const c = input[i]!
    if (c === ';') {
      while (i < input.length && input[i] !== '\n') i++
      continue
    }
    if (c === '(' || c === ')') {
      tokens.push(c)
      i++
      continue
    }
    if (c === '"' || c === "'") {
      const quote = c
      i++
      let s = ''
      while (i < input.length && input[i] !== quote) {
        if (input[i] === '\\' && i + 1 < input.length) {
          s += input[i + 1]
          i += 2
          continue
        }
        s += input[i]
        i++
      }
      i++
      tokens.push(`"${s}"`)
      continue
    }
    if (/\s/.test(c)) {
      i++
      continue
    }
    let j = i
    while (j < input.length && !/[\s();"]/.test(input[j]!)) j++
    tokens.push(input.slice(i, j))
    i = j
  }
  return tokens
}

function parseTokens(tokens: string[], idx: number): [SExpr, number] {
  const tok = tokens[idx]
  if (tok === undefined) throw new SExprParseError('Unexpected end of input')
  if (tok === '(') {
    const list: SExpr[] = []
    let i = idx + 1
    while (i < tokens.length && tokens[i] !== ')') {
      const [node, next] = parseTokens(tokens, i)
      list.push(node)
      i = next
    }
    if (tokens[i] !== ')') throw new SExprParseError('Unclosed list')
    return [list, i + 1]
  }
  if (tok === ')') throw new SExprParseError('Unexpected )')
  if (tok.startsWith('"')) return [tok.slice(1, -1), idx + 1]
  const num = Number(tok)
  if (!Number.isNaN(num) && tok !== '') return [num, idx + 1]
  return [tok, idx + 1]
}

export function isList(node: SExpr): node is SExpr[] {
  return Array.isArray(node)
}

export function listHead(node: SExpr): string | null {
  if (!isList(node) || node.length === 0) return null
  const h = node[0]
  return typeof h === 'string' ? h : null
}

export function findLists(root: SExpr, head: string): SExpr[] {
  const out: SExpr[] = []
  function walk(node: SExpr) {
    if (!isList(node)) return
    if (listHead(node) === head) out.push(node)
    for (let i = 1; i < node.length; i++) walk(node[i]!)
  }
  walk(root)
  return out
}

export function findStringField(list: SExpr[], field: string): string | null {
  if (!isList(list)) return null
  for (let i = 0; i < list.length - 1; i++) {
    if (list[i] === field) {
      const v = list[i + 1]
      if (typeof v === 'string') return v
      if (typeof v === 'number') return String(v)
    }
    if (isList(list[i]) && listHead(list[i]) === field) {
      const inner = list[i] as SExpr[]
      if (typeof inner[1] === 'string') return inner[1]
    }
  }
  return null
}

export function findSublist(list: SExpr[], field: string): SExpr[] | null {
  if (!isList(list)) return null
  for (const item of list) {
    if (isList(item) && listHead(item) === field) return item
  }
  for (let i = 0; i < list.length - 1; i++) {
    const next = list[i + 1]
    if (list[i] === field && isList(next)) return next
  }
  return null
}
