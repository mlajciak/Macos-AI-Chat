import type { RepresentationDocument } from '../../types.js'
import { INTERCHANGE_LIMITS } from '../../types.js'
import { assemblyToItems, extractAssembly } from './assembly.js'
import { parseStepEntities } from './parse-entities.js'
import { extractProducts } from './products.js'
import { countSolids, solidsToItems } from './solids.js'

function parseHeaderFields(header: string): Array<Record<string, string>> {
  const items: Array<Record<string, string>> = []

  const desc = header.match(/FILE_DESCRIPTION\s*\(\s*\(\s*'([^']*)'/i)
  if (desc) items.push({ description: desc[1]! })

  const name = header.match(
    /FILE_NAME\s*\(\s*'([^']*)'\s*,\s*'([^']*)'\s*,\s*\(\s*'([^']*)'/i,
  )
  if (name) {
    items.push({ name: name[1]! })
    items.push({ created: name[2]! })
    items.push({ author: name[3]! })
  }

  const schema = header.match(/FILE_SCHEMA\s*\(\s*\(\s*'([^']*)'/i)
  if (schema) items.push({ schema: schema[1]! })

  const preprocessor = header.match(/,\s*'([^']*)'\s*,\s*'([^']*)'\s*,\s*'Unknown'\s*\)/i)
  if (preprocessor) {
    items.push({ preprocessor: preprocessor[1]! })
    items.push({ originating_system: preprocessor[2]! })
  }

  return items
}

export function representStep(fileName: string, content: string): RepresentationDocument {
  const { header, entities, warnings: parseWarnings } = parseStepEntities(content)
  const warnings = [...parseWarnings]

  const products = extractProducts(entities)
  const productNames = new Map(products.map(p => [p.entityId, p.name]))
  const assembly = extractAssembly(entities, productNames)
  const solids = countSolids(entities)

  if (entities.size === 0) {
    warnings.push('No STEP entities parsed from DATA section')
  }

  const sections = [
    {
      id: 'file',
      title: 'File',
      items: parseHeaderFields(header),
    },
    {
      id: 'products',
      title: 'Products',
      items: products.map(p => ({
        name: p.name,
        description: p.description || '(empty)',
        role: p.role,
        entity: `#${p.entityId}`,
      })),
    },
    {
      id: 'assembly',
      title: 'Assembly',
      items: assemblyToItems(assembly),
    },
    {
      id: 'solids',
      title: 'Solids',
      items: solidsToItems(solids),
    },
  ]

  return {
    version: 0,
    formatId: 'step',
    fileName,
    sections,
    warnings,
    limits: [...INTERCHANGE_LIMITS],
  }
}

export { parseStepEntities }
