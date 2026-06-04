import { contentHash, type ProjectFileKindV0, type ProjectManifestV0 } from 'xyzt-cad'

function fileKind(path: string): ProjectFileKindV0 {
  if (typeof path !== 'string' || !path) return 'unknown'
  if (path.endsWith('.xyzt.eda')) return 'eda'
  if (path.endsWith('.xyzt.draft')) return 'drawing'
  if (path.endsWith('.xyzt.simulation')) return 'simulation'
  if (path.endsWith('.xyzt.scene')) return 'scene'
  if (path.endsWith('.xyzt')) return 'cad'
  return 'unknown'
}

export function buildFolderProjectManifest(
  paths: string[],
  getFileContent: (name: string) => string | undefined,
  rootPath?: string | null,
): ProjectManifestV0 {
  const projectId = rootPath?.split(/[/\\]/).filter(Boolean).pop() ?? 'folder-project'
  const files: ProjectManifestV0['files'] = paths
    .filter((p): p is string => typeof p === 'string' && p.length > 0)
    .filter(p => !p.startsWith('.xyzt/agent/'))
    .map(path => {
      const content = getFileContent(path)
      return {
        path,
        kind: fileKind(path),
        ...(content !== undefined ? { contentHash: contentHash(content) } : {}),
      }
    })
  return {
    version: 0,
    projectId,
    files,
    links: [],
    artifacts: [],
    updatedAt: new Date().toISOString(),
  }
}
