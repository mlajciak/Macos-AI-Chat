import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { describeFile, detectFormat } from '../index.js'

const fixtures = join(dirname(fileURLToPath(import.meta.url)), 'fixtures')

describe('KiCad representer', () => {
  it('describes PCB with footprint and net', () => {
    const content = readFileSync(join(fixtures, 'minimal.kicad_pcb'), 'utf8')
    const { document, text } = describeFile({ fileName: 'board.kicad_pcb', content })

    expect(document.formatId).toBe('kicad-pcb')
    const fps = document.sections.find(s => s.id === 'footprints')
    expect(fps?.items.some(i => i.reference === 'R1')).toBe(true)

    const nets = document.sections.find(s => s.id === 'nets')
    expect(nets?.items.some(i => i.name === 'GND')).toBe(true)
    expect(text).toContain('R1')
  })

  it('describes schematic symbol', () => {
    const content = readFileSync(join(fixtures, 'minimal.kicad_sch'), 'utf8')
    const { document } = describeFile({ fileName: 'main.kicad_sch', content })

    const comps = document.sections.find(s => s.id === 'components')
    expect(comps?.items.some(i => i.reference === 'R1' && i.value === '10k')).toBe(true)
  })

  it('describes netlist', () => {
    const content = readFileSync(join(fixtures, 'minimal.net'), 'utf8')
    const { document } = describeFile({ fileName: 'design.net', content })

    expect(document.formatId).toBe('kicad-netlist')
    const nets = document.sections.find(s => s.id === 'nets')
    expect(nets?.items.some(i => i.name === 'GND')).toBe(true)
  })

  it('detects formats by extension and sniff', () => {
    expect(detectFormat('a.stp', '')).toBe('step')
    expect(detectFormat('b.kicad_pcb', '(kicad_pcb (version 1))')).toBe('kicad-pcb')
    expect(detectFormat('unknown.bin', 'binary')).toBeNull()
  })
})
