import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '../..')

export const REPO_ROOT = repoRoot
export const GOLDENS_DIR = join(repoRoot, 'packages/xyzt-agent-tools/goldens')
export const XYZT_CORE_ROOT = join(repoRoot, 'vendor/xyzt-core')
