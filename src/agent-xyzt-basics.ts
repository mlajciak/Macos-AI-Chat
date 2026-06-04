/** Compact .xyzt authoring reference — injected with desktop discipline. */
export const XYZT_FILE_BASICS = `## .xyzt scripting

JavaScript only. No import/require/fetch/eval. Multi-file: \`use('Part.xyzt')\`. Units: mm. Sync geometry — no await. Last line returns Shape, Assembly, or \`{ model, contract: designContract({...}) }\`.

Workflow: \`create_cad\` → \`patch_file\` until spec met. Compile feedback is inline in write tool JSON (\`post_write_validate\`, \`validation\`).

Primitives: box(w,d,h) | cylinder(height, radius) | sphere(r). Booleans: reassign \`body = body.subtract(cutter)\`. Colors: .color(r,g,b). Params: param('name', default, { min, max, step }).

Assembly: mates + solve() or placementSpec() — not at:[x,y,z]. 2D: constrainedSketch(). Gears: lib.spurGear(...).`
