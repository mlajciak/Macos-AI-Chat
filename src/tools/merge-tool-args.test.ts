import { describe, expect, it } from 'vitest'
import { mergeToolArgs, mergeToolArgsForExecute } from './merge-tool-args.js'

describe('mergeToolArgsForExecute', () => {
  it('does not use partial fileName from incomplete JSON', () => {
    const raw = '{"fileName": "Oriental-Chair.xyzt"'
    expect(mergeToolArgsForExecute({}, raw)).toEqual({})
  })

  it('uses complete JSON only', () => {
    const raw = JSON.stringify({ fileName: 'Oriental-Chair.xyzt' })
    expect(mergeToolArgsForExecute({}, raw)).toEqual({ fileName: 'Oriental-Chair.xyzt' })
  })
})

describe('mergeToolArgs', () => {
  it('extracts fields from incomplete streamed JSON when event args are empty', () => {
    const raw = '{"fileName": "Oriental Chair", "content": "return box(10, 20, 10);"'
    expect(mergeToolArgs({}, raw)).toEqual({
      fileName: 'Oriental Chair',
      content: 'return box(10, 20, 10);',
    })
  })
})
