import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  buildEngineeringSystemPrompt,
  buildModelingWorkflowBrief,
  buildWorkspaceContext,
  engineeringToolDefinitions,
  workspaceContextMessage,
} from '../engineering-agent.js'

describe('engineering agent context', () => {
  it('uses representations to summarize engineering files', () => {
    const fixture = readFileSync('src/representations/__tests__/fixtures/cube.stp')
    const context = buildWorkspaceContext([
      { path: 'parts/cube.stp', content: fixture, sizeBytes: fixture.byteLength },
    ])

    expect(context.files[0]?.kind).toBe('engineering_representation')
    expect(context.text).toContain('parts/cube.stp')
    expect(context.text).toContain('STEP')
    expect(workspaceContextMessage(context)?.role).toBe('system')
  })

  it('documents the artifact-based image and 3D workflow', () => {
    expect(buildEngineeringSystemPrompt()).toContain('image generation only as an artifact')
    expect(buildModelingWorkflowBrief('make a bracket')).toContain('Render canonical views')
    expect(engineeringToolDefinitions().map(tool => tool.type)).toContain('function')
    expect(
      engineeringToolDefinitions().some(tool =>
        tool.type === 'function' && tool.function.name === 'generate_3d_asset',
      ),
    ).toBe(true)
  })
})
