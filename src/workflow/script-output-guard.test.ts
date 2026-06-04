import { describe, expect, it } from 'vitest'
import {
  looksLikeXyztScriptBody,
  outputLooksLikeConversationalFiller,
  outputLooksLikeUndeliveredScript,
  shouldAbortReasoningWithoutTools,
} from './script-output-guard.js'

describe('script-output-guard', () => {
  it('detects function spurGear style drafting', () => {
    const snippet = `
function spurGear(z, m, width) {
  const rp = z * m / 2;
  return cylinder(width, rp);
}
`
    expect(looksLikeXyztScriptBody(snippet)).toBe(true)
    expect(outputLooksLikeUndeliveredScript(snippet)).toBe(true)
  })

  it('detects param() parametric gearbox planning', () => {
    const snippet = 'const MODULE = param("module", 0.8);\nreturn assembly(housing, sun1);'
    expect(looksLikeXyztScriptBody(snippet)).toBe(true)
  })

  it('allows short engineering notes', () => {
    const notes = '2-stage compound planetary; module 0.8; sun 16/14; verify assembly condition (zSun+zRing)%3.'
    expect(looksLikeXyztScriptBody(notes)).toBe(false)
    expect(shouldAbortReasoningWithoutTools(notes, false)).toBe(false)
  })

  it('aborts early when script patterns appear', () => {
    const snippet = 'const outerD = param("outerD", 40);\nreturn box(outerD, 10, 10)'
    expect(shouldAbortReasoningWithoutTools(snippet, false)).toBe(true)
  })

  it('aborts long thinking that mentions tools but never calls them', () => {
    const long = `${'Stage 1 sun gear pitch. '.repeat(40)}Next I will call create_cad with parameters.`
    expect(shouldAbortReasoningWithoutTools(long, false)).toBe(true)
  })

  it('does not abort when tools are pending', () => {
    const code = 'function f() { return box(1,1,1); }'
    expect(shouldAbortReasoningWithoutTools(code.repeat(50), true)).toBe(false)
  })

  it('detects conversational filler', () => {
    expect(outputLooksLikeConversationalFiller('Sure, I think we should maybe start with get_capabilities.')).toBe(true)
    expect(outputLooksLikeConversationalFiller('post_write_validate ok:true; next patch_file housing.xyzt')).toBe(false)
  })
})
