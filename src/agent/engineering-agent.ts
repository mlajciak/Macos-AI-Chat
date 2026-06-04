import { describeFile, UnsupportedFormatError } from '../representations/index.js'
import type { OpenRouterChatMessage, OpenRouterTool } from './openrouter.js'

export type WorkspaceFileSnapshot = {
  path: string
  content: string | Uint8Array
  sizeBytes?: number
}

export type WorkspaceContextOptions = {
  maxFiles?: number
  maxTextChars?: number
}

export type WorkspaceFileContext = {
  path: string
  kind: 'engineering_representation' | 'text_preview' | 'unsupported'
  text: string
}

export type WorkspaceContext = {
  files: WorkspaceFileContext[]
  text: string
}

const DEFAULT_MAX_FILES = 8
const DEFAULT_MAX_TEXT_CHARS = 18_000

const TEXT_FILE_EXTENSIONS = new Set([
  '.c',
  '.cc',
  '.cpp',
  '.css',
  '.go',
  '.h',
  '.hpp',
  '.html',
  '.java',
  '.js',
  '.json',
  '.jsx',
  '.md',
  '.py',
  '.rs',
  '.sh',
  '.swift',
  '.ts',
  '.tsx',
  '.txt',
  '.xml',
  '.yaml',
  '.yml',
])

export const ENGINEERING_AGENT_SYSTEM_PROMPT = [
  'You are XYZT, an engineering agent for existing software and engineering assets.',
  'Work from the actual project files and artifacts, not from a generic blank prompt.',
  'For CAD, EDA, and 3D work, prefer editable source representations such as code, CAD scripts, STEP/IGES summaries, KiCad data, Blender Python, USD, or scene graphs.',
  'Use image generation only as an artifact-producing tool: create references, textures, masks, or concepts, then feed the resulting images or rendered views into geometry/render validation. Do not treat an image prompt as proof that the 3D asset is correct.',
  'For 3D modeling, iterate through candidate asset generation, deterministic validation, rendered multi-view inspection, and file edits until the artifact satisfies the request or the remaining issue is explicit.',
  'When modifying software, explain and apply concrete file-level changes, keep diffs reviewable, and validate with tests or builds when possible.',
].join('\n')

export function buildEngineeringSystemPrompt(extra?: string): string {
  const suffix = extra?.trim()
  return suffix ? `${ENGINEERING_AGENT_SYSTEM_PROMPT}\n\n${suffix}` : ENGINEERING_AGENT_SYSTEM_PROMPT
}

export function buildWorkspaceContext(
  files: WorkspaceFileSnapshot[],
  options: WorkspaceContextOptions = {},
): WorkspaceContext {
  const maxFiles = options.maxFiles ?? DEFAULT_MAX_FILES
  const maxTextChars = options.maxTextChars ?? DEFAULT_MAX_TEXT_CHARS
  const contexts: WorkspaceFileContext[] = []
  let remainingChars = maxTextChars

  for (const file of files.slice(0, maxFiles)) {
    if (remainingChars <= 0) break
    const context = describeWorkspaceFile(file, remainingChars)
    contexts.push(context)
    remainingChars -= context.text.length
  }

  const text = renderWorkspaceContext(contexts)
  return { files: contexts, text }
}

export function describeWorkspaceFile(
  file: WorkspaceFileSnapshot,
  maxTextChars = DEFAULT_MAX_TEXT_CHARS,
): WorkspaceFileContext {
  try {
    const result = describeFile({ fileName: file.path, content: file.content })
    return {
      path: file.path,
      kind: 'engineering_representation',
      text: truncate(result.text, maxTextChars),
    }
  } catch (error) {
    if (!(error instanceof UnsupportedFormatError)) throw error
  }

  const content = contentToString(file.content)
  if (!isTextLike(file.path) || content.trim() === '') {
    return {
      path: file.path,
      kind: 'unsupported',
      text: `Unsupported or binary file (${file.sizeBytes ?? content.length} bytes).`,
    }
  }
  return {
    path: file.path,
    kind: 'text_preview',
    text: truncate(content, maxTextChars),
  }
}

export function workspaceContextMessage(context: WorkspaceContext): OpenRouterChatMessage | null {
  if (context.files.length === 0 || context.text.trim() === '') return null
  return {
    role: 'system',
    content: [
      'Workspace context from existing files follows. Treat this as factual project context and ask for more file reads if it is insufficient.',
      context.text,
    ].join('\n\n'),
  }
}

export function engineeringToolDefinitions(): OpenRouterTool[] {
  return [
    {
      type: 'function',
      function: {
        name: 'describe_file',
        description: 'Parse or summarize an existing project file, including CAD/EDA formats when supported.',
        parameters: objectSchema({
          path: { type: 'string', description: 'Project-relative file path.' },
        }, ['path']),
      },
    },
    {
      type: 'function',
      function: {
        name: 'generate_image_reference',
        description: 'Generate or edit reference imagery, masks, or texture concepts for later 3D validation.',
        parameters: objectSchema({
          prompt: { type: 'string' },
          reference_images: imageArraySchema(),
          purpose: {
            type: 'string',
            enum: ['concept', 'texture', 'mask', 'orthographic_reference', 'style_reference'],
          },
        }, ['prompt', 'purpose']),
      },
    },
    {
      type: 'function',
      function: {
        name: 'generate_3d_asset',
        description: 'Generate a candidate 3D asset from text and/or reference images through a pluggable provider.',
        parameters: objectSchema({
          prompt: { type: 'string' },
          reference_images: imageArraySchema(),
          output_formats: {
            type: 'array',
            items: { type: 'string', enum: ['glb', 'gltf', 'obj', 'fbx', 'stl', 'usdz', 'usd'] },
          },
          quality: { type: 'string', enum: ['draft', 'production'] },
          constraints: { type: 'string', description: 'Dimensions, topology, materials, or rigging requirements.' },
        }, ['prompt', 'output_formats']),
      },
    },
    {
      type: 'function',
      function: {
        name: 'render_asset',
        description: 'Render canonical views of a 3D asset for visual and geometric inspection.',
        parameters: objectSchema({
          asset_path: { type: 'string' },
          views: {
            type: 'array',
            items: {
              type: 'string',
              enum: ['front', 'back', 'left', 'right', 'top', 'bottom', 'three_quarter', 'wireframe'],
            },
          },
        }, ['asset_path', 'views']),
      },
    },
    {
      type: 'function',
      function: {
        name: 'run_workspace_command',
        description: 'Run a shell command in the opened project folder. Destructive commands require user approval.',
        parameters: objectSchema({
          command: { type: 'string', description: 'Shell command to run in the project directory.' },
          reason: { type: 'string', description: 'Short explanation of why this command is needed.' },
        }, ['command', 'reason']),
      },
    },
    {
      type: 'function',
      function: {
        name: 'validate_asset',
        description: 'Run deterministic checks on generated or edited engineering assets.',
        parameters: objectSchema({
          asset_path: { type: 'string' },
          checks: {
            type: 'array',
            items: {
              type: 'string',
              enum: ['opens', 'dimensions', 'triangle_count', 'manifold', 'uvs', 'materials', 'origin', 'file_size'],
            },
          },
        }, ['asset_path', 'checks']),
      },
    },
  ]
}

export function buildModelingWorkflowBrief(request: string): string {
  return [
    '3D/multimodal workflow for this request:',
    '1. Identify editable source files or create procedural source first when possible.',
    '2. If imagery helps, generate or use images as reference artifacts, not as final evidence.',
    '3. Produce candidate geometry or texture assets through a typed provider/tool.',
    '4. Render canonical views and validate hard constraints such as dimensions, topology, UVs, materials, origin, and file size.',
    '5. Compare rendered output against the request and references, then revise source files or regenerate candidates.',
    '',
    `User request: ${request}`,
  ].join('\n')
}

function renderWorkspaceContext(files: WorkspaceFileContext[]): string {
  if (files.length === 0) return ''
  return files
    .map(file => [`## ${file.path}`, `Kind: ${file.kind}`, '', file.text].join('\n'))
    .join('\n\n')
}

function objectSchema(
  properties: Record<string, unknown>,
  required: string[],
): Record<string, unknown> {
  return {
    type: 'object',
    properties,
    required,
    additionalProperties: false,
  }
}

function imageArraySchema(): Record<string, unknown> {
  return {
    type: 'array',
    items: objectSchema({
      url: { type: 'string' },
      mime_type: { type: 'string' },
    }, ['url']),
  }
}

function contentToString(content: string | Uint8Array): string {
  if (typeof content === 'string') return content
  return new TextDecoder().decode(content)
}

function isTextLike(path: string): boolean {
  const dot = path.lastIndexOf('.')
  if (dot === -1) return false
  return TEXT_FILE_EXTENSIONS.has(path.slice(dot).toLowerCase())
}

function truncate(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text
  return `${text.slice(0, Math.max(0, maxChars - 32))}\n\n[truncated for context budget]`
}
