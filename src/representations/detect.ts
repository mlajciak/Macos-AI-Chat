import type { FormatId } from './types.js'

const EXT_MAP: Record<string, FormatId> = {
  '.step': 'step',
  '.stp': 'step',
  '.iges': 'iges',
  '.igs': 'iges',
  '.kicad_pcb': 'kicad-pcb',
  '.kicad_sch': 'kicad-sch',
  '.net': 'kicad-netlist',
  '.kicad_net': 'kicad-netlist',
}

function extensionOf(fileName: string): string {
  const base = fileName.split(/[/\\]/).pop() ?? fileName
  const dot = base.indexOf('.')
  if (dot < 0) return ''
  return base.slice(dot).toLowerCase()
}

export function detectFormat(fileName: string, content: string): FormatId | null {
  const ext = extensionOf(fileName)
  if (ext && EXT_MAP[ext]) return EXT_MAP[ext]

  const head = content.slice(0, 512).trimStart()
  if (head.startsWith('ISO-10303-21')) return 'step'
  if (/^\s*S\s*1/.test(head) || head.includes('START')) {
    if (head.includes('IGES') || /^\s*S\s*1/.test(head)) return 'iges'
  }
  if (head.includes('(kicad_pcb')) return 'kicad-pcb'
  if (head.includes('(kicad_sch')) return 'kicad-sch'
  if (head.includes('(export ') && head.includes('(components')) return 'kicad-netlist'
  if (head.includes('(components') && head.includes('(nets')) return 'kicad-netlist'
  if (head.includes('(net ') && head.includes('(node')) return 'kicad-netlist'

  return null
}
