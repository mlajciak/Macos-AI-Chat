import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { describeFile } from '../index.js'

const fixtures = join(dirname(fileURLToPath(import.meta.url)), 'fixtures')

describe('IGES representer', () => {
  it('parses directory entities', () => {
    const content = readFileSync(join(fixtures, 'minimal.igs'), 'utf8')
    const { document, text } = describeFile({ fileName: 'part.igs', content })

    expect(document.formatId).toBe('iges')
    const file = document.sections.find(s => s.id === 'file')
    expect(file?.items.some(i => 'directory_entries' in i)).toBe(true)
    expect(text).toContain('## Limits')
  })
})
