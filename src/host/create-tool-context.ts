import type { LocalToolResult, ToolContext } from '../types.js'

export interface DesktopToolContextOptions {
  listFilePaths: () => string[]
  getFileContent: (name: string) => string | undefined
  ensureFileContent?: (fileName: string) => Promise<string | undefined>
  sandboxEdits: boolean
  rootPath?: string | null
  engineRun: (payload: Record<string, unknown>) => Promise<Record<string, unknown>>
  startSimulationJob?: (request: unknown) => Promise<unknown>
  createSimulationJobRequest?: (
    simulation: import('xyzt-cad').SimulationJsonV0,
    meshes: import('xyzt-cad').MeshData[],
  ) => unknown
  writeBinaryFile?: (path: string, data: Uint8Array, mode: 'direct' | 'sandbox') => Promise<LocalToolResult>
  runScriptInProcess?: ToolContext['runScriptInProcess']
  searchComponents?: ToolContext['searchComponents']
  fetchComponentDetails?: ToolContext['fetchComponentDetails']
  placeComponent?: ToolContext['placeComponent']
  readWorkflowSnapshot?: ToolContext['readWorkflowSnapshot']
  persistWorkflowSnapshot?: ToolContext['persistWorkflowSnapshot']
  ngspiceAvailable?: boolean
}

export function createToolContext(opts: DesktopToolContextOptions): ToolContext {
  return {
    listFilePaths: opts.listFilePaths,
    getFileContent: opts.getFileContent,
    ensureFileContent: opts.ensureFileContent,
    sandboxEdits: opts.sandboxEdits,
    rootPath: opts.rootPath,
    engineRun: opts.engineRun,
    startSimulationJob: opts.startSimulationJob,
    createSimulationJobRequest: opts.createSimulationJobRequest,
    writeBinaryFile: opts.writeBinaryFile,
    runScriptInProcess: opts.runScriptInProcess,
    searchComponents: opts.searchComponents,
    fetchComponentDetails: opts.fetchComponentDetails,
    placeComponent: opts.placeComponent,
    readWorkflowSnapshot: opts.readWorkflowSnapshot,
    persistWorkflowSnapshot: opts.persistWorkflowSnapshot,
    ngspiceAvailable: opts.ngspiceAvailable,
  }
}
