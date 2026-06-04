import { detectFormat as detectFormatImpl } from './detect.js'
import { UnsupportedFormatError } from './errors.js'
import { representIges } from './formats/iges/index.js'
import {
  representKicadNetlistDoc,
  representKicadPcbDoc,
  representKicadSchDoc,
} from './formats/kicad/index.js'
import { representStep } from './formats/step/index.js'
import { renderText } from './render/text.js'
import type { DescribeFileResult, FormatId, RepresentationDocument } from './types.js'

export { UnsupportedFormatError } from './errors.js'
export { renderText } from './render/text.js'
export type {
  DescribeFileResult,
  FormatId,
  RepresentationDocument,
  RepresentationSection,
} from './types.js'

export function detectFormat(fileName: string, content: string): FormatId | null {
  return detectFormatImpl(fileName, content)
}

function contentToString(content: string | Uint8Array): string {
  if (typeof content === 'string') return content
  return new TextDecoder('utf-8', { fatal: false }).decode(content)
}

function represent(formatId: FormatId, fileName: string, content: string): RepresentationDocument {
  switch (formatId) {
    case 'step':
      return representStep(fileName, content)
    case 'iges':
      return representIges(fileName, content)
    case 'kicad-pcb':
      return representKicadPcbDoc(fileName, content)
    case 'kicad-sch':
      return representKicadSchDoc(fileName, content)
    case 'kicad-netlist':
      return representKicadNetlistDoc(fileName, content)
    default: {
      const _exhaustive: never = formatId
      throw new UnsupportedFormatError(fileName, String(_exhaustive))
    }
  }
}

export function describeFile(input: {
  fileName: string
  content: string | Uint8Array
}): DescribeFileResult {
  const content = contentToString(input.content)
  const formatId = detectFormatImpl(input.fileName, content)
  if (!formatId) {
    const ext = input.fileName.includes('.') ? input.fileName.split('.').pop()! : null
    throw new UnsupportedFormatError(input.fileName, ext)
  }
  const document = represent(formatId, input.fileName, content)
  const text = renderText(document)
  return { document, text }
}
