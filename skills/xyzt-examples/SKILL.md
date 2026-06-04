---
name: xyzt-examples
description: Curated CAD patterns and repo reference paths — use read_file, not example search tools
minCore: f3dc9a7
---

# xyzt-examples

Inject when you need a **specific** pattern (loft, sweep, hinge, gearbox). For primitives use **`/xyzt`** only.

## Repo reference files (`read_file`)

| Path | Use for |
|------|---------|
| `examples/advanced/cad/electric-drive-unit.xyzt` | Planetary drive, spur gears, housing |
| `examples/advanced/cad/four-bar-linkage.xyzt` | Linkages, joints |
| `examples/advanced/cad/robotic-hand.xyzt` | Constrained phalanges, placementSpec knuckles, grasp motion |
| `examples/cad/robotic-hand.xyzt` | Same (showcase path) |
| `examples/advanced/cad/rocket-stage-array.xyzt` | Stacked assemblies |

Copy structure, not whole-file paste into chat.

## Geometry Patterns

### Circular Hole Pattern
Evenly spaced holes on a bolt circle:
```js
const N = 6, BCD = 25, HOLE_R = 3, H = 20
let body = cylinder(40, H)
for (let i = 0; i < N; i++) {
  const a = (i / N) * TAU
  const hole = cylinder(HOLE_R, H + 2).translate(BCD * cos(a), BCD * sin(a), 0)
  body = body.subtract(hole)
}
return body
```

### Shell / Hollow Enclosure
Hollow box with uniform wall thickness:
```js
const W = 80, D = 60, H = 40, WALL = 3
let outer = box(W, D, H)
let inner = box(W - WALL*2, D - WALL*2, H - WALL).translate(0, 0, WALL)
let shell = outer.subtract(inner)
return shell
```

### Revolve Profile (Lathe)
Axis-symmetric part via revolve from 2D profile:
```js
const profile = sketch()
  .moveTo(5, 0)
  .lineTo(20, 0)
  .lineTo(18, 5)
  .lineTo(18, 40)
  .lineTo(12, 45)
  .lineTo(5, 45)
  .close()
return profile.revolve(360)
```

### Loft Between Profiles
```js
const bottom = XY.sketch().rect(40, 40, { center: true })
const top = XY.offset(50).sketch().circle([0, 0], 15)
return loft([bottom, top])
```

### Sweep Along Path
```js
const profile = sketch().circle([0, 0], 3)
const path = [[0,0,0], [20,0,10], [40,0,0], [60,0,10]]
return sweep(profile, path)
```

## Assembly Patterns

### Hinge Assembly
```js
const base = box(60, 40, 5).color(0.5, 0.5, 0.55)
const lid = box(60, 40, 3).translate(0, 0, 8).color(0.6, 0.6, 0.65)

const asm = assembly("Hinged Box")
  .add("base", base, { fixed: true })
  .add("lid", lid, {
    joint: revolute([1, 0, 0], { min: 0, max: 120 }),
    parent: "base",
    at: [0, -20, 5]
  })
return asm
```

### Sliding Mechanism
```js
const rail = box(100, 10, 5).color(0.4, 0.4, 0.45)
const slider = box(30, 8, 4).color(0.7, 0.3, 0.2)

const asm = assembly("Slider")
  .add("rail", rail, { fixed: true })
  .add("slider", slider, {
    joint: prismatic([1, 0, 0], { min: -35, max: 35 }),
    parent: "rail",
    at: [0, 0, 4.5]
  })
return asm
```

### Multi-Part Assembly
```js
const base = box(100, 80, 10).color(0.3, 0.3, 0.35)
const post = cylinder(8, 60).color(0.6, 0.5, 0.2)

const asm = assembly("Frame")
  .add("base", base, { fixed: true })
  .add("post_fl", post, { at: [30, 25, 10] })
  .add("post_fr", post, { at: [-30, 25, 10] })
  .add("post_bl", post, { at: [30, -25, 10] })
  .add("post_br", post, { at: [-30, -25, 10] })
return asm
```

`red.union(green)` keeps one color — use **assembly** with separate bodies for multi-color products.

## Feature Patterns

### Workplane Features
```js
let body = box(40, 40, 40)
const topHole = XY.offset(20).sketch().circle([0, 0], 8).extrude(10)
body = body.subtract(topHole)
const sideBoss = YZ.offset(20).sketch().circle([0, 0], 6).extrude(8)
body = body.union(sideBoss)
return body
```

### Linear Pattern
```js
const base = box(100, 20, 10)
const fin = box(3, 20, 15).translate(0, 0, 12.5)
const fins = linearPattern(fin, [1, 0, 0], 8, 12)
return base.union(fins)
```

### Draft Angle for Molding
```js
const part = sketch()
  .rect(50, 50, { center: true })
  .fillet2d(3)
  .extrude(30, { draft: 2 })
return part
```

## SDF Patterns

### Smooth Blend
```js
const a = sdf.sphere(12).translate(-8, 0, 0)
const b = sdf.sphere(12).translate(8, 0, 0)
return a.smoothUnion(b, 6).toShape({ edgeLength: 1.0 })
```

### Gyroid Lattice
```js
const bounds = { min: [-20,-20,-20], max: [20,20,20] }
const shell = sdf.sphere(18)
const gyroid = sdf.gyroid({ cellSize: 10, thickness: 1.0, bounds })
return gyroid.intersect(shell).toShape({ edgeLength: 0.8, bounds })
```

## Validation Patterns

### Self-Validation with TestContext
```js
const base = box(60, 40, 10).color(0.4, 0.4, 0.45)
const lid = box(58, 38, 3).translate(0, 0, 10).color(0.5, 0.5, 0.55)

function run_tests(ctx) {
  ctx.expect_gap("base", "lid", { min: 0, max: 1 })
  ctx.check("lid fits within base width", true)
  return ctx.report()
}

return { model: assembly("Box").add("base", base).add("lid", lid), tests: run_tests }
```
