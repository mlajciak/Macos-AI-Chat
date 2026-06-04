# xyzt-agent

Standalone **full-stack hardware engineering** agent runtime for XYZT projects: mechanical CAD, EDA, simulation, exports, and workflow gates.

## Quick start

```bash
# 1. Engine (submodule symlink or clone)
git submodule update --init --recursive   # when remote configured
# Local dev: vendor/xyzt-core → ../xyzt/xyzt-core (see .gitmodules)

cd vendor/xyzt-core && pnpm install && pnpm build
cd ../..

# 2. Agent
pnpm install
pnpm build
pnpm agent:gate
```

## CLI folder agent

```bash
export XYZT_ACCESS_TOKEN="<jwt>"
export XYZT_AI_STREAM_URL="https://your-host/ai/generate"   # optional

pnpm agent -- --folder examples/rp-1-electromechanical --prompt "Validate the bracket"
```

| Variable | Required | Description |
|----------|----------|-------------|
| `XYZT_ACCESS_TOKEN` | yes | JWT for cloud inference stream |
| `XYZT_AI_STREAM_URL` | no | SSE endpoint (default `/ai/generate` for desktop proxy) |

## Layout

| Path | Purpose |
|------|---------|
| `src/` | Tool loop, workflow gates, executors |
| `packages/xyzt-agent-tools/` | Tool names, parity, goldens |
| `vendor/xyzt-core/` | `xyzt-cad` engine (submodule) |
| `skills/` | Cursor / agent playbooks |
| `AGENTS.md` | Principal loop for coding agents |

## Sync from monorepo

Until this repo is wired as a git submodule inside `xyzt`:

```bash
pnpm sync:monorepo
# or: node scripts/sync-from-monorepo.mjs ~/Desktop/xyzt
```

## Deferred (not v1)

- Cloud `ai-stream` schema codegen parity
- MCP server
- RP-2 complex PCB vertical
- Hosted team agent / billing

## License

Engine (`xyzt-cad`) is UNLICENSED private; this runtime is private.
