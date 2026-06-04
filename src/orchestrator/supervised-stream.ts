import { runLocalAgentStream, type RunLocalAgentStreamOptions } from '../loop/tool-execution-loop.js'
import { routeGateBlock } from './route.js'
import { parseWorkflowGateHint } from './worker-role.js'

export type SupervisedStreamOptions = RunLocalAgentStreamOptions & {
  onGateHint?: (hint: { nextTool?: string; code?: string; note?: string }) => void
}

/**
 * Wraps local agent stream; surfaces WORKFLOW_* gate hints to the host (worker routing MVP).
 */
export async function runSupervisedAgentStream(opts: SupervisedStreamOptions): Promise<void> {
  const { onGateHint, onEvent, ...rest } = opts
  await runLocalAgentStream({
    ...rest,
    onEvent: async event => {
      if (event.type === 'tool_result' && event.success === false && event.result) {
        const parsed = parseWorkflowGateHint(event.result)
        if (parsed?.code) {
          const route = routeGateBlock(parsed.code)
          onGateHint?.({
            code: parsed.code,
            nextTool: parsed.nextTool ?? route?.nextTool,
            note: route?.note,
          })
        }
      }
      await onEvent(event)
    },
  })
}
