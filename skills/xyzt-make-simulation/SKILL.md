---
name: xyzt-make-simulation
description: .xyzt.simulation and scene orchestration
minCore: f3dc9a7
---

# xyzt-make-simulation

## Simulation file

`.xyzt.simulation` — returns `simulation()` chain (FEA, thermal, CFD export, etc.).

```js
return simulation()
  .study('static', { /* loads, materials, mesh intent */ })
```

## Backends (check first)

`get_simulation_backends` — WebGPU FEA, OpenFOAM export, ngspice availability. If backend false, return explicit diagnostic — no fake plots.

## Run discipline

1. `validate_simulation` on JSON/script output.
2. `run_simulation` — use job result meshes/scalars as evidence.
3. `simulationToResultBundle` for structured results when composing releases.

## Scene (multi-study)

Desktop folder agent: use `validate_simulation` + `run_simulation` only.

Platform/cloud: `validate_scene` / `run_scene` with `{ scene, studies }` — response must include `ok`, `childJobs`, `metrics`.

Production tiers (verify: `xyzt-core/scripts/verify-production-scenes.sh`):

| Tier | Path |
|------|------|
| A | `examples/scenes/sphere-gravity-collision.xyzt.scene`, `box-stack-collapse.xyzt.scene` |
| B | `examples/scenes/drop-impact-fea.xyzt.scene` |
| C | `examples/scenes/production-line-pick.xyzt.scene` |
| D | `examples/scenes/launch-ascent-v0.xyzt.scene`, `powered-landing-v0.xyzt.scene` |
| E | `examples/scenes/locomotion-train-v0.xyzt.scene` |

## Release claims

`createSolverEvidence`, `assertReleaseEligibleSolver` — dev synthesis is not release-grade SPICE/CFD.
