import './style.css'

/**
 * Wires the small-width nav menu to its toggle, keeping `aria-expanded` and
 * the icon pair in step. Escape closes it and hands focus back.
 *
 * Visibility moves through `toggleAttribute` rather than the `hidden`
 * property, which SVG elements do not carry, so the glyphs swap.
 */
function setupMobileMenu() {
  const toggle = document.getElementById('nav-toggle')
  const menu = document.getElementById('nav-menu')
  if (!toggle || !menu) return

  const openIcon = toggle.querySelector('[data-nav-icon="open"]')
  const closeIcon = toggle.querySelector('[data-nav-icon="close"]')

  const setOpen = (open) => {
    menu.toggleAttribute('hidden', !open)
    toggle.setAttribute('aria-expanded', String(open))
    if (openIcon) openIcon.toggleAttribute('hidden', open)
    if (closeIcon) closeIcon.toggleAttribute('hidden', !open)
  }

  toggle.addEventListener('click', () => setOpen(menu.hasAttribute('hidden')))

  menu.addEventListener('click', (event) => {
    if (event.target.closest('a')) setOpen(false)
  })

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || menu.hasAttribute('hidden')) return
    setOpen(false)
    toggle.focus()
  })

  // Above `md` the panel is hidden by CSS, so close it rather than leave it open underneath.
  window.matchMedia('(min-width: 48rem)').addEventListener('change', (event) => {
    if (event.matches) setOpen(false)
  })
}

/**
 * Marks the nav link for the section the reader is in with `aria-current`.
 * Runs off one observer rather than a scroll handler.
 */
function setupScrollSpy() {
  const linksById = new Map()
  document.querySelectorAll('#site-nav a[href^="#"]').forEach((link) => {
    const id = link.getAttribute('href').slice(1)
    if (!id) return
    if (!linksById.has(id)) linksById.set(id, [])
    linksById.get(id).push(link)
  })

  // Sections only: the wordmark points at `#main`, which wraps every one of them
  // and so always intersects, and would take the mark on every scroll position.
  const sections = [...linksById.keys()]
    .map((id) => document.getElementById(id))
    .filter((element) => element?.tagName === 'SECTION')
  if (!sections.length) return

  const visible = new Set()
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) visible.add(entry.target.id)
        else visible.delete(entry.target.id)
      })

      const active = sections.find((section) => visible.has(section.id))
      linksById.forEach((links, id) => {
        links.forEach((link) => {
          if (active && active.id === id) link.setAttribute('aria-current', 'true')
          else link.removeAttribute('aria-current')
        })
      })
    },
    { rootMargin: '-20% 0px -70% 0px' }
  )

  sections.forEach((section) => observer.observe(section))
}

/**
 * Fades a block in once as it reaches the viewport. Opting in per element
 * with `data-reveal` keeps the page readable if the script never runs.
 */
function setupScrollReveal() {
  const targets = document.querySelectorAll('[data-reveal]')
  if (!targets.length) return

  document.documentElement.classList.add('js-reveal')

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry, index) => {
        if (!entry.isIntersecting) return
        entry.target.style.transitionDelay = index > 0 ? '60ms' : '0ms'
        entry.target.classList.add('is-revealed')
        observer.unobserve(entry.target)
      })
    },
    { threshold: 0.1, rootMargin: '0px 0px -40px 0px' }
  )

  targets.forEach((target) => observer.observe(target))
}

/**
 * Copies the text of the element a button names in `data-copy-target`, then
 * swaps its label and glyph for a confirmation that clears itself. The
 * button ships hidden, so it appears only once it can do something.
 */
function setupCopyButtons() {
  document.querySelectorAll('[data-copy-target]').forEach((button) => {
    const label = button.querySelector('[data-copy-text]')
    const source = document.getElementById(button.dataset.copyTarget)

    if (!label || !source || !navigator.clipboard) return

    button.toggleAttribute('hidden', false)

    const idleIcon = button.querySelector('[data-copy-icon="idle"]')
    const doneIcon = button.querySelector('[data-copy-icon="done"]')

    const setCopied = (copied) => {
      label.textContent = copied ? button.dataset.copiedLabel : button.dataset.copyLabel
      if (idleIcon) idleIcon.toggleAttribute('hidden', copied)
      if (doneIcon) doneIcon.toggleAttribute('hidden', !copied)
    }

    let reset
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(source.textContent.trim())
      } catch {
        return
      }

      setCopied(true)
      clearTimeout(reset)
      reset = setTimeout(() => setCopied(false), 2000)
    })
  })
}

/**
 * Binds each range input that names a CSS custom property to the element it
 * scales, keeping the readout beside it in step. The control ships
 * hidden, so an unbound slider is never left on screen.
 *
 * Markup contract, all of it data attributes so no section is named here:
 * `[data-bezel-control]` wraps the control and carries `hidden`;
 * `[data-bezel-slider]` names `data-bezel-target`, `data-bezel-prop` and an
 * optional `data-bezel-unit` for the readout and `data-bezel-unit-label`
 * for the spoken one; `[data-bezel-readout]` takes the written value.
 */
function setupBezelSliders() {
  document.querySelectorAll('[data-bezel-slider]').forEach((slider) => {
    const target = document.getElementById(slider.dataset.bezelTarget)
    const property = slider.dataset.bezelProp
    if (!target || !property) return

    const control = slider.closest('[data-bezel-control]')
    const readout = control?.querySelector('[data-bezel-readout]')
    const unit = slider.dataset.bezelUnit ?? ''
    const spokenUnit = slider.dataset.bezelUnitLabel ?? unit.trim()

    // The range announces its own value, so an announcing readout would double it.
    if (readout) readout.setAttribute('aria-hidden', 'true')

    const apply = () => {
      target.style.setProperty(property, slider.value)
      if (readout) readout.textContent = `${slider.value}${unit}`
      slider.setAttribute('aria-valuetext', spokenUnit ? `${slider.value} ${spokenUnit}` : slider.value)
    }

    slider.addEventListener('input', apply)
    apply()
    if (control) control.toggleAttribute('hidden', false)
  })
}

/**
 * Wires every `[data-tabs]` root into a tablist, with roving tabindex and
 * arrow keys. The panels read as a stacked list on their own, so both
 * the list and their tabpanel roles wait for a full set.
 *
 * Markup contract: `[data-tabs]` wraps the set and takes `data-tabs-ready`
 * once wired, for any CSS the section wants to hang off that. Inside it,
 * `[data-tabs-list]` carries `hidden` and holds the `[role="tab"]` buttons,
 * each naming its panel through `aria-controls`. The tab marked
 * `aria-selected="true"` in the markup is the one that opens, and each
 * panel takes its `role`, `aria-labelledby` and `tabindex` from here.
 *
 * A closed panel is marked `inert`, which takes it out of the tab order and
 * the accessibility tree but draws nothing, so the section owns hiding it.
 * `visibility: hidden` is the expected choice, and it keeps the panel's box
 * so switching tabs cannot move the page. Hiding a panel with `hidden`
 * instead would work but could never be overridden: preflight sets
 * `display: none` on it with `!important` from inside a cascade layer,
 * which beats any section rule, layered or not, important or not.
 */
function setupTabs() {
  document.querySelectorAll('[data-tabs]').forEach((root) => {
    const list = root.querySelector('[data-tabs-list]')
    if (!list) return

    const tabs = [...list.querySelectorAll('[role="tab"]')]
    const panels = tabs.map((tab) => document.getElementById(tab.getAttribute('aria-controls')))
    if (!tabs.length || panels.some((panel) => !panel)) return

    // A hidden list leaves the accessibility tree, so these would otherwise name a
    // tablist that is not there and put three inert panels in the tab order.
    panels.forEach((panel, index) => {
      if (!tabs[index].id) tabs[index].id = `${panel.id}-tab`
      panel.setAttribute('role', 'tabpanel')
      panel.setAttribute('aria-labelledby', tabs[index].id)
      panel.setAttribute('tabindex', '0')
    })

    const select = (index, moveFocus) => {
      tabs.forEach((tab, i) => {
        const isCurrent = i === index
        tab.setAttribute('aria-selected', String(isCurrent))
        tab.tabIndex = isCurrent ? 0 : -1
        // `inert` rather than `hidden`, because preflight sets `display: none` on
        // `[hidden]` with `!important` inside a layer, which no section rule can beat.
        panels[i].toggleAttribute('inert', !isCurrent)
      })
      if (moveFocus) tabs[index].focus()
    }

    // Up and down are the pair a vertical tablist owes its reader. Left and
    // right come along because nobody checks the orientation before reaching.
    const steps = { ArrowUp: -1, ArrowLeft: -1, ArrowDown: 1, ArrowRight: 1 }

    tabs.forEach((tab, index) => {
      tab.addEventListener('click', () => select(index, false))
      tab.addEventListener('keydown', (event) => {
        if (event.key === 'Home' || event.key === 'End') {
          event.preventDefault()
          select(event.key === 'Home' ? 0 : tabs.length - 1, true)
          return
        }

        const step = steps[event.key]
        if (!step) return
        event.preventDefault()
        select((index + step + tabs.length) % tabs.length, true)
      })
    })

    // The markup names the tab to open, so a section chooses its own default.
    const marked = tabs.findIndex((tab) => tab.getAttribute('aria-selected') === 'true')

    root.setAttribute('data-tabs-ready', '')
    list.toggleAttribute('hidden', false)
    select(marked < 0 ? 0 : marked, false)
  })
}

/**
 * Phases a looping animation to the reader's own clock, so a day cycle opens on
 * the hour they are actually in. Writes a fraction and nothing else: the
 * section owns every duration and turns it into a delay.
 *
 * Markup contract: `data-clock-stops` is a comma separated list of local hours
 * in the order the loop runs through them, and `--clock-phase` comes back as
 * that stop's index over the count. It defaults to 0, which is the loop
 * starting at its first stop, so a section reads correctly without this.
 */
function setupClockPhase() {
  document.querySelectorAll('[data-clock-stops]').forEach((element) => {
    const stops = element.dataset.clockStops.split(',').map((stop) => Number(stop.trim()))
    if (!stops.length || stops.some((stop) => !Number.isFinite(stop))) return

    // Before the first stop belongs to the last one: 3am is still the small hours
    // of the night that began at the final stop of the day before.
    const hour = new Date().getHours()
    const found = stops.findLastIndex((stop) => stop <= hour)
    const index = found < 0 ? stops.length - 1 : found

    element.style.setProperty('--clock-phase', String(index / stops.length))
  })
}

setupMobileMenu()
setupScrollSpy()
setupScrollReveal()
setupCopyButtons()
setupBezelSliders()
setupTabs()
setupClockPhase()
