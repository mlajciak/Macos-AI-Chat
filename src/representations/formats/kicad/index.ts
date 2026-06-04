import type { RepresentationDocument } from '../../types.js'
import { KICAD_LIMITS } from '../../types.js'
import { representKicadNetlist } from './netlist.js'
import { representKicadPcb } from './pcb.js'
import { representKicadSch } from './sch.js'

export function representKicadPcbDoc(fileName: string, content: string): RepresentationDocument {
  const { sections, warnings } = representKicadPcb(fileName, content)
  return {
    version: 0,
    formatId: 'kicad-pcb',
    fileName,
    sections,
    warnings,
    limits: [...KICAD_LIMITS],
  }
}

export function representKicadSchDoc(fileName: string, content: string): RepresentationDocument {
  const { sections, warnings } = representKicadSch(fileName, content)
  return {
    version: 0,
    formatId: 'kicad-sch',
    fileName,
    sections,
    warnings,
    limits: [...KICAD_LIMITS],
  }
}

export function representKicadNetlistDoc(fileName: string, content: string): RepresentationDocument {
  const { sections, warnings } = representKicadNetlist(fileName, content)
  return {
    version: 0,
    formatId: 'kicad-netlist',
    fileName,
    sections,
    warnings,
    limits: [...KICAD_LIMITS],
  }
}
