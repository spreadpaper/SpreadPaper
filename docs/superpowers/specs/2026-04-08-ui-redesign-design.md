# SpreadPaper UI Redesign — Cool Dark

## Summary

Full UI redesign of SpreadPaper. Replace all current SwiftUI views with custom-styled SwiftUI + AppKit hybrid views. SwiftUI handles layout, navigation, and state management. AppKit (`NSViewRepresentable`) handles components that need pixel-level control: the schedule range bars, canvas drag interaction, and gallery card rendering. All views are custom-styled to match the Cool Dark design — no default SwiftUI component chrome.

Visual direction: **Cool Dark** — dark backgrounds (#16161a), indigo accent (#5e5ce6), wallpaper images glow against the dark canvas. Think Arc Browser, Warp Terminal.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  SwiftUI Layer (layout + state)                 │
│  Navigation, view structure, @Observable state  │
│  Custom ViewModifiers for Cool Dark styling     │
├─────────────────────────────────────────────────┤
│  AppKit Layer (NSViewRepresentable)             │
│  RangeBarView: draggable schedule handles       │
│  CanvasView: image drag/zoom interaction        │
│  GalleryCardView: image-forward rendering       │
├─────────────────────────────────────────────────┤
│  Services Layer (unchanged)                     │
│  WallpaperManager: screens, render, apply       │
│  DynamicWallpaperGenerator: HEIC creation       │
│  File I/O, presets, app lifecycle               │
└─────────────────────────────────────────────────┘
```

### Custom Styling Approach

Every view is custom-styled. No default SwiftUI buttons, lists, sliders, or toggles. Instead:

- **Custom ButtonStyle** for all buttons (Cool Dark colors, border radius, hover states)
- **Custom backgrounds** on all containers (bg-primary, bg-secondary, bg-elevated)
- **Custom slider** for zoom (AppKit NSSlider wrapped in NSViewRepresentable, or fully custom drawn)
- **Custom range bars** for schedule (AppKit NSView with mouse drag tracking, snap-to-10min)
- **Custom gallery grid** using LazyVGrid with custom card views
- **Custom segmented control** for filter tabs (not SwiftUI Picker)
- **Custom text fields** for name input (styled NSTextField)
- **Forced dark appearance** on the window (NSAppearance dark) as baseline, with custom colors on top

## Views

### 1. Gallery View (home screen)

Full-width grid of wallpaper cards. Image-forward design — images fill each card edge to edge, name and type overlaid on a dark gradient at the bottom.

**Top bar:** App title ("SpreadPaper") left, filter tabs center (All / Static / Dynamic / Light-Dark), "+ New" button right.

**Cards show:**
- Wallpaper image filling the card
- Name + type label overlaid at bottom ("Night Sky" / "Dynamic · 4 images")
- Active wallpaper: indigo border + green dot
- Light/Dark type: split preview (light left, dark right)

**Interactions:**
- Click card → navigate to Editor view
- Right-click card → context menu (Edit, Apply, Delete)
- Click "+ New" → creation modal

### 2. Creation Modal

Center modal sheet over the gallery (not a separate page). Three clickable rows:

| Type | Icon | Description |
|------|------|-------------|
| Standard Wallpaper | 🖼 | One image spread across your monitors |
| Time of Day | ☀ | Wallpaper shifts throughout the day |
| Light & Dark | ◐ | Different image for each appearance mode |

Click a row → navigate to Editor with the appropriate mode.

### 3. Editor View

**Top bar:** "← Gallery" back link, wallpaper name + type badge center.

**Main area:** Full canvas showing monitors with wallpaper image. Drag to reposition, scroll to zoom. Monitors shown at relative scale with screen names.

**Right panel** (inspector-style, ~220px wide):

#### Position section
- Zoom slider
- Fit button (auto-fit to canvas)
- Flip button (horizontal mirror)

#### Schedule section (Time of Day mode only)
Per-row range bars. Each row shows:
- Drag handle (three horizontal lines) for reordering
- Image thumbnail (32x22px)
- Auto-generated name (Sunrise, Midday, Sunset, Night, etc.)
- Time range ("7 AM – 12 PM")
- Duration badge ("5h")
- Mini 24h range bar with draggable start/end handles
- Handles snap to 10-minute marks

Rows are sorted by time. Drag to reorder → times auto-redistribute evenly. Night images wrap midnight visually (colored fill on both ends of the bar).

"+ Add Image" dashed button at the bottom.

#### Appearance section (Light/Dark mode only)
Two image cards side by side:
- Left: ☀ Light (image thumbnail + label)
- Right: 🌙 Dark (image thumbnail + label)
- Click one to preview it on the canvas
- Selected card has indigo border

#### Name section
Editable text field for the wallpaper name.

#### Apply button
Green "Apply Wallpaper" button at the bottom of the panel. Full width, prominent.

### 4. Welcome Wizard (first launch only)

**Step 1: Welcome**
- Step indicators (3 dots)
- Animated dual-monitor illustration
- "Welcome to SpreadPaper" heading
- "One wallpaper across all your monitors" subheading
- Auto-detects connected displays: "2 displays detected"
- "Get Started" button

**Step 2: Pick an Image**
- Large drop zone (drag & drop or browse files)
- "Choose your first wallpaper" heading
- Back / Next buttons

**Step 3: → Editor**
Wizard dissolves. User lands in the real Editor with:
- Image auto-fitted across monitors
- First-run tooltip on canvas: "Drag the image to reposition. Scroll to zoom. Hit Apply when you're happy."
- Tooltip dismisses on first interaction

### 5. Empty Gallery State

When no wallpapers exist (after wizard or if all deleted):
- Centered message: "No wallpapers yet"
- "+ Create your first wallpaper" button
- Or drag & drop hint

## Color Palette — Cool Dark

| Token | Value | Usage |
|-------|-------|-------|
| bg-primary | #16161a | Main background |
| bg-secondary | #1e1e24 | Panels, top bar, right sidebar |
| bg-elevated | #24242c | Cards, input fields, schedule rows |
| border | #2a2a32 | Borders, dividers |
| text-primary | #e8e8ed | Headings, names |
| text-secondary | #9e9eaa | Labels, descriptions |
| text-tertiary | #6e6e7a | Hints, placeholders |
| accent | #5e5ce6 | Active states, selected borders, buttons, links |
| accent-glow | rgba(94,92,230,0.2) | Box shadow on active cards |
| success | #34C759 | Active wallpaper dot, apply button |
| canvas-bg | #111114 | Editor canvas background |

## Custom Components Needed

These components cannot use default SwiftUI styling and need custom implementations:

| Component | Approach | Why |
|-----------|----------|-----|
| Gallery grid cards | SwiftUI + custom overlay | Image-forward with gradient overlay text |
| Filter tabs (All/Static/Dynamic/L-D) | Custom segmented control | Default Picker doesn't match Cool Dark |
| Creation modal | Custom sheet with ZStack | Styled rows, not default List |
| Editor canvas | Existing CanvasView (keep) | Already custom, just restyle colors |
| Zoom slider | NSViewRepresentable wrapping NSSlider | Custom track/thumb colors |
| Range bar with drag handles | NSViewRepresentable with mouse tracking | No SwiftUI equivalent; needs drag on sub-regions with snap-to-10min |
| Schedule row (drag to reorder) | SwiftUI with onDrag/onDrop | Style the row container custom |
| Side-by-side L/D cards | SwiftUI with custom styling | Simple enough in SwiftUI |
| Apply button | Custom ButtonStyle | Green with glow shadow |
| Name text field | Custom styled TextField | Dark background, subtle border |
| Wizard steps | Custom full-screen views | Step indicators, drop zone, animated monitors |
| First-run tooltip | Custom overlay view | Dark bubble with arrow |

## Swift Layer Changes

### Keep (unchanged)
- `WallpaperManager` — screen detection, CGContext rendering, wallpaper application
- `DynamicWallpaperGenerator` — HEIC generation
- `SavedPreset`, `TimeVariant`, `DisplayInfo` — data models
- Preset JSON persistence
- `UpdateChecker` — update checking
- `SpreadPaperApp` — app entry point (adjust scene/window config)

### Rewrite from scratch (new custom-styled views)
- `GalleryView` — replaces ContentView + SidebarView
- `EditorView` — replaces DynamicEditorView, reuses CanvasView rendering logic
- `ScheduleView` — replaces TimelineView, custom range bars
- `RangeBarView` — new NSViewRepresentable, draggable handles
- `WizardView` — new, 2-step welcome flow
- `CreationModal` — new, type picker sheet
- `GalleryCardView` — new, image-forward card

### Remove
- `SidebarView` — replaced by GalleryView
- `TimelineView` — replaced by ScheduleView with range bars
- `ImageDropZone` — integrated into WizardView and EditorView
- `MonitorOverlayView` — simplified and integrated into EditorView
- `GlassModifiers` — Cool Dark doesn't use glass effects
- `WindowDragHandler`, `WindowAccessor` — may not be needed

### New shared infrastructure
- `CoolDarkTheme.swift` — all color tokens, button styles, text styles as SwiftUI ViewModifiers
- `AppSettings` — add `hasCompletedWizard: Bool`

## Default Time Presets

When adding images in Time of Day mode, auto-assign these defaults:

| # | Name | Time |
|---|------|------|
| 1 | Sunrise | 7:00 AM |
| 2 | Morning | 9:00 AM |
| 3 | Noon | 12:00 PM |
| 4 | Afternoon | 3:00 PM |
| 5 | Late Afternoon | 5:00 PM |
| 6 | Sunset | 7:00 PM |
| 7 | Dusk | 9:00 PM |
| 8 | Night | 11:00 PM |

Additional images cycle through remaining hours.

## Scope Boundaries

**In scope:**
- Gallery view with filter tabs
- Creation modal (3 types)
- Editor with canvas + right panel
- Per-row schedule with draggable range bars (snap to 10min)
- Drag-to-reorder schedule rows
- Light/Dark editor with side-by-side thumbnails
- Welcome wizard (2 steps + editor handoff)
- Empty states
- Cool Dark color palette
- SwiftUI + AppKit hybrid architecture (custom styling, NSViewRepresentable for complex components)
- CoolDarkTheme shared styling infrastructure

**Out of scope (future):**
- Pack format / sharing
- Settings window
- Community gallery
- Auto-update UI (keep existing UpdateChecker, show in-app toast)
- Light mode theme option
