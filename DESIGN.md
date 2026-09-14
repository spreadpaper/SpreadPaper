# SpreadPaper site: art direction

The site is the app's gallery window with the chrome taken off. Dark, quiet, photographic. The photographs do the selling, the type does the talking, and nothing decorates. If a thing on the page is not a photograph, a word, or a hairline, it should not be there.

Read `src/style.css` before you write markup. `.spread`, `.cd-section`, `.cd-shell`, `.cd-card`, `.cd-button*` and `.cd-eyebrow` already exist. Do not reinvent them, and do not add a second card style.

## Type scale

Six sizes, no others. Contrast between them is the whole design.

- h1, hero only, one per page: `text-5xl sm:text-7xl lg:text-8xl font-extrabold tracking-[-0.035em] leading-[0.95] text-cd-text`
- h2, one per section: `text-3xl sm:text-4xl lg:text-5xl font-bold tracking-[-0.025em] leading-[1.05] text-cd-text`
- h3, inside a section: `text-xl font-semibold tracking-[-0.01em] text-cd-text`
- Lead, one paragraph under a heading: `text-lg sm:text-xl leading-relaxed text-cd-text-secondary max-w-[46ch]`
- Body: `text-base leading-relaxed text-cd-text-secondary max-w-[62ch]`
- Meta, captions, credits, labels: `text-sm text-cd-text-secondary`, never tertiary. See the measured table below.
- Eyebrow: the `.cd-eyebrow` class, never styled by hand

Every measure is capped. A paragraph that runs the full 76rem shell is a bug. Headings get `text-balance`, paragraphs get `text-pretty`.

## Section rhythm

Every section is `<section class="cd-section"><div class="cd-shell">`. Inside the shell, work on `grid grid-cols-12 gap-x-6 gap-y-10`. The alternation is the rhythm, so hold to it in order:

1. nav: sticky, 56px tall, `bg-cd-bg/80 backdrop-blur-md border-b border-cd-border`. Wordmark left, three links and one small primary button right. No logo lockup invention.
2. hero: full-bleed spread below the type, type in `col-span-12 lg:col-span-7`, nothing in the right five columns except air.
3. types: dark band, `bg-cd-canvas`. Three rows stacked, not three columns. Each row is text on one side, a spread on the other, and the side flips row to row.
4. editor: `bg-cd-bg`. Text in `lg:col-span-4 lg:col-start-9`, visual in `lg:col-span-7 lg:col-start-1`, so the eye lands left first for once.
5. gallery: `bg-cd-bg-secondary`. Asymmetric: one large spread plus a column of small ones, text in a narrow left rail.
6. download: `bg-cd-canvas`, the quietest section on the page. Left-aligned, requirements as a plain `<dl>`, two buttons.
7. footer: hairline top border, three short columns, photo credits live here.

Section backgrounds alternate `bg-cd-bg` and `bg-cd-canvas` or `bg-cd-bg-secondary`. Never two identical backgrounds adjacent, never a gradient between them.

## The spread, used five ways

Two numbers govern every spread, and my first version of this file got the second one wrong.

All panels in a row share one height, so a panel's `--w` is its own aspect ratio times a constant, and the box's aspect ratio is the sum of the `--w` values divided by that same constant. A 16:9 panel is `--w: 16`, a 21:9 ultrawide is `--w: 21`, the same 16:9 panel turned portrait is `--w: 5.0625`, all with k = 9. Set the box to `Σ(--w) / 9` or the panels are not the monitors you think they are. My earlier `aspect-[2400/559]` on a 16/21/16 row drew three squat 1.3:1 panels that are not any real display.

Photo paths are `/photos/NAME.jpg`, without the prefix. Vite rewrites them to `/SpreadPaper/photos/...` before the browser sees anything, verified by reading the rendered dev output. Do not test this by requesting URLs from the server: that measures what resolves, not what Vite writes into the HTML, and I got it backwards once by doing exactly that. Curl the rendered page and look at the `src` values.

The photographs are 2400 by 559 bands, so `object-fit: cover` will crop. Crop vertically, never horizontally: a box wider than 4.293 uses the full 2400px of source and trims the sky, a box narrower than that throws away width and goes soft. Prefer wide boxes for large spreads and keep the narrow, heavily cropped configurations for small ones.

- hero: full width of the shell, three panels `--w: 16` / `--w: 21` / `--w: 16` for two 16:9 displays flanking a 21:9 ultrawide, `--bezel: 16px`, and the box at `aspect-[53/9]`. Uses the whole width of the band, trims about a quarter of its height. This is the only place the spread is the hero. Below `sm` it drops to two panels at `aspect-[32/9]` and bleeds to the viewport edge with `-mx-5`, because three panels inside the gutters is a 57px ribbon on a 375px screen and two bled to the edge is 105px. Two is the floor: one monitor showing a photograph is a picture of nothing, and the spanning claim in the h1 above it stops being illustrated.
- types, Static row: two panels `16` / `16`, `--bezel: 14px`, half width, still.
- types, Light and Dark row: same two panels, with `hero-beach.jpg` under `hero-beach-night.jpg` carrying `.spread-photo-fade`. Set `--cycle: 10s`.
- types, Dynamic row: four panels `16` / `16` / `16` / `16` at `aspect-[64/9]`, dropping to two at `aspect-[32/9]` below `md`, with the four `hero-day-*.jpg` images stepping through and a time readout in `text-cd-dynamic` beside it. Four panels at the correct aspect is a 47px ribbon on a phone; four panels squeezed into a shorter box is four portrait monitors, which is worse.
- editor: a 16:9 landscape and the same panel turned portrait, `--w: 16` and `--w: 5.0625`, box at `aspect-[2.34/1]`. This is the one heavily cropped configuration on the page, which is why it is the smaller visual and not the hero. Overlay one hairline crop rectangle, nothing more. Below it, one stacked pair of the same three-panel photograph at a thin and a thick `--bezel`, captioned honestly: both are correct output for different monitor frames, so no right versus wrong framing.
- gallery: small spreads inside `.cd-card`, two panels at `aspect-[32/9]`, with a type badge in the corner. Two rather than three, because a three-panel card thumbnail at the correct `aspect-[16/3]` is a 71px ribbon. My earlier `aspect-[16/6]` here was wrong the same way the hero was; it drew three portrait slots.

Before committing any spread, do the arithmetic: sum the `--w` values, divide by 9, and check that against the box. Every section except the hero got this wrong on the first pass, usually at the mobile breakpoint, where the temptation is to make the box shorter instead of removing a panel. Removing a panel is the answer.

Set `--bezel: 8px` below `sm` in every instance. Every `.spread` sits in a figure with a real caption or a credit; a decorative photo takes `alt=""`, a photo that carries meaning takes a sentence of alt text.

## Colour

- `text-cd-accent` (#5e5ce6) is the general accent: primary buttons, links, focus rings, the one word in a heading that may be tinted.
- `text-cd-dynamic` (#f5a524) appears only where the Dynamic wallpaper kind is the subject. Nowhere else, ever.
- `text-cd-appearance` (#7c7cff) appears only where the Light and Dark kind is the subject. Nowhere else.
- `text-cd-success` is for a single availability or price line at most. Probably do not use it.
- Body copy is `text-cd-text-secondary`, never `text-cd-text-tertiary` for anything a person must read.

Static has no tint. The app is the authority here: `WallpaperType.tint` returns tertiary for Static, and `GalleryCardView` tints only the icon, never the label. Follow it, so the two special kinds stay the only colour on the page.

Every token measured against `#16161a`, so nobody re-argues it: text 14.78:1, secondary 6.81:1, tertiary 3.59:1, accent 3.57:1, appearance 5.31:1, dynamic 8.84:1, success 8.13:1.

Two rules fall straight out of that table. Accent may fill a button, ring a focus state, or tint one heading word at 24px or bold 19px and up, because 3.57:1 clears the 3:1 bar for non-text UI and large text; it may never be a sentence at body size. Inline links are `text-cd-text-secondary` with an underline, hovering to `text-cd-text`.

And tertiary is retired as a text colour. At 3.59:1 it fails the 4.5:1 floor for normal text, which means captions, credits, `dt` labels and card meta all take secondary instead. The app uses tertiary freely and we are diverging from it deliberately: a desktop app and a web page are not held to the same bar. Hierarchy between body and meta comes from size and weight, which is the more editorial answer anyway. Tertiary survives only as a hairline or icon colour where nothing has to be read.

Both kind tints clear AA for normal text, so amber and periwinkle are safe wherever their own kind is the subject.

## Surfaces, borders, shadows

One border weight: `border border-cd-border`. `border-cd-border-strong` only on an interactive edge. Radii: `rounded-xl` on cards, `rounded-full` on buttons, `rounded-lg` on a spread. No other radii.

Shadows only under something that genuinely floats: the spread already carries one, the sticky nav gets none, cards get none. No glows, no coloured shadows, no ring stacks.

Dividers are `border-t border-cd-border`, full width of the shell. Use them instead of a background change when two blocks belong to the same section.

## Motion

Opacity and small translate only, 150ms to 250ms, `ease-out`. The only looping animation on the page is `.spread-photo-fade` in the types section. Scroll reveal is a fade with a 12px rise, once, never staggered by more than 60ms. No parallax, no scroll-jacking, no counters, no marquees, no hover lift on cards. `prefers-reduced-motion` is already handled in CSS, but keep all new motion inside classes it can reach.

## Focus and responsive

Every interactive element gets `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cd-accent`. Accent is fine here: 3.57:1 clears the 3:1 bar that focus indicators are held to. The earlier ring recipe in this file was wrong twice over, so do not reintroduce it: it hardcoded `ring-offset-cd-bg` on a page where two sections are `bg-cd-canvas` and one is `bg-cd-bg-secondary`, which drew a `#16161a` halo against the wrong background, and it leaned on `ring-offset-*` utilities that are absent from the Tailwind 4 documentation though they still compile here. An outline offset shows whatever is actually behind it, so there is no offset colour left to get wrong. Tap targets 44px. The page must work at 375px with a 20px gutter, which `.cd-section` already gives; nothing may scroll the body sideways. One `<h1>`, landmarks for `nav`, `main`, `footer`, and section headings in document order.

## Browser support, checked rather than assumed

Checked in September 2026 against MDN, WebKit release notes and caniuse, not from memory. Safe to use with no fallback: `aspect-ratio`, `color-mix()` (Baseline widely available since May 2023), `:has()`, container queries, nesting and cascade layers, all above 92% globally. `text-wrap: pretty` is fine now, including Safari 26, which improves every line rather than only the last few; keep using it on paragraphs. `text-wrap: balance` only counts the first 6 lines in Chromium and 10 in Firefox, which is exactly why it belongs on headings and nowhere else.

Scroll-driven animations sit near 83% and are not a floor to build on. Our scroll reveal stays in the existing IntersectionObserver in `src/main.js`. If anyone wants a CSS scroll timeline, it goes behind `@supports (animation-timeline: view())` and the page must be complete without it.

That `color-mix()` is safe does not make the accent wash in the first hero draft a good idea. That ban is aesthetic, not technical.

## What the 2026 trend reports say, and why we are not doing it

Worth knowing what everyone else is shipping: roughly seven in ten app landing pages now default to dark, and the recurring trend stack is bento grids, glassmorphism and liquid glass, 3D device mockups and looping video heroes. Read that as a warning, not a brief. Dark is no longer a differentiator, it is the baseline, which means the dark background buys us nothing on its own and the photographs and the type have to do all of the work. Every item in that trend stack is on the banned list below, and a site that adopts them will look like the other seven in ten.

## Banned

Centred everything, which means a centred eyebrow over a centred h1 over a centred lead over centred buttons. Bento grids. Glassmorphism and liquid glass panels. 3D device mockups and looping video heroes. Three identical icon cards in a row. Purple to pink gradients, or any gradient text. Glassmorphism blobs and blurred colour orbs. "Powerful features", "Everything you need", "Why SpreadPaper". Emoji used as an icon. Testimonials, logos of companies, star ratings, download counts, any number we cannot prove. Fake browser or macOS window chrome drawn in divs. Hero screenshots floating at a 3D angle. Animated gradient borders. "Get started in seconds". Badge pills stacked above the h1.

## Copy

Sentence case headings. No em dashes anywhere, use a comma, a full stop, or a colon. No exclamation marks. Banned words: seamlessly, effortlessly, powerful, revolutionary, unleash, supercharge, simply, just. Say what the app does: one image across every display, a Light and Dark pair, up to 16 images on a schedule, bezel compensation, presets, free and open source, macOS 15 and Apple Silicon. Never invent a feature, a user, or a quote. Never hard-wrap prose in the HTML source; a paragraph is one long line.
