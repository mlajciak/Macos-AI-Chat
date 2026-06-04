import { describe, expect, it, vi } from 'vitest'

vi.mock('../tools/registry.js', () => ({
  executeTool: vi.fn(
    async (
      name: string,
      args: Record<string, unknown>,
      ctx: { engineRun: (p: Record<string, unknown>) => Promise<unknown> },
    ) => {
      if (name === 'create_cad') {
        const fileName = String(args.fileName ?? 'Part.xyzt')
        return {
          success: true,
          pending: true,
          result: 'Preview ready',
          files: [{ name: fileName, content: String(args.content ?? '') }],
        }
      }
      if (name === 'spatial_thinking') {
        await ctx.engineRun({ type: 'run', code: 'return box(1,1,1)' })
        return { success: true, result: '{"ok":true,"bodies":[]}' }
      }
      return { success: true, result: '{}' }
    },
  ),
}))

vi.mock('../tools/engine-executor.js', () => ({
  executeValidateScript: vi.fn(async () => ({
    success: true,
    result: JSON.stringify({ ok: true, valid: true }),
  })),
}))

import { runLocalAgentStream } from './tool-execution-loop.js'
import type { StreamTransport } from '../stream/sse-client.js'
import type { ToolContext } from '../types.js'

function sseResponse(lines: string[]): Response {
  const body = new ReadableStream({
    start(controller) {
      const enc = new TextEncoder()
      for (const line of lines) controller.enqueue(enc.encode(line))
      controller.close()
    },
  })
  return new Response(body, { status: 200 })
}

function mockTransport(lines: string[]): StreamTransport {
  return {
    resolveUrl: () => 'http://test/stream',
    fetch: async () => sseResponse(lines),
  }
}

function stubCtx(overrides: Partial<ToolContext> = {}): ToolContext {
  return {
    listFilePaths: () => [],
    getFileContent: () => undefined,
    sandboxEdits: true,
    engineRun: async () => ({ type: 'error', error: 'not configured' }),
    ...overrides,
  }
}

describe('runLocalAgentStream', () => {
  it('pauses after sandbox pending create_cad', async () => {
    const events: string[] = []
    const transport = mockTransport([
      'data: {"tool_call":{"id":"tc1","name":"create_cad","arguments":{"fileName":"Part","content":"return box(1,1,1)"}}}\n\n',
      'data: [DONE]\n\n',
    ])
    await runLocalAgentStream({
      history: [{ role: 'user', content: 'make part' }],
      accessToken: 'tok',
      toolContext: stubCtx(),
      transport,
      onEvent: async e => {
        if (e.type === 'tool_result' && e.name === 'create_cad') events.push(`result:${e.pending}`)
      },
    })
    expect(events).toContain('result:true')
  })

  it('runs all tools in a batch including blocked tools', async () => {
    const names: string[] = []
    const transport = mockTransport([
      'data: {"tool_call":{"id":"tc1","name":"create_cad","arguments":{"fileName":"Part","content":"return box(1,1,1)"}}}\n\n',
      'data: {"tool_call":{"id":"tc2","name":"ask_user","arguments":{"questions":[{"question":"ok?"}]}}}\n\n',
      'data: [DONE]\n\n',
    ])
    await runLocalAgentStream({
      history: [{ role: 'user', content: 'make and ask' }],
      accessToken: 'tok',
      toolContext: stubCtx(),
      transport,
      onEvent: async e => {
        if (e.type === 'tool_result') names.push(e.name)
      },
    })
    expect(names).toContain('create_cad')
    expect(names).toContain('ask_user')
  })

  it('spatial_thinking reads staged file from prior create_cad in batch', async () => {
    let spatialPayload: Record<string, unknown> | null = null
    const transport = mockTransport([
      'data: {"tool_call":{"id":"tc1","name":"create_cad","arguments":{"fileName":"Part.xyzt","content":"return box(10,10,10)"}}}\n\n',
      'data: {"tool_call":{"id":"tc2","name":"spatial_thinking","arguments":{"fileName":"Part.xyzt"}}}\n\n',
      'data: [DONE]\n\n',
    ])
    await runLocalAgentStream({
      history: [{ role: 'user', content: 'layout' }],
      accessToken: 'tok',
      toolContext: stubCtx({
        engineRun: async payload => {
          spatialPayload = payload
          return { type: 'error', error: 'mock engine off' }
        },
      }),
      transport,
      onEvent: async () => {},
    })
    expect(spatialPayload).toBeTruthy()
    const p = spatialPayload as unknown as { type?: string; code?: string; projectFiles?: unknown }
    expect(p?.type === 'run' && (p?.code || p?.projectFiles)).toBeTruthy()
  })

  it('retries stream when thinking contains undelivered script and no tools', async () => {
    let fetchCount = 0
    const scriptThinking = `function spurGear(z, m, width) {
  const rp = z * m / 2;
  return cylinder(width, rp / 2);
}
return assembly(sun1, ring1);`
    const transport: StreamTransport = {
      resolveUrl: () => 'http://test/stream',
      fetch: async () => {
        fetchCount++
        if (fetchCount === 1) {
          return sseResponse([
            `data: {"thinking":${JSON.stringify(scriptThinking.repeat(25))}}\n\n`,
            'data: [DONE]\n\n',
          ])
        }
        return sseResponse(['data: [DONE]\n\n'])
      },
    }
    await runLocalAgentStream({
      history: [{ role: 'user', content: 'gearbox' }],
      accessToken: 'tok',
      toolContext: stubCtx(),
      transport,
      onEvent: async () => {},
    })
    expect(fetchCount).toBe(2)
  })
})
