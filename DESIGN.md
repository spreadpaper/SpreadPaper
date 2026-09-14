# SpreadPaper site: art direction

The site is the app's gallery window with the chrome taken off. Dark, quiet, photographic. The photographs do the selling, the type does the talking, and nothing decorates. If a thing on the page is not a photograph, a monitor, a word, or a hairline, it should not be there.

Read `src/style.css` before you write markup. `.spread`, `.rig`, `.cd-section`, `.cd-shell`, `.cd-card`, `.cd-button*` and `.cd-eyebrow` already exist. Do not reinvent them, and do not add a second card style.

## What went wrong in the first iteration, since the fix follows from it

Every section put a text column on one side and a visual on the other, and every visual was a band between 3:1 and 6:1. A band cannot reach the height of a paragraph column standing next to it. Measured at 1440, where the shell is 1216px and one column is 79.3px: the hero left 493 by 611 pixels of nothing beside the type, then dropped a 206px ribbon below the fold; the editor stood a 900px text column against a 299px figure and left 601px of void under it; the gallery set a 48px heading in a 286px column. The page read as two unrelated halves because it was two unrelated halves.

The fix is not decoration. It is that the visual has to have vertical mass of its own, which means drawing the monitors as monitors, with frames, stands and feet, instead of floating rounded rectangles. A rig is roughly 1.6:1 to 2.5:1 where a band was 5:1, so it can stand beside a paragraph and hold its ground.

## The composition law

This is the rule the last iteration lacked. It is checkable, so check it.

1. No section may leave more than two of the twelve columns empty at `lg`. A gutter column between two blocks is not empty. A block of air where a reader expects something is.
2. A visual placed beside text must reach at least 70 per cent of that text block's height. If it cannot, the section is wrong: either the visual grows, or the layout changes so the text sits above the visual rather than beside it.
3. A section header that is only an eyebrow, a heading and a lead does not get a row of its own at full width with a 46ch cap. Split it: heading in the left five or six columns, lead in the right five, both starting on the same line. That fills the row without widening a measure past 46ch.
4. No `h2` in a column narrower than five of twelve at `lg`. At 48px in a 286px column a heading breaks to four words a line and looks like an accident.
5. Every section is one composition. Before you commit, ask what the eye lands on first and whether the second thing it finds is related to the first. Two blocks that merely share a `<section>` are not a composition.

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

Every section is `<section class="cd-section"><div class="cd-shell">`. Inside the shell, work on `grid grid-cols-12 gap-x-6 gap-y-10`. Hold to this order, and to these column assignments, which exist to satisfy the composition law rather than for their own sake.

1. nav: sticky, 56px tall, `bg-cd-bg/80 backdrop-blur-md border-b border-cd-border`. Wordmark left, three links and one small primary button right. No logo lockup invention.
2. hero: a composed header across the full twelve, then the rig full width beneath it. The h1 takes columns 1 to 7. The lead, the two buttons and the licence line take columns 8 to 12, top aligned with the h1. Nothing is beside nothing. The rig then runs the full width of the shell, bleeding to the viewport edge below `sm`. A wide subject deserves a wide visual, so the hero visual stays full width; what changes is that it is now tall enough to be the thing you see.
3. types: dark band, `bg-cd-canvas`. The header takes the left six columns and a vertical tablist of the three kinds takes the right five, which is what fills the half that used to be air: a control, not decoration. Below it one panel at a time, the rig in seven columns and the kind's copy in four starting at column nine, so the right hand rail runs unbroken from the tabs down into the panel. Without JavaScript the three panels render as a stacked list and nothing is hidden.
4. editor: `bg-cd-bg`. Two-column header across the full twelve, then the editor rig in columns 1 to 7 with the three sub-features stacked in columns 9 to 12 beside it. The bezel comparison follows as its own full-width row, text in columns 1 to 4 and the two rigs in 6 to 12.
5. gallery: `bg-cd-bg-secondary`. Two-column header, then four preset cards, three columns each at `lg` and six at `sm`. Four cards filling the row is the gallery window; one large card with a thin rail of text beside it was the old mistake.
6. download: `bg-cd-canvas`, the quietest section on the page. Header and buttons in columns 1 to 6, the requirements `<dl>` in 8 to 12. The first-launch instructions are a separate full-width row below, not a tail on the left column, or they leave a 900px void under the `<dl>`.
7. footer: hairline top border, three short columns, photo credits live here.

Section backgrounds alternate `bg-cd-bg` and `bg-cd-canvas` or `bg-cd-bg-secondary`. Never two identical backgrounds adjacent, and the seam between two sections stays a hard edge: no gradient bleeding one section into the next.

## The rig

A rig is one photograph shown across a drawn set of monitors. It replaced the bare `.spread` band everywhere on the page, gallery thumbnails included: there the rig simply loses its stand, its foot and its light, which is `rig-thumb`. `.spread` is gone from `src/style.css` and nothing should reintroduce it.

One thing the geometry cannot decide for you, found by looking at the hero rather than at the markup. A screen low and to one side of a rig samples the low, far corner of the photograph, and if that corner is much darker than the rest, the screen reads as a different picture even though the drawing is correct. The hero's laptop did exactly this against a sunset whose bottom left is near black foliage, directly under an h1 claiming one photograph across every monitor. So when a rig mixes screen heights, either put the smaller screen on a riser so it shares the others' vertical band, or choose a photograph with an even horizon. Check it by looking, because the markup will be innocent.

Each rig is one inline `<svg>` with a `viewBox`, and it is built in this order:

1. `<defs>` holding a `<clipPath>` with one `<rect>` per screen, plus the gradients that rig needs.
2. One `<image>` covering the union bounding box of every screen rect, with `preserveAspectRatio="xMidYMid slice"`, clipped by that path. One image across every screen is the product claim, so it must be one `<image>` element and never one per screen.
3. The frames: a rounded rect stroked around each screen in `#2a2a32`, 1px, with a `rgb(255 255 255 / 0.10)` inner top edge.
4. The hardware: stands, feet, laptop base, drawn flat in `#1a1a20` with a single hairline highlight along the top edge. No rendering, no bevels, no reflections of the room.
5. The light: a soft ellipse under the rig carrying the section's tint at low opacity, as if the screens were lighting the desk. This is where gradient lives on this page.

Every `id` inside a rig has to be unique across the page, because several rigs share one document and a duplicated `clipPath` id silently clips the wrong thing. Suffix every id with the rig's name.

### Geometry, which is still the law

The old rule was that panels in a row share one height and a panel's width is its aspect ratio times that height. That rule was for a flat band where every display was the same size. A rig shows displays of different physical sizes, so it gets the honest version: pick one constant k, the viewBox units per inch of real screen height, and give every screen a rect of height `k times its real height` and width `height times its aspect ratio`. Screens are then in true proportion to one another, a laptop reads as smaller than a monitor because it is, and the photograph crossing them lands where it would land in the app.

Real screen sizes, so nobody guesses:

| Display | Aspect | Screen, inches | Screen rect at k = 15.09 |
| --- | --- | --- | --- |
| 27-inch 16:9 | 1.774 | 23.5 by 13.25 | 355 by 200 |
| 27-inch turned portrait | 0.564 | 13.25 by 23.5 | 200 by 355 |
| 34-inch 21:9 ultrawide | 2.335 | 31.4 by 13.45 | 474 by 203 |
| 14-inch MacBook Pro | 1.545 | 11.97 by 7.75 | 181 by 117 |
| 16-inch MacBook Pro | 1.545 | 13.75 by 8.9 | 207 by 134 |

k is pinned at 15.09 units per inch, which makes a 27-inch screen exactly 200 units tall. Every rig on the page uses that same k, so a laptop drawn beside a monitor is smaller by the amount it is actually smaller. The first draft of the rigs drew 340 by 200 screens, a 17:10 panel nobody sells, and a laptop whose screen worked out to 10.9 inches tall. Both are the failure this table exists to prevent, so check a new screen rect against it before drawing.

The bezel is the frame stroke, not a gap in the layout: a stroke of twice `--rig-bezel` centred on the screen edge, half of it clipped away by the screen itself, leaves a visible frame of exactly `--rig-bezel`. Two screens six units apart then show about 1.7 inches of housing between them, which is a real monitor.

A monitor stand adds about 6 inches under the screen and a foot about 9 inches across. An open laptop sits with its screen base at desk level, so its screen is lower in the frame than a monitor's. Leave 1 to 1.5 inches of gap between two monitors, which is the housing, and that gap is exactly what the bezel section is about.

### Which rig goes where

| Section | Rig | Why |
| --- | --- | --- |
| hero | 14-inch laptop open at left, two 27-inch monitors on stands beside it | The everyday Mac desk, three screens, the claim at full strength |
| types, Static | Two 27-inch monitors on stands | The plainest rig for the plainest kind |
| types, Light and Dark | A 27-inch monitor with a 14-inch laptop beside it | A second setup, and the pair crossfades on both screens at once |
| types, Dynamic | 27-inch portrait, 27-inch landscape, 27-inch portrait | The tallest rig, which is what this row needs since its text carries a schedule list |
| editor, canvas | A 34-inch ultrawide beside a 27-inch portrait | Matches the copy, and the mixed pair is what the editor is for |
| editor, bezels | Three 27-inch monitors, once at a 1-inch gap and once at a 3-inch gap | The comparison is the gap, so nothing else may change between them |
| gallery | `rig-thumb`, three screens with no stand and no light | A stand at 64px tall is a smudge, but one primitive beats two |
| download | No visual at all | The quietest section stays quiet |

Photo paths are `/photos/NAME.jpg`, without the prefix. Vite rewrites them to `/SpreadPaper/photos/...` before the browser sees anything, verified by reading the rendered dev output. Do not test this by requesting URLs from the server: that measures what resolves, not what Vite writes into the HTML, and I got it backwards once by doing exactly that. Curl the rendered page and look at the `src` values.

The photographs are 2400 by 559 bands, so a screen rect taller than that band's ratio crops it hard. Prefer the wide rigs for the large photographs and keep the portrait screens showing the part of the band that survives a tall crop.

At phone widths a rig loses screens rather than height. Three screens inside a 375px gutter is a 90px toy. Drop to the two most characteristic screens of that rig, keep them at the same true proportions, and let the rig bleed to the viewport edge in the hero.

## Colour and gradient

The page was almost monochrome and read as cold. More colour, placed where it means something, and gradient only where light would actually fall.

- `text-cd-accent` (#5e5ce6) is the general accent: primary buttons, links, focus rings, and one word of the h1.
- `text-cd-dynamic` (#f5a524) appears only where the Dynamic kind is the subject. Nowhere else, ever.
- `text-cd-appearance` (#7c7cff) appears only where the Light and Dark kind is the subject. Nowhere else.
- `text-cd-success` marks the preset that is currently applied, in the gallery, and nowhere else.
- Body copy is `text-cd-text-secondary`, never `text-cd-text-tertiary` for anything a person must read.

Where colour is now allowed that it was not before:

1. One word of the h1 takes the accent. At 96px extrabold it clears the 3:1 bar that large text is held to, with room to spare.
2. The primary button fills with a vertical gradient from #5e5ce6 at the top to #4a48c9 at the bottom. White on the light end measures 5.06:1 and on the dark end 6.86:1, so the label clears AA across the whole run. Do not extend the gradient up towards #7c7cff: white on that is 3.40:1, which fails at button size. The old hover colour #6d6bf0 fails too, at 4.19:1, so hover darkens the gradient rather than lightening it: #5452d4 to #403ead, which puts white at 5.94:1 and 8.36:1.
3. Each rig casts light onto the desk beneath it, as a soft ellipse in the section's own tint: neutral white at 12 per cent for the hero and Static, periwinkle at 14 per cent for Light and Dark, amber at 14 per cent for Dynamic, accent at 12 per cent for the editor. In the types section the light follows the selected kind, so switching tabs changes the temperature of the whole panel rather than recolouring three small marks. That is also how Static gets light without getting a tint it is not entitled to.
4. The three kind markers in the types section take their own tint, on the icon and the label together, and the same three glyphs and tints mark the gallery card badges.
5. The download section sits on a low wash of accent over `cd-canvas`, 8 to 12 per cent, anchored behind the buttons and falling off to nothing, so the closing section reads as an arrival rather than as the quietest thing on the page.
6. One word of the download h2 takes the accent, as one word of the h1 does. Two tinted words on a page, one at the top and one at the bottom, is a pattern. A third would be a habit.
7. A 2px rule at the top of the footer runs indigo to periwinkle to amber, the one place all three kind tints sit together without either claiming to be about its own kind.
8. The nav marks the section you are reading with a 2px accent underline, which survives forced-colors mode where a colour shift does not.

Those numbers went up once the page was looked at rather than reasoned about. The first set, 6 to 10 per cent, could not be seen at all at either width, and a tint nobody can see is not restraint, it is an omission. Measure colour decisions in a browser, not in a stylesheet.

That is five colours present on the page against a near-monochrome ground, all of them from the app's palette, none of them decorating anything.

Static still has no tint of its own. The app is the authority: `WallpaperType.tint` returns tertiary for Static, and `GalleryCardView` tints only the icon, never the label.

Every token measured against `#16161a`, so nobody re-argues it: text 14.78:1, secondary 6.81:1, tertiary 3.59:1, accent 3.57:1, appearance 5.31:1, dynamic 8.84:1, success 8.13:1.

Two rules fall straight out of that table. Accent may fill a button, ring a focus state, or tint one heading word at 24px or bold 19px and up, because 3.57:1 clears the 3:1 bar for non-text UI and large text; it may never be a sentence at body size. Inline links are `.cd-inline-link`: `text-cd-text-secondary` with an underline in `currentColor`, hovering to `text-cd-text`. The underline must be `currentColor` at rest, not a hairline token. An inline link sits in body copy of the same colour, so the underline is carrying the entire distinction, and a `#3a3a44` underline measures 1.61:1 against the background, which is not a distinction anyone can see. In `currentColor` it is 6.81:1, as visible as the text it belongs to. Colouring the link instead does not work here: `cd-text` against surrounding secondary copy is 2.17:1 and the accent is 1.91:1, both under the 3:1 that colour needs when it is the distinguisher, so the underline is the affordance and it has to be legible.

And tertiary is retired as a text colour. At 3.59:1 it fails the 4.5:1 floor for normal text, which means captions, credits, `dt` labels and card meta all take secondary instead. The app uses tertiary freely and we are diverging from it deliberately: a desktop app and a web page are not held to the same bar. Hierarchy between body and meta comes from size and weight, which is the more editorial answer anyway. Tertiary survives only as a hairline or icon colour where nothing has to be read.

Both kind tints clear AA for normal text, so amber and periwinkle are safe wherever their own kind is the subject.

## Icons

The app draws its icons with PhosphorSwift, so the site draws the same set at the same regular weight and the two speak one icon language. Write `<!--@icon name class="..."-->` and the build inlines the real SVG from the package source: about 8KB of markup for the glyphs actually used, against 144KB of woff2 plus a 76KB stylesheet for the 1,512 that are not. An unknown name fails the build. Every icon is `aria-hidden` and sits beside a real text label, never alone as the only name for a thing.

An icon earns its place in exactly two situations, and the list is closed. It marks an affordance, something a person touches, where the glyph does work the word alone does not. Or it names one of the three wallpaper kinds, which recur across the types tablist and the gallery badges: that mark is learned once and read twice, and it is the same glyph the app uses for the same thing.

- The three kinds: image for Static, circle-half for Light and Dark, clock-clockwise for Dynamic, always in that kind's tint.
- The editor rig's floating control bar, as the app shows it: magnifying-glass-plus, arrows-out, flip-horizontal.
- Affordances: download-simple on the download buttons, github-logo on the GitHub links, copy swapping to check on the copy button, the menu toggle.

Nowhere else, and never beside an `h2` or an `h3`. An icon next to every heading is its own cliche and it is banned below. If you find yourself reaching for a glyph to fill a space, the space is the problem.

The check on the copy button stays in the button's own text colour. Success green does one job on this page, marking the applied preset in the gallery, and a second use makes it a generic "good" colour rather than a specific meaning.

## Surfaces, borders, shadows

One border weight: `border border-cd-border`. `border-cd-border-strong` only on an interactive edge. Radii: `rounded-xl` on cards, `rounded-full` on buttons, `rounded-lg` on a spread thumbnail. Screens inside a rig take an 8px radius in viewBox units scaled to match. No other radii.

Shadows only under something that genuinely floats: a rig casts one soft shadow on the desk, cards get none, the sticky nav gets none. No glows, no coloured shadows, no ring stacks. The light ellipse under a rig is light, not a shadow, and a rig gets one of each and no more.

Dividers are `border-t border-cd-border`, full width of the shell. Use them instead of a background change when two blocks belong to the same section.

## Overriding the primitives

A Tailwind utility cannot override a property that `.spread`, `.rig`, `.cd-card` or `.cd-button` already sets. Those classes live unlayered in `src/style.css`, the utilities live in `@layer utilities`, and unlayered CSS wins over layered CSS regardless of specificity. So `rounded-none` on a `.spread` is inert, and it fails silently: the class is in the markup and simply does nothing. To change one of those properties, pair the classes in a section `<style>` block so it wins on specificity, as the hero does for its full-bleed corner. Keep such a rule local until a second section needs it; the moment one does, it moves to `src/style.css` as a shared variant rather than being copied.

## Motion

Opacity and small translate only, 150ms to 250ms, `ease-out`. The only looping animations on the page are the photograph crossfades inside the types rigs. Scroll reveal is a fade with a 12px rise, once, never staggered by more than 60ms. No parallax, no scroll-jacking, no counters, no marquees, no hover lift on cards. Nothing in a rig moves except the photograph behind the screens: the hardware is furniture and furniture does not animate. Under `prefers-reduced-motion` every one of these is absent rather than faster, and new motion goes inside a class the existing rules already reach.

Interactivity is rationed to one idea, and the ration is the point. The bezel slider in the editor section is the centrepiece: dragging it widens the frames while the photograph stays put, so the hidden strip grows and the ridgeline still meets on the far side. It earns its place because it is the one thing on this page genuinely better understood by touching it than by reading about it, which two static pictures side by side had proved.

Everything else is deliberately smaller. The types tabs switch a panel, which is navigation rather than a demonstration. The Dynamic loop starts from the reader's real wall clock, as the app's own hero does, so it opens on the photograph that matches their hour instead of an arbitrary one. The gallery cards lighten their border on hover, because the app's cards respond and a card that looks clickable and does nothing is worse than one that plainly does not.

Two things were proposed and ruled out, for the same reason. A second slider for the Dynamic schedule, and filter chips that really filter in the gallery. Both are good ideas in isolation and both steal the bezel slider's moment, because a page with three interactive toys has no centrepiece, only demos. When something new wants to be interactive, the question is not whether it would work; it is whether it is better than the slider, and if it is not, it stays still.

## Focus and responsive

Every interactive element gets `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cd-accent`. Accent is fine here: 3.57:1 clears the 3:1 bar that focus indicators are held to. The earlier ring recipe in this file was wrong twice over, so do not reintroduce it: it hardcoded `ring-offset-cd-bg` on a page where two sections are `bg-cd-canvas` and one is `bg-cd-bg-secondary`, which drew a `#16161a` halo against the wrong background, and it leaned on `ring-offset-*` utilities that are absent from the Tailwind 4 documentation though they still compile here. An outline offset shows whatever is actually behind it, so there is no offset colour left to get wrong.

Two traps go with this, both found the hard way. Converting is a replacement, never an addition: `outline-none` compiles in Tailwind 4 to `outline-style: none` and wins on source order over `outline-2`, so leaving it in place beside the new utilities silently deletes every focus state on the page while the markup still looks correct. And the old ring recipe was not merely ugly, it was broken for keyboard users in Windows forced-colors mode, because `ring-*` renders as a box-shadow and box-shadow is not painted there, so `outline-none` plus a ring left those users with no focus indicator at all. A real outline needs no suppression, which is why the problem cannot recur. Keep `outline-offset-2` everywhere: at 3.6:1 the accent clears the 3:1 focus bar without much room, so the offset is a contrast mechanism and not decoration. Tap targets 44px. The page must work at 375px with a 20px gutter, which `.cd-section` already gives; nothing may scroll the body sideways. One `<h1>`, landmarks for `nav`, `main`, `footer`, and section headings in document order.

Every rig carries `role="img"` and an `aria-label` describing the setup and the photograph on it, since the `<svg>` replaces what used to be an `<img alt>`. Decorative gallery thumbnails keep `alt=""`.

## Browser support, checked rather than assumed

Checked in September 2026 against MDN, WebKit release notes and caniuse, not from memory. Safe to use with no fallback: `aspect-ratio`, `color-mix()` (Baseline widely available since May 2023), `:has()`, container queries, nesting and cascade layers, all above 92% globally. `text-wrap: pretty` is fine now, including Safari 26, which improves every line rather than only the last few; keep using it on paragraphs. `text-wrap: balance` only counts the first 6 lines in Chromium and 10 in Firefox, which is exactly why it belongs on headings and nowhere else.

Inline SVG with `clipPath` and `<image>` is universal and needs no guard. `preserveAspectRatio="xMidYMid slice"` on an `<image>` is the SVG spelling of `object-fit: cover` and behaves the same everywhere.

Scroll-driven animations sit near 83% and are not a floor to build on. Our scroll reveal stays in the existing IntersectionObserver in `src/main.js`. If anyone wants a CSS scroll timeline, it goes behind `@supports (animation-timeline: view())` and the page must be complete without it.

That `color-mix()` is safe does not make an accent wash across a whole section a good idea. That ban is aesthetic, not technical.

## What the 2026 trend reports say, and why we are not doing it

Worth knowing what everyone else is shipping: roughly seven in ten app landing pages now default to dark, and the recurring trend stack is bento grids, glassmorphism and liquid glass, 3D device mockups and looping video heroes. Read that as a warning, not a brief. Dark is no longer a differentiator, it is the baseline, which means the dark background buys us nothing on its own and the photographs and the type have to do all of the work. Every item in that trend stack is on the banned list below, and a site that adopts them will look like the other seven in ten.

Drawing the monitors is not the 3D mockup trend and must not become it. A rig is flat, straight on, orthographic, in two or three greys. The moment one tilts, gains a perspective vanishing point, a glass reflection or a rendered photograph of a real desk, it has crossed into the thing we are avoiding.

## Banned

Centred everything, which means a centred eyebrow over a centred h1 over a centred lead over centred buttons. Bento grids. Glassmorphism and liquid glass panels. 3D device mockups, tilted or perspective monitors, and looping video heroes. Three identical icon cards in a row. An icon beside every heading. Purple to pink gradients, or any gradient text. Glassmorphism blobs and blurred colour orbs. "Powerful features", "Everything you need", "Why SpreadPaper". Emoji used as an icon. Testimonials, logos of companies, star ratings, download counts, any number we cannot prove. Fake browser or macOS window chrome drawn in divs. Hero screenshots floating at a 3D angle. Animated gradient borders. "Get started in seconds". Badge pills stacked above the h1. A column of air beside a column of text, which is what this iteration exists to undo.

## Copy

Sentence case headings. No em dashes anywhere, use a comma, a full stop, or a colon. No exclamation marks. Banned words: seamlessly, effortlessly, powerful, revolutionary, unleash, supercharge, simply, just. Say what the app does: one image across every display, a Light and Dark pair, up to 16 images on a schedule, bezel compensation, presets, free and open source, macOS 15 and Apple Silicon. Never invent a feature, a user, or a quote. Never hard-wrap prose in the HTML source; a paragraph is one long line.

The editor section leads on placement rather than on the canvas metaphor: exactly where the wallpaper sits, in step with where the monitors sit. That is the sentence the client wants to read there.
