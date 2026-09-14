// Checks the section files against the rig contract, for the five ways a rig
// goes wrong without rendering wrong. Run with `npm run rigs:check`.
//
// Every failure here is invisible on the page: a duplicate clipPath id draws a
// plausible rig clipped against the wrong screens, a frame rect drifted from
// its clip rect draws a plausible frame, markup copied before the geometry
// changed draws a plausible rig at the wrong size, a chin a unit out of place
// covers a line of the photograph, a desk light off the sanctioned palette is
// simply a colour nobody chose, and a second size of a picture the page already
// has is just a second download.

import { readFileSync, readdirSync } from 'node:fs'
import { resolve, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { PHOTOS, RIGS, GLOW, chinOf, glowOf } from './rigs.mjs'

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

    for (const [, tint] of text.matchAll(/--rig-glow-color:\s*([^";]+)/g)) {
      const sanctioned = Object.values(GLOW).includes(tint.trim())
      if (!sanctioned) {
        fail(file, line,
          `desk light "${tint.trim()}" is not one of the sanctioned tints; pass glow: "<name>" to markup() rather than writing a colour, so regenerating cannot lose it`)
      }
    }

    for (const [, id] of text.matchAll(/<clipPath id="([^"]+)"/g)) {
      const seen = ids.get(id)
      if (seen) fail(file, line, `clipPath id "${id}" is already used at ${seen}`)
      else ids.set(id, `${file.replace(ROOT + '/', '')}:${line}`)
    }
  })

  const source = lines.join('\n')

  for (const [svg, classes, viewBox] of source.matchAll(
    /<svg class="([^"]*\brig\b[^"]*)"[^>]*viewBox="([^"]+)"[\s\S]*?<\/svg>/g
  )) {
    const name = classes.split(/\s+/).map((c) => c.replace(/^rig-/, '')).find((c) => RIGS[c])
    if (!name) continue
    const at = lineOf(source, { raw: `viewBox="${viewBox}"` })

    const want = `0 0 ${RIGS[name].viewBox.join(' ')}`
    if (viewBox !== want) {
      fail(file, at, `rig-${name} has viewBox "${viewBox}" but the generator draws "${want}"`)
      continue
    }

    // A geometry change that leaves the viewBox alone, like moving one screen,
    // is invisible to the check above and to a reader.
    const body = svg.match(/<clipPath id="[^"]+">([\s\S]*?)<\/clipPath>/)?.[1] ?? ''
    const drawn = [...body.matchAll(/<rect ([^/>]*)\/>/g)]
      .map((m) => geometry(m[1]))
      .map((r) => `${r.x},${r.y},${r.w},${r.h}`)
    const expected = RIGS[name].screens.map((s) => `${s.x},${s.y},${s.w},${s.h}`)
    if (drawn.join(' ') !== expected.join(' ')) {
      fail(file, at,
        `rig-${name} clips at ${drawn.join(' ')} but the generator draws ${expected.join(' ')}`)
    }

    // Two rigs in a responsive swap are never on screen together, so one of them
    // keeping a stale ellipse shows as a pool of light under one and none under
    // the other, which nobody sees in review.
    const glow = svg.match(/<ellipse class="rig-glow" ([^/>]*)\/>/)?.[1]
    if (glow) {
      const at2 = (k) => glow.match(new RegExp(`${k}="([^"]+)"`))?.[1]
      const want = glowOf(RIGS[name])
      const off = ['cx', 'cy', 'rx', 'ry'].filter((k) => String(want[k]) !== at2(k))
      if (off.length) {
        fail(file, at,
          `rig-${name} draws its desk light at ${['cx', 'cy', 'rx', 'ry'].map((k) => at2(k)).join(',')} but the generator draws ${['cx', 'cy', 'rx', 'ry'].map((k) => want[k]).join(',')}`)
      }
    }

    // The chin meets the bottom of the lit screen exactly, so a unit either way
    // either covers a line of the photograph or leaves the lid's corner showing.
    const chin = svg.match(/<rect class="rig-chin" ([^/>]*)\/>/)?.[1]
    if (chin) {
      const drawnChin = geometry(chin)
      const wantChin = chinOf(RIGS[name])
      const same = ['x', 'y', 'w', 'h'].every((k) => String(wantChin[k]) === drawnChin[k])
      if (!same) {
        fail(file, at,
          `rig-${name} draws its chin at ${drawnChin.x},${drawnChin.y},${drawnChin.w},${drawnChin.h} but the generator draws ${wantChin.x},${wantChin.y},${wantChin.w},${wantChin.h}`)
      }
    }
  }

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
  const needle = rect.raw ?? `x="${rect.x}" y="${rect.y}" width="${rect.w}" height="${rect.h}"`
  return source.slice(0, source.indexOf(needle)).split('\n').length
}

const css = readFileSync(join(ROOT, 'src', 'rigs.css'), 'utf8')
const declared = css.match(/--rig-glow-color:\s*([^;]+);/)?.[1]?.trim()
if (declared !== GLOW.neutral) {
  problems.push(`src/rigs.css  the default desk light is "${declared}" but the generator's neutral tint is "${GLOW.neutral}"`)
}

if (problems.length) {
  console.log(problems.join('\n'))
  console.log(`\n${problems.length} problems`)
  process.exit(1)
}
console.log(`rig contract holds across ${files.length} files, ${ids.size} rigs`)
