---
name: xyzt-make-drawing
description: .xyzt.draft 2D drawings — chain API, mm
minCore: f3dc9a7
---

# xyzt-make-drawing

## File

`.xyzt.draft` — JavaScript chain, **not JSON**.

```js
return drawing()
  .units('mm')
  .layer('geometry', { color: '#ccc' })
  .rect(0, 0, 297, 210)
  .layer('dims')
  .dimension([0, 0], [297, 0], { offset: 8 })
```

## Chain ops

`.units()`, `.layer()`, `.line()`, `.rect()`, `.circle()`, `.arc()`, `.polyline()`, `.text()`, `.mtext()`, `.dimension()`, `.hatch()`, `.insert()`, `.sheet(w, h)`.

## Associative dimensions (GD-4)

Linear dimensions may carry a stable model ref:

```js
.dimension([0, 0], [100, 0], {
  modelRef: { bodyId: 'Root/Body_1', edgeId: 'edge-width', role: 'width' },
})
```

After CAD regen, refs rebuild or return `drawing.dim_rebuild_failed`.

## Use

Floor plans, assembly sheets, layout — sync only, must `return drawing()`.

## Render

`drawingToRenderScene` / SVG export via engine — 2D preview is valid shipped artifact.
