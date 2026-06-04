import { streamAgentEvents, type StreamTransport } from '../stream/sse-client.js'
import { formatToolExecutionError } from '../tools/apply-patches.js'
import { mergeToolArgs, mergeToolArgsForExecute } from '../tools/merge-tool-args.js'
import { canEarlyAbortToolStream } from '../tools/tool-args-ready.js'
import {
  applyEdaVerifyWorkflow,
  applyValidateScriptWorkflow,
  executeTool,
} from '../tools/registry.js'
import { executeValidateScript, executeVerifyEda } from '../tools/engine-executor.js'
import { normalizeCreateFileName } from '../tools/apply-patches.js'
import { registerSessionFiles, toolContextWithSessionFiles } from '../tools/tool-context-session.js'
import {
  outputLooksLikeUndeliveredScript,
  shouldAbortReasoningWithoutTools,
  WORKFLOW_REASONING_BUDGET_NUDGE,
  WORKFLOW_TOOL_ONLY_NUDGE,
} from '../workflow/script-output-guard.js'
import type { AgentStreamRequest, AIMessage, LocalToolResult, StreamEvent, ToolContext } from '../types.js'

/** Default tool rounds per agent turn. */
export const MAX_TOOL_ITERATIONS = 40

export interface RunLocalAgentStreamOptions {
  history: AIMessage[]
  accessToken: string
  runId?: string
  signal?: AbortSignal
  sandboxEdits?: boolean
  continueFromToolCallId?: string
  toolResult?: string
  toolContext: ToolContext
  agentSurface?: string
  model?: string
  autoModel?: string
  onEvent: (event: StreamEvent) => void | Promise<void>
  transport?: StreamTransport
  authHeaders?: (token: string | null) => Record<string, string>
}

export async function runLocalAgentStream(opts: RunLocalAgentStreamOptions): Promise<void> {
  const messages: AIMessage[] = [...opts.history]
  const runKey = opts.toolContext

  if (opts.continueFromToolCallId && opts.toolResult) {
    const hasTool = messages.some(
      m => m.role === 'tool' && m.tool_call_id === opts.continueFromToolCallId,
    )
    if (!hasTool) {
      messages.push({
        role: 'tool',
        tool_call_id: opts.continueFromToolCallId,
        content: opts.toolResult,
      })
    }
  }

  const streamReq: AgentStreamRequest = {
    runId: opts.runId,
    sandboxEdits: opts.sandboxEdits,
    agentSurface: opts.agentSurface,
    model: opts.model,
    autoModel: opts.autoModel,
  }

  for (let iteration = 0; iteration < MAX_TOOL_ITERATIONS; iteration++) {
    if (opts.signal?.aborted) return
    const pendingTools = new Map<
      string,
      { id: string; name: string; args: Record<string, unknown>; argsJson: string }
    >()
    const argsRawById = new Map<string, string>()
    let assistantText = ''
    let thinkingText = ''
    let abortedReasoningWithoutTools = false
    const streamAbort = new AbortController()
    const onParentAbort = () => streamAbort.abort()
    opts.signal?.addEventListener('abort', onParentAbort, { once: true })

    const ingestEvent = async (event: StreamEvent) => {
      await opts.onEvent(event)
      if (event.type === 'token') assistantText += event.content
      if (event.type === 'thinking') {
        thinkingText += event.content
        if (shouldAbortReasoningWithoutTools(thinkingText, pendingTools.size > 0)) {
          abortedReasoningWithoutTools = true
          streamAbort.abort()
        }
      }
      if (event.type === 'tool_progress') {
        argsRawById.set(event.toolCallId, event.partialContent)
        const existing = pendingTools.get(event.toolCallId)
        const args = mergeToolArgs(existing?.args ?? {}, event.partialContent)
        pendingTools.set(event.toolCallId, {
          id: event.toolCallId,
          name: existing?.name ?? '',
          args,
          argsJson: JSON.stringify(args),
        })
      }
      if (event.type === 'tool_call') {
        const raw = argsRawById.get(event.toolCall.id)
        const args = mergeToolArgs(event.toolCall.args, raw)
        pendingTools.set(event.toolCall.id, {
          ...event.toolCall,
          args,
          argsJson: JSON.stringify(args),
        })
      }
    }

    try {
      for await (const event of streamAgentEvents(
        messages,
        opts.accessToken,
        streamAbort.signal,
        {
          ...streamReq,
          continueFromToolCallId: iteration === 0 ? opts.continueFromToolCallId : undefined,
          toolResult: iteration === 0 ? opts.toolResult : undefined,
        },
        opts.transport,
        opts.authHeaders,
      )) {
        if (opts.signal?.aborted) return
        await ingestEvent(event)
        if (pendingTools.size > 0 && canEarlyAbortToolStream(pendingTools, argsRawById)) {
          streamAbort.abort()
          break
        }
      }
    } catch (err) {
      const aborted =
        streamAbort.signal.aborted
        || opts.signal?.aborted
        || (err instanceof Error && err.name === 'AbortError')
      if (!aborted) throw err
    } finally {
      opts.signal?.removeEventListener('abort', onParentAbort)
    }

    if (opts.signal?.aborted) return
    if (pendingTools.size === 0) {
      const combined = `${thinkingText}\n${assistantText}`
      const undelivered = outputLooksLikeUndeliveredScript(combined)
      const reasoningBudget =
        abortedReasoningWithoutTools
        || (thinkingText.length >= 2800 && !outputLooksLikeUndeliveredScript(combined))
      if ((undelivered || reasoningBudget) && iteration < MAX_TOOL_ITERATIONS - 1) {
        messages.push({
          role: 'user',
          content: undelivered ? WORKFLOW_TOOL_ONLY_NUDGE : WORKFLOW_REASONING_BUDGET_NUDGE,
        })
        continue
      }
      return
    }

    const toolList = [...pendingTools.values()]

    messages.push({
      role: 'assistant',
      content: assistantText || null,
      tool_calls: toolList.map(tc => ({
        id: tc.id,
        type: 'function',
        function: { name: tc.name, arguments: tc.argsJson },
      })),
    })

    let sandboxPause = false
    const sessionFiles = new Map<string, string>()
    const toolContext = toolContextWithSessionFiles(
      { ...opts.toolContext, agentRunId: opts.runId ?? opts.toolContext.agentRunId },
      sessionFiles,
    )
    for (const tc of toolList) {
      if (opts.signal?.aborted) return
      const raw = argsRawById.get(tc.id)
      const args = mergeToolArgsForExecute(tc.args, raw)
      let local: LocalToolResult
      try {
        local = await executeTool(tc.name, args, toolContext, runKey)
        registerSessionFiles(sessionFiles, local.files)
        if (
          local.success
          && (tc.name === 'create_cad' || tc.name === 'create_eda' || tc.name === 'patch_file')
        ) {
          const fileName =
            typeof args.fileName === 'string'
              ? tc.name.startsWith('create_')
                ? normalizeCreateFileName(tc.name, args.fileName.trim())
                : args.fileName.trim()
              : ''
          const isEdaFile = fileName.endsWith('.xyzt.eda')
          const validateFile =
            fileName
            && !isEdaFile
            && (tc.name === 'patch_file' ? fileName.endsWith('.xyzt') : true)
          const verifyEdaFile =
            fileName && (tc.name === 'create_eda' || (tc.name === 'patch_file' && isEdaFile))
          if (verifyEdaFile && !local.pending) {
            const verify = await executeVerifyEda({ fileName }, toolContext)
            let verifyPayload: unknown
            try {
              verifyPayload = JSON.parse(verify.result)
            } catch {
              verifyPayload = { ok: verify.success, raw: verify.result }
            }
            const verifyOk: boolean =
              verify.success === true
              && verifyPayload != null
              && typeof verifyPayload === 'object'
              && (verifyPayload as { ok?: boolean }).ok === true
            if (verifyOk) applyEdaVerifyWorkflow(runKey, fileName, verifyPayload)
            local = {
              ...local,
              success: verifyOk,
              result: JSON.stringify(
                {
                  ok: verifyOk,
                  pending: !!local.pending,
                  message: local.result,
                  post_write_verify_eda: verifyOk,
                  verify_eda: verifyPayload,
                },
                null,
                2,
              ),
            }
          }
          if (validateFile && !local.pending) {
            const inlineCode =
              typeof args.content === 'string' && args.content.trim()
                ? args.content
                : sessionFiles.get(fileName)
            const validation = await executeValidateScript(
              inlineCode ? { fileName, code: inlineCode } : { fileName },
              toolContext,
            )
            let validationPayload: unknown
            try {
              validationPayload = JSON.parse(validation.result)
            } catch {
              validationPayload = { ok: validation.success, raw: validation.result }
            }
            const parsedValidation =
              validationPayload && typeof validationPayload === 'object'
                ? (validationPayload as { ok?: boolean; valid?: boolean })
                : {}
            const validationOk: boolean =
              validation.success === true
              && (parsedValidation.ok === true || parsedValidation.valid === true)
            applyValidateScriptWorkflow(runKey, fileName, validationPayload)
            local = {
              ...local,
              success: validationOk,
              result: JSON.stringify(
                {
                  ok: validationOk,
                  pending: !!local.pending,
                  message: local.result,
                  validation: validationPayload,
                  post_write_validate: validationOk,
                },
                null,
                2,
              ),
            }
          }
        }
      } catch (err) {
        local = { success: false, result: formatToolExecutionError(tc.name, err) }
      }
      if (local.pending) sandboxPause = true

      const toolEvent: StreamEvent = {
        type: 'tool_result',
        toolCallId: tc.id,
        name: tc.name,
        args,
        result: local.result,
        success: local.success,
        pending: local.pending,
        meshData: local.meshData,
        measurements: local.measurements,
        duration: local.duration,
        files: local.files,
      }
      await opts.onEvent(toolEvent)

      messages.push({
        role: 'tool',
        tool_call_id: tc.id,
        content: local.result,
      })
    }

    if (sandboxPause) return
  }

  await opts.onEvent({
    type: 'token',
    content: JSON.stringify({
      ok: false,
      code: 'TOOL_ITERATION_CAP',
      error: `Agent tool iteration limit (${MAX_TOOL_ITERATIONS}) reached. Continue the run to proceed.`,
      retryable: true,
    }),
  })
}
