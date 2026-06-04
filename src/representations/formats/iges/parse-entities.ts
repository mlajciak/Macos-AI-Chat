export type IgesEntity = {
  sequence: number
  type: number
  params: string
  form: number
}

export type IgesParseResult = {
  start: string[]
  global: string[]
  directory: IgesEntity[]
  parameter: string[]
  warnings: string[]
}

function parseDirectoryLine(line: string): IgesEntity | null {
  if (line.length < 24) return null
  const seq = Number.parseInt(line.slice(0, 8).trim(), 10)
  const form = Number.parseInt(line.slice(24, 32).trim(), 10) || 0
  const type = Number.parseInt(line.slice(32, 40).trim(), 10)
  if (Number.isNaN(seq) || Number.isNaN(type)) return null
  return { sequence: seq, type, form, params: line.slice(40).trim() }
}

export function parseIgesFile(content: string): IgesParseResult {
  const warnings: string[] = []
  const start: string[] = []
  const global: string[] = []
  const directory: IgesEntity[] = []
  const parameter: string[] = []

  const lines = content.split(/\r?\n/)
  for (const raw of lines) {
    const line = raw.padEnd(80, ' ').slice(0, 80)
    if (line.length < 73) continue
    const section = line[72]
    const text = line.slice(0, 72).trimEnd()

    switch (section) {
      case 'S':
        start.push(text)
        break
      case 'G':
        global.push(text)
        break
      case 'D': {
        const ent = parseDirectoryLine(line.slice(0, 72))
        if (ent) directory.push(ent)
        else warnings.push(`Malformed directory line: ${line.slice(0, 40)}…`)
        break
      }
      case 'P':
        parameter.push(text)
        break
      default:
        break
    }
  }

  return { start, global, directory, parameter, warnings }
}

export function countByType(directory: IgesEntity[], types: number[]): number {
  const set = new Set(types)
  return directory.filter(d => set.has(d.type)).length
}
