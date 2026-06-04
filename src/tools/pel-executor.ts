import type { RunResult } from 'xyzt-cad'
import {
  applyPelProgramVerifyToRun,
  buildPelBoardFromManifest,
  buildPelProgramDigest,
  checkpointPelRun,
  createEmptyPelBoard,
  createPelRun,
  assemblePelNodeContext,
  mergeAssemblyGraphIntoPelBoard,
  mergeOelIntoPelBoard,
  parsePelBoard,
  PROJECT_SYMBOL_INDEX_REL_PATH,
  readSymbolIndexFromRaw,
  parsePelRun,
  pelBoardRelativePath,
  pelRunRelativePath,
  pelVerifyTargetsFromBoard,
  pelVerifyTargetsFromManifest,
  runPelProgramVerify,
  serializePelBoard,
  serializePelRun,
  setPelActiveNode,
  summarizePelDigestForDiscipline,
} from 'xyzt-cad'
import type { ProjectManifestV0 } from 'xyzt-cad'
import { parseOelBlackboard, oelBlackboardRelativePath } from 'xyzt-cad'
import { buildFolderProjectManifest } from '../project/folder-manifest.js'
import type { LocalToolResult, ToolContext } from '../types.js'

function readJsonFile(ctx: ToolContext, relPath: string): unknown {
  const raw = ctx.getFileContent(relPath)
  if (!raw) return undefined
  try {
    return JSON.parse(raw)
  } catch {
    return undefined
  }
}

function resolveProjectManifest(
  ctx: ToolContext,
  args: Record<string, unknown>,
): ProjectManifestV0 | undefined {
  if (args.json != null && typeof args.json === 'object') return args.json as ProjectManifestV0
  if (args.manifest != null && typeof args.manifest === 'object') return args.manifest as ProjectManifestV0
  const onDisk = readJsonFile(ctx, 'project.manifest.json') as ProjectManifestV0 | undefined
  if (onDisk) return onDisk
  return buildFolderProjectManifest(
    ctx.listFilePaths(),
    ctx.getFileContent,
    ctx.rootPath,
  )
}

export async function executePelPlan(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const goalSummary = typeof args.goalSummary === 'string' ? args.goalSummary : undefined
  const manifestRaw = resolveProjectManifest(ctx, args)
  const projectId =
    typeof args.projectId === 'string'
      ? args.projectId
      : manifestRaw?.projectId ?? 'local-project'

  let board = manifestRaw
    ? buildPelBoardFromManifest(manifestRaw, { goalSummary })
    : createEmptyPelBoard(projectId)

  if (ctx.runScriptInProcess) {
    for (const node of board.nodes.filter(n => n.kind === 'cad_file')) {
      const path = node.oelFile ?? node.paths[0]
      if (!path) continue
      const code = ctx.getFileContent(path)
      if (!code?.trim()) continue
      try {
        const run = await ctx.runScriptInProcess(code, {})
        if (run.success && run.assemblyGraph) {
          board = mergeAssemblyGraphIntoPelBoard(board, run.assemblyGraph, path)
        }
      } catch {
        /* skip cad files that fail compile during plan */
      }
    }
  }

  const run = createPelRun(projectId)
  const oelRaw = ctx.getFileContent(oelBlackboardRelativePath())
  const oel = oelRaw ? parseOelBlackboard(oelRaw) : undefined
  const merged = oel ? mergeOelIntoPelBoard(board, oel) : board
  const digest = buildPelProgramDigest({ board: merged, manifest: manifestRaw, oel })

  const checkpointed = checkpointPelRun(run, {
    phase: 'decompose',
    progressNote: `PEL plan: ${merged.nodes.length} nodes`,
  })

  return {
    success: true,
    result: JSON.stringify(
      {
        ok: true,
        board: merged,
        digest,
        discipline: summarizePelDigestForDiscipline(digest),
        run: checkpointed,
      },
      null,
      2,
    ),
    files: [
      { name: pelBoardRelativePath(), content: serializePelBoard(merged) },
      { name: pelRunRelativePath(), content: serializePelRun(checkpointed) },
    ],
  }
}

export async function executePelActivateNode(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const nodeId = typeof args.nodeId === 'string' ? args.nodeId.trim() : ''
  if (!nodeId) {
    return { success: false, result: JSON.stringify({ ok: false, error: 'nodeId is required' }) }
  }

  const boardRaw = ctx.getFileContent(pelBoardRelativePath())
  const board = boardRaw ? parsePelBoard(boardRaw) : createEmptyPelBoard('local-project')
  const next = setPelActiveNode(board, nodeId)
  const oelRaw = ctx.getFileContent(oelBlackboardRelativePath())
  const oel = oelRaw ? parseOelBlackboard(oelRaw) : undefined
  const digest = buildPelProgramDigest({ board: next, oel })
  const indexRaw = ctx.getFileContent(PROJECT_SYMBOL_INDEX_REL_PATH)
  const nodeContext = assemblePelNodeContext({
    board: next,
    digest,
    symbolIndex: readSymbolIndexFromRaw(indexRaw),
  })

  const runRaw = ctx.getFileContent(pelRunRelativePath())
  let run = runRaw ? parsePelRun(runRaw) : null
  if (!run) run = createPelRun(next.projectId)
  const checkpointed = checkpointPelRun(run, {
    phase: 'author',
    activeNodeId: nodeId,
    progressNote: `Active node: ${nodeId}`,
  })

  return {
    success: true,
    result: JSON.stringify(
      {
        ok: true,
        activeNodeId: nodeId,
        node: next.nodes.find((n: { id: string }) => n.id === nodeId),
        digest,
        context: nodeContext,
        agentHints: [
          nodeContext.t0,
          nodeContext.t1,
          'Scope patch_file to active node paths only. Run orient_cad after validate on each touched CAD file.',
        ],
      },
      null,
      2,
    ),
    files: [
      { name: pelBoardRelativePath(), content: serializePelBoard(next) },
      { name: pelRunRelativePath(), content: serializePelRun(checkpointed) },
    ],
  }
}

export async function executePelReadDigest(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const boardRaw = ctx.getFileContent(pelBoardRelativePath())
  if (!boardRaw) {
    return {
      success: true,
      result: JSON.stringify({
        ok: true,
        hint: 'No PEL board yet. Call pel_plan after validate_project.',
        digest: null,
      }),
    }
  }
  const board = parsePelBoard(boardRaw)
  const oelRaw = ctx.getFileContent(oelBlackboardRelativePath())
  const oel = oelRaw ? parseOelBlackboard(oelRaw) : undefined
  const merged = oel ? mergeOelIntoPelBoard(board, oel) : board
  const digest = buildPelProgramDigest({ board: merged, oel })

  return {
    success: true,
    result: JSON.stringify(
      {
        ok: true,
        digest,
        discipline: summarizePelDigestForDiscipline(digest),
        openWork: merged.nodes.filter((n: { status: string }) => !['done', 'verified'].includes(n.status))
          .length,
      },
      null,
      2,
    ),
  }
}

export async function executePelVerifyProgram(
  args: Record<string, unknown>,
  ctx: ToolContext,
): Promise<LocalToolResult> {
  const manifestRaw = resolveProjectManifest(ctx, args)
  const boardRaw = ctx.getFileContent(pelBoardRelativePath())
  const board = boardRaw ? parsePelBoard(boardRaw) : null
  const targets = board
    ? pelVerifyTargetsFromBoard(board)
    : manifestRaw
      ? pelVerifyTargetsFromManifest(manifestRaw)
      : []

  if (targets.length === 0) {
    return {
      success: false,
      result: JSON.stringify({
        ok: false,
        error: 'No CAD/scene targets for program verify. Run pel_plan or validate_project first.',
      }),
    }
  }

  const runScript = async (path: string, code: string): Promise<RunResult> => {
    if (ctx.runScriptInProcess) return ctx.runScriptInProcess(code, {})
    const res = await ctx.engineRun({ type: 'run_script', code, fileName: path })
    if (res.type === 'error') throw new Error((res.error as string) ?? 'run failed')
    return res.result as RunResult
  }

  const verify = await runPelProgramVerify({
    targets,
    runScript,
    getCadCode: path => ctx.getFileContent(path),
    readSceneJson: path => {
      const raw = ctx.getFileContent(path)
      if (!raw) return undefined
      try {
        return JSON.parse(raw)
      } catch {
        return undefined
      }
    },
  })

  const runRaw = ctx.getFileContent(pelRunRelativePath())
  let pelRun =
    (runRaw ? parsePelRun(runRaw) : null) ??
    createPelRun(manifestRaw?.projectId ?? board?.projectId ?? 'local-project')
  const checkpointed = applyPelProgramVerifyToRun(pelRun, verify)

  let nextBoard = board
  if (nextBoard) {
    nextBoard = {
      ...nextBoard,
      nodes: nextBoard.nodes.map(n => {
        const hit = verify.reports.find(r => n.paths.includes(r.path))
        if (!hit) return n
        return { ...n, status: hit.ok ? ('verified' as const) : ('blocked' as const) }
      }),
    }
  }

  const files: Array<{ name: string; content: string }> = [
    { name: pelRunRelativePath(), content: serializePelRun(checkpointed) },
  ]
  if (nextBoard) {
    files.push({ name: pelBoardRelativePath(), content: serializePelBoard(nextBoard) })
  }

  return {
    success: verify.ok,
    result: JSON.stringify({ ok: verify.ok, verify, run: checkpointed }, null, 2),
    files,
  }
}
