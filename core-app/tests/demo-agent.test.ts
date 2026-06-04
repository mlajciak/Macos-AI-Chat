import { describe, expect, it, beforeEach } from 'vitest'
import {
  demoReplyText,
  pickFaqAnswer,
  resetFaqRotation,
} from '../src/demo-agent.js'
import type { ChatMessage } from '../src/types.js'

const fx = {
  helpText: 'Help text',
  faqAnswers: ['FAQ one', 'FAQ two'],
  echoTemplate: 'Echo: {text}',
}

function userMessage(content: string): ChatMessage {
  return { id: '1', role: 'user', content, createdAt: 0 }
}

describe('demoReplyText', () => {
  beforeEach(() => resetFaqRotation())

  it('returns help for /help', () => {
    expect(demoReplyText([userMessage('/help')], fx)).toBe('Help text')
  })

  it('rotates FAQ answers for questions', () => {
    expect(demoReplyText([userMessage('What is this?')], fx)).toBe('FAQ one')
    expect(demoReplyText([userMessage('Another?')], fx)).toBe('FAQ two')
    expect(demoReplyText([userMessage('Third?')], fx)).toBe('FAQ one')
  })

  it('echoes non-question input', () => {
    expect(demoReplyText([userMessage('hello world')], fx)).toBe(
      'Echo: hello world',
    )
  })
})

describe('pickFaqAnswer', () => {
  beforeEach(() => resetFaqRotation())

  it('cycles through answers', () => {
    const answers = ['a', 'b']
    expect(pickFaqAnswer(answers)).toBe('a')
    expect(pickFaqAnswer(answers)).toBe('b')
    expect(pickFaqAnswer(answers)).toBe('a')
  })
})
