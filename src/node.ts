/** Node.js / CLI entry — not imported by browser surfaces. */
export { createCliFolderHost, type CliFolderHostOptions } from './host/cli-folder-host.js'
export { runLocalAgentStream, MAX_TOOL_ITERATIONS } from './loop/tool-execution-loop.js'
