import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { DESKTOP_AGENT_TOOL_NAMES, EXPORT_TOOL_NAMES, RUNTIME_AGENT_TOOL_NAMES } from './index.js'
import { readFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const goldensDir = join(root, 'goldens')

describe('xyzt-agent-tools contract', () => {
  it('lists minimal folder-agent tools', () => {
    assert.ok(DESKTOP_AGENT_TOOL_NAMES.includes('read_file'))
    assert.ok(DESKTOP_AGENT_TOOL_NAMES.includes('patch_file'))
    assert.ok(DESKTOP_AGENT_TOOL_NAMES.includes('create_cad'))
    assert.equal(DESKTOP_AGENT_TOOL_NAMES.length, 7)
    assert.ok(EXPORT_TOOL_NAMES.length > 0)
  })

  it('parity.json matches RUNTIME_AGENT_TOOL_NAMES', () => {
    const parity = JSON.parse(readFileSync(join(root, 'parity.json'), 'utf8')) as {
      tools: Array<{ name: string; desktop: boolean }>
    }
    const parityNames = parity.tools.filter(t => t.desktop).map(t => t.name).sort()
    const ssot = [...RUNTIME_AGENT_TOOL_NAMES].sort()
    assert.deepEqual(parityNames, ssot)
  })

  it('goldens directory includes workflow transcript fixtures', () => {
    const transcriptFiles = readdirSync(goldensDir).filter(f => f.includes('transcript'))
    assert.ok(transcriptFiles.length >= 5, `expected >= 5 transcript goldens, got ${transcriptFiles.length}`)
    for (const file of transcriptFiles) {
      const raw = JSON.parse(readFileSync(join(goldensDir, file), 'utf8')) as {
        steps?: unknown[]
        tool?: string
        expectKeys?: string[]
      }
      if (Array.isArray(raw.steps)) {
        assert.ok(raw.steps.length > 0, `${file} missing steps[]`)
      } else if (typeof raw.tool === 'string') {
        assert.ok(Array.isArray(raw.expectKeys) && raw.expectKeys.length > 0, `${file} missing expectKeys`)
      } else {
        assert.fail(`${file} is not a workflow or executor transcript golden`)
      }
    }
  })

  it('goldens directory has at least 10 executor fixtures', () => {
    const files = readdirSync(goldensDir).filter(f => f.endsWith('.json') && !f.includes('transcript'))
    assert.ok(files.length >= 10, `expected >= 10 goldens, got ${files.length}`)
    for (const file of files) {
      const raw = JSON.parse(readFileSync(join(goldensDir, file), 'utf8')) as {
        tool?: string
        input?: Record<string, unknown>
        expectKeys?: string[]
      }
      assert.ok(typeof raw.tool === 'string', `${file} missing tool`)
      assert.ok(raw.input != null, `${file} missing input`)
      assert.ok(Array.isArray(raw.expectKeys) && raw.expectKeys.length > 0, `${file} missing expectKeys`)
    }
  })
})
