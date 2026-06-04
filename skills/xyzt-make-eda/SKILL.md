---
name: xyzt-make-eda
description: .xyzt.eda schematic + PCB scripting
minCore: f3dc9a7
---

# xyzt-make-eda

## File

`.xyzt.eda` — returns `circuit()`.

```js
const vcc = net('VCC'), gnd = net('GND')
resistor({ name: 'R1', value: '10k', footprint: '0402', pin1: vcc, pin2: gnd })
return circuit()
```

## Declarative placement

Do not hand-write `.at(x, y)` for layout. Use constraints + placement solver:

```js
return circuit('Board')
  .board(50, 40)
  .constraints({ preset: 'mcu-mixed-signal', minTraceWidth: 0.2 })
  .placement(
    edaPlacement().near('U1', 'top', { insetMm: 10 }).onEdge('J1', 'left'),
  )
```

Engine emits coordinates internally. Cite `verify_eda` JSON if you must reference positions.

## Verify (required before done)

1. `verify_eda` with `profile: "fab"` — must pass (0 DRC errors, unrouted nets = 0).
2. `run_drc` — layout-profile DRC slice when adjusting traces.
3. `export_gerber_bundle` — deterministic fab zip.

## Parts

1. `search_components` → LCSC part id (`lcsc:C12345`).
2. Script: `.usingPart('lcsc.C12345@1')` — part ref must be registered or ERC reports `INVALID_PART_REF`.
3. MCP `place_part` returns `.add(...)` line; apply with `edit_file`.

## Board edits

MCP `edit_board` / `apply_eda_edit` with `circuit_json` from last run — do not hand-edit JSON files.
