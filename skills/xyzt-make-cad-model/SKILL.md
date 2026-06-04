---
name: xyzt-make-cad-model
description: Assemblies, joints, design contracts, motion studies
minCore: f3dc9a7
---

# xyzt-make-cad-model

## When

Multi-body products, clearances, motion, parametric stacks (gearboxes, drives, enclosures, planetary stages).

## Authoring (agent)

1. **`/xyzt`** skill + generated API reference for sandbox globals.
2. **`update_plan`** with `dependsOn`: research → parallel part files → assembly file (see `/xyzt-platform`).
3. `create_cad` per part (stub OK) → **`patch_file`** until validate passes — gears via **`lib.spurGear`**, housings via booleans.
4. Separate `.xyzt` per major part when parallel agents enabled; one assembly file that `use()`s them.
5. Emit code early: `return { model, placement, contract }` or `assembly(...).mate(...).solve()` in the first substantive edit.

## Spatial (desktop — required)

After patches that change mates, gaps, or body count:

1. `orient_cad` with `fileName`.
2. Read `mateSolveReport`, `ledger`, `gates` JSON — adjust **constraints**, not coordinates.
3. Do not patch `at:[x,y,z]` unless `mateSolveReport.fullyConstrained` is false and orient cites an escape.

## Assembly (constraint-first)

```js
const base = box(100, 100, 10, { center: true }).withAnchors({
  mount: { point: [20, 0, 5], axis: [0, 0, 1] },
})
const lid = box(80, 80, 5, { center: true }).withAnchors({
  bottom: { point: [0, 0, -2.5], axis: [0, 0, -1] },
})
const asm = assembly('Product')
  .add('base', base, { fixed: true })
  .add('lid', lid)
  .mate('lid.bottom', 'base.mount', 'offset', { distance: 2 })
  .solve()
return {
  model: asm,
  contract: designContract({
    profile: 'strict',
    requiredGaps: [{ partA: 'lid', partB: 'base', min: 1.5, max: 3 }],
  }),
}
```

Or declarative:

```js
return {
  model: asm,
  placement: placementSpec()
    .fixed('base')
    .flush('lid.bottom', 'base.top')
    .gap('lid', 'base', { min: 1.5, max: 3 }),
  contract: designContract({ profile: 'strict' }),
}
```

## 2D sketch

Use `constrainedSketch()` + `.concentric()` / `.distance()` — not guessed point coordinates.

## Colors / materials

- `.color(r,g,b)` 0–1 on each body in multi-body assemblies.
- `.material('Steel ASTM A36')` — use `searchMaterials` / `listMaterials` if unsure.
- Do not `union()` differently colored solids expecting both colors — use separate assembly bodies.

## Motion

`motionSequence`, joints — only if capability manifest lists assembly motion; validate with `solve_joints` when available.

## Ship order

1. `pel_plan` when multi-file or many parts.
2. Build each named part → mates/placementSpec → `solve()`.
3. `orient_cad` → contract/motion if needed.

Never call `update_overview` while the model is still a placeholder stub.
