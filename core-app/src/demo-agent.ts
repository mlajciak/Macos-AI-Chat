import demoFixtures from '../fixtures/demo-responses.json' with { type: 'json' }
import type { ChatMessage } from './types.js'
import { lastUserMessage } from './session.js'

export type DemoFixtures = {
  helpText: string
  faqAnswers: string[]
  echoTemplate: string
}

export const fixtures: DemoFixtures = demoFixtures

let faqRotation = 0

export function resetFaqRotation(): void {
  faqRotation = 0
}

export function pickFaqAnswer(answers: string[]): string {
  if (answers.length === 0) return ''
  const answer = answers[faqRotation % answers.length]!
  faqRotation += 1
  return answer
}

export function demoReplyText(messages: ChatMessage[], fx: DemoFixtures = fixtures): string {
  const last = lastUserMessage(messages)
  if (!last) return fx.helpText

  const trimmed = last.content.trim()
  if (trimmed === '/help') return fx.helpText
  if (trimmed.endsWith('?')) return pickFaqAnswer(fx.faqAnswers)
  return fx.echoTemplate.replace('{text}', trimmed)
}

export async function demoReply(
  messages: ChatMessage[],
  options?: { minDelayMs?: number; maxDelayMs?: number; fx?: DemoFixtures },
): Promise<string> {
  const min = options?.minDelayMs ?? 600
  const max = options?.maxDelayMs ?? 1200
  const delay = min + Math.floor(Math.random() * (max - min + 1))
  await new Promise<void>(resolve => setTimeout(resolve, delay))
  return demoReplyText(messages, options?.fx ?? fixtures)
}
