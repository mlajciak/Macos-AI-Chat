#!/usr/bin/env node
import { createCliFolderHost } from '../dist/host/cli-folder-host.js'
import { runLocalAgentStream } from '../dist/loop/tool-execution-loop.js'

function parseArgs(argv) {
  const out = { folder: '.', prompt: '', token: process.env.XYZT_ACCESS_TOKEN ?? '' }
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--folder' && argv[i + 1]) out.folder = argv[++i]
    else if (argv[i] === '--prompt' && argv[i + 1]) out.prompt = argv[++i]
    else if (argv[i] === '--token' && argv[i + 1]) out.token = argv[++i]
  }
  return out
}

const args = parseArgs(process.argv.slice(2))
if (!args.prompt.trim()) {
  console.error('Usage: xyzt-agent --folder <path> --prompt "<task>" [--token <jwt>]')
  process.exit(1)
}
if (!args.token) {
  console.error('Set XYZT_ACCESS_TOKEN or pass --token')
  process.exit(1)
}

const ctx = await createCliFolderHost({ rootPath: args.folder })
const history = [{ role: 'user', content: args.prompt }]

await runLocalAgentStream({
  history,
  accessToken: args.token,
  toolContext: ctx,
  agentSurface: 'cli_folder',
  sandboxEdits: false,
  onEvent: async event => {
    if (event.type === 'token') process.stdout.write(event.content)
    if (event.type === 'tool_result') {
      console.error(`\n[tool ${event.name}] ${event.result.slice(0, 500)}`)
    }
    if (event.type === 'budget_exceeded') {
      console.error(`\n${event.message}`)
    }
  },
})

console.error('\nDone.')
