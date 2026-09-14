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

**The photo href.** Write it as `/photos/hero-beach.jpg` or `/photos/1200/hero-beach.jpg`, never `/SpreadPaper/photos/...`. Vite prepends the base itself, so the longer form resolves to `/SpreadPaper/SpreadPaper/` and serves the HTML fallback instead of an image.

**The accessible name.** Either `role="img"` with an `aria-label` naming the setup and describing the photograph, or `aria-hidden="true"` when a caption beside it already says the same thing. Never both, and never neither. The label is the only alt text the photograph gets, so write it as a sentence about the picture and the displays, not a repeat of the heading. Every rig also carries `focusable="false"` so nothing inside it lands in the tab order.

**The `.rig-frame` rects.** Each one repeats the geometry of the clip rect it frames. If you move a screen, move both. They are next to each other in the markup for exactly this reason.

## Sizing

A rig fills its container's width and takes its height from its viewBox, so give it a container with a width and nothing else. Do not set an aspect ratio on the wrapper: the viewBox already carries it, and a second one will fight it. There is no outer corner to square when a rig bleeds to the viewport edge either, because the rounded corners belong to each screen rect rather than to a container.

@table

At phone widths a rig drops screens rather than height. Swap in a rig with fewer screens: two svgs, the wide one `hidden sm:block` and the narrow one `sm:hidden`. A hidden element leaves the accessibility tree, so both may carry the same `aria-label` without reading twice. Shortening the box instead squeezes every display into a sliver.

## Custom properties

| Property | Default | What it does |
| --- | --- | --- |
| `--rig-bezel` | `10`, `9` on the two laptop rigs, `4` on the thumbnail | Visible frame width, in viewBox units, so it scales with the rig |
| `--rig-frame-color` | `#1c1c23` | Frame and laptop chin colour |
| `--rig-stand-color` | `#191920` | Stand, foot and laptop base colour |
| `--rig-glow-color` | `rgb(255 255 255 / 0.06)` | The light pooling on the desk under the rig |
| `--rig-cycle` | `12s` | Length of a Light and Dark crossfade |
| `--rig-day-cycle` | `20s` | Length of one Dynamic day |

`--rig-bezel` is unitless on purpose. It is measured in viewBox units, not pixels, so a rig at 300px wide and the same rig at 900px keep frames of the same proportion, and a section that wants pixels can compose `calc(var(--rig-bezel) * 1px)` from it.

The glow is where the page gets its colour, and it is motivated light rather than decoration, which is the only reason it survives review. One shadow and one light ellipse per rig, no more. The tints:

| Section | `--rig-glow-color` |
| --- | --- |
| Hero and Static | `rgb(255 255 255 / 0.06)` |
| Light and Dark | `rgb(124 124 255 / 0.10)` |
| Dynamic | `rgb(245 165 36 / 0.10)` |
| Editor | `rgb(94 92 230 / 0.08)` |

Two modifier classes come with the family. `.rig-glass` makes the frames translucent so the picture can be seen carrying on behind them, which is what the bezel comparison needs. `.rig-crop` is the hairline rectangle marking the area a render keeps, used by the editor canvas.

## The rigs

### rig-desk

A 14-inch laptop open at the left with two 27-inch monitors beside it. The everyday Mac desk, and the widest rig on the page.

@rig desk {"id": "rig-example-desk", "photos": ["/photos/hero-beach.jpg"], "label": "A beach at sunset carried across a laptop and the two monitors beside it on a desk."}

Natural ratio 3.86. It is the hero rig, and the hero is the one place to use the 2400px original at `/photos/hero-beach.jpg` rather than the 1200px set, because at full shell width the derivative is visibly soft. That URL is load bearing: `index.html` preloads it, and a preload that does not byte-match the href fetches a file nobody uses.

### rig-dual

Two matched 27-inch monitors on stands. The plainest rig, and the right one whenever the point is simply that a picture spans more than one screen.

@rig dual {"id": "rig-example-dual", "photos": ["/photos/1200/hero-beach.jpg"], "label": "A beach at sunset carried across two monitors side by side."}

Natural ratio 3.03. Suits the Static kind and any beat that needs a rig without making a point of the arrangement.

### rig-laptop

A 27-inch monitor with a 14-inch laptop beside it, the laptop screen smaller and sitting lower, as it does on a real desk.

@rig laptop {"id": "rig-example-laptop", "photos": ["/photos/1200/hero-beach.jpg", "/photos/1200/hero-beach-night.jpg"], "label": "A beach carried across a monitor and the laptop beside it, fading from day to night."}

Natural ratio 2.33. The laptop screen showing a lower part of the photograph is not a bug: macOS lays the wallpaper out across the display arrangement, so a screen sitting lower shows what is lower in the picture. Worth saying in a caption, because it is the detail that proves the app is doing real work. Shown above with a crossfade, since this is the Light and Dark rig, and note that the pair covers both screens rather than one.

### rig-portrait-trio

A 27-inch portrait, a 27-inch landscape and another 27-inch portrait, bottoms level.

@rig portrait-trio {"id": "rig-example-trio", "photos": ["/photos/hero-day-1.jpg"], "label": "One alpine ridge carried across a portrait monitor, a landscape monitor and another portrait monitor."}

Natural ratio 1.96, the tallest rig on the page, which is deliberate: it belongs beside the Dynamic schedule list and gives that row a tall neighbour. The union of the screens is tall, so a panoramic photograph is scaled up to cover it and you see roughly the middle half of the picture. That is honest, because the app would have to crop the same way. Use a 2400px original here, not the 1200px set, and check the horizon still runs across all three screens, since continuity is the only thing the rig has to prove.

### rig-trio

Three matched 27-inch monitors. Two gaps rather than one, so it is the rig that argues hardest for continuity.

@rig trio {"id": "rig-example-trio-row", "photos": ["/photos/1200/hero-day-1.jpg"], "label": "An alpine ridge at sunrise carried across three matched monitors."}

Natural ratio 4.56, which is close to the photographs' own 4.29, so it crops them least of any rig. It is the bezel comparison rig.

### rig-ultrawide

One 34-inch ultrawide on a wide foot.

@rig ultrawide {"id": "rig-example-ultrawide", "photos": ["/photos/1200/hero-beach.jpg"], "label": "A beach at sunset on a single ultrawide monitor."}

Natural ratio 1.98, the most upright rig in the set, so it fits a narrow column where a row of monitors will not.

### rig-mixed

The editor canvas rather than a desk: a 34-inch ultrawide beside a 27-inch portrait, the photograph carrying on past both, dimmed, a hairline rectangle marking the area the render keeps, and the app's floating HUD over the bottom of the wide screen.

@rig mixed {"id": "rig-example-mixed", "photos": ["/photos/1200/hero-day-2.jpg"], "label": "The editor canvas: an ultrawide beside a portrait monitor, the photograph reaching past both."}

Natural ratio 1.81. It carries no stands, no desk light and no drop shadow, because it is a view inside the app rather than an object on a desk. Two things to watch. The dimmed `.rig-bleed` image and the clipped one share their geometry exactly, which is what makes the bright part sit inside the dim part rather than beside it, so change the href in both. And the HUD glyphs are `@icon` tokens, which expand only inside files that `index.html` includes, so they work in a section and not in a standalone page. `crop` is a placeholder name: pick the three glyphs the HUD should actually carry, and ask shell-dev if a name does not resolve.

### rig-thumb

Three screens, no stands, no furniture. Built to survive being 92px tall on a gallery card.

@rig thumb {"id": "rig-example-thumb", "photos": ["/photos/600/hero-beach.jpg"]}

Natural ratio 5.41, and it is the one rig meant to be sized by height rather than width: `class="rig rig-thumb" style="height: 92px; width: auto"`, or a class doing the same. Use the 600px photographs. It is decorative on a card whose heading already names the preset, so it takes `aria-hidden="true"` and no label.

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

@rig portrait-trio {"id": "rig-example-day", "photos": ["/photos/hero-day-1.jpg", "/photos/hero-day-2.jpg", "/photos/hero-day-3.jpg", "/photos/hero-day-4.jpg", "/photos/hero-day-1.jpg"], "day": true, "label": "Three monitors running through one day, sunrise to night."}

Set `--rig-day-cycle` on the svg to change the pace. The default is 20 seconds, which is 5 seconds a photograph.

If a section lights something up in step with the cycle, a row of times for instance, drive it from the same duration so the two never drift apart.

## Driving the layers yourself

`.rig-photo` carries no opacity and no animation. It is a marker class, nothing more, so a section that wants to own its own schedule stacks plain `.rig-photo` images inside the clip and sets their opacity itself, from a stylesheet, from a slider, from anything. `.rig-photo-fade` and `.rig-day` are conveniences for the standard behaviour, not a policy: leave them off and the rig imposes no timing at all.

Two things the rig cannot give you, because SVG does not. An `<image>` takes no `loading="lazy"` and no `fetchpriority`, so every photograph in every rig is fetched as the page loads and priority has to come from a preload link in the head instead. Stacked layers need no `alt` or `aria-hidden` either: they sit inside a labelled `role="img"`, so they are not announced separately.

## Loading

Every photograph in every rig is fetched as the page loads, for the reason above. That costs less than it sounds: the site has six photographs and the browser fetches each one once however many rigs point at it. Still, reach for the smallest set that holds up. The 600px photographs for thumbnails, the 1200px set for anything inside a column, the 2400px originals only for the hero and for tall rigs like `rig-portrait-trio` where the picture is scaled up to cover the screens.

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

**The desk light is cut off in a straight line.** Something set `overflow: hidden` on the rig or a wrapper clipped it. The glow is a blurred ellipse that deliberately spills past the viewBox.
