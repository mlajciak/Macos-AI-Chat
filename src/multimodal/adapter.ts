import type { AIMessage, AIMessageContentPart } from '../types.js'

export interface TextAttachment {
  name: string
  text: string
}

export interface ImageAttachment {
  name: string
  mimeType: string
  dataUrl: string
}

export function buildUserMessageContent(
  text: string,
  attachments?: { text?: TextAttachment[]; images?: ImageAttachment[] },
): string | AIMessageContentPart[] {
  const images = attachments?.images ?? []
  const textFiles = attachments?.text ?? []
  if (!images.length && !textFiles.length) return text

  const parts: AIMessageContentPart[] = [{ type: 'text', text }]
  for (const f of textFiles) {
    parts.push({ type: 'text', text: `\n\n[File: ${f.name}]\n${f.text}` })
  }
  for (const img of images) {
    parts.push({ type: 'image_url', image_url: { url: img.dataUrl } })
  }
  return parts
}

export function userMessage(text: string, attachments?: Parameters<typeof buildUserMessageContent>[1]): AIMessage {
  return {
    role: 'user',
    content: buildUserMessageContent(text, attachments),
  }
}
