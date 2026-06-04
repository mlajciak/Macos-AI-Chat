---
name: hw-engineering
description: Full-stack hardware engineering orchestration — CAD, EDA, simulation, exports, and verification gates for the xyzt-agent runtime
---

# HW engineering (orchestrator)

Use this skill when the task spans **mechanical**, **electronics**, and/or **simulation** in one project.

## Principal loop

1. **Plan** — `get_capabilities`, `validate_project`, optional `build_project_run_plan`, `pel_plan` for large programs.
2. **Author** — `create_cad` / `create_eda` / `create_simulation` + `patch_file` (never paste full scripts in chat).
3. **Validate** — `validate_script`, `verify_eda`, `validate_simulation`; `orient_cad` after CAD placement edits; `run_drc` when layout changes matter.
4. **Export** — `export_stl` or `export_step`, `export_gerber_bundle`, `export_bom`, `run_verify_profile` (profile `strict` for mechanical ship).
5. **Ship** — `update_overview` only after domain gates pass.

## Domain skills

| Domain | Skill |
|--------|--------|
| CAD | [xyzt](../xyzt/SKILL.md), [xyzt-make-cad-model](../xyzt-make-cad-model/SKILL.md) |
| EDA | [xyzt-make-eda](../xyzt-make-eda/SKILL.md) |
| Simulation | [xyzt-make-simulation](../xyzt-make-simulation/SKILL.md) |
| Cross-check | [xyzt-validate](../xyzt-validate/SKILL.md) |
| Project / PEL | [xyzt-platform](../xyzt-platform/SKILL.md) |

## Minimum acceptance (RP-1)

Electromechanical wedge reference: `examples/rp-1-electromechanical/`

- Mechanical: `validate_script` + mesh run OK on bracket script.
- EDA (if present): `verify_eda` after every board mutation.
- Simulation (if present): `validate_simulation` before `run_simulation`.
- CI golden IDs: `rp-1-electromechanical`, `hw-sim-smoke`, `hw-export-bundle`.

## Artifact checklist

| Artifact | Tool |
|----------|------|
| STL / STEP | `export_stl` / `export_step` |
| Gerber zip | `export_gerber_bundle` |
| BOM CSV | `export_bom` |
| Verify report | `run_verify_profile` |

## Tool SSOT

Runtime allowlist: `RUNTIME_AGENT_TOOL_NAMES` in `packages/xyzt-agent-tools`. Model-facing minimal set: `DESKTOP_AGENT_TOOL_NAMES` (7 authoring tools).
