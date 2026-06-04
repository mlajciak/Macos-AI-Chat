import { describe, expect, it } from 'vitest'
import {
  normalizeCreateFileName,
  formatToolExecutionError,
  isPendingFileReviewTool,
  isFileMutationTool,
} from './apply-patches.js'

describe('normalizeCreateFileName', () => {
  it('sanitizes display names into safe paths', () => {
    expect(normalizeCreateFileName('create_cad', 'Test Bracket')).toBe('Test-Bracket.xyzt')
    expect(normalizeCreateFileName('create_cad', undefined)).toBe('model.xyzt')
  })
})

describe('isPendingFileReviewTool', () => {
  it('includes CAD pending tools and file mutations', () => {
    expect(isPendingFileReviewTool('edit_feature')).toBe(true)
    expect(isPendingFileReviewTool('apply_direct_edit')).toBe(true)
    expect(isPendingFileReviewTool('patch_file')).toBe(true)
    expect(isFileMutationTool('run_script')).toBe(false)
    expect(isPendingFileReviewTool('run_script')).toBe(false)
  })
})

describe('formatToolExecutionError', () => {
  it('maps low-level path errors to tool messages', () => {
    expect(formatToolExecutionError('create_cad', new TypeError("Cannot read properties of undefined (reading 'endsWith')"))).toBe(
      'create_cad failed: invalid or missing file path.',
    )
  })
})
