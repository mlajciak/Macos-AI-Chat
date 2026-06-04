# @xyzt/agent

Engineering agent runtime. **Representations** turn CAD/EDA files into structured summaries and plain text for tools and prompts.

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

## Scripts

```bash
npm install
npm test
npm run build
```
