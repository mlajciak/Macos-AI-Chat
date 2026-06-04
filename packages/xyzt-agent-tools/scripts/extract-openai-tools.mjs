#!/usr/bin/env node
/**
 * Extract OpenAI tool schemas from infra ai-stream.ts into generated/openai-tools.json (TC-2 SSOT).
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { pathToFileURL } from 'node:url'

const pkgRoot = join(dirname(new URL(import.meta.url).pathname), '..')
const repoRoot = join(pkgRoot, '../..')
const aiStreamPath = join(repoRoot, 'infra/src/ai-stream.ts')
const outDir = join(pkgRoot, 'generated')
const outPath = join(outDir, 'openai-tools.json')

const mod = await import(pathToFileURL(aiStreamPath).href)
const tools = mod.TOOLS
if (!Array.isArray(tools)) {
  console.error('ai-stream.ts must export TOOLS array')
  process.exit(1)
}
mkdirSync(outDir, { recursive: true })
writeFileSync(
  outPath,
  JSON.stringify({ version: 0, generatedAt: new Date().toISOString(), tools }, null, 2) + '\n',
)
console.log(`Wrote ${tools.length} tool schemas to generated/openai-tools.json`)
