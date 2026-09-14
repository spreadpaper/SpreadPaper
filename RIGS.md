# Monitor rigs

The rigs are the SVG-drawn displays the marketing site carries one photograph across. They are the site's main visual argument: SpreadPaper does not put a copy of a picture on each screen, it puts one picture across all of them, and a rig has to show that or it is not doing its job.

Everything they need is in `src/rigs.css`, which `src/style.css` imports. Nothing here depends on Tailwind. Copy the markup for the rig you want out of this file, change the four things listed under it, and you are done.

## How a rig works

One `<image>` is drawn across the whole rig. A `<clipPath>` holding one `<rect>` per screen cuts it down to the screens, so the photograph is physically continuous and each screen is a window onto its own part of it. Nothing is sliced and nothing is repeated, which is why the picture carries on behind every frame rather than restarting.

The frame around each screen is that same rect again, stroked rather than filled, at twice `--rig-bezel` and clipped by the screen it sits on. Half the stroke falls outside the clip and disappears, so the frame you see measures `--rig-bezel` exactly. Widening the bezel therefore eats into the photograph from the edges of each screen without moving the photograph itself, which is what makes the thin against thick comparison honest.

Stands, laptop bases and feet are plain rects drawn outside the clip, before it, so the photograph never touches them.

## The four things to change per instance

**The clipPath id.** It must be unique on the page. Two rigs sharing an id is the one failure mode that gives no error: the second rig clips against the first one's screens and comes out wrong or blank. Name it after the section and the instance, like `rig-hero`, `rig-types-static`, `rig-gallery-2`.

**The photo href.** Write it as `/photos/hero-beach.jpg` or `/photos/1200/hero-beach.jpg`, never `/SpreadPaper/photos/...`. Vite prepends the base itself, so the longer form resolves to `/SpreadPaper/SpreadPaper/` and serves the HTML fallback instead of an image. Use the 1200px set for anything below full width and the 2400px originals for the hero and for tall rigs.

**The accessible name.** Either `role="img"` with an `aria-label` describing what the photograph shows and that it runs across the screens, or `aria-hidden="true"` when a caption beside it already says the same thing. Never both, and never neither. Every rig also carries `focusable="false"` so nothing inside it lands in the tab order.

**The `.rig-frame` rects.** Each one repeats the geometry of the clip rect it frames. If you move a screen, move both. They are next to each other in the markup for exactly this reason.

## Sizing

A rig fills its container's width and takes its height from its viewBox, so give it a container with a width and nothing else. Do not set an aspect ratio on the wrapper: the viewBox already carries it, and a second one will fight it.

| `rig-dual` | Two matched monitors | `0 0 686 236` | 2.91 |
| `rig-triple` | Three matched monitors | `0 0 1032 236` | 4.37 |
| `rig-ultrawide` | One ultrawide | `0 0 440 236` | 1.86 |
| `rig-laptop` | A monitor with a laptop beside it | `0 0 616 236` | 2.61 |
| `rig-portrait-trio` | Portrait, landscape, portrait | `0 0 752 376` | 2.00 |
| `rig-canvas` | The editor canvas | `0 0 570 292` | 1.95 |
| `rig-thumb` | Gallery thumbnail | `0 0 320 64` | 5.00 |

To go narrower on a phone, swap in a rig with fewer screens rather than squashing the one you have. Two svgs, the wide one `hidden sm:block` and the narrow one `sm:hidden`, is the pattern. A hidden element leaves the accessibility tree, so both may carry the same `aria-label` without reading twice.

## Custom properties

| Property | Default | What it does |
| --- | --- | --- |
| `--rig-bezel` | `10` (`4` on the thumbnail, `9` on the laptop) | Visible frame width, in viewBox units, so it scales with the rig |
| `--rig-frame-color` | `#1c1c23` | Frame colour |
| `--rig-stand-color` | `#282831` | Stand, foot and laptop base colour |
| `--rig-cycle` | `12s` | Length of a Light and Dark crossfade |
| `--rig-day-cycle` | `20s` | Length of one Dynamic day |

`--rig-bezel` is unitless on purpose. It is measured in viewBox units, not pixels, so a rig at 300px wide and the same rig at 900px keep frames of the same proportion.

Two modifier classes come with the family. `.rig-glass` makes the frames translucent so the strip of photograph running on behind them stays visible, which is what the bezel comparison needs. `.rig-crop` is the hairline rectangle marking the area a render keeps, used by the editor canvas.

## The rigs

### rig-dual

Two matched 16:9 monitors. The default rig, and the right one whenever the point is simply that a picture spans more than one screen.

```html
<svg class="rig rig-dual" viewBox="0 0 686 236" role="img" aria-label="A beach at sunset, one photograph carried across two monitors side by side." focusable="false">
  <defs>
    <clipPath id="rig-example-dual">
      <rect x="0" y="0" width="340" height="200" rx="10"/>
      <rect x="346" y="0" width="340" height="200" rx="10"/>
    </clipPath>
  </defs>
  <g class="rig-stand">
    <rect x="156" y="200" width="28" height="28"/><rect x="115" y="228" width="110" height="8" rx="4"/>
    <rect x="502" y="200" width="28" height="28"/><rect x="461" y="228" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-dual)">
    <image class="rig-photo" href="/photos/1200/hero-beach.jpg" x="0" y="0" width="686" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="346" y="0" width="340" height="200" rx="10"/>
  </g>
</svg>
```

Natural ratio 2.91. Suits the hero at phone widths, the Static kind, and anything that needs a rig without making a point of the arrangement.

### rig-triple

Three matched 16:9 monitors. The widest rig, and the one that shows off continuity best because the picture has to survive two gaps rather than one.

```html
<svg class="rig rig-triple" viewBox="0 0 1032 236" role="img" aria-label="An alpine ridge at sunrise carried across three matched monitors." focusable="false">
  <defs>
    <clipPath id="rig-example-triple">
      <rect x="0" y="0" width="340" height="200" rx="10"/>
      <rect x="346" y="0" width="340" height="200" rx="10"/>
      <rect x="692" y="0" width="340" height="200" rx="10"/>
    </clipPath>
  </defs>
  <g class="rig-stand">
    <rect x="156" y="200" width="28" height="28"/><rect x="115" y="228" width="110" height="8" rx="4"/>
    <rect x="502" y="200" width="28" height="28"/><rect x="461" y="228" width="110" height="8" rx="4"/>
    <rect x="848" y="200" width="28" height="28"/><rect x="807" y="228" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-triple)">
    <image class="rig-photo" href="/photos/1200/hero-day-1.jpg" x="0" y="0" width="1032" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="346" y="0" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="692" y="0" width="340" height="200" rx="10"/>
  </g>
</svg>
```

Natural ratio 4.37, which is close to the photographs' own 4.29, so it crops them least of any rig. Suits the hero at desktop widths, the Dynamic schedule, and the bezel comparison.

### rig-ultrawide

One 21:9 ultrawide on a wide foot.

```html
<svg class="rig rig-ultrawide" viewBox="0 0 440 236" role="img" aria-label="A beach at sunset on a single ultrawide monitor." focusable="false">
  <defs>
    <clipPath id="rig-example-ultrawide">
      <rect x="0" y="0" width="440" height="200" rx="10"/>
    </clipPath>
  </defs>
  <g class="rig-stand">
    <rect x="206" y="200" width="28" height="28"/><rect x="145" y="228" width="150" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-ultrawide)">
    <image class="rig-photo" href="/photos/1200/hero-beach.jpg" x="0" y="0" width="440" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="440" height="200" rx="10"/>
  </g>
</svg>
```

Natural ratio 1.86, the most upright rig in the set, so it fits a narrow column where a row of monitors will not. Suits a feature beat about one display being enough, or a card in a grid.

### rig-laptop

A 16:9 monitor with a laptop beside it, the laptop screen smaller and sitting lower, as it does on a real desk.

```html
<svg class="rig rig-laptop" viewBox="0 0 616 236" role="img" aria-label="A mountain ridge carried across a monitor and the laptop beside it." focusable="false">
  <defs>
    <clipPath id="rig-example-laptop">
      <rect x="0" y="0" width="340" height="200" rx="10"/>
      <rect x="356" y="60" width="250" height="164" rx="9"/>
    </clipPath>
  </defs>
  <g class="rig-stand">
    <rect x="156" y="200" width="28" height="28"/><rect x="115" y="228" width="110" height="8" rx="4"/>
    <rect x="346" y="224" width="270" height="12" rx="5"/>
  </g>
  <g clip-path="url(#rig-example-laptop)">
    <image class="rig-photo" href="/photos/1200/hero-day-2.jpg" x="0" y="0" width="616" height="224" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="356" y="60" width="250" height="164" rx="9"/>
    <rect class="rig-chin" x="356" y="206" width="250" height="18"/>
  </g>
</svg>
```

Natural ratio 2.61. The `.rig-chin` rect is the deeper frame below a laptop screen, which is what stops the lid reading as a small monitor. The laptop screen showing a lower part of the photograph is not a bug: macOS lays the wallpaper out across the display arrangement, so a screen that sits lower shows what is lower in the picture. That is worth saying in a caption, because it is the detail that proves the app is doing real work. Suits any beat about the setup people actually have.

### rig-portrait-trio

A portrait monitor, a landscape monitor and another portrait monitor, bottoms level.

```html
<svg class="rig rig-portrait-trio" viewBox="0 0 752 376" role="img" aria-label="One photograph carried across a portrait monitor, a landscape monitor and another portrait monitor." focusable="false">
  <defs>
    <clipPath id="rig-example-trio">
      <rect x="0" y="0" width="200" height="340" rx="10"/>
      <rect x="206" y="140" width="340" height="200" rx="10"/>
      <rect x="552" y="0" width="200" height="340" rx="10"/>
    </clipPath>
  </defs>
  <g class="rig-stand">
    <rect x="86" y="340" width="28" height="28"/><rect x="45" y="368" width="110" height="8" rx="4"/>
    <rect x="362" y="340" width="28" height="28"/><rect x="321" y="368" width="110" height="8" rx="4"/>
    <rect x="638" y="340" width="28" height="28"/><rect x="597" y="368" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-trio)">
    <image class="rig-photo" href="/photos/hero-day-1.jpg" x="0" y="0" width="752" height="340" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="200" height="340" rx="10"/>
    <rect class="rig-frame" x="206" y="140" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="552" y="0" width="200" height="340" rx="10"/>
  </g>
</svg>
```

Natural ratio 2.00. The union of the screens is tall, so a panoramic photograph is scaled up to cover it and you see roughly the middle half of the picture. Use a 2400px original here, not the 1200px set. Suits the point that the arrangement can be anything, and the editor.

### rig-canvas

The editor canvas rather than a desk: a wide display with a narrow one beside it, the photograph carrying on past both, dimmed, and a hairline rectangle marking the area the render keeps.

```html
<svg class="rig rig-canvas" viewBox="0 0 570 292" role="img" aria-label="The editor canvas: a wide display with a narrow one beside it, the photograph reaching past both." focusable="false">
  <defs>
    <clipPath id="rig-example-canvas">
      <rect x="34" y="44" width="340" height="200" rx="10"/>
      <rect x="390" y="24" width="146" height="244" rx="10"/>
    </clipPath>
  </defs>
  <image class="rig-bleed" href="/photos/1200/hero-day-2.jpg" x="0" y="0" width="570" height="292" preserveAspectRatio="xMidYMid slice"/>
  <rect class="rig-crop" x="24" y="14" width="522" height="264" rx="8"/>
  <g clip-path="url(#rig-example-canvas)">
    <image class="rig-photo" href="/photos/1200/hero-day-2.jpg" x="0" y="0" width="570" height="292" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="34" y="44" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="390" y="24" width="146" height="244" rx="10"/>
  </g>
</svg>
```

Natural ratio 1.95. It carries no stands and no drop shadow, because it is a view inside the app. The dimmed `.rig-bleed` image and the clipped one share their geometry exactly, which is what makes the bright part sit inside the dim part rather than beside it. Change the href in both or the two halves will show different photographs.

### rig-thumb

Three screens, no stands, no furniture. Built to survive being 92px tall on a gallery card.

```html
<svg class="rig rig-thumb" viewBox="0 0 320 64" aria-hidden="true" focusable="false">
  <defs>
    <clipPath id="rig-example-thumb">
      <rect x="0" y="0" width="104" height="64" rx="5"/>
      <rect x="108" y="0" width="104" height="64" rx="5"/>
      <rect x="216" y="0" width="104" height="64" rx="5"/>
    </clipPath>
  </defs>
  <g clip-path="url(#rig-example-thumb)">
    <image class="rig-photo" href="/photos/600/hero-beach.jpg" x="0" y="0" width="320" height="64" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="104" height="64" rx="5"/>
    <rect class="rig-frame" x="108" y="0" width="104" height="64" rx="5"/>
    <rect class="rig-frame" x="216" y="0" width="104" height="64" rx="5"/>
  </g>
</svg>
```

Natural ratio 5.00, and it is the one rig meant to be sized by height rather than width: `class="rig rig-thumb" style="height: 92px; width: auto"`, or a class doing the same. Use the 600px photographs. It is decorative on a card whose heading already names the preset, so it takes `aria-hidden="true"` and no label, as above.

## Worked example: thin against thick frames

The same rig twice, the photograph in the same place both times, only `--rig-bezel` different. The frames are drawn as glass so the strip of picture hidden behind each one stays visible, which is the whole argument: the ridgeline still meets across every gap.

```html
<figure>
  <p>Thin frames</p>
  <svg class="rig rig-triple rig-glass" style="--rig-bezel: 4" viewBox="0 0 1032 236" role="img" aria-label="An alpine ridge across three displays with narrow frames." focusable="false">
    <!-- the rest exactly as rig-triple above, with its own clipPath id -->
  </svg>

  <p>Thick frames</p>
  <svg class="rig rig-triple rig-glass" style="--rig-bezel: 26" viewBox="0 0 1032 236" role="img" aria-label="The same ridge across three displays with wide frames, still meeting across each gap." focusable="false">
    <!-- the rest exactly as rig-triple above, with a different clipPath id -->
  </svg>
</figure>
```

Two things to keep. The two rigs must show the same photograph, or there is nothing to compare. And the ids must differ, or the second one clips against the first.

## Worked example: a Light and Dark pair

Extra photographs stack inside the same clipped group, above the first one, and fade in over it. They rest at opacity 0, so a reader with motion turned off sees the photograph at the bottom of the stack and nothing moves.

```html
<svg class="rig rig-dual" viewBox="0 0 686 236" role="img" aria-label="A beach across two monitors, fading between day and night." focusable="false">
  <defs>
    <clipPath id="rig-example-pair">
      <rect x="0" y="0" width="340" height="200" rx="10"/>
      <rect x="346" y="0" width="340" height="200" rx="10"/>
    </clipPath>
  </defs>
  <g class="rig-stand">
    <rect x="156" y="200" width="28" height="28"/><rect x="115" y="228" width="110" height="8" rx="4"/>
    <rect x="502" y="200" width="28" height="28"/><rect x="461" y="228" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-pair)">
    <image class="rig-photo" href="/photos/1200/hero-beach.jpg" x="0" y="0" width="686" height="200" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-photo-fade" href="/photos/1200/hero-beach-night.jpg" x="0" y="0" width="686" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="346" y="0" width="340" height="200" rx="10"/>
  </g>
</svg>
```

The label describes the first photograph, since that is what a reader with motion off will see. The second image needs no label of its own: it is inside a labelled `role="img"` and is not announced separately.

Set `--rig-cycle` on the svg to change the pace. The default is 12 seconds.

## Worked example: the Dynamic day

Five images: the four hours of the schedule, then the first one again so the loop closes on a fade rather than a cut. `rig-day-2`, `-3` and `-4` hold their photograph from its own hour until the next covers it, and `rig-day-wrap` carries the repeat.

```html
<svg class="rig rig-triple" viewBox="0 0 1032 236" role="img" aria-label="Three monitors running through one day, sunrise to night." focusable="false">
  <defs>
    <clipPath id="rig-example-day">
      <rect x="0" y="0" width="340" height="200" rx="10"/>
      <rect x="346" y="0" width="340" height="200" rx="10"/>
      <rect x="692" y="0" width="340" height="200" rx="10"/>
    </clipPath>
  </defs>
  <g class="rig-stand">
    <rect x="156" y="200" width="28" height="28"/><rect x="115" y="228" width="110" height="8" rx="4"/>
    <rect x="502" y="200" width="28" height="28"/><rect x="461" y="228" width="110" height="8" rx="4"/>
    <rect x="848" y="200" width="28" height="28"/><rect x="807" y="228" width="110" height="8" rx="4"/>
  </g>
  <g clip-path="url(#rig-example-day)">
    <image class="rig-photo" href="/photos/1200/hero-day-1.jpg" x="0" y="0" width="1032" height="200" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-2" href="/photos/1200/hero-day-2.jpg" x="0" y="0" width="1032" height="200" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-3" href="/photos/1200/hero-day-3.jpg" x="0" y="0" width="1032" height="200" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-4" href="/photos/1200/hero-day-4.jpg" x="0" y="0" width="1032" height="200" preserveAspectRatio="xMidYMid slice"/>
    <image class="rig-photo rig-day rig-day-wrap" href="/photos/1200/hero-day-1.jpg" x="0" y="0" width="1032" height="200" preserveAspectRatio="xMidYMid slice"/>
    <rect class="rig-frame" x="0" y="0" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="346" y="0" width="340" height="200" rx="10"/>
    <rect class="rig-frame" x="692" y="0" width="340" height="200" rx="10"/>
  </g>
</svg>
```

Set `--rig-day-cycle` on the svg to change the pace. The default is 20 seconds, which is 5 seconds a photograph.

If a section lights something up in step with the cycle, a row of times for instance, drive it from the same duration so the two never drift apart.

## Loading

An SVG `<image>` takes no `loading="lazy"`, so every photograph in every rig is fetched as the page loads. That costs less than it sounds: the site has six photographs and the browser fetches each one once however many rigs point at it. Still, reach for the smallest set that holds up. The 600px photographs for thumbnails, the 1200px set for anything inside a column, the 2400px originals only for the hero and for tall rigs like `rig-portrait-trio` where the picture is scaled up to cover the screens.

An SVG `<image>` also takes no `fetchpriority`, which the hero photograph used to carry. If the hero rig measures badly, preload it from `index.html` instead, with `<link rel="preload" as="image" href="/photos/hero-beach.jpg">`.

## Motion

Every animation in the family stops under `prefers-reduced-motion: reduce`, and because each stacked photograph rests at opacity 0, stopping leaves the rig showing the first photograph rather than a blank screen or a half-faded blend. Nothing else is needed in a section.

## Things that go wrong

**The second rig is blank or shows the wrong screens.** Two clipPath ids collided. They are global to the page, not scoped to the svg.

**A frame does not line up with its screen.** The `.rig-frame` rect and the clip rect drifted apart. They carry the same numbers.

**A screen is empty.** It sits outside the `<image>` rect. Every screen has to be inside the image, or there is nothing to show through it.

**The photograph is served as HTML.** The path was written with `/SpreadPaper/` in front of it.

**The rig is squashed.** Something set an aspect ratio or a height on the wrapper. Give it width and let the viewBox do the rest.

**A frame is a hairline no matter what `--rig-bezel` says.** The property was set with a unit. It is in viewBox units and takes a plain number: `--rig-bezel: 26`, not `26px`.
