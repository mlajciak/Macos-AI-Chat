# HW engineering agent

Standalone **full-stack hardware engineering** agent runtime (`@xyzt/agent`): CAD + EDA + simulation + exports, with workflow gates and golden transcripts.

## Principal loop

```
Planning  → get_capabilities, validate_project, build_project_run_plan
Author    → create_cad | create_eda | create_simulation + patch_file
Validate  → validate_script | verify_eda | validate_simulation (+ orient_cad, run_drc)
Export    → export_stl | export_step | export_gerber_bundle | export_bom | run_verify_profile
Ship      → update_overview (only after gates pass)
```

## Non-negotiables

- **No script in chat** — use `create_*` and `patch_file` only.
- **EDA** — `circuit().constraints(...)` + `edaPlacement()`; run `verify_eda` after every EDA mutation.
- **Simulation** — `validate_simulation` before `run_simulation`.
- **CAD assemblies** — mates / `placementSpec()` + `solve()`, not guessed `at:[x,y,z]`.

## Skills

| Skill | Path |
|-------|------|
| Orchestrator | [skills/hw-engineering/SKILL.md](skills/hw-engineering/SKILL.md) |
| CAD | [skills/xyzt/SKILL.md](skills/xyzt/SKILL.md) |
| EDA | [skills/xyzt-make-eda/SKILL.md](skills/xyzt-make-eda/SKILL.md) |
| Simulation | [skills/xyzt-make-simulation/SKILL.md](skills/xyzt-make-simulation/SKILL.md) |
| Validate / export | [skills/xyzt-validate/SKILL.md](skills/xyzt-validate/SKILL.md) |

## Verify

```bash
pnpm agent:gate
```

See [docs/verification.md](docs/verification.md).

## CLI

```bash
export XYZT_ACCESS_TOKEN="<jwt>"
export XYZT_AI_STREAM_URL="https://your-host/ai/generate"   # optional; default /ai/generate

xyzt-agent --folder examples/rp-1-electromechanical --prompt "Validate bracket and list next steps"
```

## Engine dependency

`xyzt-cad` lives in [vendor/xyzt-core](vendor/xyzt-core) (git submodule). Build engine before agent:

```bash
cd vendor/xyzt-core && pnpm install && pnpm build
cd ../.. && pnpm install && pnpm build
```

Local dev without submodule: set `"xyzt-cad": "file:../xyzt/xyzt-core"` in `package.json`.
