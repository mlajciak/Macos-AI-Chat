# CAD sandbox API (generated)

> Generated 2026-05-26T21:09:39.336Z from `xyzt-core/src/runner/globals.ts` (`GLOBAL_NAMES`). Do not edit — run `pnpm --filter xyzt-cad docs:agent`.

### Primitives

| Global | Signature hint |
|--------|----------------|
| `box` | box(w, d, h) |
| `sphere` | sphere(radius) |
| `cylinder` | cylinder(height, radius) |
| `cone` | — |
| `torus` | — |
| `wedge` | — |
| `prism` | — |
| `helix` | — |
| `pipe` | — |
| `capsule` | — |
| `ellipsoid` | — |
| `polyhedron` | — |

### 2D / sketch

| Global | Signature hint |
|--------|----------------|
| `rect` | — |
| `circle2d` | — |
| `roundedRect` | — |
| `ngon` | — |
| `ellipse2d` | — |
| `slot2d` | — |
| `star` | — |
| `arcSlot` | — |
| `polygon2d` | — |
| `Sketch` | — |
| `sketch` | sketch(XY).rect(w, h).close() |
| `workplane` | — |
| `XY` | — |
| `XZ` | — |
| `YZ` | — |

### Features

| Global | Signature hint |
|--------|----------------|
| `extrude` | extrude(profile, height) |
| `revolve` | — |
| `sweep` | — |
| `loft` | — |
| `linearPattern` | — |
| `circularPattern` | — |
| `mirrorCopy` | — |
| `draft` | — |
| `thread` | — |
| `threadedHole` | — |
| `hole` | — |
| `counterboreHole` | — |
| `countersinkHole` | — |
| `tappedHole` | — |
| `splitBody` | — |
| `coil` | — |
| `compressionSpring` | — |
| `tensionSpring` | — |
| `rib` | — |
| `boss` | — |
| `rectangularBoss` | — |
| `web` | — |
| `gusset` | — |
| `thicken` | — |
| `boundaryFill` | — |
| `patch` | — |
| `stitch` | — |
| `offsetSurface` | — |
| `extendSurface` | — |
| `trimSurface` | — |
| `cosmeticThread` | — |
| `applyVisualThread` | — |
| `Form` | — |
| `derive` | — |
| `createForm` | — |

### Booleans & text

| Global | Signature hint |
|--------|----------------|
| `union` | — |
| `difference` | — |
| `intersection` | — |
| `hull` | — |
| `text` | — |
| `engrave` | — |
| `emboss` | — |

### Assembly

| Global | Signature hint |
|--------|----------------|
| `Assembly` | — |
| `assembly` | assembly('Name').add(id, shape, opts) |
| `Component` | — |
| `component` | — |
| `revolute` | — |
| `prismatic` | — |
| `fixed` | — |
| `connector` | — |

### Measure & inspect

| Global | Signature hint |
|--------|----------------|
| `volume` | — |
| `area` | — |
| `boundingBox` | — |
| `distance` | — |
| `angle` | — |
| `dimensions` | — |
| `center` | — |
| `faces` | — |
| `edges` | — |
| `vertices` | — |
| `check` | — |

### Params & units

| Global | Signature hint |
|--------|----------------|
| `Param` | — |
| `param` | param('name', default, { min, max, step }) |
| `boolParam` | — |
| `choiceParam` | — |
| `listParam` | — |
| `setUnits` | — |
| `getUnits` | — |
| `setTolerance` | — |
| `getTolerance` | — |
| `setSegments` | — |
| `getSegments` | — |
| `mm` | — |
| `cm` | — |
| `m` | — |
| `inch` | — |
| `ft` | — |
| `toMM` | — |
| `fromMM` | — |

### Materials & export

| Global | Signature hint |
|--------|----------------|
| `getMaterial` | — |
| `listMaterials` | — |
| `searchMaterials` | — |
| `createMaterial` | — |
| `pbrMaterial` | — |
| `toMesh` | — |
| `toSTL` | — |
| `toSTLBinary` | — |
| `toOBJ` | — |
| `to3MF` | — |

### SDF & lib

| Global | Signature hint |
|--------|----------------|
| `sdf` | — |
| `lib` | lib.spurGear(module, teeth, thickness, opts) |
| `bolt` | — |
| `nut` | — |
| `washer` | — |

### EDA

| Global | Signature hint |
|--------|----------------|
| `circuit` | — |
| `resistor` | — |
| `capacitor` | — |
| `inductor` | — |
| `led` | — |
| `chip` | — |
| `net` | — |
| `XyztCircuit` | — |
| `registerComponent` | — |
| `customComponent` | — |

### Drawing & simulation

| Global | Signature hint |
|--------|----------------|
| `drawing` | — |
| `XyztDrawing` | — |

### Import / export interchange

| Global | Signature hint |
|--------|----------------|
| `importSTL` | — |
| `importOBJ` | — |
| `meshShape` | — |
| `registerShape` | — |
| `getRegisteredShape` | — |
| `importSTEP` | — |
| `importSTEPDetailed` | — |
| `importIGES` | — |
| `importBREP` | — |
| `importCadFile` | — |
| `importEdaFile` | — |
| `convertToXyzt` | — |
| `recognizeFeatures` | — |
| `importInterchangeAsComponent` | — |
| `exportKicadPcb` | — |
| `exportKicadSchematic` | — |
| `exportEagle` | — |

### Sheet metal

| Global | Signature hint |
|--------|----------------|
| `sheetMetalBaseFlange` | — |
| `baseFlange` | — |
| `sheetMetalEdgeFlange` | — |
| `edgeFlange` | — |

### Other

- `splitBodyPair`
- `returnSplitBodies`
- `splitBodyWithShape`
- `splitBodyMultiple`
- `splitFace`
- `Shape`
- `SdfShape`
- `TestContext`
- `getKernelSegments`
- `setDisplaySegments`
- `getDisplaySegments`
- `getConfig`
- `setConfig`
- `PI`
- `TAU`
- `sin`
- `cos`
- `tan`
- `asin`
- `acos`
- `atan`
- `atan2`
- `sqrt`
- `abs`
- `min`
- `max`
- `floor`
- `ceil`
- `round`
- `pow`
- `exp`
- `log`
- `deg2rad`
- `rad2deg`
- `clamp`
- `lerp`
- `map`
- `Math`
- `console`
- `readProjectFile`
