// Checks the section files against the rig contract, for the three ways a rig
// goes wrong without rendering wrong. Run with `npm run rigs:check`.
//
// Every failure here is invisible on the page: a duplicate clipPath id draws a
// plausible rig clipped against the wrong screens, a frame rect that has
// drifted from its clip rect draws a plausible frame, and a second size of a
// photograph the page already has is simply a second download.

import { readFileSync, readdirSync } from 'node:fs'
import { resolve, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { PHOTOS } from './rigs.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const SECTIONS = join(ROOT, 'src', 'sections')

const allowed = new Map(Object.values(PHOTOS).map((p) => [p.url, p.url]))
const byName = new Map(Object.entries(PHOTOS).map(([name, p]) => [name, p.url]))

const files = [
  ...readdirSync(SECTIONS).filter((f) => f.endsWith('.html')).map((f) => join(SECTIONS, f)),
  join(ROOT, 'index.html'),
]

const problems = []

/** Reports a problem against a file and line, the way an editor wants to read it. */
function fail(file, line, message) {
  problems.push(`${file.replace(ROOT + '/', '')}:${line}  ${message}`)
}

const ids = new Map()

for (const file of files) {
  const lines = readFileSync(file, 'utf8').split('\n')

  lines.forEach((text, i) => {
    const line = i + 1

    for (const [, url] of text.matchAll(/(?:href|src)="(\/photos\/[^"]+)"/g)) {
      if (allowed.has(url)) continue
      const name = url.split('/').pop().replace('.jpg', '')
      const want = byName.get(name)
      fail(file, line, want ? `${url} should be ${want}` : `${url} is not a photograph the page uses`)
    }

    for (const [, id] of text.matchAll(/<clipPath id="([^"]+)"/g)) {
      const seen = ids.get(id)
      if (seen) fail(file, line, `clipPath id "${id}" is already used at ${seen}`)
      else ids.set(id, `${file.replace(ROOT + '/', '')}:${line}`)
    }
  })

  const source = lines.join('\n')
  for (const [, body] of source.matchAll(/<clipPath id="[^"]+">([\s\S]*?)<\/clipPath>/g)) {
    const rects = [...body.matchAll(/<rect ([^/>]*)\/>/g)].map((m) => geometry(m[1]))
    for (const rect of rects) {
      const framed = source.includes(`<rect class="rig-frame" x="${rect.x}" y="${rect.y}" width="${rect.w}" height="${rect.h}"`)
      if (!framed) fail(file, lineOf(source, rect), `no rig-frame rect matches the clip rect at ${rect.x},${rect.y}`)
    }
  }
}

/** Pulls x, y, width and height out of a rect's attributes. */
function geometry(attrs) {
  const at = (name) => attrs.match(new RegExp(`${name}="([^"]+)"`))?.[1]
  return { x: at('x'), y: at('y'), w: at('width'), h: at('height') }
}

/** Finds the line a clip rect sits on, so the message points somewhere useful. */
function lineOf(source, rect) {
  const needle = `x="${rect.x}" y="${rect.y}" width="${rect.w}" height="${rect.h}"`
  return source.slice(0, source.indexOf(needle)).split('\n').length
}

if (problems.length) {
  console.log(problems.join('\n'))
  console.log(`\n${problems.length} problems`)
  process.exit(1)
}
console.log(`rig contract holds across ${files.length} files, ${ids.size} rigs`)
