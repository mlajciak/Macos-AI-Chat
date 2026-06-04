# @xyzt/agent

Engineering agent runtime. **Representations** turn CAD/EDA files into structured summaries and plain text for tools and prompts, while the merged **agent runtime** streams model replies, tracks sessions, and defines the engineering tool contracts used by surfaces like the macOS app.

## Representations (v1)

```typescript
import { describeFile } from '@xyzt/agent'

const { document, text } = describeFile({
  fileName: 'bracket.stp',
  content: await readFile('bracket.stp'),
})
```

Supported formats:

- STEP (`.step`, `.stp`)
- IGES (`.iges`, `.igs`)
- KiCad PCB (`.kicad_pcb`), schematic (`.kicad_sch`), netlist (`.net`)

Future: `describeRun()` for native `.xyzt` feature timelines, sketches, and joints.

## Unified agent runtime

`core/` has been folded into the root package under `src/agent`, so `@xyzt/agent` now exposes one API for both file representations and chat/runtime behavior:

```typescript
import {
  buildWorkspaceContext,
  engineeringToolDefinitions,
  streamAgentReply,
} from '@xyzt/agent'

const workspaceContext = buildWorkspaceContext([
  { path: 'bracket.stp', content: await readFile('bracket.stp') },
])

for await (const event of streamAgentReply(messages, {
  apiKey: process.env.OPENROUTER_API_KEY!,
  model: 'openai/gpt-4o',
  includeEngineeringSystemPrompt: true,
  workspaceContext,
  tools: engineeringToolDefinitions(),
})) {
  // text deltas and thinking/tool-card events
}
```

The OpenRouter client supports text and multimodal content parts, model modality discovery, server tools such as image generation, and generic function tools for future providers.

## 3D and image workflow

XYZT treats image generation as an artifact-producing tool, not as a substitute for geometry. The intended loop is:

1. Read or create editable source: code, CAD scripts, STEP/IGES summaries, KiCad data, Blender Python, USD, or scene graphs.
2. Generate or attach reference images only when they help create textures, masks, concepts, or orthographic references.
3. Produce candidate 3D assets through a typed provider adapter.
4. Render canonical views and run deterministic checks such as dimensions, topology, UVs, materials, origin, and file size.
5. Revise the editable source or candidate asset until validation passes or the remaining issue is explicit.

The macOS app now injects a transient engineering prompt and workspace context from the opened folder into each generation request, while keeping those system messages out of the visible chat transcript.

## Scripts

```bash
npm install
npm test
npm run build
```
