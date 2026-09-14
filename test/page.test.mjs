/**
 * Drives the built page in a DOM and asserts how it behaves, which reading the
 * markup cannot tell you. Both bugs found this way read correctly in
 * source and behaved wrongly in the browser.
 *
 * Run with `npm test`, which builds first. Assertions belong here whenever a
 * section's CSS depends on how this script hides something, since that
 * coupling is invisible from either file on its own.
 *
 * WHAT THIS CANNOT TEST. jsdom drops every rule inside `@layer`, and Tailwind
 * puts all of preflight there, so `getComputedStyle` answers as though half the
 * stylesheet does not exist. It reported a section's `display` override winning
 * a fight it actually loses to preflight's `!important`. So assert attributes,
 * classes and inline styles, which are real, and never a computed style or
 * anything resolved through the cascade: those come back confidently wrong.
 * jsdom also has no layout, so every measurement is zero. A rule about which
 * of two stylesheet declarations wins has to be checked in a browser.
 */
import { readFileSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { JSDOM } from 'jsdom'

const site = join(dirname(fileURLToPath(import.meta.url)), '..', 'dist')
const html = readFileSync(join(site, 'index.html'), 'utf8')
const bundleName = readdirSync(join(site, 'assets')).find((f) => f.endsWith('.js'))
const bundle = readFileSync(join(site, 'assets', bundleName), 'utf8')

let failures = 0
const check = (name, condition, detail = '') => {
  if (condition) console.log(`  pass  ${name}`)
  else {
    failures++
    console.log(`  FAIL  ${name} ${detail}`)
  }
}

const { window } = new JSDOM(html, { pretendToBeVisual: true, runScripts: 'outside-only' })
const doc = window.document

// jsdom ships neither of these; the nav and the reveal both reach for them.
window.matchMedia = () => ({ matches: false, addEventListener() {}, removeEventListener() {} })
const observers = []
window.IntersectionObserver = class {
  constructor(callback, options) {
    this.callback = callback
    this.options = options
    this.targets = []
    observers.push(this)
  }
  observe(target) {
    this.targets.push(target)
  }
  unobserve() {}
  disconnect() {}
}

const slider = doc.querySelector('[data-bezel-slider]')
const control = doc.querySelector('[data-bezel-control]')
const readout = doc.querySelector('[data-bezel-readout]')
const rig = slider && doc.getElementById(slider.dataset.bezelTarget)
const copyButton = doc.querySelector('[data-copy-target]')
const tabRoot = doc.querySelector('[data-tabs]')
const tabList = tabRoot && tabRoot.querySelector('[data-tabs-list]')

console.log('with no script, the page is still complete')
check('bezel control ships hidden', control?.hasAttribute('hidden'))
check('tab list ships hidden', tabList?.hasAttribute('hidden'))
check('copy button ships hidden', copyButton?.hasAttribute('hidden'))
check('the command itself is readable', doc.getElementById('quarantine-command')?.textContent.includes('xattr'))
const tabsBefore = tabList ? [...tabList.querySelectorAll('[role="tab"]')] : []
const panelsBefore = tabsBefore.map((tab) => doc.getElementById(tab.getAttribute('aria-controls')))
check('every tab panel is readable', panelsBefore.length > 0 && panelsBefore.every((p) => p && !p.hasAttribute('inert')))
check('no panel sits in the tab order yet', panelsBefore.every((p) => !p.hasAttribute('tabindex')))
check('nav menu links exist in the markup', doc.querySelectorAll('#nav-menu a').length > 0)
check('no tabs-ready flag before the script', !tabRoot?.hasAttribute('data-tabs-ready'))

window.eval(bundle)

const panels0 = panelsBefore

console.log('\nbezel slider')
const startValue = slider.value
check('control is revealed', !control.hasAttribute('hidden'))
check('property matches the slider on load', rig.style.getPropertyValue(slider.dataset.bezelProp) === startValue,
  `got "${rig.style.getPropertyValue(slider.dataset.bezelProp)}" want "${startValue}"`)
check('readout agrees on load', readout.textContent === `${startValue}${slider.dataset.bezelUnit}`,
  `got "${readout.textContent}"`)
check('readout is hidden from assistive tech', readout.getAttribute('aria-hidden') === 'true')
check('slider speaks its unit', slider.getAttribute('aria-valuetext') === `${startValue} points`,
  `got "${slider.getAttribute('aria-valuetext')}"`)

slider.value = '75'
slider.dispatchEvent(new window.Event('input', { bubbles: true }))
check('property follows the drag', rig.style.getPropertyValue(slider.dataset.bezelProp) === '75',
  `got "${rig.style.getPropertyValue(slider.dataset.bezelProp)}"`)
check('readout follows the drag', readout.textContent === '75 pt', `got "${readout.textContent}"`)
check('spoken value follows the drag', slider.getAttribute('aria-valuetext') === '75 points')
check('property stays unitless, so the section composes the unit',
  !/[a-z%]/i.test(rig.style.getPropertyValue(slider.dataset.bezelProp)))

slider.value = slider.max
slider.dispatchEvent(new window.Event('input', { bubbles: true }))
check('the far end of the range applies', rig.style.getPropertyValue(slider.dataset.bezelProp) === slider.max)

// A closed panel has to keep its box, which is the whole reason for inert over
// hidden, and nothing in the script may put display:none back on it.
check('no panel is ever hidden outright', panels0.every((p) => !p.hasAttribute('hidden')),
  'a hidden attribute collapses the box and the page jumps on every switch')

const panelClasses = panelsBefore.map((p) => p.className)

console.log('\ntabs')
const tabs = [...tabList.querySelectorAll('[role="tab"]')]
const panels = tabs.map((tab) => doc.getElementById(tab.getAttribute('aria-controls')))
check('tab list is revealed', !tabList.hasAttribute('hidden'))
check('root is flagged ready for its own CSS', tabRoot.hasAttribute('data-tabs-ready'))
check('three tabs found', tabs.length === 3, `got ${tabs.length}`)
check('every tab resolves to a panel', panels.every(Boolean))
check('the script gives each panel its role', panels.every((p) => p.getAttribute('role') === 'tabpanel'))
check('each panel is labelled by its own tab',
  panels.every((p, i) => p.getAttribute('aria-labelledby') === tabs[i].id && tabs[i].id))
check('each panel becomes focusable', panels.every((p) => p.getAttribute('tabindex') === '0'))
check('first tab selected', tabs[0].getAttribute('aria-selected') === 'true')
check('other tabs leave the tab order', tabs.slice(1).every((tab) => tab.tabIndex === -1))
check('only the first panel is open', panels.slice(1).every((p) => p.hasAttribute('inert')) && !panels[0].hasAttribute('inert'))

tabs[0].dispatchEvent(new window.KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }))
check('arrow down moves selection', tabs[1].getAttribute('aria-selected') === 'true')
check('and swaps the panel', !panels[1].hasAttribute('inert') && panels[0].hasAttribute('inert'))

tabs[1].dispatchEvent(new window.KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true }))
check('arrow up moves back', tabs[0].getAttribute('aria-selected') === 'true')

tabs[0].dispatchEvent(new window.KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true }))
check('arrow up wraps to the last', tabs.at(-1).getAttribute('aria-selected') === 'true')

tabs.at(-1).dispatchEvent(new window.KeyboardEvent('keydown', { key: 'Home', bubbles: true }))
check('home jumps to the first', tabs[0].getAttribute('aria-selected') === 'true')

tabs[2].dispatchEvent(new window.MouseEvent('click', { bubbles: true }))
check('click selects', tabs[2].getAttribute('aria-selected') === 'true')
check('exactly one panel is ever open', panels.filter((p) => !p.hasAttribute('inert')).length === 1)
// A closed panel is marked inert and the section hides it, so the script must not
// hide it as well: an inline style or a class here would take the choice away and,
// with visibility, would break the transition the section fades it out with.
check('panels are closed by attribute, never by inline style',
  panels.every((p) => !p.style.display),
  panels.map((p) => p.style.display).join(','))
check('and never by a class',
  panels.every((p, i) => p.className === panelClasses[i]),
  panels.map((p, i) => `${p.className} was ${panelClasses[i]}`).join(' | '))

console.log('\nnav menu')
const toggle = doc.getElementById('nav-toggle')
const menu = doc.getElementById('nav-menu')
check('menu starts closed', menu.hasAttribute('hidden'))
toggle.dispatchEvent(new window.MouseEvent('click', { bubbles: true }))
check('click opens it', !menu.hasAttribute('hidden'))
check('aria-expanded tracks it', toggle.getAttribute('aria-expanded') === 'true')
check('glyphs swap',
  doc.querySelector('[data-nav-icon="open"]').hasAttribute('hidden') &&
    !doc.querySelector('[data-nav-icon="close"]').hasAttribute('hidden'))
menu.querySelector('a').dispatchEvent(new window.MouseEvent('click', { bubbles: true }))
check('following a link closes it', menu.hasAttribute('hidden'))
toggle.dispatchEvent(new window.MouseEvent('click', { bubbles: true }))
doc.dispatchEvent(new window.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
check('escape closes it', menu.hasAttribute('hidden'))
check('and restores the glyphs',
  !doc.querySelector('[data-nav-icon="open"]').hasAttribute('hidden') &&
    doc.querySelector('[data-nav-icon="close"]').hasAttribute('hidden'))

console.log('\ncopy button')
check('stays hidden where there is no clipboard',
  window.navigator.clipboard ? !copyButton.hasAttribute('hidden') : copyButton.hasAttribute('hidden'),
  `clipboard present: ${Boolean(window.navigator.clipboard)}`)

console.log('\nscroll spy')
const spy = observers.find((o) => o.options?.rootMargin === '-20% 0px -70% 0px')
check('the spy is watching something', Boolean(spy?.targets.length))
check('it watches sections only, never the main wrapper',
  spy.targets.every((t) => t.tagName === 'SECTION'),
  spy.targets.map((t) => `${t.tagName}#${t.id}`).join(', '))

// `main` wraps every section, so it intersects wherever the reader is. Replaying
// that is what shows whether the spy marks the section or the page.
const marksFor = (id) => {
  spy.callback(spy.targets.map((target) => ({ target, isIntersecting: target.id === id })))
  return [...doc.querySelectorAll('#site-nav [aria-current]')].map((a) => a.getAttribute('href'))
}
for (const id of ['types', 'editor', 'gallery']) {
  const marked = marksFor(id)
  check(`reading #${id} marks its own link`, marked.length > 0 && marked.every((h) => h === `#${id}`),
    `marked ${marked.join(' + ') || 'nothing'}`)
}
check('the wordmark is never marked', !doc.querySelector('#site-nav a[href="#main"][aria-current]'))

console.log('\nclock phase')
const clock = doc.querySelector('[data-clock-stops]')
check('a section carries the clock contract', Boolean(clock))
// Read off the markup rather than restated here, so changing the stops cannot
// leave this asserting a schedule the page no longer runs.
const stops = clock.dataset.clockStops.split(',').map((stop) => Number(stop.trim()))
const hour = new Date().getHours()
// Re-derived rather than hardcoded, so the check means something at any hour.
const found = stops.findLastIndex((stop) => stop <= hour)
const expected = String((found < 0 ? stops.length - 1 : found) / stops.length)
check(`phase matches the wall clock at ${hour}:00`,
  clock.style.getPropertyValue('--clock-phase') === expected,
  `got "${clock.style.getPropertyValue('--clock-phase')}" want "${expected}"`)
check('the phase is a bare fraction, so the section owns the duration',
  /^0(\.\d+)?$/.test(clock.style.getPropertyValue('--clock-phase')))

console.log('\nicons')
const glyphs = [...doc.querySelectorAll('svg')].filter((s) => s.getAttribute('viewBox') === '0 0 256 256')
check('every Phosphor glyph is hidden from assistive tech',
  glyphs.length > 0 && glyphs.every((g) => g.getAttribute('aria-hidden') === 'true'), `${glyphs.length} glyphs`)
check('no icon token survived unexpanded', !html.includes('@icon'))

console.log(failures ? `\n${failures} FAILED` : '\nall checks passed')
process.exit(failures ? 1 : 0)
