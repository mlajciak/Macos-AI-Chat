/** Text representation of CAD/EDA files for agent consumption. */

export type FormatId =
  | 'step'
  | 'iges'
  | 'kicad-pcb'
  | 'kicad-sch'
  | 'kicad-netlist'

export type RepresentationSection = {
  id: string
  title: string
  items: Array<Record<string, string | number | boolean | string[]>>
}

export type RepresentationDocument = {
  version: 0
  formatId: FormatId
  fileName: string
  sections: RepresentationSection[]
  warnings: string[]
  limits: string[]
}

export type DescribeFileResult = {
  document: RepresentationDocument
  text: string
}

/** Interchange formats cannot carry native parametric history (future: describeRun). */
export const INTERCHANGE_LIMITS = [
  'Parametric sketches, joints, and feature timelines are not available in STEP/IGES interchange.',
] as const

export const KICAD_LIMITS = [
  'Logical schematic connectivity may differ from PCB copper; verify nets on the board file.',
] as const
