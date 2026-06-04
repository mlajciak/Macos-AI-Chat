import type { RepresentationSection } from '../../types.js'
import { findLists, findStringField, findSublist, isList, listHead, parseSExpr, type SExpr } from './sexpr.js'

function layerFromNode(node: SExpr): string | null {
  if (!isList(node)) return null
  if (listHead(node) === 'layer' && typeof node[1] === 'string') return node[1]
  return null
}

function atFromFootprint(fp: SExpr[]): string {
  const at = findSublist(fp, 'at')
  if (!at || at.length < 3) return ''
  const x = at[1]
  const y = at[2]
  return `${x}, ${y}`
}

function fpTextReference(fp: SExpr[]): string | null {
  for (const item of fp) {
    if (!isList(item) || listHead(item) !== 'fp_text') continue
    if (item[1] === 'reference' && typeof item[2] === 'string') return item[2]
    if (isList(item[1]) && item[1]![0] === 'reference') {
      const refList = item[1] as SExpr[]
      if (typeof refList[1] === 'string') return refList[1]
    }
  }
  return null
}

function edgeCutsPoints(root: SExpr): Array<{ x: number; y: number }> {
  const points: Array<{ x: number; y: number }> = []
  for (const seg of findLists(root, 'segment')) {
    const layer = findStringField(seg as SExpr[], 'layer') ?? layerFromNode(findSublist(seg as SExpr[], 'layer') ?? [])
    const layerStr =
      layer ??
      (() => {
        for (const it of seg as SExpr[]) {
          if (isList(it) && listHead(it) === 'layer' && typeof it[1] === 'string') return it[1]
        }
        return null
      })()
    if (layerStr !== 'Edge.Cuts') continue
    const start = findSublist(seg as SExpr[], 'start')
    const end = findSublist(seg as SExpr[], 'end')
    if (start && typeof start[1] === 'number' && typeof start[2] === 'number') {
      points.push({ x: start[1], y: start[2] })
    }
    if (end && typeof end[1] === 'number' && typeof end[2] === 'number') {
      points.push({ x: end[1], y: end[2] })
    }
  }
  return points
}

function bboxFromPoints(points: Array<{ x: number; y: number }>): string {
  if (points.length === 0) return '(unknown)'
  let minX = Infinity
  let minY = Infinity
  let maxX = -Infinity
  let maxY = -Infinity
  for (const p of points) {
    minX = Math.min(minX, p.x)
    minY = Math.min(minY, p.y)
    maxX = Math.max(maxX, p.x)
    maxY = Math.max(maxY, p.y)
  }
  return `${minX.toFixed(2)}×${minY.toFixed(2)} … ${maxX.toFixed(2)}×${maxY.toFixed(2)} mm`
}

export function representKicadPcb(_fileName: string, content: string): {
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

  if (!isList(root) || listHead(root) !== 'kicad_pcb') {
    warnings.push('Root is not kicad_pcb')
  }

  const versionNode = findSublist(root as SExpr[], 'version')
  const version =
    versionNode && (typeof versionNode[1] === 'number' || typeof versionNode[1] === 'string')
      ? String(versionNode[1])
      : 'unknown'
  const generatorNode = findSublist(root as SExpr[], 'generator')
  const generator =
    generatorNode && typeof generatorNode[1] === 'string' ? generatorNode[1] : '(unknown)'

  const edgePoints = edgeCutsPoints(root)
  const layers = new Set<string>()
  for (const seg of findLists(root, 'segment')) {
    for (const it of seg as SExpr[]) {
      if (isList(it) && listHead(it) === 'layer' && typeof it[1] === 'string') layers.add(it[1])
    }
  }
  for (const fp of findLists(root, 'footprint')) {
    const l = findStringField(fp as SExpr[], 'layer')
    if (l) layers.add(l)
    for (const it of fp as SExpr[]) {
      if (isList(it) && listHead(it) === 'layer' && typeof it[1] === 'string') layers.add(it[1])
    }
  }

  const footprints = findLists(root, 'footprint')
  const fpItems: Array<Record<string, string>> = []
  for (const fp of footprints) {
    const fpList = fp as SExpr[]
    const ref = fpTextReference(fpList) ?? '?'
    const name = typeof fpList[1] === 'string' ? fpList[1] : ''
    fpItems.push({
      reference: ref,
      footprint: name,
      at: atFromFootprint(fpList),
    })
  }

  const netDecls = findLists(root, 'net')
  const netItems: Array<Record<string, string>> = []
  for (const n of netDecls) {
    const nl = n as SExpr[]
    if (typeof nl[1] === 'number' && typeof nl[2] === 'string') {
      netItems.push({ id: String(nl[1]), name: nl[2] })
    }
  }

  for (const fp of footprints) {
    for (const pad of findLists(fp, 'pad')) {
      const pl = pad as SExpr[]
      const netId = (() => {
        for (const it of pl) {
          if (isList(it) && listHead(it) === 'net' && typeof it[1] === 'number') return it[1]
        }
        return null
      })()
      if (netId !== null) {
        const ref = fpTextReference(fp as SExpr[]) ?? '?'
        const padName = typeof pl[1] === 'string' ? pl[1] : '?'
        netItems.push({ pad: `${ref}.${padName}`, net_id: String(netId) })
      }
    }
  }

  const segments = findLists(root, 'segment').length
  const vias = findLists(root, 'via').length

  return {
    warnings,
    sections: [
      {
        id: 'board',
        title: 'Board',
        items: [
          { version: version ?? 'unknown' },
          { generator: generator || '(unknown)' },
          { edge_cuts_bbox: bboxFromPoints(edgePoints) },
        ],
      },
      {
        id: 'layers',
        title: 'Layers',
        items: [...layers].sort().map(l => ({ name: l })),
      },
      { id: 'footprints', title: 'Footprints', items: fpItems },
      { id: 'nets', title: 'Nets', items: netItems },
      {
        id: 'stats',
        title: 'Stats',
        items: [
          { footprints: String(footprints.length) },
          { segments: String(segments) },
          { vias: String(vias) },
        ],
      },
    ],
  }
}
