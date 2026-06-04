export function isExamplesPath(requested: string): boolean {
  const normalized = requested.trim().replace(/\\/g, '/').replace(/^\.?\//, '').toLowerCase()
  if (!normalized) return false
  return (
    normalized === 'examples'
    || normalized.startsWith('examples/')
    || /(?:^|\/)examples(?:\/|$)/.test(normalized)
  )
}

export function examplesPathBlockedResult(requested?: string): { success: false; result: string } {
  return {
    success: false,
    result: JSON.stringify(
      {
        ok: false,
        code: 'EXAMPLES_PATH_BLOCKED',
        requested,
        message: 'Example corpus paths are blocked. Use /xyzt skill API reference for sandbox globals.',
      },
      null,
      2,
    ),
  }
}

export function filterExamplesFromFileList(paths: string[]): string[] {
  return paths.filter(p => !isExamplesPath(p))
}
