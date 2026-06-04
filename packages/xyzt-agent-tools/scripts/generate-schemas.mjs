#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(fileURLToPath(new URL('..', import.meta.url)))
const parity = JSON.parse(readFileSync(join(root, 'parity.json'), 'utf8'))
const outDir = join(root, 'generated')
mkdirSync(outDir, { recursive: true })
const out = {
  version: 0,
  generatedAt: new Date().toISOString(),
  tools: parity.tools.map(t => ({ name: t.name, desktop: t.desktop, ai_stream_schema: t.ai_stream_schema })),
}
writeFileSync(join(outDir, 'tool-names.json'), JSON.stringify(out, null, 2) + '\n')
console.log(`Wrote ${out.tools.length} tools to generated/tool-names.json`)
