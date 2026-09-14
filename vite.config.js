import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'

/**
 * Inlines `<!--@include src/sections/name.html-->` at build and dev time, so each
 * section lives in its own file and edits never collide. Watches the
 * partials too, which is what makes them hot-reload.
 */
function htmlIncludes() {
  const pattern = /<!--@include\s+([^\s>]+)\s*-->/g
  return {
    name: 'html-includes',
    transformIndexHtml: {
      order: 'pre',
      handler(html) {
        return html.replace(pattern, (_, file) =>
          readFileSync(resolve(process.cwd(), file), 'utf8')
        )
      },
    },
    handleHotUpdate({ file, server }) {
      if (file.includes('/src/sections/')) {
        server.ws.send({ type: 'full-reload' })
        return []
      }
    },
  }
}

/* Phosphor ships as raw SVG here, so only the glyphs the page names are ever
   written out. The webfont build is 144 KB of woff2 for all 1,512 of them. */
const ICON_ROOT = resolve(
  createRequire(import.meta.url).resolve('@phosphor-icons/core/assets/regular/gear.svg'),
  '../..'
)

const ICON_TOKEN = /<!--@icon\s+([a-z][a-z0-9-]*)\s*([^>]*?)-->/g
const ICON_WEIGHT = /\bweight="([a-z]+)"/

/**
 * Expands `<!--@icon name attrs-->` into that Phosphor glyph, inlined as SVG,
 * so the page carries a dozen paths rather than an icon font. Every glyph
 * is emitted decorative, and an unknown name fails the build.
 *
 * @returns {import('vite').Plugin} The plugin, to run after the includes one.
 */
function phosphorIcons() {
  return {
    name: 'phosphor-icons',
    transformIndexHtml: {
      order: 'pre',
      handler(html) {
        return html.replace(ICON_TOKEN, (token, name, attrs) => {
          const weight = attrs.match(ICON_WEIGHT)?.[1] ?? 'regular'
          const file = resolve(ICON_ROOT, weight, `${name}${weight === 'regular' ? '' : `-${weight}`}.svg`)

          let source
          try {
            source = readFileSync(file, 'utf8')
          } catch {
            throw new Error(`${token} names no Phosphor glyph: there is no ${weight} icon called "${name}".`)
          }

          const viewBox = source.match(/viewBox="([^"]*)"/)?.[1] ?? '0 0 256 256'
          const body = source.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '')
          const rest = attrs.replace(ICON_WEIGHT, '').trim()

          return `<svg viewBox="${viewBox}" fill="currentColor" aria-hidden="true" focusable="false"${rest ? ` ${rest}` : ''}>${body}</svg>`
        })
      },
    },
  }
}

export default defineConfig({
  plugins: [htmlIncludes(), phosphorIcons(), tailwindcss()],
  base: '/SpreadPaper/',
  build: {
    outDir: 'dist',
  },
})
