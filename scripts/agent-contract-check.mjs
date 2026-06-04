#!/usr/bin/env node
/**
 * Standalone agent contract check: RUNTIME_AGENT_TOOL_NAMES ↔ parity.json ↔ registry.ts
 */
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const errors = []

function err(msg) {
  errors.push(msg)
}

const toolsIndexPath = join(root, 'packages/xyzt-agent-tools/src/index.ts')
const parityPath = join(root, 'packages/xyzt-agent-tools/parity.json')
const registryPath = join(root, 'src/tools/registry.ts')

const parity = JSON.parse(readFileSync(parityPath, 'utf8'))
const ssotNames = parity.tools.filter(t => t.desktop).map(t => t.name).sort()

const indexSrc = readFileSync(toolsIndexPath, 'utf8')
for (const name of ssotNames) {
  if (!indexSrc.includes(`'${name}'`)) {
    err(`index.ts RUNTIME set missing '${name}'`)
  }
}

const registrySrc = readFileSync(registryPath, 'utf8')
for (const name of ssotNames) {
  if (!registrySrc.includes(`case '${name}':`)) {
    err(`registry.ts missing case '${name}'`)
  }
}

if (errors.length) {
  console.error('agent-contract-check failed:\n' + errors.map(e => `  - ${e}`).join('\n'))
  process.exit(1)
}
console.log(`agent-contract-check ok (${ssotNames.length} runtime tools)`)
