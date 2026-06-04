#!/usr/bin/env node
/**
 * Refresh agent runtime from a local xyzt monorepo checkout.
 * Usage: node scripts/sync-from-monorepo.mjs [path-to-xyzt]
 */
import { cpSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execSync } from 'node:child_process'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const mono = process.argv[2] ?? join(root, '..', 'xyzt')

if (!existsSync(join(mono, 'xyzt-agent', 'src'))) {
  console.error(`Monorepo not found at ${mono} (expected xyzt-agent/src)`)
  process.exit(1)
}

const pairs = [
  [join(mono, 'xyzt-agent', 'src'), join(root, 'src')],
  [join(mono, 'xyzt-agent', 'bin'), join(root, 'bin')],
  [join(mono, 'xyzt-agent', 'scripts', 'generate-desktop-agent-contract.ts'), join(root, 'scripts', 'generate-desktop-agent-contract.ts')],
  [join(mono, 'packages', 'xyzt-agent-tools'), join(root, 'packages', 'xyzt-agent-tools')],
]

for (const [from, to] of pairs) {
  cpSync(from, to, { recursive: true, filter: (src) => !src.includes('node_modules') && !src.includes('/dist/') })
  console.log(`Synced ${from} → ${to}`)
}

console.log('Re-applying standalone paths (lib/paths.ts, RUNTIME_AGENT_TOOL_NAMES) may be required after sync.')
console.log('Run: pnpm generate:contract && pnpm agent:gate')

try {
  execSync('pnpm generate:contract', { cwd: root, stdio: 'inherit' })
} catch {
  console.warn('generate:contract skipped (run manually)')
}
