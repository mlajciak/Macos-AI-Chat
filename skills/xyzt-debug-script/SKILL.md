---
name: xyzt-debug-script
description: Debug failing .xyzt scripts — agent workflow, validate_script, common failures
minCore: f3dc9a7
---

# xyzt-debug-script

Use when `validate_script` fails, preview is empty, or geometry is wrong after `patch_file`.

## Agent steps

1. Read **tool result JSON** — line/column, `logs[]` from `console.log`.
2. **`validate_script`** again after each fix (do not skip).
3. Shrink: comment out last boolean/feature; re-add one operation.
4. **`orient_cad`** / **`spatial_thinking`** if problem is position/clearance, not syntax.

## Syntax / runtime

| Error | Fix |
|-------|-----|
| `SyntaxError` | Typos, missing `)`, using `await` on geometry |
| `X is not defined` | Typo or illegal import — only globals exist |
| Nothing returned | Add `return` on last line |
| Empty mesh | Cutter misses body; check `boundingBox` both |

## Geometry logic

| Symptom | Fix |
|---------|-----|
| Boolean no-op | Cutter does not intersect — log bboxes, extend cutter height |
| Paper-thin part | Extrude height 0 or wrong sketch plane |
| Holes wrong place | `orient_cad` — do not guess coordinates |
| Assembly exploded | Wrong `at:` — read spatial JSON |

## Debug snippets (inside script)

```js
console.log('bbox', boundingBox(body))
console.log('vol', volume(body))
const c = check(body)
console.log('check', c)
```

## patch_file strategy

- Fix **one file** per iteration when possible.
- Prefer small hunks over rewriting 500 lines in reasoning.
- If stuck after 3 validate failures: `read_file` a working `examples/advanced/cad/*.xyzt` and align structure.
