import { describe, expect, it } from 'vitest'
import { resolveProjectFileName } from './resolve-project-file.js'

describe('resolveProjectFileName', () => {
  const paths = ['Oriental-Chair.xyzt', 'subdir/Bracket.xyzt']

  it('matches exact path', () => {
    expect(resolveProjectFileName('Oriental-Chair.xyzt', paths)).toBe('Oriental-Chair.xyzt')
  })

  it('matches basename', () => {
    expect(resolveProjectFileName('Bracket.xyzt', paths)).toBe('subdir/Bracket.xyzt')
  })
})
