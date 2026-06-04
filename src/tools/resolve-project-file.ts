/** Resolve a tool-requested path to an exact project-relative path. */
export function resolveProjectFileName(
  requested: string,
  paths: string[],
): string | undefined {
  const r = requested.trim().replace(/\\/g, '/')
  if (!r) return undefined
  if (paths.includes(r)) return r
  const base = r.split('/').pop() ?? r
  const exact = paths.find(p => p === base || p.endsWith(`/${base}`))
  if (exact) return exact
  const lower = base.toLowerCase()
  return paths.find(p => p.toLowerCase() === lower || p.toLowerCase().endsWith(`/${lower}`))
}
