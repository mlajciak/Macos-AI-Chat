import { describe, expect, it } from 'vitest'
import {
  examplesPathBlockedResult,
  filterExamplesFromFileList,
  isExamplesPath,
} from './block-examples-path.js'

describe('isExamplesPath', () => {
  it('blocks examples/ prefix paths', () => {
    expect(isExamplesPath('examples/foo.xyzt')).toBe(true)
    expect(isExamplesPath('./examples/advanced/cad/x.xyzt')).toBe(true)
    expect(isExamplesPath('project/examples/part.xyzt')).toBe(true)
  })

  it('allows project files outside examples', () => {
    expect(isExamplesPath('Bracket.xyzt')).toBe(false)
    expect(isExamplesPath('.xyzt/agent/brief.md')).toBe(false)
  })
})

describe('filterExamplesFromFileList', () => {
  it('removes examples paths from list_files output', () => {
    expect(
      filterExamplesFromFileList(['Part.xyzt', 'examples/demo.xyzt', 'lib/use.xyzt']),
    ).toEqual(['Part.xyzt', 'lib/use.xyzt'])
  })
})

describe('examplesPathBlockedResult', () => {
  it('returns structured error code', () => {
    const res = examplesPathBlockedResult('examples/foo.xyzt')
    expect(res.success).toBe(false)
    const parsed = JSON.parse(res.result) as { code: string }
    expect(parsed.code).toBe('EXAMPLES_PATH_BLOCKED')
  })
})
