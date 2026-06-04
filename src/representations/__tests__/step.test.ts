import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { describeFile } from '../index.js'

const fixtures = join(dirname(fileURLToPath(import.meta.url)), 'fixtures')

describe('STEP representer', () => {
  it('describes single-part cube', () => {
    const content = readFileSync(join(fixtures, 'cube.stp'), 'utf8')
    const { document, text } = describeFile({ fileName: 'cube.stp', content })

    expect(document.formatId).toBe('step')
    const products = document.sections.find(s => s.id === 'products')
    expect(products?.items.some(i => i.name === 'Cube')).toBe(true)

    const solids = document.sections.find(s => s.id === 'solids')
    expect(solids?.items.some(i => i.entity === 'manifold_solids' && Number(i.count) >= 1)).toBe(
      true,
    )

    expect(text).toContain('## Limits')
    expect(text).toContain('Parametric sketches')
  })

  it('parses assembly occurrence', () => {
    const content = readFileSync(join(fixtures, 'assembly-minimal.stp'), 'utf8')
    const { document } = describeFile({ fileName: 'assembly-minimal.stp', content })

    const assembly = document.sections.find(s => s.id === 'assembly')
    const hasOccurrence =
      assembly?.items.some(i => 'occurrence' in i || 'label' in i) ?? false
    expect(hasOccurrence).toBe(true)
  })
})
