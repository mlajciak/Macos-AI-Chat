import { readFile, readdir, stat, writeFile, mkdir } from 'node:fs/promises'
import { dirname, join, resolve, sep } from 'node:path'
import type { LocalToolResult, ToolContext } from '../types.js'
import { createToolContext, type DesktopToolContextOptions } from './create-tool-context.js'

const SKIP_DIRS = new Set([
  'node_modules',
  '.git',
  'dist',
  'release',
  'out',
  '.cursor',
  '.xyzt',
  '.pnpm',
  '.turbo',
  'coverage',
  'build',
  '.next',
  'target',
  '__pycache__',
  '.venv',
  'vendor',
  '.cache',
  'ios',
  'android',
  '.nx',
  'DerivedData',
  '.gradle',
  '.idea',
  '.vscode',
  '.vite',
  '.parcel-cache',
  'storybook-static',
])

const TEXT_EXTENSIONS = new Set([
  '.xyzt',
  '.xyzt.cad',
  '.xyzt.eda',
  '.xyzt.draft',
  '.xyzt.simulation',
  '.xyzt.mesh',
  '.md',
  '.txt',
  '.json',
  '.csv',
  '.html',
  '.js',
  '.ts',
  '.tsx',
  '.jsx',
  '.mjs',
  '.cjs',
  '.py',
  '.step',
  '.stp',
  '.dxf',
  '.dwg',
  '.iges',
  '.igs',
  '.kicad_pcb',
  '.kicad_sym',
  '.kicad_mod',
  '.kicad_net',
  '.lbr',
  '.brd',
  '.sch',
  '.dsn',
  '.net',
])

const BINARY_EXTENSIONS = new Set(['.step', '.stp', '.dwg', '.iges', '.igs'])

const MAX_LISTED_PATHS = 8000
const MAX_FILE_BYTES = 8 * 1024 * 1024

function isTextProjectFile(name: string): boolean {
  const lower = name.toLowerCase()
  for (const ext of TEXT_EXTENSIONS) {
    if (lower.endsWith(ext)) return true
  }
  return false
}

function fileExtension(name: string): string {
  const lower = name.toLowerCase()
  for (const ext of [...TEXT_EXTENSIONS].sort((a, b) => b.length - a.length)) {
    if (lower.endsWith(ext)) return ext
  }
  const dot = lower.lastIndexOf('.')
  return dot >= 0 ? lower.slice(dot) : ''
}

async function listProjectPaths(root: string): Promise<string[]> {
  const filePaths: string[] = []
  let truncated = false

  async function walk(dir: string, rel: string): Promise<void> {
    if (truncated) return
    let entries
    try {
      entries = await readdir(dir, { withFileTypes: true })
    } catch {
      return
    }
    for (const ent of entries) {
      if (ent.name === '.DS_Store') continue
      const relPath = rel ? `${rel}/${ent.name}` : ent.name
      if (ent.isDirectory()) {
        if (SKIP_DIRS.has(ent.name)) continue
        await walk(join(dir, ent.name), relPath)
      } else if (ent.isFile() && isTextProjectFile(ent.name)) {
        filePaths.push(relPath.replace(/\\/g, '/'))
        if (filePaths.length >= MAX_LISTED_PATHS) {
          truncated = true
          return
        }
      }
    }
  }

  await walk(root, '')
  return filePaths
}

export interface CliFolderHostOptions {
  rootPath: string
  engineRun?: (payload: Record<string, unknown>) => Promise<Record<string, unknown>>
  runScriptInProcess?: import('../types.js').ToolContext['runScriptInProcess']
}

export async function createCliFolderHost(opts: CliFolderHostOptions): Promise<ToolContext> {
  const root = resolve(opts.rootPath)
  const filePaths = await listProjectPaths(root)
  const fileCache = new Map<string, string>()

  async function loadFile(path: string): Promise<string | undefined> {
    if (fileCache.has(path)) return fileCache.get(path)
    const rel = path.replace(/\\/g, '/')
    const full = resolve(root, rel)
    const rootPrefix = root.endsWith(sep) ? root : root + sep
    if (!full.startsWith(rootPrefix) && full !== root) return undefined
    try {
      const info = await stat(full)
      if (!info.isFile() || info.size > MAX_FILE_BYTES) return undefined
      const ext = fileExtension(rel)
      if (BINARY_EXTENSIONS.has(ext)) {
        const buf = await readFile(full)
        const content = `base64:${buf.toString('base64')}`
        fileCache.set(path, content)
        return content
      }
      const content = await readFile(full, 'utf8')
      fileCache.set(path, content)
      return content
    } catch {
      return undefined
    }
  }

  const engineRun =
    opts.engineRun ??
    (async () => ({
      type: 'error',
      error: 'CLI engine not configured. Set XYZT_ENGINE_CMD or use desktop for full engine.',
    }))

  async function writeBinaryFile(
    path: string,
    data: Uint8Array,
    _mode: 'direct' | 'sandbox',
  ): Promise<LocalToolResult> {
    const full = join(root, path)
    await mkdir(dirname(full), { recursive: true })
    await writeFile(full, data)
    return {
      success: true,
      result: JSON.stringify({ ok: true, path, bytes: data.length }),
    }
  }

  const hostOpts: DesktopToolContextOptions = {
    listFilePaths: () => filePaths,
    getFileContent: p => fileCache.get(p),
    ensureFileContent: async (p: string) => {
      const content = await loadFile(p)
      if (content !== undefined) fileCache.set(p, content)
      return content
    },
    sandboxEdits: false,
    rootPath: root,
    engineRun,
    writeBinaryFile,
    runScriptInProcess: opts.runScriptInProcess,
  }

  return createToolContext(hostOpts)
}
