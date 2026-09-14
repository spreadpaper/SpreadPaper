import './style.css'

/**
 * Wires the small-width nav menu to its toggle, keeping `aria-expanded` and
 * the icon pair in step. Escape closes it and hands focus back.
 */
function setupMobileMenu() {
  const toggle = document.getElementById('nav-toggle')
  const menu = document.getElementById('nav-menu')
  if (!toggle || !menu) return

  const openIcon = toggle.querySelector('[data-nav-icon="open"]')
  const closeIcon = toggle.querySelector('[data-nav-icon="close"]')

  const setOpen = (open) => {
    menu.hidden = !open
    toggle.setAttribute('aria-expanded', String(open))
    if (openIcon) openIcon.hidden = open
    if (closeIcon) closeIcon.hidden = !open
  }

  toggle.addEventListener('click', () => setOpen(menu.hidden))

  menu.addEventListener('click', (event) => {
    if (event.target.closest('a')) setOpen(false)
  })

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || menu.hidden) return
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

  const sections = [...linksById.keys()]
    .map((id) => document.getElementById(id))
    .filter(Boolean)
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
 * swaps the button label for a confirmation. Hidden without a clipboard.
 */
function setupCopyButtons() {
  document.querySelectorAll('[data-copy-target]').forEach((button) => {
    const label = button.querySelector('[data-copy-text]')
    const source = document.getElementById(button.dataset.copyTarget)

    if (!label || !source || !navigator.clipboard) {
      button.hidden = true
      return
    }

    let reset
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(source.textContent.trim())
      } catch {
        return
      }

      label.textContent = button.dataset.copiedLabel
      clearTimeout(reset)
      reset = setTimeout(() => {
        label.textContent = button.dataset.copyLabel
      }, 2000)
    })
  })
}

setupMobileMenu()
setupScrollSpy()
setupScrollReveal()
setupCopyButtons()
