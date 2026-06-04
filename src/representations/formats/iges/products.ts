import type { IgesEntity } from './parse-entities.js'

export type IgesProduct = {
  sequence: number
  type: number
  label: string
  kind: string
}

const TYPE_LABELS: Record<number, string> = {
  402: 'group',
  408: 'subfigure',
  124: 'transformation',
  186: 'manifold_solid_brep',
  308: 'subfigure_definition',
  314: 'color',
}

export function extractIgesProducts(directory: IgesEntity[]): IgesProduct[] {
  const products: IgesProduct[] = []

  for (const d of directory) {
    const kind = TYPE_LABELS[d.type]
    if (!kind && d.type < 100) continue
    if (d.type === 402 || d.type === 408 || d.type === 124 || d.type === 186) {
      products.push({
        sequence: d.sequence,
        type: d.type,
        label: `Entity_${d.sequence}`,
        kind: kind ?? `type_${d.type}`,
      })
    }
  }

  return products
}

export function extractGroupHierarchy(directory: IgesEntity[]): Array<Record<string, string>> {
  const groups = directory.filter(d => d.type === 402)
  if (groups.length === 0) {
    return [{ note: 'no type-402 group entities found' }]
  }

  return groups.map(g => ({
    sequence: String(g.sequence),
    type: '402',
    kind: 'group',
  }))
}
