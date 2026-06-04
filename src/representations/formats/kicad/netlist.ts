import type { RepresentationSection } from '../../types.js'
import { findLists, findSublist, isList, listHead, parseSExpr, type SExpr } from './sexpr.js'

export function representKicadNetlist(_fileName: string, content: string): {
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

  const compItems: Array<Record<string, string>> = []
  const netItems: Array<Record<string, string | string[]>> = []

  if (isList(root)) {
    const comps = findLists(root, 'comp')
    for (const c of comps.length ? comps : findLists(root, 'component')) {
      const cl = c as SExpr[]
      let ref = ''
      let value = ''
      let footprint = ''
      const refList = findSublist(cl, 'ref')
      const valueList = findSublist(cl, 'value')
      const fpList = findSublist(cl, 'footprint')
      if (refList && typeof refList[1] === 'string') ref = refList[1]
      if (valueList && typeof valueList[1] === 'string') value = valueList[1]
      if (fpList && typeof fpList[1] === 'string') footprint = fpList[1]
      for (const field of cl) {
        if (!isList(field)) continue
        const h = listHead(field)
        if (!ref && h === 'ref' && typeof field[1] === 'string') ref = field[1]
        if (!value && h === 'value' && typeof field[1] === 'string') value = field[1]
        if (!footprint && h === 'footprint' && typeof field[1] === 'string') footprint = field[1]
      }
      if (ref) compItems.push({ ref, value, footprint })
    }

    for (const n of findLists(root, 'net')) {
      const nl = n as SExpr[]
      let name = ''
      const nameList = findLists(nl, 'name')[0] as SExpr[] | undefined
      if (nameList && typeof nameList[1] === 'string') name = nameList[1]
      else if (typeof nl[1] === 'string') name = nl[1]

      const nodes: string[] = []
      for (const node of findLists(nl, 'node')) {
        const nd = node as SExpr[]
        let r = ''
        let pin = ''
        for (const field of nd) {
          if (!isList(field)) continue
          const h = listHead(field)
          if (h === 'ref' && typeof field[1] === 'string') r = field[1]
          if (h === 'pin' && (typeof field[1] === 'string' || typeof field[1] === 'number')) {
            pin = String(field[1])
          }
        }
        if (!r && typeof nd[1] === 'string') r = nd[1]
        if (!pin && (typeof nd[2] === 'string' || typeof nd[2] === 'number')) pin = String(nd[2])
        if (r) nodes.push(`${r}.${pin}`)
      }
      if (name) netItems.push({ name, nodes })
    }
  }

  return {
    warnings,
    sections: [
      { id: 'components', title: 'Components', items: compItems },
      { id: 'nets', title: 'Nets', items: netItems },
    ],
  }
}
