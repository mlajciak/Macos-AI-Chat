---
name: xyzt-validate
description: Validation before claiming done — scripts, EDA, simulation, diagnostics
minCore: f3dc9a7
---

# xyzt-validate

## CAD

- `validate_script` on every `.xyzt` change.
- Multi-body: **`orient_cad`** after mate/placement/contract edits.
- `mateSolveReport.fullyConstrained` must be true (or documented solver failure) before ship.
- `ledger` must have no open `declared`/`solved`/`measured` failures.
- `probe_model` for face ids (offsetFace) when needed.

## EDA

- `verify_eda` with `profile: "fab"` before "fab ready".
- Placement via `circuit().placement(edaPlacement())` — not ad-hoc `.at()` in agent patches.

## Simulation

- Desktop: `validate_simulation` then `run_simulation`.

## Project

- `validate_project` / `build_project_run_plan` when multiple linked files.

## On failure

`explain_diagnostics` — quote codes, prefer `patch_constraint` repair actions over `patch_coord`.

## Done means

- Tool success JSON (meshCount, mateSolveReport, circuitJson).
- User-visible file exists and returns valid domain object.

Never: "should work", success without tool run.
