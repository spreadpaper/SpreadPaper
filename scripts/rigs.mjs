// The geometry of every monitor rig, and the one place it is written down.
// RIGS.md and rigs-preview.html are both generated from here by `npm run rigs`,
// so the clip rects and the frame rects that trace them cannot drift apart.
//
// Screens are drawn to scale from real displays. k is viewBox units per inch of
// real screen height, picked so a 27-inch screen comes out 200 units tall.

export const K = 15.09

/** Real screens, in viewBox units. A laptop reads as a laptop only at true size. */
export const SCREEN = {
  monitor27: { w: 355, h: 200 },
  monitor27Portrait: { w: 200, h: 355 },
  ultrawide34: { w: 474, h: 203 },
  laptop14: { w: 181, h: 117 },
}

// One URL per photograph for the whole page, whatever rig shows it. A browser
// caches per URL, so a second size is a second download of a picture the page
// already has rather than a cheaper substitute for it. The beach is the one
// 2400px original, because the hero draws it at full shell width.
export const PHOTOS = {
  'hero-beach': { url: '/photos/hero-beach.jpg', caption: 'Beach at sunset' },
  'hero-beach-night': { url: '/photos/1200/hero-beach-night.jpg', caption: 'Beach at night' },
  'hero-day-1': { url: '/photos/1200/hero-day-1.jpg', caption: 'Sunrise on the ridge' },
  'hero-day-2': { url: '/photos/1200/hero-day-2.jpg', caption: 'Midday over the peak' },
  'hero-day-3': { url: '/photos/1200/hero-day-3.jpg', caption: 'Evening light' },
  'hero-day-4': { url: '/photos/1200/hero-day-4.jpg', caption: 'The Milky Way' },
}

// What the app's editor HUD actually shows, read off EditorView.swift rather
// than from memory of what an editor HUD usually looks like.
const HUD_GLYPHS = ['minus', 'plus', 'arrows-out-simple', 'arrows-left-right']

const GAP = 6
const NECK = { w: 28, h: 28 }
const FOOT = { w: 110, h: 8 }
const STAND_DROP = NECK.h + FOOT.h

const m27 = (x, y = 0) => ({ x, y, ...SCREEN.monitor27, rx: 10 })
const m27p = (x, y = 0) => ({ x, y, ...SCREEN.monitor27Portrait, rx: 10 })
const lid = (x, y) => ({ x, y, ...SCREEN.laptop14, rx: 8 })

export const RIGS = {
  desk: {
    title: 'A laptop and two monitors',
    section: 'hero',
    viewBox: [911, 236],
    image: { x: 0, y: 0, w: 911, h: 218 },
    screens: [lid(0, 101), m27(195), m27(556)],
    stands: [{ cx: 372.5, top: 200 }, { cx: 733.5, top: 200 }],
    laptop: { chin: { x: 0, y: 210, w: 181, h: 20, rx: 3 }, base: { x: 0, y: 230, w: 189, h: 6, rx: 3 } },
    glow: true,
  },
  dual: {
    title: 'Two matched monitors',
    section: 'the Static kind',
    viewBox: [716, 236],
    image: { x: 0, y: 0, w: 716, h: 200 },
    screens: [m27(0), m27(361)],
    stands: [{ cx: 177.5, top: 200 }, { cx: 538.5, top: 200 }],
    glow: true,
  },
  laptop: {
    title: 'A monitor and a laptop',
    section: 'the Light and Dark kind',
    viewBox: [550, 236],
    image: { x: 0, y: 0, w: 550, h: 218 },
    screens: [m27(0), lid(361, 101)],
    stands: [{ cx: 177.5, top: 200 }],
    laptop: { chin: { x: 361, y: 210, w: 181, h: 20, rx: 3 }, base: { x: 357, y: 230, w: 189, h: 6, rx: 3 } },
    glow: true,
  },
  'portrait-trio': {
    title: 'Portrait, landscape, portrait',
    section: 'the Dynamic kind',
    viewBox: [767, 391],
    image: { x: 0, y: 0, w: 767, h: 355 },
    screens: [m27p(0), m27(206, 155), m27p(567)],
    stands: [{ cx: 100, top: 355 }, { cx: 383.5, top: 355 }, { cx: 667, top: 355 }],
    glow: true,
  },
  trio: {
    title: 'Three matched monitors',
    section: 'the editor bezel comparison',
    viewBox: [1077, 236],
    image: { x: 0, y: 0, w: 1077, h: 200 },
    screens: [m27(0), m27(361), m27(722)],
    stands: [{ cx: 177.5, top: 200 }, { cx: 538.5, top: 200 }, { cx: 899.5, top: 200 }],
    glow: true,
  },
  ultrawide: {
    title: 'One ultrawide',
    section: 'a single-display beat',
    viewBox: [474, 239],
    image: { x: 0, y: 0, w: 474, h: 203 },
    screens: [{ x: 0, y: 0, ...SCREEN.ultrawide34, rx: 10 }],
    stands: [{ cx: 237, top: 203, footW: 150 }],
    glow: true,
  },
  mixed: {
    title: 'The editor canvas',
    section: 'the editor canvas',
    viewBox: [728, 403],
    image: { x: 0, y: 0, w: 728, h: 403 },
    bleed: true,
    crop: { x: 14, y: 14, w: 700, h: 375, rx: 8 },
    screens: [{ x: 24, y: 100, ...SCREEN.ultrawide34, rx: 10 }, m27p(504, 24)],
    stands: [],
    hud: { bar: { x: 175, y: 253, w: 172, h: 30, rx: 15 }, glyphs: [191, 233, 275, 317], y: 261, size: 14 },
  },
  'thumb-pair': {
    title: 'Gallery thumbnail, two monitors',
    section: 'gallery cards',
    viewBox: [230, 64],
    image: { x: 0, y: 0, w: 230, h: 64 },
    screens: [
      { x: 0, y: 0, w: 114, h: 64, rx: 3 },
      { x: 116, y: 0, w: 114, h: 64, rx: 3 },
    ],
    stands: [],
  },
  'thumb-portrait': {
    title: 'Gallery thumbnail, a portrait beside a landscape',
    section: 'gallery cards',
    viewBox: [180, 114],
    image: { x: 0, y: 0, w: 180, h: 114 },
    screens: [
      { x: 0, y: 0, w: 64, h: 114, rx: 3 },
      { x: 66, y: 50, w: 114, h: 64, rx: 3 },
    ],
    stands: [],
  },
  'thumb-laptop': {
    title: 'Gallery thumbnail, a monitor and a laptop',
    section: 'gallery cards',
    viewBox: [174, 70],
    image: { x: 0, y: 0, w: 174, h: 70 },
    screens: [
      { x: 0, y: 0, w: 114, h: 64, rx: 3 },
      { x: 116, y: 32, w: 58, h: 37, rx: 2 },
    ],
    stands: [],
  },
  thumb: {
    title: 'Gallery thumbnail, three monitors',
    section: 'gallery cards',
    viewBox: [346, 64],
    image: { x: 0, y: 0, w: 346, h: 64 },
    screens: [
      { x: 0, y: 0, w: 114, h: 64, rx: 3 },
      { x: 116, y: 0, w: 114, h: 64, rx: 3 },
      { x: 232, y: 0, w: 114, h: 64, rx: 3 },
    ],
    stands: [],
  },
}

const rect = (s, cls) =>
  `<rect${cls ? ` class="${cls}"` : ''} x="${s.x}" y="${s.y}" width="${s.w}" height="${s.h}"${s.rx ? ` rx="${s.rx}"` : ''}/>`

/**
 * Writes the markup for one rig, ready to paste into a section. `photos` is
 * one href, or several to stack for a crossfade, and `id` has to be
 * unique across the whole page.
 *
 * @param {string} name - Key in RIGS.
 * @param {{id: string, photos: string[], label?: string, classes?: string, indent?: string, day?: boolean, glyphs?: string[]}} opts
 * @returns {string} The SVG markup.
 */
export function markup(name, { id, photos, label, classes = '', indent = '', day = false, glyphs = HUD_GLYPHS }) {
  const r = RIGS[name]
  const [vw, vh] = r.viewBox
  const p = (n) => indent + '  '.repeat(n)
  const a11y = label ? `role="img" aria-label="${label}"` : 'aria-hidden="true"'

  const images = photos.map((href, i) => {
    let cls = 'rig-photo'
    if (i > 0) cls += day ? ` rig-day rig-day-${i + 1}` : ' rig-photo-fade'
    if (day && i > 0 && i === photos.length - 1) cls = 'rig-photo rig-day rig-day-wrap'
    return `${p(2)}<image class="${cls}" href="${href}" x="${r.image.x}" y="${r.image.y}" width="${r.image.w}" height="${r.image.h}" preserveAspectRatio="xMidYMid slice"/>`
  })

  const furniture = r.stands.map((st) => {
    const footW = st.footW ?? FOOT.w
    return (
      p(2) +
      `<rect x="${st.cx - NECK.w / 2}" y="${st.top}" width="${NECK.w}" height="${NECK.h}"/>` +
      `<rect x="${st.cx - footW / 2}" y="${st.top + NECK.h}" width="${footW}" height="${FOOT.h}" rx="4"/>`
    )
  })
  if (r.laptop) furniture.push(p(2) + rect(r.laptop.base))

  const lines = [
    `${indent}<svg class="rig rig-${name}${classes ? ' ' + classes : ''}" viewBox="0 0 ${vw} ${vh}" ${a11y} focusable="false">`,
    `${p(1)}<defs>`,
    `${p(2)}<clipPath id="${id}">`,
    ...r.screens.map((s) => p(3) + rect(s)),
    `${p(2)}</clipPath>`,
    `${p(1)}</defs>`,
  ]

  if (r.glow) {
    lines.push(
      `${p(1)}<ellipse class="rig-glow" cx="${vw / 2}" cy="${vh - 2}" rx="${Math.round(vw * 0.42)}" ry="10"/>`
    )
  }
  if (furniture.length) lines.push(`${p(1)}<g class="rig-stand">`, ...furniture, `${p(1)}</g>`)
  if (r.laptop) lines.push(p(1) + rect(r.laptop.chin, 'rig-chin'))
  if (r.bleed) {
    lines.push(
      `${p(1)}<image class="rig-bleed" href="${photos[0]}" x="${r.image.x}" y="${r.image.y}" width="${r.image.w}" height="${r.image.h}" preserveAspectRatio="xMidYMid slice"/>`,
      `${p(1)}` + rect(r.crop, 'rig-crop')
    )
  }

  lines.push(
    `${p(1)}<g clip-path="url(#${id})">`,
    ...images,
    ...r.screens.map((s) => p(2) + rect(s, 'rig-frame')),
    `${p(1)}</g>`
  )

  if (r.hud) {
    lines.push(`${p(1)}<g class="rig-hud">`, p(2) + rect(r.hud.bar, 'rig-hud-bar'))
    r.hud.glyphs.forEach((x, i) => {
      lines.push(
        `${p(2)}<!--@icon ${glyphs[i]} x="${x}" y="${r.hud.y}" width="${r.hud.size}" height="${r.hud.size}"-->`
      )
    })
    lines.push(`${p(1)}</g>`)
  }

  lines.push(`${indent}</svg>`)
  return lines.join('\n')
}

/** Checks that every screen sits inside both the image box and the viewBox. */
export function check() {
  const problems = []
  for (const [name, r] of Object.entries(RIGS)) {
    const [vw, vh] = r.viewBox
    for (const s of r.screens) {
      if (s.x < r.image.x || s.y < r.image.y) problems.push(`${name}: a screen starts before the image`)
      if (s.x + s.w > r.image.x + r.image.w) problems.push(`${name}: a screen runs past the right of the image`)
      if (s.y + s.h > r.image.y + r.image.h) problems.push(`${name}: a screen runs past the bottom of the image`)
      if (s.x + s.w > vw || s.y + s.h > vh) problems.push(`${name}: a screen runs outside the viewBox`)
    }
    for (const st of r.stands) {
      if (st.top + STAND_DROP > vh) problems.push(`${name}: a stand runs past the bottom of the viewBox`)
    }
    if (r.laptop && r.laptop.base.y + r.laptop.base.h > vh) problems.push(`${name}: the laptop base runs past the viewBox`)
    if (r.hud) {
      const wide = r.screens[0]
      const { bar } = r.hud
      const inside =
        bar.x >= wide.x && bar.y >= wide.y && bar.x + bar.w <= wide.x + wide.w && bar.y + bar.h <= wide.y + wide.h
      if (!inside) problems.push(`${name}: the control bar is not over the wide screen`)
    }
  }
  return problems
}
