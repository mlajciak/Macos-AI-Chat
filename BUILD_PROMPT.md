═══════════════════════════════════════════════════════════════════════════════════════════════════════
                                    XYZT AGENT SWARM REBUILD PROMPT
                              Complete Physical AI Design Platform — 4-Hour Build
═══════════════════════════════════════════════════════════════════════════════════════════════════════

YOU ARE THE XYZT ARCHITECT. You have FULL AUTHORITY to redesign, restructure, and rewrite 
any existing code. Do not preserve broken patterns. Do not cargo-cult existing mistakes. 
Build from first principles. The goal is a working, demo-ready XYZT platform in 4 hours.

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 0: EXECUTIVE MANDATE
═══════════════════════════════════════════════════════════════════════════════════════════════════════

MISSION: Build XYZT — a physical AI design platform that generates native engineering files 
(STEP, KiCad, URDF, STL, 3MF, FCStd) from natural language descriptions, with ZERO complex UI, 
ZERO scripts for the user, and a 5-minute turnaround per design.

PHILOSOPHY: "Files, not workflows." The user types a description and gets a ZIP of native files. 
No CAD skills needed. No SolidWorks workflow. No Fusion timeline. Just input → files.

NON-NEGOTIABLE CONSTRAINTS:
  1. Build time: 4 hours maximum
  2. No complex UI: One input, one button, one ZIP
  3. Native files only: STEP, KiCad, URDF, STL, 3MF, FCStd — no scripts, no templates
  4. Generative: AI does 95% of the work, user provides minimal input
  5. Fast test loop: <5 minutes from prompt to downloadable files
  6. TypeScript/Node 22+, ES modules, pnpm workspace
  7. Three-layer architecture (see below)

YOU HAVE PERMISSION TO:
  → Delete any existing code that doesn't serve the mission
  → Restructure directories however you see fit
  → Replace any library with a better alternative
  → Skip "nice-to-have" features that aren't demo-critical
  → Hardcode demo data if it makes the 4-hour deadline
  → Use any API (Claude, OpenAI, etc.) with the provided keys

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 1: THREE-LAYER ARCHITECTURE
═══════════════════════════════════════════════════════════════════════════════════════════════════════

LAYER 1: xyzt-core (The Truth Layer)
─────────────────────────────────────────────────────────────────────────────────────────────────────
Location: packages/xyzt-core/
Purpose: Geometry, EDA, and simulation truth. The canonical representation of all designs.

Responsibilities:
  • Body Plan Schema: JSON schema for robot descriptions (kinematics, dynamics, electronics, materials)
  • CAD Engine: CadQuery 2.x integration for parametric BRep generation → native STEP export
  • EDA Engine: SKiDL 2.2.3 integration for schematic + PCB generation → native KiCad files
  • Mesh Engine: trimesh integration for tessellation → STL, OBJ, 3MF export
  • Sim Engine: urdfpy integration for robot description → native URDF/SDF export
  • FreeCAD Bridge: FreeCAD Python API for parametric FCStd export
  • Validation: File integrity checks (STEP BRep valid, KiCad DRC clean, URDF parseable, mesh watertight)
  • Cost Engine: BOM generation with supplier links (DigiKey, Mouser, JLCPCB)

Key Files:
  • packages/xyzt-core/src/schema/body-plan.ts — BodyPlan type definition, Zod validation
  • packages/xyzt-core/src/cad/cad-engine.ts — CadQuery wrapper, STEP/FCStd generation
  • packages/xyzt-core/src/eda/eda-engine.ts — SKiDL wrapper, KiCad generation
  • packages/xyzt-core/src/mesh/mesh-engine.ts — trimesh wrapper, STL/3MF generation
  • packages/xyzt-core/src/sim/sim-engine.ts — urdfpy wrapper, URDF/SDF generation
  • packages/xyzt-core/src/validate/validators.ts — File validation pipeline
  • packages/xyzt-core/src/cost/bom-engine.ts — BOM + cost estimation

Implementation Notes:
  • CadQuery runs in a Docker container or Python subprocess (it's Python)
  • Use python-shell or similar for Node → Python bridge
  • Each engine is idempotent: same input → same output
  • Engines are pure functions: no side effects, no global state
  • Cache intermediate results (body plan → engines can reuse)

LAYER 2: @xyzt/agent (The Runtime Layer)
─────────────────────────────────────────────────────────────────────────────────────────────────────
Location: packages/xyzt-agent/
Purpose: Tool loop, workflow gates, orchestration. The brain that coordinates Layer 1.

Responsibilities:
  • Prompt Parser: Takes natural language → structured BodyPlan (via Claude 4.6 or local LLM)
  • Tool Registry: 55+ tool names with parity to golden transcripts
  • Workflow Gates: Enforce design rules (e.g., verify_eda before more EDA edits)
  • Parallel Execution: Spawn agents for CAD, EDA, Mesh, Sim simultaneously
  • Validation Pipeline: Run all validators before packaging
  • Export Bundler: ZIP generation with all native files + README + previews
  • Progress Tracking: SSE or WebSocket progress updates to frontend

Key Files:
  • packages/xyzt-agent/src/parser/prompt-parser.ts — LLM prompt engineering, structured output
  • packages/xyzt-agent/src/tools/tool-registry.ts — Tool definitions, parity check
  • packages/xyzt-agent/src/gates/workflow-gates.ts — Gate logic (PEL: Pre-Export Lock, OEL: Open Export Lock)
  • packages/xyzt-agent/src/orchestrator/parallel-agent.ts — Parallel execution coordinator
  • packages/xyzt-agent/src/validate/validation-pipeline.ts — Run all validators
  • packages/xyzt-agent/src/export/zip-bundler.ts — ZIP packaging
  • packages/xyzt-agent/src/runtime/agent-loop.ts — Main tool loop

Implementation Notes:
  • Agent scripts are JavaScript in a sandbox, NOT arbitrary Node in tools
  • Use vm2 or isolated-vm for sandboxing agent scripts
  • Tool loop: while (not_done) { observe → think → act → validate }
  • Workflow gates are declarative: JSON rules, not imperative code
  • Cloud inference optional: if XYZT_AI_STREAM_URL is set, use SSE; else use local LLM

LAYER 3: xyzt-agent-tools (The Tool Layer)
─────────────────────────────────────────────────────────────────────────────────────────────────────
Location: packages/xyzt-agent-tools/
Purpose: 55 runtime tool names, parity with golden transcripts, tool implementations.

Responsibilities:
  • Tool Definitions: Each tool has name, schema, handler, validator
  • Golden Transcripts: Expected input/output pairs for regression testing
  • Tool Parity: Contract check that all tools in registry match parity.json
  • Tool Categories:
    - Authoring: create_cad, create_eda, patch_file, delete_file, etc.
    - Validation: validate_script, verify_eda, verify_cad, verify_mesh, verify_sim
    - Export: export_step, export_kicad, export_urdf, export_stl, export_3mf, export_fcstd
    - Query: query_body_plan, query_bom, query_sim_results, query_validation
    - Meta: list_tools, describe_tool, check_parity, run_smoke_test

Key Files:
  • packages/xyzt-agent-tools/src/registry.ts — Tool registry, all 55 tools
  • packages/xyzt-agent-tools/src/tools/authoring/*.ts — Authoring tools
  • packages/xyzt-agent-tools/src/tools/validation/*.ts — Validation tools
  • packages/xyzt-agent-tools/src/tools/export/*.ts — Export tools
  • packages/xyzt-agent-tools/src/transcripts/golden.ts — Golden transcript definitions
  • packages/xyzt-agent-tools/src/parity/parity.json — Tool parity manifest

Implementation Notes:
  • Each tool is a class implementing Tool interface: name, schema, execute(), validate()
  • Tools are self-describing: schema includes input/output types, examples, errors
  • Golden transcripts are TypeScript objects, not JSON files (type safety)
  • Parity check: pnpm agent:gate runs Vitest against golden transcripts

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 2: PROJECT STRUCTURE
═══════════════════════════════════════════════════════════════════════════════════════════════════════

xyzt/
├── package.json                    # Root workspace, pnpm workspaces config
├── pnpm-workspace.yaml             # Workspace definition
├── tsconfig.json                   # Root TypeScript config
├── vitest.config.ts               # Test config
├── .env.example                    # Environment variables template
├── docker-compose.yml              # CadQuery, FreeCAD, KiCad containers
│
├── packages/
│   ├── xyzt-core/                  # LAYER 1: Truth (geometry, EDA, sim)
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── src/
│   │   │   ├── index.ts            # Public API
│   │   │   ├── schema/
│   │   │   │   ├── body-plan.ts    # BodyPlan type, Zod schema
│   │   │   │   ├── cad-schema.ts   # CAD-specific types
│   │   │   │   ├── eda-schema.ts   # EDA-specific types
│   │   │   │   └── index.ts        # Schema exports
│   │   │   ├── cad/
│   │   │   │   ├── cad-engine.ts   # CadQuery wrapper
│   │   │   │   ├── step-exporter.ts # STEP export logic
│   │   │   │   ├── fcstd-exporter.ts # FCStd export logic
│   │   │   │   └── index.ts
│   │   │   ├── eda/
│   │   │   │   ├── eda-engine.ts   # SKiDL wrapper
│   │   │   │   ├── kicad-exporter.ts # KiCad export logic
│   │   │   │   ├── bom-generator.ts # BOM generation
│   │   │   │   └── index.ts
│   │   │   ├── mesh/
│   │   │   │   ├── mesh-engine.ts  # trimesh wrapper
│   │   │   │   ├── stl-exporter.ts # STL export
│   │   │   │   ├── threemf-exporter.ts # 3MF export
│   │   │   │   └── index.ts
│   │   │   ├── sim/
│   │   │   │   ├── sim-engine.ts   # urdfpy wrapper
│   │   │   │   ├── urdf-exporter.ts # URDF export
│   │   │   │   ├── sdf-exporter.ts # SDF export
│   │   │   │   └── index.ts
│   │   │   ├── validate/
│   │   │   │   ├── validators.ts   # All validators
│   │   │   │   ├── step-validator.ts
│   │   │   │   ├── kicad-validator.ts
│   │   │   │   ├── urdf-validator.ts
│   │   │   │   ├── mesh-validator.ts
│   │   │   │   └── index.ts
│   │   │   └── cost/
│   │   │       ├── bom-engine.ts   # Cost estimation
│   │   │       └── index.ts
│   │   └── tests/                  # Unit tests for each engine
│   │
│   ├── xyzt-agent/                 # LAYER 2: Runtime (orchestration)
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── src/
│   │   │   ├── index.ts            # Public API
│   │   │   ├── parser/
│   │   │   │   ├── prompt-parser.ts # LLM prompt → BodyPlan
│   │   │   │   ├── prompt-templates.ts # Prompt engineering templates
│   │   │   │   └── index.ts
│   │   │   ├── tools/
│   │   │   │   ├── tool-registry.ts # Tool registry
│   │   │   │   ├── tool-interface.ts # Tool interface definition
│   │   │   │   └── index.ts
│   │   │   ├── gates/
│   │   │   │   ├── workflow-gates.ts # Gate logic
│   │   │   │   ├── pel-gate.ts      # Pre-Export Lock
│   │   │   │   ├── oel-gate.ts      # Open Export Lock
│   │   │   │   └── index.ts
│   │   │   ├── orchestrator/
│   │   │   │   ├── parallel-agent.ts # Parallel execution
│   │   │   │   ├── agent-loop.ts    # Main loop
│   │   │   │   └── index.ts
│   │   │   ├── validate/
│   │   │   │   ├── validation-pipeline.ts # Run all validators
│   │   │   │   └── index.ts
│   │   │   ├── export/
│   │   │   │   ├── zip-bundler.ts   # ZIP packaging
│   │   │   │   ├── preview-generator.ts # Preview images
│   │   │   │   └── index.ts
│   │   │   └── runtime/
│   │   │       ├── agent-loop.ts    # Main runtime loop
│   │   │       ├── sse-server.ts    # SSE progress updates
│   │   │       └── index.ts
│   │   └── tests/                  # Integration tests, golden transcripts
│   │
│   ├── xyzt-agent-tools/           # LAYER 3: Tools (55 tools)
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── src/
│   │   │   ├── index.ts            # Public API
│   │   │   ├── registry.ts         # Tool registry (all 55 tools)
│   │   │   ├── tools/
│   │   │   │   ├── authoring/      # create_cad, create_eda, patch_file, etc.
│   │   │   │   ├── validation/     # verify_eda, verify_cad, etc.
│   │   │   │   ├── export/         # export_step, export_kicad, etc.
│   │   │   │   ├── query/          # query_body_plan, query_bom, etc.
│   │   │   │   └── meta/           # list_tools, check_parity, etc.
│   │   │   ├── transcripts/
│   │   │   │   ├── golden.ts       # Golden transcript definitions
│   │   │   │   ├── rp1-transcript.ts # RP-1 smoke test
│   │   │   │   ├── eda-transcript.ts # EDA golden
│   │   │   │   └── index.ts
│   │   │   └── parity/
│   │   │       ├── parity.json     # Tool parity manifest
│   │   │       └── parity-checker.ts # Contract check
│   │   └── tests/                  # Tool parity tests, Vitest
│   │
│   └── xyzt-web/                   # Frontend (minimal, demo-only)
│       ├── package.json
│       ├── tsconfig.json
│       ├── src/
│       │   ├── app/
│       │   │   ├── page.tsx        # Main page: one input, one button
│       │   │   ├── layout.tsx
│       │   │   └── api/
│       │   │       └── generate/
│       │   │           └── route.ts # API route for generation
│       │   ├── components/
│       │   │   ├── PromptInput.tsx  # Big text input
│       │   │   ├── GenerateButton.tsx
│       │   │   ├── ProgressBar.tsx
│       │   │   ├── PreviewGallery.tsx # File previews
│       │   │   └── DownloadButton.tsx
│       │   └── lib/
│       │       ├── api-client.ts    # Fetch wrapper
│       │       └── types.ts         # Frontend types
│       └── tests/
│
├── scripts/
│   ├── setup-python-env.sh         # Install CadQuery, SKiDL, etc.
│   ├── docker-build.sh             # Build Docker images
│   └── smoke-test.sh              # Run all smoke tests
│
├── docker/
│   ├── cadquery.Dockerfile         # CadQuery + pythonOCC container
│   ├── kicad.Dockerfile            # KiCad headless container
│   └── freecad.Dockerfile          # FreeCAD headless container
│
└── docs/
    ├── ARCHITECTURE.md             # This architecture doc
    ├── API.md                      # API documentation
    └── TOOLS.md                    # Tool reference (55 tools)


═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 3: CORE DATA SCHEMAS
═══════════════════════════════════════════════════════════════════════════════════════════════════════

BODY PLAN SCHEMA (Zod):
─────────────────────────────────────────────────────────────────────────────────────────────────────

The BodyPlan is the canonical representation of a robot design. All engines consume this.

```typescript
// packages/xyzt-core/src/schema/body-plan.ts
import { z } from 'zod';

export const JointSchema = z.object({
  name: z.string(),
  type: z.enum(['revolute', 'prismatic', 'fixed', 'continuous', 'planar', 'floating']),
  parent: z.string(),
  child: z.string(),
  axis: z.tuple([z.number(), z.number(), z.number()]).default([0, 0, 1]),
  origin: z.object({
    xyz: z.tuple([z.number(), z.number(), z.number()]).default([0, 0, 0]),
    rpy: z.tuple([z.number(), z.number(), z.number()]).default([0, 0, 0]),
  }),
  limits: z.object({
    lower: z.number().default(-3.14),
    upper: z.number().default(3.14),
    effort: z.number().default(10),
    velocity: z.number().default(1),
  }).optional(),
  damping: z.number().default(0.1),
  friction: z.number().default(0.1),
});

export const LinkSchema = z.object({
  name: z.string(),
  mass: z.number().positive(),
  inertia: z.object({
    ixx: z.number(), ixy: z.number(), ixz: z.number(),
    iyy: z.number(), iyz: z.number(), izz: z.number(),
  }),
  geometry: z.object({
    type: z.enum(['box', 'cylinder', 'sphere', 'mesh', 'capsule']),
    dimensions: z.union([
      z.tuple([z.number(), z.number(), z.number()]), // box: [x, y, z]
      z.tuple([z.number(), z.number()]),             // cylinder: [radius, length]
      z.tuple([z.number()]),                         // sphere: [radius]
    ]),
  }),
  material: z.object({
    name: z.string(),
    color: z.tuple([z.number(), z.number(), z.number(), z.number()]).optional(),
    density: z.number().optional(),
  }),
  collision: z.object({
    type: z.enum(['box', 'cylinder', 'sphere', 'mesh']),
    dimensions: z.array(z.number()),
  }).optional(),
});

export const SensorSchema = z.object({
  name: z.string(),
  type: z.enum(['camera', 'lidar', 'imu', 'force', 'gps', 'encoder', 'touch']),
  parent: z.string(),
  origin: z.object({
    xyz: z.tuple([z.number(), z.number(), z.number()]),
    rpy: z.tuple([z.number(), z.number(), z.number()]),
  }),
  specs: z.record(z.any()).optional(), // sensor-specific parameters
});

export const ActuatorSchema = z.object({
  name: z.string(),
  type: z.enum(['servo', 'dc_motor', 'stepper', 'linear', 'hydraulic']),
  count: z.number().int().positive(),
  specs: z.object({
    torque_nm: z.number().optional(),
    speed_rpm: z.number().optional(),
    voltage_v: z.number().optional(),
    current_a: z.number().optional(),
    brand: z.string().optional(),
    model: z.string().optional(),
  }),
});

export const ElectronicsSchema = z.object({
  compute: z.object({
    board: z.enum(['jetson_nano', 'jetson_orin', 'raspberry_pi', 'stm32', 'teensy', 'esp32']),
    power_w: z.number().positive(),
  }),
  power: z.object({
    battery_type: z.enum(['lipo_4s', 'lipo_6s', 'liion', 'nimh']),
    capacity_mah: z.number().positive(),
    voltage_v: z.number().positive(),
    estimated_runtime_h: z.number().positive(),
  }),
  communication: z.array(z.enum(['wifi', 'bluetooth', 'can', 'uart', 'i2c', 'spi', 'ethernet'])),
  sensors: z.array(SensorSchema),
});

export const BodyPlanSchema = z.object({
  name: z.string().min(1).max(100),
  version: z.string().default('1.0.0'),
  description: z.string().optional(),

  locomotion: z.object({
    type: z.enum(['quadruped', 'biped', 'wheeled', 'tracked', 'flying', 'swimming', 'static']),
    stability: z.enum(['static', 'dynamic', 'passive']).default('dynamic'),
    gait: z.enum(['walk', 'trot', 'gallop', 'crawl', 'roll', 'fly']).optional(),
  }),

  payload: z.object({
    mass_kg: z.number().positive(),
    volume_l: z.number().positive().optional(),
    securement: z.string().optional(),
  }),

  environment: z.object({
    terrain: z.array(z.enum(['flat', 'carpet', 'tile', 'rubble', 'stairs', 'mud', 'water', 'air'])),
    obstacles: z.enum(['none', 'static', 'dynamic', 'cluttered']).default('none'),
    weather: z.array(z.enum(['indoor', 'outdoor', 'rain', 'dust', 'extreme_temp'])).optional(),
  }),

  dimensions: z.object({
    max_length_cm: z.number().positive(),
    max_width_cm: z.number().positive(),
    max_height_cm: z.number().positive(),
    min_clearance_cm: z.number().positive().optional(),
  }),

  mass_budget_kg: z.number().positive(),

  links: z.array(LinkSchema),
  joints: z.array(JointSchema),
  actuators: z.array(ActuatorSchema),
  electronics: ElectronicsSchema,

  materials: z.array(z.object({
    name: z.string(),
    type: z.enum(['aluminum', 'steel', 'carbon_fiber', 'titanium', 'plastic', 'wood', 'composite']),
    application: z.string().optional(),
  })),

  estimated_cost_usd: z.number().positive(),

  metadata: z.object({
    generated_at: z.string().datetime(),
    generator_version: z.string(),
    llm_model: z.string().optional(),
  }).optional(),
});

export type BodyPlan = z.infer<typeof BodyPlanSchema>;
export type Joint = z.infer<typeof JointSchema>;
export type Link = z.infer<typeof LinkSchema>;
export type Sensor = z.infer<typeof SensorSchema>;
export type Actuator = z.infer<typeof ActuatorSchema>;
export type Electronics = z.infer<typeof ElectronicsSchema>;
```

CAD SCHEMA:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```typescript
// packages/xyzt-core/src/schema/cad-schema.ts
export interface CadFeature {
  type: 'extrude' | 'revolve' | 'loft' | 'sweep' | 'boolean' | 'fillet' | 'hole' | 'mirror' | 'array';
  params: Record<string, number | string | boolean>;
  children?: CadFeature[];
}

export interface CadPart {
  name: string;
  features: CadFeature[];
  material: string;
  color: [number, number, number, number];
  mass_kg: number;
}

export interface CadAssembly {
  name: string;
  parts: CadPart[];
  constraints: Array<{
    type: 'mate' | 'align' | 'insert' | 'angle' | 'distance';
    part1: string;
    part2: string;
    params: Record<string, number>;
  }>;
}
```

EDA SCHEMA:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```typescript
// packages/xyzt-core/src/schema/eda-schema.ts
export interface Component {
  ref: string;
  value: string;
  footprint: string;
  datasheet?: string;
  supplier_links?: Record<string, string>;
}

export interface Net {
  name: string;
  pins: Array<{ ref: string; pin: number }>;
}

export interface Schematic {
  components: Component[];
  nets: Net[];
  sheets: Array<{ name: string; components: string[] }>;
}

export interface PcbLayout {
  width_mm: number;
  height_mm: number;
  layers: number;
  components: Array<{
    ref: string;
    x: number;
    y: number;
    rotation: number;
    layer: 'top' | 'bottom';
  }>;
  traces: Array<{
    net: string;
    points: Array<{ x: number; y: number; layer: number }>;
    width_mm: number;
  }>;
  vias: Array<{ x: number; y: number; from_layer: number; to_layer: number }>;
}
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 4: THE 55 TOOLS (Tool Registry)
═══════════════════════════════════════════════════════════════════════════════════════════════════════

AUTHORING TOOLS (15 tools):
─────────────────────────────────────────────────────────────────────────────────────────────────────
1. create_cad — Generate a new CAD part or assembly from description
2. create_eda — Generate a new schematic or PCB from description
3. patch_file — Apply a patch to an existing file (unified diff format)
4. delete_file — Delete a file from the project
5. move_file — Move/rename a file
6. create_directory — Create a directory structure
7. write_file — Write content to a file (overwrite)
8. append_file — Append content to a file
9. read_file — Read content of a file
10. list_directory — List files in a directory
11. search_files — Search for patterns across files
12. replace_in_file — Replace text in a file
13. create_symlink — Create a symbolic link
14. copy_file — Copy a file
15. run_command — Execute a shell command (sandboxed)

VALIDATION TOOLS (12 tools):
─────────────────────────────────────────────────────────────────────────────────────────────────────
16. validate_script — Validate a JavaScript/TypeScript script for syntax errors
17. verify_cad — Validate a CAD file (STEP, FCStd) for integrity
18. verify_eda — Validate EDA files (KiCad) for DRC errors
19. verify_mesh — Validate mesh files (STL, OBJ, 3MF) for watertightness
20. verify_sim — Validate simulation files (URDF, SDF) for parse errors
21. verify_body_plan — Validate a BodyPlan JSON against schema
22. check_bom — Verify BOM completeness and cost accuracy
23. run_unit_test — Run a specific unit test
24. run_integration_test — Run an integration test
25. run_smoke_test — Run a smoke test (RP-1, EDA, sim, export)
26. check_parity — Verify tool registry matches parity.json
27. lint_project — Run linter on the codebase

EXPORT TOOLS (10 tools):
─────────────────────────────────────────────────────────────────────────────────────────────────────
28. export_step — Export CAD to STEP format
29. export_kicad — Export EDA to KiCad format (.kicad_sch, .kicad_pcb)
30. export_urdf — Export simulation to URDF format
31. export_sdf — Export simulation to SDF format
32. export_stl — Export mesh to STL format
33. export_3mf — Export mesh to 3MF format
34. export_fcstd — Export CAD to FreeCAD native format
35. export_obj — Export mesh to OBJ format
36. export_zip — Bundle all exports into a ZIP file
37. export_readme — Generate README.md with assembly instructions

QUERY TOOLS (10 tools):
─────────────────────────────────────────────────────────────────────────────────────────────────────
38. query_body_plan — Get the current BodyPlan JSON
39. query_bom — Get the current Bill of Materials
40. query_cad — Get CAD file paths and metadata
41. query_eda — Get EDA file paths and metadata
42. query_sim — Get simulation results and metrics
43. query_mesh — Get mesh file paths and metadata
44. query_validation — Get validation results
45. query_cost — Get cost breakdown
46. query_progress — Get generation progress (for SSE)
47. query_history — Get action history

META TOOLS (8 tools):
─────────────────────────────────────────────────────────────────────────────────────────────────────
48. list_tools — List all available tools
49. describe_tool — Get detailed description of a tool
50. get_tool_schema — Get JSON schema for a tool
51. set_workflow_gate — Set a workflow gate condition
52. clear_workflow_gate — Clear a workflow gate
53. get_system_status — Get overall system health
54. get_logs — Get recent logs
55. reset_state — Reset agent state (dangerous, requires confirmation)

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 5: WORKFLOW GATES (PEL/OEL)
═══════════════════════════════════════════════════════════════════════════════════════════════════════

GATE DEFINITIONS:
─────────────────────────────────────────────────────────────────────────────────────────────────────

Pre-Export Lock (PEL):
  • Trigger: Before any export_* tool can run
  • Condition: ALL validators must pass (verify_cad, verify_eda, verify_mesh, verify_sim)
  • Action: If any validator fails, block export and return error with fix suggestions
  • Override: Requires explicit confirmation with override_pel flag

Open Export Lock (OEL):
  • Trigger: After successful export
  • Condition: Export files must exist and be non-empty
  • Action: Lock further edits until user confirms they want to modify exported files
  • Purpose: Prevents accidental overwrites of shipped files

EDA Gate:
  • Trigger: Before create_eda or patch_file on EDA files
  • Condition: verify_eda must pass on existing files (if they exist)
  • Action: If DRC fails, block edits and show DRC errors

CAD Gate:
  • Trigger: Before create_cad or patch_file on CAD files
  • Condition: verify_cad must pass on existing files
  • Action: If BRep is invalid, block edits and show repair suggestions

Gate Implementation:
```typescript
// packages/xyzt-agent/src/gates/workflow-gates.ts
export interface Gate {
  name: string;
  trigger: string; // tool name or pattern
  condition: () => Promise<boolean>;
  action: 'block' | 'warn' | 'allow';
  message: string;
  overrideable: boolean;
}

export const DEFAULT_GATES: Gate[] = [
  {
    name: 'PEL',
    trigger: 'export_*',
    condition: async () => {
      const cad = await verifyCad();
      const eda = await verifyEda();
      const mesh = await verifyMesh();
      const sim = await verifySim();
      return cad && eda && mesh && sim;
    },
    action: 'block',
    message: 'Pre-Export Lock: All validators must pass before export.',
    overrideable: true,
  },
  // ... more gates
];
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 6: PROMPT PARSER (LLM Integration)
═══════════════════════════════════════════════════════════════════════════════════════════════════════

PROMPT ENGINEERING TEMPLATE:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```typescript
// packages/xyzt-agent/src/parser/prompt-templates.ts
export const BODY_PLAN_PROMPT = `You are a robotics engineer. Convert the user's description into a structured BodyPlan JSON.

User Description: {user_description}

Constraints:
- Mass budget must be realistic for the locomotion type
- Actuator count must match joint count (1:1 for revolute/prismatic)
- Electronics must support all sensors and actuators
- Cost estimate must be within 20% of realistic component costs

Output a valid BodyPlan JSON matching this schema exactly:
{schema_description}

Rules:
1. Generate ALL required fields
2. Use realistic values (not placeholder numbers)
3. Ensure joint limits are physically plausible
4. Include at least 1 sensor per major function (navigation, manipulation, safety)
5. Cost estimate should include: actuators ($50-200 each), compute ($100-500), sensors ($20-100 each), structure ($100-500), battery ($50-200)
6. Return ONLY the JSON, no markdown, no explanation
`;

export const CAD_PROMPT = `You are a CAD engineer. Convert this BodyPlan into a CadAssembly JSON.

BodyPlan: {body_plan_json}

Generate:
1. Chassis part (box extrusion with mounting holes)
2. One part per link in the body plan
3. Joint mounts (cylindrical features with bearing seats)
4. Assembly constraints (mate, align, insert)

Output CadAssembly JSON. Return ONLY JSON.`;

export const EDA_PROMPT = `You are an electronics engineer. Convert this BodyPlan into Schematic and PcbLayout JSON.

BodyPlan: {body_plan_json}

Generate:
1. Power section: battery, regulators, protection circuits
2. Motor drivers: one per actuator type
3. MCU section: microcontroller, communication interfaces
4. Sensor interfaces: one per sensor in body plan
5. PCB layout: board size from chassis dimensions, component placement, auto-routing

Output { schematic: Schematic, pcb: PcbLayout } JSON. Return ONLY JSON.`;
```

LLM CONFIGURATION:
─────────────────────────────────────────────────────────────────────────────────────────────────────

Primary: Claude 4.6 Sonnet (via Anthropic API)
  • Model: claude-4-6-sonnet-20250601
  • Max tokens: 4096
  • Temperature: 0.2 (low creativity for structured output)
  • System prompt: "You are a precise robotics engineer. Output only valid JSON."

Fallback: OpenAI GPT-5.4 (via OpenAI API)
  • Model: gpt-5.4-turbo
  • Max tokens: 4096
  • Temperature: 0.2
  • Response format: { type: "json_object" }

Local Fallback: Ollama with Llama 4 (if cloud unavailable)
  • Model: llama4:70b
  • Temperature: 0.2

Environment Variables:
  • XYZT_AI_PROVIDER: "anthropic" | "openai" | "ollama" | "auto"
  • XYZT_ANTHROPIC_API_KEY: Anthropic API key
  • XYZT_OPENAI_API_KEY: OpenAI API key
  • XYZT_AI_STREAM_URL: SSE endpoint for streaming (optional)
  • XYZT_ACCESS_TOKEN: Authentication token for cloud inference


═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 7: PYTHON BRIDGE (Node ↔ Python)
═══════════════════════════════════════════════════════════════════════════════════════════════════════

ARCHITECTURE:
─────────────────────────────────────────────────────────────────────────────────────────────────────

Node.js (TypeScript) orchestrates, Python engines execute.

Communication:
  • Method: Python subprocess via python-shell or child_process.spawn
  • Protocol: JSON-RPC over stdin/stdout
  • Error handling: Python exceptions → JSON error objects
  • Timeout: 30 seconds per engine call (configurable)
  • Parallel: Each engine runs in its own Python process

Python Environment:
  • Managed by: scripts/setup-python-env.sh
  • Virtual env: .venv/ in project root
  • Packages: cadquery, skidl, trimesh, urdfpy, numpy-stl, pymeshlab, numpy, scipy
  • Docker: Each engine can run in its own container (cadquery.Dockerfile, etc.)

Node.js Bridge Implementation:
```typescript
// packages/xyzt-core/src/python-bridge.ts
import { PythonShell } from 'python-shell';

export interface PythonEngine {
  name: string;
  scriptPath: string;
  pythonPath: string;
  timeout: number;
}

export async function runPythonEngine<T>(
  engine: PythonEngine,
  input: unknown
): Promise<T> {
  const options = {
    mode: 'json',
    pythonPath: engine.pythonPath,
    pythonOptions: ['-u'], // unbuffered
    scriptPath: engine.scriptPath,
    args: [JSON.stringify(input)],
    timeout: engine.timeout,
  };

  return new Promise((resolve, reject) => {
    const shell = new PythonShell('engine.py', options);
    let result: T | null = null;
    let error: string | null = null;

    shell.on('message', (message) => {
      if (message.type === 'result') {
        result = message.data;
      } else if (message.type === 'error') {
        error = message.error;
      }
    });

    shell.on('error', (err) => {
      reject(new Error(`Python engine ${engine.name} error: ${err.message}`));
    });

    shell.end((err) => {
      if (err) {
        reject(new Error(`Python engine ${engine.name} failed: ${err.message}`));
      } else if (error) {
        reject(new Error(`Python engine ${engine.name} error: ${error}`));
      } else if (result === null) {
        reject(new Error(`Python engine ${engine.name} returned no result`));
      } else {
        resolve(result);
      }
    });
  });
}
```

Python Engine Template:
```python
# packages/xyzt-core/python/cad_engine.py
import sys
import json
import cadquery as cq

def main():
    input_data = json.loads(sys.argv[1])
    body_plan = input_data['body_plan']

    # Generate CAD
    assembly = generate_assembly(body_plan)

    # Export STEP
    step_path = input_data['output_dir'] + '/robot.step'
    assembly.save(step_path, 'STEP')

    # Return result
    result = {
        'type': 'result',
        'data': {
            'step_path': step_path,
            'part_count': len(assembly.parts),
            'mass_kg': calculate_mass(assembly),
        }
    }
    print(json.dumps(result))

def generate_assembly(body_plan):
    # CadQuery logic here
    pass

def calculate_mass(assembly):
    # Mass calculation
    pass

if __name__ == '__main__':
    main()
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 8: VALIDATION PIPELINE
═══════════════════════════════════════════════════════════════════════════════════════════════════════

VALIDATORS:
─────────────────────────────────────────────────────────────────────────────────────────────────────

1. BodyPlan Validator:
   • Schema compliance (Zod parse)
   • Physical plausibility (mass > 0, dimensions > 0)
   • Joint-link consistency (every joint references valid links)
   • Actuator-joint matching (actuator count >= joint count)
   • Power budget (electronics.power >= sum of all power draws)

2. STEP Validator:
   • File exists and is non-empty
   • BRep geometry is valid (pythonOCC check)
   • Assembly hierarchy is non-empty
   • No degenerate faces or edges

3. KiCad Validator:
   • .kicad_sch exists and is parseable
   • .kicad_pcb exists and is parseable
   • DRC check passes (no unconnected nets, no clearance violations)
   • BOM references are valid (all components have footprints)

4. URDF Validator:
   • XML is well-formed
   • All links referenced by joints exist
   • Joint limits are physically plausible
   • Mass properties are positive
   • Check with urdfpy.validate()

5. Mesh Validator:
   • File exists and is non-empty
   • Mesh is watertight (no holes)
   • No degenerate faces
   • Normals are consistent
   • Check with trimesh (mesh.is_watertight, mesh.is_winding_consistent)

6. 3MF Validator:
   • File exists and is valid 3MF (XML schema check)
   • Contains at least one mesh
   • Materials are defined (if present)

7. FCStd Validator:
   • File exists and is valid FreeCAD document
   • Contains at least one Part object
   • Spreadsheet is present (if parametric)

VALIDATION PIPELINE:
```typescript
// packages/xyzt-agent/src/validate/validation-pipeline.ts
export interface ValidationResult {
  validator: string;
  passed: boolean;
  errors: string[];
  warnings: string[];
  duration_ms: number;
}

export async function runValidationPipeline(
  files: Record<string, string>
): Promise<ValidationResult[]> {
  const validators = [
    validateBodyPlan,
    validateStep,
    validateKicad,
    validateUrdf,
    validateMesh,
    validate3mf,
    validateFcstd,
  ];

  const results = await Promise.all(
    validators.map(async (validator) => {
      const start = Date.now();
      try {
        const result = await validator(files);
        return { ...result, duration_ms: Date.now() - start };
      } catch (err) {
        return {
          validator: validator.name,
          passed: false,
          errors: [err.message],
          warnings: [],
          duration_ms: Date.now() - start,
        };
      }
    })
  );

  return results;
}
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 9: EXPORT BUNDLER (ZIP Generation)
═══════════════════════════════════════════════════════════════════════════════════════════════════════

ZIP STRUCTURE:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```
RobotName_v1.zip
├── README.md                       # Assembly instructions, BOM, links
├── body_plan.json                  # Canonical BodyPlan (editable)
│
├── cad/
│   ├── RobotName_v1.step           # Native STEP (SolidWorks, CATIA, NX)
│   ├── RobotName_v1.FCStd          # FreeCAD native (parametric)
│   └── preview_cad.png             # Rendered 3D view
│
├── electronics/
│   ├── RobotName_v1.kicad_sch      # KiCad schematic
│   ├── RobotName_v1.kicad_pcb      # KiCad PCB layout
│   ├── RobotName_v1.kicad_pro      # KiCad project
│   ├── RobotName_v1_BOM.csv        # Bill of Materials with DigiKey links
│   ├── gerbers/                    # Gerber files for fabrication
│   │   ├── RobotName_v1.gtl        # Top layer
│   │   ├── RobotName_v1.gbl        # Bottom layer
│   │   ├── RobotName_v1.gto        # Top overlay
│   │   └── ...
│   └── preview_pcb.png             # 2D PCB layout view
│
├── simulation/
│   ├── RobotName_v1.urdf           # ROS2 / Gazebo / Isaac Sim
│   ├── RobotName_v1.sdf            # Gazebo/Ignition simulation
│   └── preview_sim.png             # Gazebo screenshot
│
├── 3d_print/
│   ├── RobotName_v1.stl            # Standard mesh (all slicers)
│   ├── RobotName_v1.3mf             # Modern multi-material format
│   └── preview_mesh.png             # Mesh render
│
└── docs/
    ├── assembly.md                  # Step-by-step assembly guide
    ├── wiring.md                    # Wiring diagram and pinout
    ├── simulation_setup.md          # How to run simulation
    └── troubleshooting.md           # Common issues and fixes
```

README.md TEMPLATE:
```markdown
# RobotName_v1 — Generated by XYZT

## Description
[Auto-generated from user prompt]

## Specifications
- Locomotion: [type]
- Payload: [mass] kg
- Dimensions: [L] x [W] x [H] cm
- Mass: [mass] kg
- Estimated Cost: $[cost]

## Files Included
- **CAD**: Open `RobotName_v1.step` in SolidWorks, CATIA, NX, or FreeCAD
- **PCB**: Open `RobotName_v1.kicad_pcb` in KiCad, send to JLCPCB
- **Simulation**: Load `RobotName_v1.urdf` in Gazebo or Isaac Sim
- **3D Print**: Slice `RobotName_v1.stl` or `RobotName_v1.3mf` in Cura

## Assembly
1. [Step 1]
2. [Step 2]
...

## Bill of Materials
| Part | Qty | Supplier | Link | Price |
|------|-----|----------|------|-------|
| ... | ... | ... | ... | ... |

## Next Steps
- [ ] Order PCB from JLCPCB ($12 for 5 boards, 5-day turnaround)
- [ ] 3D print chassis and leg parts
- [ ] Assemble electronics
- [ ] Flash firmware and run simulation
- [ ] Iterate in XYZT: upload modified body_plan.json and regenerate

---
Generated by XYZT v1.0.0 on [date]
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 10: FRONTEND (Minimal UI)
═══════════════════════════════════════════════════════════════════════════════════════════════════════

DESIGN PRINCIPLES:
─────────────────────────────────────────────────────────────────────────────────────────────────────
1. ONE INPUT: Big, centered text area. No tabs, no menus, no sidebars.
2. ONE BUTTON: "Generate Robot Files". Prominent, primary color.
3. PROGRESS: Simple progress bar with 4 steps: Planning → Designing → Validating → Ready
4. PREVIEWS: Clickable thumbnails that expand. No 3D manipulator. Just rotate/zoom.
5. DOWNLOAD: One ZIP button. Individual file links below.

PAGE STRUCTURE (Next.js 14 App Router):
─────────────────────────────────────────────────────────────────────────────────────────────────────

```tsx
// packages/xyzt-web/src/app/page.tsx
export default function Home() {
  return (
    <main className="min-h-screen bg-zinc-950 text-white flex flex-col items-center justify-center p-8">
      <h1 className="text-4xl font-bold mb-2">XYZT</h1>
      <p className="text-zinc-400 mb-8">Robot files in 5 minutes. No CAD skills needed.</p>

      <PromptInput />
      <GenerateButton />
      <ProgressBar />
      <PreviewGallery />
      <DownloadSection />
    </main>
  );
}
```

COMPONENTS:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```tsx
// packages/xyzt-web/src/components/PromptInput.tsx
'use client';

import { useState } from 'react';

export function PromptInput() {
  const [prompt, setPrompt] = useState('');

  return (
    <textarea
      className="w-full max-w-2xl h-32 bg-zinc-900 border border-zinc-700 rounded-lg p-4 text-lg resize-none focus:outline-none focus:border-blue-500 transition-colors"
      placeholder="Describe your robot... e.g., 'A quadruped that delivers 5kg packages in a warehouse'"
      value={prompt}
      onChange={(e) => setPrompt(e.target.value)}
    />
  );
}
```

```tsx
// packages/xyzt-web/src/components/GenerateButton.tsx
'use client';

import { useState } from 'react';

export function GenerateButton({ onGenerate, disabled }: { onGenerate: () => void; disabled: boolean }) {
  return (
    <button
      onClick={onGenerate}
      disabled={disabled}
      className="mt-4 px-8 py-4 bg-blue-600 hover:bg-blue-500 disabled:bg-zinc-700 disabled:cursor-not-allowed rounded-lg font-semibold text-lg transition-colors"
    >
      {disabled ? 'Generating...' : 'Generate Robot Files'}
    </button>
  );
}
```

```tsx
// packages/xyzt-web/src/components/ProgressBar.tsx
'use client';

export function ProgressBar({ step, total }: { step: number; total: number }) {
  const steps = ['Planning', 'Designing', 'Validating', 'Ready'];

  return (
    <div className="w-full max-w-2xl mt-8">
      <div className="flex justify-between mb-2">
        {steps.map((s, i) => (
          <span key={s} className={`text-sm ${i < step ? 'text-blue-400' : 'text-zinc-600'}`}>
            {s}
          </span>
        ))}
      </div>
      <div className="w-full h-2 bg-zinc-800 rounded-full overflow-hidden">
        <div 
          className="h-full bg-blue-500 transition-all duration-500"
          style={{ width: `${(step / total) * 100}%` }}
        />
      </div>
    </div>
  );
}
```

```tsx
// packages/xyzt-web/src/components/PreviewGallery.tsx
'use client';

import { useState } from 'react';

interface PreviewFile {
  name: string;
  type: 'cad' | 'pcb' | 'sim' | 'mesh';
  url: string;
  format: string;
}

export function PreviewGallery({ files }: { files: PreviewFile[] }) {
  const [selected, setSelected] = useState<PreviewFile | null>(null);

  return (
    <div className="w-full max-w-4xl mt-8 grid grid-cols-2 md:grid-cols-4 gap-4">
      {files.map((file) => (
        <div 
          key={file.name}
          onClick={() => setSelected(file)}
          className="bg-zinc-900 border border-zinc-700 rounded-lg p-4 cursor-pointer hover:border-blue-500 transition-colors"
        >
          <img src={file.url} alt={file.name} className="w-full h-32 object-contain mb-2" />
          <p className="text-sm font-medium">{file.name}</p>
          <p className="text-xs text-zinc-500">{file.format}</p>
        </div>
      ))}

      {selected && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50" onClick={() => setSelected(null)}>
          <img src={selected.url} alt={selected.name} className="max-w-4xl max-h-[80vh] object-contain" />
        </div>
      )}
    </div>
  );
}
```

```tsx
// packages/xyzt-web/src/components/DownloadSection.tsx
'use client';

export function DownloadSection({ zipUrl, files }: { zipUrl: string; files: Array<{name: string, url: string}> }) {
  return (
    <div className="w-full max-w-2xl mt-8 p-6 bg-zinc-900 border border-zinc-700 rounded-lg">
      <a 
        href={zipUrl}
        download
        className="block w-full py-4 bg-green-600 hover:bg-green-500 rounded-lg text-center font-semibold text-lg transition-colors"
      >
        📦 Download All Files (.zip)
      </a>

      <div className="mt-4 grid grid-cols-2 gap-2">
        {files.map((file) => (
          <a 
            key={file.name}
            href={file.url}
            download
            className="text-sm text-blue-400 hover:text-blue-300 py-2 px-3 bg-zinc-800 rounded"
          >
            {file.name}
          </a>
        ))}
      </div>
    </div>
  );
}
```

API ROUTE:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```typescript
// packages/xyzt-web/src/app/api/generate/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { generateRobot } from '@xyzt/agent';

export async function POST(req: NextRequest) {
  const { prompt } = await req.json();

  if (!prompt || prompt.length < 10) {
    return NextResponse.json({ error: 'Prompt too short' }, { status: 400 });
  }

  try {
    const result = await generateRobot(prompt, {
      onProgress: (step, total, message) => {
        // SSE or WebSocket progress update
      }
    });

    return NextResponse.json({
      success: true,
      downloadUrl: result.zipUrl,
      previews: result.previews,
      bodyPlan: result.bodyPlan,
    });
  } catch (err) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 11: TESTING & GOLDEN TRANSCRIPTS
═══════════════════════════════════════════════════════════════════════════════════════════════════════

GOLDEN TRANSCRIPTS:
─────────────────────────────────────────────────────────────────────────────────────────────────────

Golden transcripts are expected input/output pairs for regression testing.
They define the "correct" behavior of each tool.

```typescript
// packages/xyzt-agent-tools/src/transcripts/golden.ts
export interface GoldenTranscript {
  id: string;
  tool: string;
  input: unknown;
  expectedOutput: unknown;
  expectedValidation: ValidationResult;
  tags: string[];
}

export const RP1_TRANSCRIPT: GoldenTranscript = {
  id: 'RP-1',
  tool: 'create_cad',
  input: {
    prompt: 'A simple box chassis, 100x80x60mm, with 4 mounting holes',
    bodyPlan: {
      name: 'TestChassis',
      links: [{
        name: 'chassis',
        mass: 0.5,
        inertia: { ixx: 0.01, ixy: 0, ixz: 0, iyy: 0.01, iyz: 0, izz: 0.01 },
        geometry: { type: 'box', dimensions: [100, 80, 60] },
        material: { name: 'aluminum_6061', type: 'aluminum' },
      }],
      joints: [],
      actuators: [],
      electronics: {
        compute: { board: 'stm32', power_w: 2 },
        power: { battery_type: 'lipo_4s', capacity_mah: 2000, voltage_v: 14.8, estimated_runtime_h: 2 },
        communication: ['uart'],
        sensors: [],
      },
      materials: [{ name: 'aluminum_6061', type: 'aluminum' }],
      estimated_cost_usd: 50,
    },
  },
  expectedOutput: {
    step_path: '/tmp/test_chassis.step',
    part_count: 1,
    mass_kg: 0.5,
  },
  expectedValidation: {
    validator: 'verify_cad',
    passed: true,
    errors: [],
    warnings: [],
    duration_ms: expect.any(Number),
  },
  tags: ['smoke', 'cad', 'rp1'],
};

export const EDA_TRANSCRIPT: GoldenTranscript = {
  id: 'EDA-1',
  tool: 'create_eda',
  input: {
    prompt: 'Power supply for 4 servos, 12V input, 5V and 12V outputs',
    bodyPlan: {
      name: 'TestPower',
      actuators: [{
        name: 'servo_power',
        type: 'servo',
        count: 4,
        specs: { voltage_v: 5, current_a: 1 },
      }],
      electronics: {
        compute: { board: 'stm32', power_w: 2 },
        power: { battery_type: 'lipo_4s', capacity_mah: 5000, voltage_v: 14.8, estimated_runtime_h: 2 },
        communication: ['uart'],
        sensors: [],
      },
    },
  },
  expectedOutput: {
    kicad_sch_path: '/tmp/test_power.kicad_sch',
    kicad_pcb_path: '/tmp/test_power.kicad_pcb',
    component_count: expect.any(Number),
    net_count: expect.any(Number),
  },
  expectedValidation: {
    validator: 'verify_eda',
    passed: true,
    errors: [],
    warnings: [],
    duration_ms: expect.any(Number),
  },
  tags: ['smoke', 'eda', 'power'],
};
```

TEST COMMANDS:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```json
// package.json scripts
{
  "scripts": {
    "agent:gate": "vitest run --config vitest.config.ts",
    "agent:smoke": "vitest run --config vitest.config.ts --tag smoke",
    "agent:unit": "vitest run --config vitest.config.ts --tag unit",
    "agent:integration": "vitest run --config vitest.config.ts --tag integration",
    "agent:parity": "vitest run --config vitest.config.ts --tag parity",
    "agent:golden": "vitest run --config vitest.config.ts --tag golden",
    "agent:contract": "node scripts/check-contract.js"
  }
}
```

VITEST CONFIG:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['packages/*/tests/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['packages/*/src/**/*.ts'],
      exclude: ['**/*.d.ts', '**/node_modules/**'],
    },
    testTimeout: 30000, // 30 seconds per test
    hookTimeout: 30000,
  },
});
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 12: ENVIRONMENT VARIABLES
═══════════════════════════════════════════════════════════════════════════════════════════════════════

```bash
# .env.example

# AI Configuration
XYZT_AI_PROVIDER=anthropic          # anthropic | openai | ollama | auto
XYZT_ANTHROPIC_API_KEY=sk-ant-...
XYZT_OPENAI_API_KEY=sk-...
XYZT_AI_STREAM_URL=                 # SSE endpoint for cloud inference (optional)
XYZT_ACCESS_TOKEN=                  # Auth token for cloud inference (optional)

# Python Environment
XYZT_PYTHON_PATH=./.venv/bin/python
XYZT_CADQUERY_PATH=./.venv/bin/python
XYZT_KICAD_PATH=/usr/bin/kicad-cli
XYZT_FREECAD_PATH=/usr/bin/freecadcmd

# Docker
XYZT_USE_DOCKER=true
XYZT_CADQUERY_IMAGE=xyzt-cadquery:latest
XYZT_KICAD_IMAGE=xyzt-kicad:latest
XYZT_FREECAD_IMAGE=xyzt-freecad:latest

# Output
XYZT_OUTPUT_DIR=./output
XYZT_TEMP_DIR=./tmp
XYZT_MAX_FILE_SIZE_MB=100

# Validation
XYZT_VALIDATE_STRICT=true
XYZT_DRC_ENABLED=true
XYZT_MESH_WATERTIGHT_REQUIRED=true

# Performance
XYZT_PARALLEL_ENGINES=true
XYZT_ENGINE_TIMEOUT_MS=30000
XYZT_MAX_CONCURRENT_ENGINES=4

# Frontend
XYZT_WEB_PORT=3000
XYZT_API_PORT=3001
XYZT_SSE_ENABLED=true
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 13: DOCKER SETUP
═══════════════════════════════════════════════════════════════════════════════════════════════════════

cadquery.Dockerfile:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y     libgl1-mesa-glx     libgl1-mesa-dri     libxmu6     libxext6     libxi6     libxrender1     libfontconfig1     && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements-cadquery.txt .
RUN pip install --no-cache-dir -r requirements-cadquery.txt

COPY python/cad_engine.py .
COPY python/cad_utils.py .

CMD ["python", "cad_engine.py"]
```

requirements-cadquery.txt:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```
cadquery==2.5.2
pythonOCC==7.9.3
numpy==1.26.4
scipy==1.13.0
trimesh==4.4.0
numpy-stl==3.1.2
```

kicad.Dockerfile:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```dockerfile
FROM kicad/kicad:9.0

WORKDIR /app

COPY python/eda_engine.py .
COPY python/eda_utils.py .

CMD ["python3", "eda_engine.py"]
```

freecad.Dockerfile:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```dockerfile
FROM freecad/freecad:1.0

WORKDIR /app

COPY python/fcstd_engine.py .
COPY python/fcstd_utils.py .

CMD ["freecadcmd", "fcstd_engine.py"]
```

docker-compose.yml:
─────────────────────────────────────────────────────────────────────────────────────────────────────

```yaml
version: '3.8'

services:
  cadquery:
    build:
      context: .
      dockerfile: docker/cadquery.Dockerfile
    volumes:
      - ./tmp:/tmp
      - ./output:/output
    environment:
      - PYTHONUNBUFFERED=1

  kicad:
    build:
      context: .
      dockerfile: docker/kicad.Dockerfile
    volumes:
      - ./tmp:/tmp
      - ./output:/output

  freecad:
    build:
      context: .
      dockerfile: docker/freecad.Dockerfile
    volumes:
      - ./tmp:/tmp
      - ./output:/output

  web:
    build:
      context: .
      dockerfile: docker/web.Dockerfile
    ports:
      - "3000:3000"
    environment:
      - XYZT_API_URL=http://api:3001
    depends_on:
      - api

  api:
    build:
      context: .
      dockerfile: docker/api.Dockerfile
    ports:
      - "3001:3001"
    environment:
      - XYZT_AI_PROVIDER=${XYZT_AI_PROVIDER}
      - XYZT_ANTHROPIC_API_KEY=${XYZT_ANTHROPIC_API_KEY}
      - XYZT_PYTHON_PATH=python
    volumes:
      - ./tmp:/tmp
      - ./output:/output
    depends_on:
      - cadquery
      - kicad
      - freecad
```

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 14: 4-HOUR BUILD CHECKLIST
═══════════════════════════════════════════════════════════════════════════════════════════════════════

HOUR 0: SCAFFOLD
─────────────────────────────────────────────────────────────────────────────────────────────────────
□ Create project directory: mkdir xyzt && cd xyzt
□ Initialize pnpm workspace: pnpm init && create pnpm-workspace.yaml
□ Create package.json with workspace config
□ Create root tsconfig.json
□ Create vitest.config.ts
□ Create .env.example
□ Create directory structure (packages/, docker/, scripts/, docs/)
□ Initialize git: git init && git add . && git commit -m "Initial scaffold"

HOUR 1: xyzt-core (Truth Layer)
─────────────────────────────────────────────────────────────────────────────────────────────────────
□ Create packages/xyzt-core/package.json
□ Install dependencies: zod, python-shell, @types/node
□ Implement BodyPlan schema (schema/body-plan.ts)
□ Implement CadEngine (cad/cad-engine.ts) — CadQuery wrapper
□ Implement StepExporter (cad/step-exporter.ts)
□ Implement FcstdExporter (cad/fcstd-exporter.ts)
□ Implement EdAEngine (eda/eda-engine.ts) — SKiDL wrapper
□ Implement KicadExporter (eda/kicad-exporter.ts)
□ Implement BomGenerator (eda/bom-generator.ts)
□ Implement MeshEngine (mesh/mesh-engine.ts) — trimesh wrapper
□ Implement StlExporter (mesh/stl-exporter.ts)
□ Implement ThreemfExporter (mesh/threemf-exporter.ts)
□ Implement SimEngine (sim/sim-engine.ts) — urdfpy wrapper
□ Implement UrdfExporter (sim/urdf-exporter.ts)
□ Implement SdfExporter (sim/sdf-exporter.ts)
□ Implement Validators (validate/validators.ts)
□ Implement BomEngine (cost/bom-engine.ts)
□ Write Python bridge (python-bridge.ts)
□ Write Python engine scripts (python/cad_engine.py, python/eda_engine.py, etc.)
□ Test: pnpm test — verify core engines work

HOUR 2: xyzt-agent (Runtime Layer)
─────────────────────────────────────────────────────────────────────────────────────────────────────
□ Create packages/xyzt-agent/package.json
□ Install dependencies: @xyzt/core, anthropic, openai, zod
□ Implement PromptParser (parser/prompt-parser.ts)
□ Implement PromptTemplates (parser/prompt-templates.ts)
□ Implement ToolRegistry (tools/tool-registry.ts)
□ Implement ToolInterface (tools/tool-interface.ts)
□ Implement WorkflowGates (gates/workflow-gates.ts)
□ Implement PelGate (gates/pel-gate.ts)
□ Implement OelGate (gates/oel-gate.ts)
□ Implement ParallelAgent (orchestrator/parallel-agent.ts)
□ Implement AgentLoop (orchestrator/agent-loop.ts)
□ Implement ValidationPipeline (validate/validation-pipeline.ts)
□ Implement ZipBundler (export/zip-bundler.ts)
□ Implement PreviewGenerator (export/preview-generator.ts)
□ Implement SseServer (runtime/sse-server.ts)
□ Test: pnpm test — verify agent orchestration works

HOUR 3: xyzt-agent-tools (Tool Layer)
─────────────────────────────────────────────────────────────────────────────────────────────────────
□ Create packages/xyzt-agent-tools/package.json
□ Install dependencies: @xyzt/core, @xyzt/agent, vitest
□ Implement all 55 tools (see Section 4)
□ Implement ToolRegistry (registry.ts)
□ Implement GoldenTranscripts (transcripts/golden.ts)
□ Implement Rp1Transcript (transcripts/rp1-transcript.ts)
□ Implement EdaTranscript (transcripts/eda-transcript.ts)
□ Implement ParityChecker (parity/parity-checker.ts)
□ Create parity.json manifest
□ Write tests: tests/tool-parity.test.ts
□ Write tests: tests/golden-transcripts.test.ts
□ Test: pnpm agent:gate — verify all tests pass

HOUR 4: xyzt-web (Frontend) + Launch
─────────────────────────────────────────────────────────────────────────────────────────────────────
□ Create packages/xyzt-web/package.json (Next.js 14)
□ Install dependencies: next, react, react-dom, tailwindcss, three, @react-three/fiber
□ Implement page.tsx (main page)
□ Implement PromptInput.tsx
□ Implement GenerateButton.tsx
□ Implement ProgressBar.tsx
□ Implement PreviewGallery.tsx
□ Implement DownloadSection.tsx
□ Implement API route: app/api/generate/route.ts
□ Implement API client: lib/api-client.ts
□ Add types: lib/types.ts
□ Configure Tailwind: tailwind.config.ts
□ Configure Next.js: next.config.js
□ Test frontend: pnpm dev — verify UI works
□ Create viral video (screen record, 60 seconds)
□ Post to X, Hacker News, Reddit, LinkedIn
□ Tag: @NVIDIA, @FigureAI, @BostonDynamics, @Tesla
□ Headline: "I designed a robot in 5 minutes. Every file is native format."
□ Set up landing page: xyzt.ai
□ Add "Contact for acquisition" form
□ Monitor, respond, DM key people

═══════════════════════════════════════════════════════════════════════════════════════════════════════
SECTION 15: FINAL MANDATE
═══════════════════════════════════════════════════════════════════════════════════════════════════════

YOU ARE BUILDING THE FUTURE OF PHYSICAL AI DESIGN. 

This is not a side project. This is not a hackathon demo. This is the 
"Photoshop of Physical AI" — the missing layer that NVIDIA, Figure AI, 
Boston Dynamics, and every robotics company desperately needs.

The 4-hour constraint is your SUPERPOWER. It forces elegance, not complexity. 
It proves you can execute. It makes the demo more impressive because it 
shows what's possible with focus and skill.

DO NOT:
  → Over-engineer. If it works for the demo, ship it.
  → Add features that aren't in this prompt. Scope creep kills deadlines.
  → Worry about edge cases. Handle the happy path perfectly.
  → Build a generic coding agent. This is SPECIFICALLY for hardware engineering.
  → Use complex UI frameworks. One input, one button, one ZIP.

DO:
  → Focus on native file output. That's the differentiator.
  → Make the demo video perfect. 60 seconds, no narration, just proof.
  → Tag the right people. NVIDIA Jensen Huang, Figure AI Brett Adcock, etc.
  → Respond to every comment. Engagement drives algorithmic reach.
  → Have the acquisition form ready. Strike while the iron is hot.

THE 3-SENTENCE PITCH:
"XYZT is the first AI platform that designs robots in native formats. 
Type a task, get a native STEP file for SolidWorks, a KiCad PCB for JLCPCB, 
and a URDF for ROS2 — all in 5 minutes, no scripts, no workflows. 
NVIDIA built the simulators. We built the design layer they forgot."

NOW GO BUILD IT. 4 HOURS. CLOCK STARTS NOW.
═══════════════════════════════════════════════════════════════════════════════════════════════════════
