# Monitor rigs

The rigs are the SVG-drawn displays the marketing site carries one photograph across. They are the site's main visual argument: SpreadPaper does not put a copy of a picture on each screen, it puts one picture across all of them, and a rig has to show that or it is not doing its job. They are also how the page gets its vertical mass, which is why stands and feet are load bearing rather than decoration.

Everything they need is in `src/rigs.css`, which `src/style.css` imports. Nothing here depends on Tailwind. Copy the markup for the rig you want out of this file, change the four things listed under it, and you are done.

**This file is generated.** `npm run rigs` rewrites it and `rigs-preview.html` from `scripts/rigs.mjs`, which holds the geometry of every rig, and from `scripts/rigs-prose.md`, which holds this text. Edit those, not this. A hand edit here is lost the next time anyone regenerates.

## How a rig works

One `<image>` is drawn across the whole rig. A `<clipPath>` holding one `<rect>` per screen cuts it down to the screens, so the photograph is physically continuous and each screen is a window onto its own part of it. Nothing is sliced and nothing is repeated, which is why the picture carries on behind every frame rather than restarting.

The frame around each screen is that same rect again, stroked rather than filled, at twice `--rig-bezel` and clipped by the screen it sits on. Half the stroke falls outside the clip and disappears, so the frame you see measures `--rig-bezel` exactly. Widening the bezel therefore eats into the photograph from the edges of each screen without moving the photograph itself, which is what makes the thin against thick comparison honest.

Stands, feet, laptop bases and the light pooling on the desk are plain shapes drawn outside the clip, before it, so the photograph never touches them.

## Screens are drawn to scale

Every screen in every rig is a real display at true proportion, at 15.09 viewBox units per inch of screen height.

| Display | Screen rect | Aspect |
| --- | --- | --- |
| 27-inch landscape | 355 by 200 | 1.774 |
| 27-inch portrait | 200 by 355 | 0.564 |
| 34-inch ultrawide | 474 by 203 | 2.335 |
| 14-inch MacBook Pro | 181 by 117 | 1.545 |

This is not fussiness. A laptop beside a monitor reads as a laptop only because it is visibly smaller in the right proportion, and a 17:10 panel is a shape nobody sells. If you need a display the table does not have, add it to `scripts/rigs.mjs` rather than guessing at numbers in a section.

## The four things to change per instance

**The clipPath id.** It must be unique on the page. Two rigs sharing an id is the one failure mode that gives no error: the second rig clips against the first one's screens and comes out wrong or blank. Name it after the section and the instance, like `rig-hero`, `rig-types-static`, `rig-gallery-2`.

**The photo href.** Every photograph has one URL for the whole page, listed under Which file below. Never pick a size to suit your rig. Write it as `/photos/hero-beach.jpg`, never `/SpreadPaper/photos/...`: Vite prepends the base itself, so the longer form resolves to `/SpreadPaper/SpreadPaper/` and serves the HTML fallback instead of an image.

**The accessible name.** Either `role="img"` with an `aria-label` naming the setup and describing the photograph, or `aria-hidden="true"` when a caption beside it already says the same thing. Never both, and never neither. The label is the only alt text the photograph gets, so write it as a sentence about the picture and the displays, not a repeat of the heading. Every rig also carries `focusable="false"` so nothing inside it lands in the tab order.

**How the photograph is framed,** but only where the default crops badly. `markup()` takes an `align`, which becomes the first half of `preserveAspectRatio` and defaults to `xMidYMid`. Reach for it when a dark or empty part of a picture lands in a screen: `xMidYMax` keeps the bottom of the photograph, `xMinYMid` its left edge, and so on.

Which way a rig crops depends on whether its image box is wider or narrower than the photograph's own 4.29. A box wider than that, like `rig-trio` at 5.16 or `rig-thumb` at 5.41, shows the picture's full width and crops top and bottom, so the outermost screens show the far edges of the photograph and `align` moves the crop vertically. A narrower box crops the sides instead and shows the middle, so `align` moves it horizontally. If a screen is showing an empty corner, the quickest fix is usually a narrower rig rather than a different alignment: `rig-thumb-pair` at 3.59 and `rig-thumb-laptop` at 2.49 both keep to the centre of a picture, where `rig-thumb` reaches its edges.

**The `.rig-frame` rects.** Each one repeats the geometry of the clip rect it frames. If you move a screen, move both. They are next to each other in the markup for exactly this reason.

## Sizing

A rig fills its container's width and takes its height from its viewBox, so give it a container with a width and nothing else. Do not set an aspect ratio on the wrapper: the viewBox already carries it, and a second one will fight it. There is no outer corner to square when a rig bleeds to the viewport edge either, because the rounded corners belong to each screen rect rather than to a container.

| Rig | What it draws | viewBox | Ratio | Where it belongs |
| --- | --- | --- | --- | --- |
| `rig-desk` | A laptop and two monitors | `0 0 911 236` | 3.86 | hero |
| `rig-dual` | Two matched monitors | `0 0 716 236` | 3.03 | the Static kind |
| `rig-laptop` | A monitor and a laptop | `0 0 550 236` | 2.33 | the Light and Dark kind |
| `rig-portrait-trio` | Portrait, landscape, portrait | `0 0 767 391` | 1.96 | the Dynamic kind |
| `rig-trio` | Three matched monitors | `0 0 1077 236` | 4.56 | the editor bezel comparison |
| `rig-ultrawide` | One ultrawide | `0 0 474 239` | 1.98 | a single-display beat |
| `rig-mixed` | The editor canvas | `0 0 728 403` | 1.81 | the editor canvas |
| `rig-thumb-pair` | Gallery thumbnail, two monitors | `0 0 230 64` | 3.59 | gallery cards |
| `rig-thumb-portrait` | Gallery thumbnail, a portrait beside a landscape | `0 0 180 114` | 1.58 | gallery cards |
| `rig-thumb-laptop` | Gallery thumbnail, a monitor and a laptop | `0 0 174 70` | 2.49 | gallery cards |
| `rig-thumb` | Gallery thumbnail, three monitors | `0 0 346 64` | 5.41 | gallery cards |

At phone widths a rig drops screens rather than height. Swap in a rig with fewer screens: two svgs, the wide one `hidden sm:block` and the narrow one `sm:hidden`. Shortening the box instead squeezes every display into a sliver.

Two things about that swap. It works because every rule in `rigs.css` sits in Tailwind's `components` layer, so a utility class on a rig beats it. An unlayered rule outranks a layered one whatever its specificity, so if these rules ever move out of that layer, `hidden` loses to `.rig { display: block }` and both halves render, one above the other, with no error. And the hidden svg leaves the accessibility tree, so both halves carry the same `aria-label`: write one that is true of both rigs, which usually means describing the photograph and the desk rather than counting the screens.

## Custom properties

| Property | Default | What it does |
| --- | --- | --- |
| `--rig-bezel` | `10`, `9` on the two laptop rigs, `4` on the thumbnail | Visible frame width, in viewBox units, so it scales with the rig |
| `--rig-frame-color` | `#1c1c23` | Frame and laptop chin colour |
| `--rig-stand-color` | `#191920` | Stand, foot and laptop base colour |
| `--rig-glow-color` | `rgb(255 255 255 / 0.12)` | The light pooling on the desk under the rig |
| `--rig-cycle` | `12s` | Length of a Light and Dark crossfade |
| `--rig-day-cycle` | `20s` | Length of one Dynamic day |

`--rig-bezel` is unitless on purpose. It is measured in viewBox units, not pixels, so a rig at 300px wide and the same rig at 900px keep frames of the same proportion, and a section that wants pixels can compose `calc(var(--rig-bezel) * 1px)` from it.

The glow is where the page gets its colour, and it is motivated light rather than decoration, which is the only reason it survives review. One shadow and one light ellipse per rig, no more. The tints:

| Where | `glow` | Colour |
| --- | --- | --- |
| Hero and Static | `neutral` | `rgb(255 255 255 / 0.12)` |
| Light and Dark | `appearance` | `rgb(124 124 255 / 0.14)` |
| Dynamic | `dynamic` | `rgb(245 165 36 / 0.14)` |
| Editor | `accent` | `rgb(94 92 230 / 0.10)` |

Pass the name to `markup()` as `glow: "dynamic"` rather than writing the colour onto the generated svg afterwards. The tints are a design ruling rather than a preference, and `rigs:check` fails on any `--rig-glow-color` that is not one of these four. An unknown name throws at generation.

Keep the blur under the ellipse's own height if you change either. Blurring a shape by more than it measures spreads the tint until none of it reaches the page, which is how the first version of this came out invisible rather than subtle.

Two modifier classes come with the family. `.rig-glass` makes the frames translucent so the picture can be seen carrying on behind them, which is what the bezel comparison needs. `.rig-crop` is the hairline rectangle marking the area a render keeps, used by the editor canvas.

## The rigs

### rig-desk

A 14-inch laptop open at the left with two 27-inch monitors beside it. The everyday Mac desk, and the widest rig on the page.

```html
<svg class="rig rig-desk" viewBox="0 0 911 236" role="img" aria-label="A beach at sunset carried across a laptop and the two monitors beside it on a desk." focusable="false">
  <defs>
    <clipPath id="rig-example-desk">
      <rect x="0" y="83" width="181" height="117" rx="8"/>
      <rect x="195" y="0" width="355" height="200" rx="10"/>
      <rect x="556" y="0" width="355" height="200" rx="10"/>
    </clipPath>
  </defs>
  <ellipse class="rig-glow" cx="455.5" cy="232" rx="401" ry="18"/>
  <g class="rig-stand">
    <rect x="358.5" y="200" width="28" height="28"/><rect x="317.5" y="228" width="110" height="8" rx="4"/>
    <rect x="719.5" y="200" width="28" height="28"/><rect x="678.5" y="228" width="110" height="8" rx="4"/>
    <polygon points="-3,206 184,206 201,236 -20,236"/>
  </g>
  <rect class="rig-chin" x="0" y="191" width="181" height="15" rx="3"/>
  <g clip-path="url(#rig-example-desk)">
    <image class="rig-photo" href="/photos/hero-beach.jpg" x="0" y="0" width="911" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="83" width="181" height="117" rx="8"/>
    <rect class="rig-frame" x="195" y="0" width="355" height="200" rx="10"/>
    <rect class="rig-frame" x="556" y="0" width="355" height="200" rx="10"/>
  </g>
</svg>
```

Natural ratio 3.86. It is the hero rig, and the hero is the one place to use the 2400px original at `/photos/hero-beach.jpg` rather than the 1200px set, because at full shell width the derivative is visibly soft. That URL is load bearing: `index.html` preloads it, and a preload that does not byte-match the href fetches a file nobody uses.

### rig-dual

Two matched 27-inch monitors on stands. The plainest rig, and the right one whenever the point is simply that a picture spans more than one screen.

```html
<svg class="rig rig-dual" viewBox="0 0 716 236" role="img" aria-label="A beach at sunset carried across two monitors side by side." focusable="false">
  <defs>
    <clipPath id="rig-example-dual">
      <rect x="0" y="0" width="355" height="200" rx="10"/>
      <rect x="361" y="0" width="355" height="200" rx="10"/>
    </clipPath>
  </defs>
  <ellipse class="rig-glow" cx="358" cy="232" rx="315" ry="18"/>
  <g class="rig-stand">
    <rect x="163.5" y="200" width="28" height="28"/><rect x="122.5" y="228" width="110" height="8" rx="4"/>
    <rect x="524.5" y="200" width="28" height="28"/><rect x="483.5" y="228" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-dual)">
    <image class="rig-photo" href="/photos/hero-beach.jpg" x="0" y="0" width="716" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="355" height="200" rx="10"/>
    <rect class="rig-frame" x="361" y="0" width="355" height="200" rx="10"/>
  </g>
</svg>
```

Natural ratio 3.03. Suits the Static kind and any beat that needs a rig without making a point of the arrangement.

### rig-laptop

A 27-inch monitor with a 14-inch laptop beside it, the laptop screen smaller and sitting lower, as it does on a real desk.

```html
<svg class="rig rig-laptop" viewBox="0 0 550 236" role="img" aria-label="A beach carried across a monitor and the laptop beside it, fading from day to night." focusable="false">
  <defs>
    <clipPath id="rig-example-laptop">
      <rect x="0" y="0" width="355" height="200" rx="10"/>
      <rect x="361" y="101" width="181" height="117" rx="8"/>
    </clipPath>
  </defs>
  <ellipse class="rig-glow" cx="275" cy="232" rx="242" ry="18"/>
  <g class="rig-stand">
    <rect x="163.5" y="200" width="28" height="28"/><rect x="122.5" y="228" width="110" height="8" rx="4"/>
    <rect x="357" y="230" width="189" height="6" rx="3"/>
  </g>
  <rect class="rig-chin" x="361" y="209" width="181" height="21" rx="3"/>
  <g clip-path="url(#rig-example-laptop)">
    <image class="rig-photo" href="/photos/hero-beach.jpg" x="0" y="0" width="550" height="218" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-photo-fade" href="/photos/1200/hero-beach-night.jpg" x="0" y="0" width="550" height="218" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="355" height="200" rx="10"/>
    <rect class="rig-frame" x="361" y="101" width="181" height="117" rx="8"/>
  </g>
</svg>
```

Natural ratio 2.33. The laptop screen showing a lower part of the photograph is not a bug: macOS lays the wallpaper out across the display arrangement, so a screen sitting lower shows what is lower in the picture. Worth saying in a caption, because it is the detail that proves the app is doing real work. Shown above with a crossfade, since this is the Light and Dark rig, and note that the pair covers both screens rather than one.

### rig-portrait-trio

A 27-inch portrait, a 27-inch landscape and another 27-inch portrait, bottoms level.

```html
<svg class="rig rig-portrait-trio" viewBox="0 0 767 391" role="img" aria-label="One alpine ridge carried across a portrait monitor, a landscape monitor and another portrait monitor." focusable="false">
  <defs>
    <clipPath id="rig-example-trio">
      <rect x="0" y="0" width="200" height="355" rx="10"/>
      <rect x="206" y="155" width="355" height="200" rx="10"/>
      <rect x="567" y="0" width="200" height="355" rx="10"/>
    </clipPath>
  </defs>
  <ellipse class="rig-glow" cx="383.5" cy="387" rx="337" ry="18"/>
  <g class="rig-stand">
    <rect x="86" y="355" width="28" height="28"/><rect x="45" y="383" width="110" height="8" rx="4"/>
    <rect x="369.5" y="355" width="28" height="28"/><rect x="328.5" y="383" width="110" height="8" rx="4"/>
    <rect x="653" y="355" width="28" height="28"/><rect x="612" y="383" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-trio)">
    <image class="rig-photo" href="/photos/1200/hero-day-1.jpg" x="0" y="0" width="767" height="355" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="200" height="355" rx="10"/>
    <rect class="rig-frame" x="206" y="155" width="355" height="200" rx="10"/>
    <rect class="rig-frame" x="567" y="0" width="200" height="355" rx="10"/>
  </g>
</svg>
```

Natural ratio 1.96, the tallest rig on the page, which is deliberate: it belongs beside the Dynamic schedule list and gives that row a tall neighbour. The union of the screens is tall, so a panoramic photograph is scaled up to cover it and you see roughly the middle half of the picture. That is honest, because the app would have to crop the same way. It is also why this rig is the softest on the page, which Which file above explains and accepts. Check the horizon still runs across all three screens, since continuity is the only thing the rig has to prove.

### rig-trio

Three matched 27-inch monitors. Two gaps rather than one, so it is the rig that argues hardest for continuity.

```html
<svg class="rig rig-trio" viewBox="0 0 1077 236" role="img" aria-label="An alpine ridge at sunrise carried across three matched monitors." focusable="false">
  <defs>
    <clipPath id="rig-example-trio-row">
      <rect x="0" y="0" width="355" height="200" rx="10"/>
      <rect x="361" y="0" width="355" height="200" rx="10"/>
      <rect x="722" y="0" width="355" height="200" rx="10"/>
    </clipPath>
  </defs>
  <ellipse class="rig-glow" cx="538.5" cy="232" rx="474" ry="18"/>
  <g class="rig-stand">
    <rect x="163.5" y="200" width="28" height="28"/><rect x="122.5" y="228" width="110" height="8" rx="4"/>
    <rect x="524.5" y="200" width="28" height="28"/><rect x="483.5" y="228" width="110" height="8" rx="4"/>
    <rect x="885.5" y="200" width="28" height="28"/><rect x="844.5" y="228" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-trio-row)">
    <image class="rig-photo" href="/photos/1200/hero-day-1.jpg" x="0" y="0" width="1077" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="355" height="200" rx="10"/>
    <rect class="rig-frame" x="361" y="0" width="355" height="200" rx="10"/>
    <rect class="rig-frame" x="722" y="0" width="355" height="200" rx="10"/>
  </g>
</svg>
```

Natural ratio 4.56, which is close to the photographs' own 4.29, so it crops them least of any rig. It is the bezel comparison rig.

### rig-ultrawide

One 34-inch ultrawide on a wide foot.

```html
<svg class="rig rig-ultrawide" viewBox="0 0 474 239" role="img" aria-label="A beach at sunset on a single ultrawide monitor." focusable="false">
  <defs>
    <clipPath id="rig-example-ultrawide">
      <rect x="0" y="0" width="474" height="203" rx="10"/>
    </clipPath>
  </defs>
  <ellipse class="rig-glow" cx="237" cy="235" rx="209" ry="18"/>
  <g class="rig-stand">
    <rect x="223" y="203" width="28" height="28"/><rect x="162" y="231" width="150" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-ultrawide)">
    <image class="rig-photo" href="/photos/hero-beach.jpg" x="0" y="0" width="474" height="203" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="474" height="203" rx="10"/>
  </g>
</svg>
```

Natural ratio 1.98, the most upright rig in the set, so it fits a narrow column where a row of monitors will not.

### rig-mixed

The editor canvas rather than a desk: a 34-inch ultrawide beside a 27-inch portrait, the photograph carrying on past both, dimmed, a hairline rectangle marking the area the render keeps, and the app's floating HUD over the bottom of the wide screen.

```html
<svg class="rig rig-mixed" viewBox="0 0 728 403" role="img" aria-label="The editor canvas: an ultrawide beside a portrait monitor, the photograph reaching past both." focusable="false">
  <defs>
    <clipPath id="rig-example-mixed">
      <rect x="24" y="100" width="474" height="203" rx="10"/>
      <rect x="504" y="24" width="200" height="355" rx="10"/>
    </clipPath>
  </defs>
  <image class="rig-bleed" href="/photos/1200/hero-day-2.jpg" x="0" y="0" width="728" height="403" preserveAspectRatio="xMidYMid slice"/>
  <rect class="rig-crop" x="14" y="14" width="700" height="375" rx="8"/>
  <g clip-path="url(#rig-example-mixed)">
    <image class="rig-photo" href="/photos/1200/hero-day-2.jpg" x="0" y="0" width="728" height="403" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="24" y="100" width="474" height="203" rx="10"/>
    <rect class="rig-frame" x="504" y="24" width="200" height="355" rx="10"/>
  </g>
  <g class="rig-hud">
    <rect class="rig-hud-bar" x="175" y="253" width="172" height="30" rx="15"/>
    <!--@icon minus x="191" y="261" width="14" height="14"-->
    <!--@icon plus x="233" y="261" width="14" height="14"-->
    <!--@icon arrows-out-simple x="275" y="261" width="14" height="14"-->
    <!--@icon arrows-left-right x="317" y="261" width="14" height="14"-->
  </g>
</svg>
```

Natural ratio 1.81. It carries no stands, no desk light and no drop shadow, because it is a view inside the app rather than an object on a desk. Two things to watch. The dimmed `.rig-bleed` image and the clipped one share their geometry exactly, which is what makes the bright part sit inside the dim part rather than beside it, so change the href in both. And the HUD glyphs are `@icon` tokens, which expand only inside files that `index.html` includes, so they work in a section and not in a standalone page. The four glyphs are the ones the app's editor actually shows, read off `EditorView.swift`: zoom out, zoom in, fit to canvas and flip horizontally. Pass `glyphs` to `markup()` to change them rather than editing the output. Pass position and size through the token and nothing else, because the expansion fills every path, so a `stroke` attribute riding along will wreck a glyph.

### rig-thumb

Three screens, no stands, no furniture. Built to survive being 92px tall on a gallery card.

```html
<svg class="rig rig-thumb" viewBox="0 0 346 64" aria-hidden="true" focusable="false">
  <defs>
    <clipPath id="rig-example-thumb">
      <rect x="0" y="0" width="114" height="64" rx="3"/>
      <rect x="116" y="0" width="114" height="64" rx="3"/>
      <rect x="232" y="0" width="114" height="64" rx="3"/>
    </clipPath>
  </defs>
  <g clip-path="url(#rig-example-thumb)">
    <image class="rig-photo" href="/photos/hero-beach.jpg" x="0" y="0" width="346" height="64" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="114" height="64" rx="3"/>
    <rect class="rig-frame" x="116" y="0" width="114" height="64" rx="3"/>
    <rect class="rig-frame" x="232" y="0" width="114" height="64" rx="3"/>
  </g>
</svg>
```

Natural ratio 5.41. Three siblings draw the other arrangements a gallery of presets wants: `rig-thumb-pair` at 230 by 64, `rig-thumb-portrait` at 180 by 114, and `rig-thumb-laptop` at 174 by 70, whose lid sits lower than the monitor beside it for the same reason the full-size laptop rig's does. All four take the same thin frames and tight shadow.

```html
<svg class="rig rig-thumb-pair" viewBox="0 0 230 64" aria-hidden="true" focusable="false">
  <defs>
    <clipPath id="rig-example-thumb-pair">
      <rect x="0" y="0" width="114" height="64" rx="3"/>
      <rect x="116" y="0" width="114" height="64" rx="3"/>
    </clipPath>
  </defs>
  <g clip-path="url(#rig-example-thumb-pair)">
    <image class="rig-photo" href="/photos/1200/hero-day-3.jpg" x="0" y="0" width="230" height="64" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="114" height="64" rx="3"/>
    <rect class="rig-frame" x="116" y="0" width="114" height="64" rx="3"/>
  </g>
</svg>
```

```html
<svg class="rig rig-thumb-portrait" viewBox="0 0 180 114" aria-hidden="true" focusable="false">
  <defs>
    <clipPath id="rig-example-thumb-portrait">
      <rect x="0" y="0" width="64" height="114" rx="3"/>
      <rect x="66" y="50" width="114" height="64" rx="3"/>
    </clipPath>
  </defs>
  <g clip-path="url(#rig-example-thumb-portrait)">
    <image class="rig-photo" href="/photos/1200/hero-day-4.jpg" x="0" y="0" width="180" height="114" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="64" height="114" rx="3"/>
    <rect class="rig-frame" x="66" y="50" width="114" height="64" rx="3"/>
  </g>
</svg>
```

```html
<svg class="rig rig-thumb-laptop" viewBox="0 0 174 70" aria-hidden="true" focusable="false">
  <defs>
    <clipPath id="rig-example-thumb-laptop">
      <rect x="0" y="0" width="114" height="64" rx="3"/>
      <rect x="116" y="32" width="58" height="37" rx="2"/>
    </clipPath>
  </defs>
  <g clip-path="url(#rig-example-thumb-laptop)">
    <image class="rig-photo" href="/photos/1200/hero-beach-night.jpg" x="0" y="0" width="174" height="70" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="114" height="64" rx="3"/>
    <rect class="rig-frame" x="116" y="32" width="58" height="37" rx="2"/>
  </g>
</svg>
```

They are the one family meant to be sized by something other than the container width, and they have different natural ratios, so give each a shared tile and let it sit at its own size inside: a rig with more screens then comes out smaller, which is what would happen on a real desk. Put the aspect on the tile and never on the rig. Each is decorative on a card whose heading already names the preset, so it takes `aria-hidden="true"` and no label, and each uses that photograph's one URL like everything else.

## Worked example: thin against thick frames

The same rig twice, the photograph in the same place both times, only `--rig-bezel` different. The frames are drawn as glass so you can see the picture carrying on behind them, which is the whole argument: the ridgeline still meets across every gap.

```html
<figure>
  <p>Thin frames</p>
  <svg class="rig rig-trio rig-glass" style="--rig-bezel: 4" viewBox="0 0 1077 236" role="img" aria-label="An alpine ridge across three displays with narrow frames." focusable="false">
    <!-- the rest exactly as rig-trio above, with its own clipPath id -->
  </svg>

  <p>Thick frames</p>
  <svg class="rig rig-trio rig-glass" style="--rig-bezel: 26" viewBox="0 0 1077 236" role="img" aria-label="The same ridge across three displays with wide frames, still meeting across each gap." focusable="false">
    <!-- the rest exactly as rig-trio above, with a different clipPath id -->
  </svg>
</figure>
```

Three things to keep. The two rigs must show the same photograph, or there is nothing to compare. The ids must differ, or the second one clips against the first. And keep the caption accurate: the frames are glass so the picture can be seen carrying on behind them, but the gap between two housings is genuinely undrawn, so at a thick bezel the hidden band reads as glass, then a blank line, then glass. That blank line is the air between two monitors and it is correct. Do not write a caption claiming the whole hidden strip stays visible.

## Worked example: a Light and Dark pair

Extra photographs stack inside the same clipped group, above the first one, and fade in over it. They rest at opacity 0, so a reader with motion turned off sees the photograph at the bottom of the stack and nothing moves. The `rig-laptop` entry above is a working example.

The label describes the first photograph, since that is what a reader with motion off will see. The second image needs no label of its own: it is inside a labelled `role="img"` and is not announced separately.

Set `--rig-cycle` on the svg to change the pace. The default is 12 seconds.

## Worked example: the Dynamic day

Five images: the four hours of the schedule, then the first one again so the loop closes on a fade rather than a cut. `rig-day-2`, `-3` and `-4` hold their photograph from its own hour until the next covers it, and `rig-day-wrap` carries the repeat.

```html
<svg class="rig rig-portrait-trio" viewBox="0 0 767 391" role="img" aria-label="Three monitors running through one day, sunrise to night." focusable="false">
  <defs>
    <clipPath id="rig-example-day">
      <rect x="0" y="0" width="200" height="355" rx="10"/>
      <rect x="206" y="155" width="355" height="200" rx="10"/>
      <rect x="567" y="0" width="200" height="355" rx="10"/>
    </clipPath>
  </defs>
  <ellipse class="rig-glow" cx="383.5" cy="387" rx="337" ry="18"/>
  <g class="rig-stand">
    <rect x="86" y="355" width="28" height="28"/><rect x="45" y="383" width="110" height="8" rx="4"/>
    <rect x="369.5" y="355" width="28" height="28"/><rect x="328.5" y="383" width="110" height="8" rx="4"/>
    <rect x="653" y="355" width="28" height="28"/><rect x="612" y="383" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-day)">
    <image class="rig-photo" href="/photos/1200/hero-day-1.jpg" x="0" y="0" width="767" height="355" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-2" href="/photos/1200/hero-day-2.jpg" x="0" y="0" width="767" height="355" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-3" href="/photos/1200/hero-day-3.jpg" x="0" y="0" width="767" height="355" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-4" href="/photos/1200/hero-day-4.jpg" x="0" y="0" width="767" height="355" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-wrap" href="/photos/1200/hero-day-1.jpg" x="0" y="0" width="767" height="355" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="200" height="355" rx="10"/>
    <rect class="rig-frame" x="206" y="155" width="355" height="200" rx="10"/>
    <rect class="rig-frame" x="567" y="0" width="200" height="355" rx="10"/>
  </g>
</svg>
```

Set `--rig-day-cycle` on the svg to change the pace. The default is 20 seconds, which is 5 seconds a photograph.

If a section lights something up in step with the cycle, a row of times for instance, drive it from the same duration so the two never drift apart.

## Driving the layers yourself

`.rig-photo` carries no opacity and no animation. It is a marker class, nothing more, so a section that wants to own its own schedule stacks plain `.rig-photo` images inside the clip and sets their opacity itself, from a stylesheet, from a slider, from anything. `.rig-photo-fade` and `.rig-day` are conveniences for the standard behaviour, not a policy: leave them off and the rig imposes no timing at all.

Two things the rig cannot give you, because SVG does not. An `<image>` takes no `loading="lazy"` and no `fetchpriority`, so every photograph in every rig is fetched as the page loads and priority has to come from a preload link in the head instead. Stacked layers need no `alt` or `aria-hidden` either: they sit inside a labelled `role="img"`, so they are not announced separately.

## Which file

One size per photograph, for the whole page, whatever rig is showing it.

| Photograph | URL |
| --- | --- |
| Beach at sunset | `/photos/hero-beach.jpg` |
| Beach at night | `/photos/1200/hero-beach-night.jpg` |
| Sunrise on the ridge | `/photos/1200/hero-day-1.jpg` |
| Midday over the peak | `/photos/1200/hero-day-2.jpg` |
| Evening light | `/photos/1200/hero-day-3.jpg` |
| The Milky Way | `/photos/1200/hero-day-4.jpg` |

`npm run rigs:check` enforces this across every section file, along with the other four rig failures that do not show on the page. It is a rule about photographs, not about rigs, and it is the one thing here most likely to be got wrong, because choosing a size per rig feels like the careful thing to do. It is the opposite. A browser caches per URL, so a thumbnail asking for the 600px copy of a photograph the hero already fetched at 2400 does not save anything, it adds a second download of a picture the page already has. Picking sizes per rig took the page from 636KB of photographs to 1192KB, with four of the six fetched at two or three sizes each.

Changing a photograph's size is therefore all or nothing, and it is the one edit here that is worse half done. While two sections point at the old URL and one points at the new one, that picture is being fetched twice, which costs more than the migration saves for it. So change every reference to a photograph in the same pass, and check the rendered page rather than the section files, since the sections may be moving while you look.

`hero-beach.jpg` is the page's one 2400px original, because the hero draws it at full shell width and it is the LCP element. Every rig showing that photograph uses the same 2400px file, thumbnails included, and none of them pays anything for it: the hero has already caused the download.

Everything else is on the 1200px set. The tall rigs are the honest cost of that. `rig-portrait-trio` scales a panoramic photograph up to cover a tall union of screens, so it asks for roughly 3.8 times its own rendered width in device pixels, which on a Retina display is more than 1200 gives. It is a below-the-fold illustration inside drawn monitors, mid-crossfade much of the time, and 648KB is worth more to this page than the difference. If that ever stops being true, the right fix is a cropped derivative rather than the full-width original: the tall rigs show about half the width of each picture, so a pre-cropped file would be sharper than the 2400px original at a quarter of its weight.

## Loading

Every photograph in every rig is fetched as the page loads, because an SVG `<image>` takes no `loading` attribute and native lazy loading is not available for inline SVG at all. That is a property of the primitive rather than an oversight, so do not add `loading="lazy"` to a rig and wait for something to happen.

It matters most for the hero. Its photograph is the LCP element and it competes with every below-the-fold rig photograph, all requested at once at ordinary priority, which is why the preload in `index.html` is load bearing rather than a nicety. Keeping the page to one file per photograph is also the fastest way to take weight out of that contention.

## Regenerating a rig

Regenerating replaces the whole svg, and `markup()` knows only what you pass it. So anything a section added to a generated rig by hand is silently gone on the next pass: no error, a page that still renders, and a check that still passes, because most of what a section adds is not geometry.

This matters more than it sounds, because regenerating is the fix for markup that has fallen behind the geometry, so the remedy for one silent failure is the cause of another. Everything the rig family knows about is therefore an option rather than something to bolt on: `glow` for the desk light, `glyphs` for the editor HUD, `align` for the crop, `classes` for anything else. Pass them and a regeneration is safe. If you find yourself editing generated output by hand, that is the signal to add an option here instead.

## Motion

Every animation in the family stops under `prefers-reduced-motion: reduce`, and because each stacked photograph rests at opacity 0, stopping leaves the rig showing the first photograph rather than a blank screen or a half-faded blend. Nothing else is needed in a section.

## Seeing them all at once

`rigs-preview.html` at the repo root draws every rig on one page, plus the bezel comparison and both crossfades. Run the dev server and open <http://localhost:5180/SpreadPaper/rigs-preview.html>. It is generated by `npm run rigs` alongside this file, and the Vite build only builds `index.html`, so it ships nothing.

## Things that go wrong

**The second rig is blank or shows the wrong screens.** Two clipPath ids collided. They are global to the page, not scoped to the svg.

**A frame does not line up with its screen.** The `.rig-frame` rect and the clip rect drifted apart. They carry the same numbers.

**A screen is empty.** It sits outside the `<image>` rect. Every screen has to be inside the image, or there is nothing to show through it.

**The photograph is served as HTML.** The path was written with `/SpreadPaper/` in front of it.

**The rig is squashed.** Something set an aspect ratio or a height on the wrapper. Give it width and let the viewBox do the rest.

**A frame is a hairline no matter what `--rig-bezel` says.** The property was set with a unit. It is in viewBox units and takes a plain number: `--rig-bezel: 26`, not `26px`.

**Both halves of a responsive swap render, one above the other.** `hidden` lost to `.rig`. Check that the rig rules are still inside `@layer components`, because an unlayered rule beats a layered utility whatever the specificity says.

**A rig is the wrong size but looks fine.** Its markup was copied before the geometry changed, and the clip rects and frame rects agree with each other while both disagree with the generator. `npm run rigs:check` catches this by comparing each rig's viewBox against the one the generator draws for that rig name.

**The desk light is cut off in a straight line.** Something set `overflow: hidden` on the rig or a wrapper clipped it. The glow is a blurred ellipse that deliberately spills past the viewBox.
