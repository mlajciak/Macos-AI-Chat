import { DESKTOP_CAD_AGENT_DISCIPLINE_BODY } from './agent-discipline.generated.js'
import { XYZT_FILE_BASICS } from './agent-xyzt-basics.js'

/** Injected into desktop agent user messages (cloud system prompt + this). */
export const DESKTOP_CAD_AGENT_DISCIPLINE = `${DESKTOP_CAD_AGENT_DISCIPLINE_BODY}

${XYZT_FILE_BASICS}`
