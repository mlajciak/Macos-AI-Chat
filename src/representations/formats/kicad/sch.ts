import type { RepresentationSection } from '../../types.js'
import { findLists, isList, listHead, parseSExpr, type SExpr } from './sexpr.js'

function propertyValue(sym: SExpr[], key: string): string | null {
  for (const item of sym) {
    if (!isList(item) || listHead(item) !== 'property') continue
    const prop = item as SExpr[]
    if (prop[1] === key && typeof prop[2] === 'string') return prop[2]
  }
  return null
}

function symbolRef(sym: SExpr[]): string | null {
  return propertyValue(sym, 'Reference')
}

function symbolValue(sym: SExpr[]): string | null {
  return propertyValue(sym, 'Value')
}

export function representKicadSch(_fileName: string, content: string): {
  sections: RepresentationSection[]
  warnings: string[]
} {
  const warnings: string[] = []
  let root: SExpr
  try {
    root = parseSExpr(content)
  } catch (e) {
    warnings.push(e instanceof Error ? e.message : String(e))
    return { sections: [], warnings }
  }

  if (!isList(root) || listHead(root) !== 'kicad_sch') {
    warnings.push('Root is not kicad_sch')
  }

  const symbols = findLists(root, 'symbol')
  const compItems: Array<Record<string, string>> = []
  for (const sym of symbols) {
    const sl = sym as SExpr[]
    const ref = symbolRef(sl) ?? '?'
    const value = symbolValue(sl) ?? ''
    compItems.push({ reference: ref, value })
  }

  const labels = findLists(root, 'label').length + findLists(root, 'global_label').length
  const wires = findLists(root, 'wire').length
  const sheets = findLists(root, 'sheet')

  const sheetItems = sheets.map(s => {
    const sl = s as SExpr[]
    let name = '?'
    for (const it of sl) {
      if (isList(it) && listHead(it) === 'property' && it[1] === 'Sheet name') {
        name = typeof it[2] === 'string' ? it[2] : name
      }
    }
    return { sheet: name }
  })

  return {
    warnings,
    sections: [
      { id: 'components', title: 'Components', items: compItems },
      { id: 'sheets', title: 'Sheets', items: sheetItems.length ? sheetItems : [{ note: '(none)' }] },
      {
        id: 'stats',
        title: 'Stats',
        items: [
          { symbols: String(symbols.length) },
          { labels: String(labels) },
          { wires: String(wires) },
        ],
      },
    ],
  }
}
