---
name: xyzt
description: XYZT CAD scripting for agents — sandbox rules, globals API, assemblies, patch workflow
minCore: f3dc9a7
---

# xyzt — CAD scripting (agent)

Use this skill for every `.xyzt` file the agent authors. **Truth lives in the script** — run `validate_script` / tools; do not claim geometry you did not execute.

## Sandbox (non-negotiable)

| Rule | Detail |
|------|--------|
| Language | JavaScript in a **closed sandbox** — no `import`, `require`, `fetch`, `eval`, dynamic `Function` |
| Multi-file | `use('OtherPart.xyzt')` only — returns what that file exports |
| Units | **Millimeters** unless you call `setUnits` |
| Async | Geometry is **synchronous** — no `await` on primitives/features |
| Return | **Last expression** must be `Shape`, `Assembly`, or `{ model, placement?, contract }` |
| Authoring | **Never** paste full scripts in chat reasoning — only `create_cad` / `patch_file` `content` |

## Agent tool workflow (desktop)

```
get_capabilities → validate_project
→ create_cad (stub OK) → patch_file until done
→ validate_script → orient_cad (after constraint/placement edits)
→ update_overview last
```

- First `create_cad` may be a **minimal compiling stub**; real work is **`patch_file`** until the user task is met.
- Assemblies: **mates + `solve()`** or **`placementSpec()`** — not `at:[x,y,z]` unless solver failed (cite orient JSON).

## Primitives

```js
let body = box(40, 30, 12)
const hole = cylinder(12 + 2, 3)  // cylinder(height, radius)
```

**Booleans:** reassign — `body = body.subtract(cutter)`.

## Parameters

```js
const w = param('width', 40, { min: 10, max: 100, step: 1 })
```

## Sketch → solid (constraints)

```js
const cs = constrainedSketch()
const p0 = cs.point(0, 0)
const p1 = cs.point(40, 0)
const p2 = cs.point(40, 30)
const p3 = cs.point(0, 30)
cs.line(p0, p1).line(p1, p2).line(p2, p3).line(p3, p0)
cs.distance(p0, p1, 40).distance(p1, p2, 30)
return cs.solve().extrude(10)
```

## Assembly

```js
return assembly('DriveUnit')
  .add('housing', housing, { fixed: true })
  .add('shaft', shaft)
  .mate('shaft.center', 'housing.bore', 'coaxial')
  .solve()
```

## Design contract + placement

```js
return {
  model: asm,
  placement: placementSpec().fixed('base').stackOn('lid', 'base'),
  contract: designContract({ profile: 'strict', requiredGaps: [...] }),
}
```

## Multi-file

```js
const pin = use('Pin.xyzt')
return assembly('Stack')
  .add('pin', pin)
  .mate('pin.center', 'base.hole', 'coincident')
  .solve()
```

## Anti-patterns

- `at:[x,y,z]` placement without `mateSolveReport.fullyConstrained`.
- Drafting full scripts in thinking instead of tool calls.
- Guessing hole centers / stack height without orient/ledger JSON.

## Generated API reference

See `generated-api-reference.md` in this skill folder (from `pnpm --filter xyzt-cad docs:agent`).
