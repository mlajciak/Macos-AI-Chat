import type { StepEntity } from './parse-entities.js'
import { firstQuotedString } from './parse-entities.js'

export type StepProduct = {
  entityId: number
  name: string
  description: string
  role: string
}

export function extractProducts(entities: Map<number, StepEntity>): StepProduct[] {
  const products: StepProduct[] = []

  for (const e of entities.values()) {
    if (e.type !== 'PRODUCT') continue
    const parts = splitTopLevelStrings(e.params)
    const name = parts[0] ?? firstQuotedString(e.params) ?? `Product_${e.id}`
    const description = parts[1] ?? ''
    products.push({
      entityId: e.id,
      name,
      description,
      role: 'part',
    })
  }

  return products
}

function splitTopLevelStrings(params: string): string[] {
  const out: string[] = []
  let i = 0
  while (i < params.length) {
    if (params[i] === "'") {
      let j = i + 1
      while (j < params.length && params[j] !== "'") j++
      out.push(params.slice(i + 1, j))
      i = j + 1
      continue
    }
    i++
  }
  return out
}

export function extractProductDefinitions(
  entities: Map<number, StepEntity>,
): Map<number, { formationRef: number | null; productRef: number | null }> {
  const map = new Map<number, { formationRef: number | null; productRef: number | null }>()

  for (const e of entities.values()) {
    if (e.type !== 'PRODUCT_DEFINITION') continue
    const refs = [...e.params.matchAll(/#(\d+)/g)].map(m => Number.parseInt(m[1]!, 10))
    map.set(e.id, {
      formationRef: refs[0] ?? null,
      productRef: refs[1] ?? null,
    })
  }

  return map
}

export function formationToProduct(
  entities: Map<number, StepEntity>,
): Map<number, number> {
  const map = new Map<number, number>()
  for (const e of entities.values()) {
    if (e.type !== 'PRODUCT_DEFINITION_FORMATION') continue
    const refs = [...e.params.matchAll(/#(\d+)/g)].map(m => Number.parseInt(m[1]!, 10))
    if (refs.length >= 2) map.set(e.id, refs[1]!)
  }
  return map
}
