# RP-1 electromechanical wedge

Minimal reference project for the HW agent: one mechanical part script.

```bash
# From repo root (after pnpm build)
export XYZT_ACCESS_TOKEN="<jwt>"
export XYZT_AI_STREAM_URL="https://your-inference-host/ai/generate"

pnpm agent -- --folder examples/rp-1-electromechanical --prompt "Validate bracket.xyzt and suggest EDA next steps"
```

Golden transcript: `packages/xyzt-agent-tools/goldens/rp-1-electromechanical-transcript.json`
