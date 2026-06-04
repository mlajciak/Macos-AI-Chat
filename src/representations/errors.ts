export class UnsupportedFormatError extends Error {
  readonly fileName: string
  readonly hint: string | null

  constructor(fileName: string, hint: string | null = null) {
    const msg = hint
      ? `Unsupported format for "${fileName}" (detected: ${hint})`
      : `Unsupported format for "${fileName}"`
    super(msg)
    this.name = 'UnsupportedFormatError'
    this.fileName = fileName
    this.hint = hint
  }
}
