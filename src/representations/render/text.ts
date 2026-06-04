import type { RepresentationDocument } from '../types.js'

function formatValue(v: string | number | boolean | string[]): string {
  if (Array.isArray(v)) return v.join(', ')
  if (typeof v === 'boolean') return v ? 'yes' : 'no'
  return String(v)
}

export function renderText(doc: RepresentationDocument): string {
  const lines: string[] = [
    `# Representation: ${doc.fileName} (${doc.formatId})`,
    '',
  ]

  for (const section of doc.sections) {
    lines.push(`## ${section.title}`)
    if (section.items.length === 0) {
      lines.push('(none)')
    } else {
      for (const item of section.items) {
        const parts = Object.entries(item).map(([k, v]) => `${k}: ${formatValue(v)}`)
        lines.push(`- ${parts.join('; ')}`)
      }
    }
    lines.push('')
  }

  lines.push('## Limits')
  if (doc.limits.length === 0) {
    lines.push('(none)')
  } else {
    for (const limit of doc.limits) lines.push(`- ${limit}`)
  }
  lines.push('')

  lines.push('## Warnings')
  if (doc.warnings.length === 0) {
    lines.push('(none)')
  } else {
    for (const w of doc.warnings) lines.push(`- ${w}`)
  }

  return lines.join('\n').trimEnd() + '\n'
}
