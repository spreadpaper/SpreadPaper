// Writes rigs-preview.html, a development page drawing every rig plus the three
// motion cases. Not part of the site: the Vite build only builds index.html.

import { writeFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { markup, RIGS, check } from './rigs.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const P = '/photos/1200'

const GLOW = {
  desk: 'neutral',
  dual: 'neutral',
  laptop: 'appearance',
  'portrait-trio': 'dynamic',
  trio: 'accent',
  ultrawide: 'neutral',
}

const block = (heading, note, svg, width = '52rem') => `
  <section>
    <h2>${heading}</h2>
    <p>${note}</p>
    <div style="max-width: ${width}">
${svg}
    </div>
  </section>`

/** Draws one rig in its own section, tinted with the glow its section uses. */
function one(name, opts, note, width) {
  const r = RIGS[name]
  const [w, h] = r.viewBox
  const svg = markup(name, { indent: '      ', glow: GLOW[name], ...opts })
  return block(
    `rig-${name}`,
    `viewBox 0 0 ${w} ${h}, ratio ${(w / h).toFixed(2)}. ${note}`,
    svg,
    width
  )
}

const pair = (a, b) => [a, '    </div><div style="max-width: 52rem; margin-top: 1.5rem">', b].join('\n')

const bezel = (id, value, label) =>
  markup('trio', { id, photos: [`${P}/hero-day-1.jpg`], classes: 'rig-glass', indent: '      ', label })
    .replace('<svg ', `<svg style="--rig-bezel: ${value}" `)

const problems = check()
if (problems.length) throw new Error(problems.join('\n'))

const parts = [
  one('desk', { id: 'pv-desk', photos: ['/photos/hero-beach.jpg'], label: 'A beach at sunset carried across a laptop and the two monitors beside it.' },
    'The hero rig, on the 2400px original. Widest rig on the page.', '64rem'),

  one('dual', { id: 'pv-dual', photos: [`/photos/hero-beach.jpg`], label: 'A beach at sunset carried across two monitors side by side.' },
    'The Static kind.'),

  one('laptop', { id: 'pv-laptop', photos: [`/photos/hero-beach.jpg`, `${P}/hero-beach-night.jpg`], label: 'A beach carried across a monitor and the laptop beside it, fading from day to night.' },
    'The Light and Dark kind, crossfading, with the pair covering both screens. The laptop screen sits lower, so it shows a lower part of the photograph.', '44rem'),

  one('portrait-trio', { id: 'pv-trio', photos: ['/photos/1200/hero-day-1.jpg'], label: 'One alpine ridge carried across a portrait monitor, a landscape monitor and another portrait monitor.' },
    'The Dynamic kind, and the tallest rig on the page.', '44rem'),

  one('trio', { id: 'pv-row', photos: [`${P}/hero-day-1.jpg`], label: 'An alpine ridge at sunrise carried across three matched monitors.' },
    'The bezel comparison rig, and the one that crops the panoramas least.', '64rem'),

  one('ultrawide', { id: 'pv-ultra', photos: [`/photos/hero-beach.jpg`], label: 'A beach at sunset on a single ultrawide monitor.' },
    'The most upright rig in the set.', '30rem'),

  one('mixed', { id: 'pv-mixed', photos: [`${P}/hero-day-2.jpg`], label: 'The editor canvas: an ultrawide beside a portrait monitor, the photograph reaching past both.' },
    'The editor canvas. The HUD glyphs are @icon tokens, which only expand inside files index.html includes, so they are blank here and correct in a section.', '40rem'),

  one('thumb', { id: 'pv-thumb', photos: ['/photos/hero-beach.jpg'] },
    'Shown at 92px tall, the size it has to survive.', '520px'),

  block(
    'The other gallery thumbnails',
    'Three arrangements beside the plain trio, each at its own size inside a shared tile rather than stretched to fill one.',
    ['thumb-pair', 'thumb-portrait', 'thumb-laptop']
      .map((n, i) => markup(n, { id: `pv-${n}`, photos: [`${P}/hero-day-${i + 2}.jpg`], indent: '      ' }))
      .join('\n    </div><div style="max-width: 520px; margin-top: 1.5rem">'),
    '520px'
  ),

  block(
    'Thin against thick frames',
    'The same rig twice, one at --rig-bezel 4 and one at 26. The photograph does not move: the frames eat further into it and the ridgeline still lines up across the gap.',
    pair(
      bezel('pv-thin', 4, 'Three displays with narrow frames.'),
      bezel('pv-thick', 26, 'The same three displays with wide frames.')
    )
  ),

  block(
    'Dynamic day cycle',
    'Five photographs: four hours of the day plus a repeat of the first so the loop closes on a fade.',
    markup('portrait-trio', {
      id: 'pv-day',
      photos: [1, 2, 3, 4, 1].map((n) => `/photos/1200/hero-day-${n}.jpg`),
      day: true,
      indent: '      ',
      label: 'Three monitors running through one day, sunrise to night.',
      glow: GLOW['portrait-trio'],
    }),
    '44rem'
  ),

  block(
    'Two rigs of the same kind on one page',
    'Different clipPath ids. If the second one is blank, ids collided.',
    pair(
      markup('dual', { id: 'pv-twin-a', photos: [`${P}/hero-day-3.jpg`], indent: '      ', label: 'First of two.' }),
      markup('dual', { id: 'pv-twin-b', photos: [`${P}/hero-day-4.jpg`], indent: '      ', label: 'Second of two.' })
    )
  ),
]

writeFileSync(
  resolve(ROOT, 'rigs-preview.html'),
  `<!DOCTYPE html>
<!-- Generated development preview of src/rigs.css. Run \`npm run rigs\` to rebuild
     it, and edit scripts/rigs-preview.mjs rather than this file. It is not part
     of the site: the Vite build only builds index.html, so nothing here ships. -->
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Rig preview</title>
<link rel="stylesheet" href="/src/style.css">
<style>
  body { padding: 3rem 1.5rem; max-width: 72rem; margin-inline: auto; }
  section { padding-block: 3rem; border-top: 1px solid #2a2a32; }
  h2 { font-size: 1.05rem; font-weight: 600; color: #e8e8ed; }
  p { margin-top: .4rem; margin-bottom: 1.75rem; color: #9e9eaa; font-size: .9rem; max-width: 62ch; }
  .rig-thumb { height: 92px; width: auto; }
</style>
</head>
<body>
<h1 style="font-size:1.6rem;font-weight:700">Monitor rigs</h1>
<p>Development preview of src/rigs.css, generated by <code>npm run rigs</code>. Not part of the site.</p>
${parts.join('\n')}
</body>
</html>
`
)
console.log('rigs-preview.html')
