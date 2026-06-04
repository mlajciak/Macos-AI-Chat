import type { RepresentationDocument } from '../../types.js'
import { INTERCHANGE_LIMITS } from '../../types.js'
import { countByType, parseIgesFile } from './parse-entities.js'
import { extractGroupHierarchy, extractIgesProducts } from './products.js'

export function representIges(fileName: string, content: string): RepresentationDocument {
  const { start, global, directory, warnings: parseWarnings } = parseIgesFile(content)
  const warnings = [...parseWarnings]

  const products = extractIgesProducts(directory)
  const assembly = extractGroupHierarchy(directory)

  const solidCount = countByType(directory, [186, 184, 510])
  const groupCount = countByType(directory, [402, 408])

  if (directory.length === 0) {
    warnings.push('No IGES directory entities parsed')
  }

  const fileItems: Array<Record<string, string>> = []
  if (start[0]) fileItems.push({ start_record: start[0].slice(0, 60) })
  if (global[0]) fileItems.push({ global: global[0].slice(0, 60) })
  fileItems.push({ directory_entries: String(directory.length) })

  return {
    version: 0,
    formatId: 'iges',
    fileName,
    sections: [
      { id: 'file', title: 'File', items: fileItems },
      {
        id: 'products',
        title: 'Products',
        items: products.map(p => ({
          sequence: String(p.sequence),
          type: String(p.type),
          kind: p.kind,
          label: p.label,
        })),
      },
      { id: 'assembly', title: 'Assembly', items: assembly },
      {
        id: 'solids',
        title: 'Solids',
        items: [
          { entity: 'manifold_solid_brep_186', count: String(solidCount) },
          { entity: 'groups_subfigures', count: String(groupCount) },
        ],
      },
    ],
    warnings,
    limits: [...INTERCHANGE_LIMITS],
  }
}
