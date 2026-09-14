// Writes RIGS.md from scripts/rigs-prose.md, expanding every `@rig` token into
// that rig's real markup so the documented copy and the drawing cannot disagree.

import { writeFileSync, readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { markup, RIGS, PHOTOS, GLOW, check } from './rigs.mjs'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(HERE, '..')

/**
 * Replaces every `@rig name {json}` token with a fenced block of that rig's
 * markup, built from the same geometry the preview page draws.
 *
 * @param {string} text - The prose, with tokens.
 * @returns {string} The prose, with markup.
 */
function expand(text) {
  return text.replace(/@rig (\S+) (\{.*\})/g, (_, name, json) => {
    if (!RIGS[name]) throw new Error(`no rig called ${name}`)
    return '```html\n' + markup(name, JSON.parse(json)) + '\n```'
  })
}

/** Prints the Sizing table row for one rig: name, what it is, viewBox, ratio. */
function row(name) {
  const r = RIGS[name]
  const [w, h] = r.viewBox
  return `| \`rig-${name}\` | ${r.title} | \`0 0 ${w} ${h}\` | ${(w / h).toFixed(2)} | ${r.section} |`
}

const problems = check()
if (problems.length) throw new Error(problems.join('\n'))

const header =
  '| Rig | What it draws | viewBox | Ratio | Where it belongs |\n| --- | --- | --- | --- | --- |\n'

const photos =
  '| Photograph | URL |\n| --- | --- |\n' +
  Object.values(PHOTOS).map((p) => `| ${p.caption} | \`${p.url}\` |`).join('\n')

const text = expand(readFileSync(resolve(HERE, 'rigs-prose.md'), 'utf8'))
  .replace('@table', header + Object.keys(RIGS).map(row).join('\n'))
  .replace('@photos', photos)
  .replace('@glow-neutral', `\`${GLOW.neutral}\``)

writeFileSync(resolve(ROOT, 'RIGS.md'), text)
console.log('RIGS.md', text.split('\n').length, 'lines')
