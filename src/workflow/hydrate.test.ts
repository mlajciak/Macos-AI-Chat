import { describe, expect, it } from 'vitest'
import { hydrateWorkflowFromArtifacts } from './hydrate.js'
import type { ToolContext } from '../types.js'

const pelRunFixture = {
  version: 0,
  runId: 'run-1',
  projectId: 'p1',
  phase: 'orient',
  checkpointSeq: 2,
  gates: {
    compileByFile: { 'bracket.xyzt': true },
    orientByFile: { 'bracket.xyzt': true },
    mechanicalByFile: {},
  },
  status: 'running',
  updatedAt: '2026-05-25T00:00:00.000Z',
}

const boardFixture = {
  version: 0,
  projectId: 'p1',
  nodes: [
    {
      id: 'bracket',
      kind: 'cad_file',
      label: 'bracket',
      paths: ['bracket.xyzt'],
      dependsOn: [],
      status: 'active',
      blockers: [],
      oelFile: 'bracket.xyzt',
    },
    {
      id: 'lid',
      kind: 'cad_file',
      label: 'lid',
      paths: ['lid.xyzt'],
      dependsOn: [],
      status: 'planned',
      blockers: [],
      oelFile: 'lid.xyzt',
    },
  ],
  connectors: [],
  updatedAt: '2026-05-25T00:00:00.000Z',
}

describe('hydrateWorkflowFromArtifacts', () => {
  it('maps pel-run gates into cadSpatialByFile', () => {
    const files: Record<string, string> = {
      '.xyzt.agent/pel-run.json': JSON.stringify(pelRunFixture),
      '.xyzt.agent/pel-program-board.json': JSON.stringify(boardFixture),
    }
    const ctx = {
      getFileContent: (p: string) => files[p],
      listFilePaths: () => [],
      sandboxEdits: false,
      engineRun: async () => ({ type: 'error', error: 'test' }),
    } satisfies ToolContext
    const state = hydrateWorkflowFromArtifacts(ctx)
    expect(state).not.toBeNull()
    expect(state!.phase).toBe('orient')
    expect(state!.cadSpatialByFile['bracket.xyzt']).toMatchObject({
      validateOk: true,
      spatialOk: true,
      critiqueOk: false,
    })
    expect(state!.sawOrient).toBe(true)
    expect(state!.pelProgramRequired).toBe(true)
    expect(state!.pelCadNodesTotal).toBe(2)
  })

  it('returns null when pel-run missing', () => {
    const ctx = {
      getFileContent: () => undefined,
      listFilePaths: () => [],
      sandboxEdits: false,
      engineRun: async () => ({ type: 'error', error: 'test' }),
    } satisfies ToolContext
    expect(hydrateWorkflowFromArtifacts(ctx)).toBeNull()
  })
})
