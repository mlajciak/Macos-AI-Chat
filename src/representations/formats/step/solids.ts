import type { StepEntity } from './parse-entities.js'

export type SolidCounts = {
  manifoldSolidBrep: number
  advancedBrepShapeRepresentation: number
  closedShell: number
  shell: number
  advancedFace: number
}

export function countSolids(entities: Map<number, StepEntity>): SolidCounts {
  const counts: SolidCounts = {
    manifoldSolidBrep: 0,
    advancedBrepShapeRepresentation: 0,
    closedShell: 0,
    shell: 0,
    advancedFace: 0,
  }

  for (const e of entities.values()) {
    switch (e.type) {
      case 'MANIFOLD_SOLID_BREP':
        counts.manifoldSolidBrep++
        break
      case 'ADVANCED_BREP_SHAPE_REPRESENTATION':
        counts.advancedBrepShapeRepresentation++
        break
      case 'CLOSED_SHELL':
        counts.closedShell++
        break
      case 'SHELL':
        counts.shell++
        break
      case 'ADVANCED_FACE':
        counts.advancedFace++
        break
      default:
        break
    }
  }

  return counts
}

export function solidsToItems(counts: SolidCounts): Array<Record<string, string | number>> {
  return [
    { entity: 'manifold_solids', count: counts.manifoldSolidBrep },
    { entity: 'advanced_brep_shape_representations', count: counts.advancedBrepShapeRepresentation },
    { entity: 'closed_shells', count: counts.closedShell },
    { entity: 'shells', count: counts.shell },
    { entity: 'advanced_faces', count: counts.advancedFace },
  ]
}
