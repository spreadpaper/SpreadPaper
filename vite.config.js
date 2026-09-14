import { readFileSync } from 'node:fs'
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

export default defineConfig({
  plugins: [htmlIncludes(), tailwindcss()],
  base: '/SpreadPaper/',
  build: {
    outDir: 'dist',
  },
})
