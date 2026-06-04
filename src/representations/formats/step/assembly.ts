import type { StepEntity } from './parse-entities.js'
import { firstQuotedString } from './parse-entities.js'

export type AssemblyNode = {
  id: string
  label: string
  children: AssemblyNode[]
}

export type AssemblySummary = {
  tree: AssemblyNode[]
  occurrences: number
  flatRelations: Array<{ parent: string; child: string; name: string }>
}

export function extractAssembly(
  entities: Map<number, StepEntity>,
  productNames: Map<number, string>,
): AssemblySummary {
  const flatRelations: AssemblySummary['flatRelations'] = []
  const childrenByParent = new Map<string, AssemblyNode[]>()

  for (const e of entities.values()) {
    if (e.type !== 'NEXT_ASSEMBLY_USAGE_OCCURRENCE') continue
    const name = firstQuotedString(e.params) ?? `Occurrence_${e.id}`
    const refs = [...e.params.matchAll(/#(\d+)/g)].map(m => Number.parseInt(m[1]!, 10))
    const parentDef = refs[0]
    const childDef = refs[1]
    const parentLabel = parentDef ? `PD_${parentDef}` : 'root'
    const childLabel = childDef ? `PD_${childDef}` : `occ_${e.id}`
    flatRelations.push({ parent: parentLabel, child: childLabel, name })

    const childNode: AssemblyNode = {
      id: String(e.id),
      label: name,
      children: [],
    }
    const list = childrenByParent.get(parentLabel) ?? []
    list.push(childNode)
    childrenByParent.set(parentLabel, list)
  }

  if (flatRelations.length === 0) {
    const productList = [...productNames.entries()]
    if (productList.length <= 1) {
      return {
        tree: [],
        occurrences: 0,
        flatRelations: [],
      }
    }
    const root: AssemblyNode = {
      id: 'root',
      label: 'assembly',
      children: productList.map(([id, name]) => ({
        id: String(id),
        label: name,
        children: [],
      })),
    }
    return { tree: [root], occurrences: 0, flatRelations: [] }
  }

  const roots: AssemblyNode[] = []
  const seen = new Set<string>()
  for (const [parent, kids] of childrenByParent) {
    if (seen.has(parent)) continue
    seen.add(parent)
    roots.push({ id: parent, label: parent, children: kids })
  }

  return {
    tree: roots,
    occurrences: flatRelations.length,
    flatRelations,
  }
}

export function assemblyToItems(summary: AssemblySummary): Array<Record<string, string | string[]>> {
  if (summary.occurrences === 0 && summary.tree.length === 0) {
    return [{ note: 'single-part file; no NEXT_ASSEMBLY_USAGE_OCCURRENCE' }]
  }

  const items: Array<Record<string, string | string[]>> = []

  function walk(node: AssemblyNode, depth: number) {
    items.push({
      depth: String(depth),
      id: node.id,
      label: node.label,
    })
    for (const c of node.children) walk(c, depth + 1)
  }

  for (const root of summary.tree) walk(root, 0)

  for (const rel of summary.flatRelations) {
    items.push({
      parent: rel.parent,
      child: rel.child,
      occurrence: rel.name,
    })
  }

  return items
}
