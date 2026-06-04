import { createToolCard, type AgentToolCard } from './tools.js'

export type StreamParserEvent =
  | { type: 'thinking_start'; card: AgentToolCard }
  | { type: 'thinking_delta'; cardId: string; delta: string }
  | { type: 'thinking_end'; cardId: string }
  | { type: 'text_delta'; delta: string }

const THINK_OPEN = ['<', 'think', '>'].join('')
const THINK_CLOSE = ['<', '/', 'think', '>'].join('')

export class AgentStreamParser {
  private mode: 'seek' | 'think' | 'text' = 'seek'
  private carry = ''
  private thinkingCard: AgentToolCard | null = null
  private thinkingSource: 'tag' | 'reasoning' | null = null
  private nextToolId = 0

  pushReasoning(delta: string): StreamParserEvent[] {
    if (!delta) return []
    const events: StreamParserEvent[] = []
    if (this.mode !== 'think') {
      this.beginThinking(events, 'reasoning')
    }
    events.push(...this.thinkingDelta(delta))
    return events
  }

  push(delta: string): StreamParserEvent[] {
    if (!delta) return []
    const events: StreamParserEvent[] = []
    if (this.mode === 'think' && this.thinkingSource === 'reasoning') {
      events.push(...this.endThinking())
    }
    let rest = this.carry + delta
    this.carry = ''

    while (rest.length > 0) {
      if (this.mode === 'seek') {
        const openIdx = rest.indexOf(THINK_OPEN)
        if (openIdx === -1) {
          const partial = stripPartialTagSuffix(rest, THINK_OPEN)
          this.carry = partial.suffix
          if (partial.text) {
            events.push({ type: 'text_delta', delta: partial.text })
            this.mode = 'text'
          }
          rest = ''
          break
        }
        if (openIdx > 0) {
          events.push({ type: 'text_delta', delta: rest.slice(0, openIdx) })
        }
        rest = rest.slice(openIdx + THINK_OPEN.length)
        this.beginThinking(events, 'tag')
        continue
      }

      if (this.mode === 'think') {
        const closeIdx = rest.indexOf(THINK_CLOSE)
        if (closeIdx === -1) {
          const partial = stripPartialTagSuffix(rest, THINK_CLOSE)
          this.carry = partial.suffix
          if (partial.text) {
            events.push(...this.thinkingDelta(partial.text))
          }
          rest = ''
          break
        }
        const chunk = rest.slice(0, closeIdx)
        if (chunk) events.push(...this.thinkingDelta(chunk))
        rest = rest.slice(closeIdx + THINK_CLOSE.length)
        events.push(...this.endThinking())
        continue
      }

      events.push({ type: 'text_delta', delta: rest })
      rest = ''
    }

    return events
  }

  flush(): StreamParserEvent[] {
    const events: StreamParserEvent[] = []
    if (this.carry) {
      if (this.mode === 'think') {
        events.push(...this.thinkingDelta(this.carry))
      } else if (this.mode === 'text' || this.mode === 'seek') {
        events.push({ type: 'text_delta', delta: this.carry })
      }
      this.carry = ''
    }
    if (this.mode === 'think') {
      events.push(...this.endThinking())
    }
    return events
  }

  private beginThinking(events: StreamParserEvent[], source: 'tag' | 'reasoning') {
    this.mode = 'think'
    this.thinkingSource = source
    this.nextToolId += 1
    const card = createToolCard('thinking', `thinking-${this.nextToolId}`)
    this.thinkingCard = card
    events.push({ type: 'thinking_start', card })
  }

  private thinkingDelta(text: string): StreamParserEvent[] {
    if (!this.thinkingCard || !text) return []
    this.thinkingCard = { ...this.thinkingCard, body: this.thinkingCard.body + text }
    return [{ type: 'thinking_delta', cardId: this.thinkingCard.id, delta: text }]
  }

  private endThinking(): StreamParserEvent[] {
    if (!this.thinkingCard) {
      this.thinkingSource = null
      this.mode = 'text'
      return []
    }
    const cardId = this.thinkingCard.id
    this.thinkingCard = null
    this.thinkingSource = null
    this.mode = 'text'
    return [{ type: 'thinking_end', cardId }]
  }
}

function stripPartialTagSuffix(
  text: string,
  fullTag: string,
): { text: string; suffix: string } {
  for (let i = fullTag.length - 1; i >= 1; i--) {
    const prefix = fullTag.slice(0, i)
    if (text.endsWith(prefix)) {
      return { text: text.slice(0, -i), suffix: prefix }
    }
  }
  return { text, suffix: '' }
}
