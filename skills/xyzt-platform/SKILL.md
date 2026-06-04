---
name: xyzt-platform
description: How agents use XYZT — tools, phases, planning DAG, verification, honest limits
minCore: f3dc9a7
---

# xyzt-platform (agent)

## Your job

Ship **working project files** with tool evidence. The user sees previews and validation JSON — not prose substitutes for geometry.

## Start every task

1. **`get_capabilities`** — what is partial vs missing.
2. **`validate_project`** — multi-file health before large edits.
3. Building streams auto-inject **`/xyzt`** + **`/xyzt-make-cad-model`** (desktop). Type `/xyzt` in chat to pull skills manually during planning.

Regenerate manifests in repo: `pnpm --filter xyzt-cad docs:agent` → `docs/agent/generated/`.

## Chat tab workflow (desktop)

- **One active plan per tab** — follow-up messages while executing enqueue; they flush when the current todo batch completes (no replan).
- **`update_plan`** during execution can adjust todos in place.
- Example corpus paths (`examples/…`) are **blocked** on `read_file` / `list_files` — use `/xyzt` generated API reference.

## Desktop agent phases

| Phase | Allowed | Forbidden |
|-------|---------|-----------|
| **Planning** | `update_plan`, `read_file`, `list_files`, `get_capabilities`, `validate_project`, `ask_user` | `create_cad`, `patch_file`, any file authoring |
| **Executing** | Full authoring + validate + spatial + simulation per workflow | Skipping validate after substantive CAD edits |

**Plan shape:** `update_plan` todos use **`dependsOn`** (todo ids). Roots = no deps. Siblings with same parent run **in parallel** when user enables parallel agents (disjoint files per branch).

## Default CAD loop (executing)

```
create_cad (stub) → patch_file (iterate)
→ validate_script
→ orient_cad / spatial_thinking (after placement changes)
→ probe_model only for math orient cannot give
→ update_overview last
```

**OEL / spatial gate:** After validate, before placement `patch_file`, read `orient.gates` in tool results. If blocked, run `spatial_thinking` or `orient_cad` — do not argue around the gate.

## Tool cheat sheet

| Tool | When |
|------|------|
| `/xyzt` API reference | Sandbox globals before large CAD builds |
| `create_cad` / `patch_file` | Author `.xyzt` / `.xyzt.eda` / etc. |
| `validate_script` | After script changes; trust `ok: true` |
| `orient_cad` | Preferred spatial read on a file |
| `spatial_thinking` | Layout report when orient unavailable |
| `run_script` | Quick execute without full agent patch cycle |
| `get_simulation_backends` | Before promising FEA/CFD |
| `run_simulation` | Only listed backends |
| `explain_diagnostics` | User-facing failure explanation |
| `update_plan` | Structured multi-step plan (planning phase) |
| `update_overview` | README last, when model is real |

## Functional rules

1. Scripts **return** the domain object (last line).
2. No imports — globals only (`use()` for other `.xyzt`).
3. No `await` on sync CAD geometry.
4. Reassign: `part = part.translate(...)`.
5. Never claim “done” without tool JSON showing success.
6. On error: fix and **retry the tool** — do not narrate a fix without calling tools.

## Honest limits (do not fake)

Partial: parametric solids, board schematic, static FEA, CFD thermal, scene orchestration (check snapshot).

Missing / not real: high-speed SI EDA, SPICE solve, proprietary native CAD edit.

## Parallel execution (desktop)

When **parallel agents** is on, todos whose dependencies are `done` may run in concurrent streams (cap 3). Give parallel branches **different target files**. When off, one todo at a time in DAG order.

## Schemas

Use validators in xyzt-core: `ProjectManifestV0`, `SimulationJsonV0`, `SceneJsonV0`, `ResultBundleV0` — no invented fields.

## Related skills

| Skill | Domain |
|-------|--------|
| `/xyzt` | `.xyzt` language reference |
| `/xyzt-make-cad-model` | Assemblies, contracts |
| `/xyzt-make-eda` | `.xyzt.eda` |
| `/xyzt-make-drawing` | `.xyzt.draft` |
| `/xyzt-make-simulation` | `.xyzt.simulation` |
| `/xyzt-validate` | Verification checklist |
