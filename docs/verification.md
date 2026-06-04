# Verification

| Layer | Command | What it proves |
|-------|---------|----------------|
| Agent runtime | `pnpm agent:gate` | Vitest, tool goldens, contract check (55 runtime tools ↔ registry ↔ parity) |
| Tool package | `pnpm --filter xyzt-agent-tools test` | SSOT names, transcript fixtures |
| Engine (submodule) | `cd vendor/xyzt-core && pnpm test` | CAD/EDA/sim truth (advisory on pin) |

## Golden transcript IDs

- `rp-1-electromechanical` — CAD validate / run / verify profile
- `eda-lcsc-place-verify` — EDA workflow gates
- `hw-sim-smoke` — simulation backends + validate_simulation
- `hw-export-bundle` — STL + Gerber + BOM export path

## Manual dogfood (15 min)

1. Open `examples/rp-1-electromechanical` in CLI agent.
2. Ask: validate bracket, export STL, summarize.
3. Confirm tool results show `ok` / diagnostics, not raw script dumps.
