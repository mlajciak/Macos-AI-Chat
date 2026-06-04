import { isEdaVerifyProfile, runScript, validateScript, verifyEda } from 'xyzt-cad'
import type { ToolContext } from '../types.js'

export function goldenEngineCtx(): ToolContext {
  return {
    listFilePaths: () => [],
    getFileContent: () => undefined,
    sandboxEdits: false,
    engineRun: async (payload: Record<string, unknown>) => {
      const type = payload.type as string
      const code = String(payload.code ?? '')
      if (type === 'validate') {
        return { type: 'validated', validation: validateScript(code) }
      }
      if (type === 'run') {
        return { type: 'result', result: await runScript(code, (payload.params as Record<string, unknown>) ?? {}) }
      }
      if (type === 'verify_eda') {
        const run = await runScript(code, (payload.params as Record<string, unknown>) ?? {})
        if (!run.success) {
          return { type: 'error', error: run.error ?? 'EDA compile failed' }
        }
        const circuit = run.circuitJson
        if (!circuit?.length) {
          return { type: 'error', error: 'No circuitJson from EDA script' }
        }
        const rawProfile = (payload.profile as string) ?? 'fab'
        const profile = isEdaVerifyProfile(rawProfile) ? rawProfile : 'fab'
        const report = verifyEda(circuit, { profile })
        return { type: 'verified', report }
      }
      return { type: 'error', error: `unsupported engineRun type ${type}` }
    },
    runScriptInProcess: async (code, params) => runScript(code, params ?? {}),
  }
}
