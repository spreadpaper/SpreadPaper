# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpreadPaper is a native macOS app (Swift 6 / SwiftUI) that spreads images across multiple monitors as wallpaper: one static image, a Light & Dark pair, or a time-of-day schedule. Requires macOS 15.0+ (Sequoia) and Apple Silicon. The repo also contains a Vite + Tailwind CSS marketing website.

## Build & Run

**macOS App (Xcode):**
```bash
open SpreadPaper.xcodeproj    # Open in Xcode, then Cmd+R to build/run
xcodebuild -scheme SpreadPaper -configuration Debug build       # CLI build
xcodebuild test -scheme SpreadPaper -destination 'platform=macOS'   # Swift Testing suites in SpreadPaperTests/
```

**Website:**
```bash
npm ci
npm run dev      # Local dev server
npm run build    # Production build to dist/
```

**App icon:** `design/make-icon.swift` renders `design/app-icon-source.png` into every size in `SpreadPaper/Assets.xcassets/AppIcon.appiconset/`.

## Architecture

Source files organized under `SpreadPaper/`. One external package: PhosphorSwift (icons), resolved by Xcode from `https://github.com/phosphor-icons/swift`.

### App

- **App/SpreadPaperApp.swift** — App entry point. ZStack with route-based main content and CreationModal overlay. Forces dark appearance, hidden title bar, wizard on first launch, `Settings` scene. Checks for updates two seconds after launch.

### Theme (Cool Dark design system)

- **Theme/CoolDarkTheme.swift** — Color tokens (`Color.cd*` extensions), `CoolDarkButtonStyle`, `SectionHeader`
- **Theme/CoolDarkComponents.swift** — Reusable styled components: `CoolDarkTextField`, `ToastView`

### Navigation

- **Navigation/AppNavigation.swift** — `@Observable` navigation model with `AppRoute` enum (wizard/gallery/editor/editorNew), `WallpaperType` enum (owns each kind's title, subtitle, SF Symbol and tint), `GalleryFilter` enum, and the pending image URLs handed to a new editor

### Views

- **Views/WizardView.swift** — 2-step first-run wizard: display count, then an image picker that also accepts drops. One image opens a static editor, several open a dynamic one
- **Views/GalleryView.swift** — Home screen: sidebar filters, search, preset grid, error banner, New Wallpaper button, rename alert and delete confirmation
- **Views/GalleryCardView.swift** — Preset card with thumbnail, type badge and a Rename / Duplicate / Show in Finder / Delete menu
- **Views/CreationModal.swift** — Overlay modal picking the wallpaper type (Static / Light & Dark / Dynamic) before a new preset, with an animated monitor hero and arrow-key navigation
- **Views/EditorView.swift** — Full editor: header, canvas with a floating zoom/fit/flip HUD, and an inspector with type, images, zoom and orientation sections, plus a displays section for bezels that appears only with two or more displays
- **Views/EditorCanvasView.swift** — Monitor canvas rendering with image overlay, drag, zoom, snap and image drops
- **Views/MonitorPreviewView.swift** — Individual monitor outline for the canvas
- **Views/ScheduleView.swift** — `ScheduleDetailModal`, opened from an editor schedule row: name, active period, one range bar
- **Views/RangeBarView.swift** — SwiftUI time bar with one draggable, snapping handle, plus `RangeBarMath` (pure, unit-tested). Used once, inside `ScheduleDetailModal`
- **Views/SaveDialog.swift** — Overlay that names a preset before Save or Save & Apply
- **Views/SettingsView.swift** — Native Settings window with General (default display gap) and Updates tabs

### Services

- **Services/WallpaperManager.swift** — `@Observable` class: screen detection, preset persistence, render orchestration and wallpaper application for all three kinds. Applies are serialized behind `isApplying`
- **Services/WallpaperRenderer.swift** — Pure, `nonisolated` CGContext rendering of one `RenderSpec` (a `Sendable` placement) plus PNG encoding
- **Services/DynamicWallpaperGenerator.swift** — HEIC dynamic desktop file generation with Apple XMP metadata, time-based and appearance-based (based on wallpapper's reverse engineering)
- **Services/ThumbnailRenderer.swift** — ImageIO downsampling for gallery thumbnails, safe off the main actor
- **Services/PresetStore.swift** — Reads and writes the presets JSON, backs up a corrupt file, flags legacy files needing a migration rewrite
- **Services/DisplayLayout.swift** — `Bezel` struct and the frame spacing that pushes displays apart by the bezels between them
- **Services/WallpaperFilenames.swift** — Names of the rendered per-display files, and the tests for pre-1.7.1 legacy names
- **Services/FilenameUtils.swift** — Stored image filenames (`UUID_original.ext`) and the display name read back out
- **Services/ImageFileFilter.swift** — Keeps only local image file URLs from a drop
- **Services/UpdateChecker.swift** — Fetches the latest GitHub release, compares versions, parses CHANGELOG.md for release notes, read at the release tag and falling back to `main`. Non-2xx replies become a `GitHubStatusError` with plain UI copy
- **Services/SemanticVersion.swift** — semver 2.0 parsing and ordering; unparseable versions never report an update
- **Services/NSImage+PixelSize.swift** — True pixel size of an `NSImage`, not its point size

### Models

- **Models/SavedPreset.swift** — Preset data model; `kind` derives the `WallpaperType` from `isAppearanceBased` / `isDynamic`, and decoding migrates presets written before `isAppearanceBased`
- **Models/TimeVariant.swift** — One image in a schedule: filename, time of day, and its own offset, scale and flip. Formats times for the user's locale
- **Models/DisplayInfo.swift** — Connected display, identified by `CGDirectDisplayID`, carrying its frame and bezel
- **Models/AppSettings.swift** — Persisted settings: `hasCompletedWizard`, `bezelGap`, per-display `bezelWidths`, `bezelPerDisplay`

### Key Implementation Details

- **Cool Dark theme** — All UI uses the `Color.cd*` token system and `CoolDarkButtonStyle` for consistent dark styling
- **Route-based navigation** — `AppNavigation.route` drives the entire app flow; no NavigationStack or NavigationSplitView
- Images are stored with `UUID_original.ext` filenames in the app data directory, which the sandbox puts at `~/Library/Containers/<bundle id>/Data/Library/Application Support/SpreadPaper/`; rendered wallpapers go to `wallpapers/`, dynamic HEICs to `dynamic/<presetId>/`
- Per-display files are keyed on `CGDirectDisplayID`, not the screen name, so identical monitors stay distinct: `spreadpaper_wall_{displayID}_{timestamp}.png` and `{displayID}_{timestamp}.heic`
- Files written before 1.7.1 used screen names; they are deleted only once every connected display has a replacement in place, so the live wallpaper is never removed
- Older files for a display are cleaned up after its new wallpaper is actually set; a fresh timestamp per apply, static and dynamic alike, is what makes macOS reload the image. `WallpaperFilenames.removableDynamicFiles` decides what a preset directory may lose
- Rendering runs in a detached task over `Sendable` specs, HEIC encoding inside it; only screen detection and applying touch the main actor
- Bezel compensation spreads the display frames apart by the physical frame widths, per display or uniform (`AppSettings.bezelGap` as the fallback), so a spanned image lines up across the gaps
- Presets are serialized to `spreadpaper_presets.json` in the app support directory, written atomically; a file that fails to decode is moved to `spreadpaper_presets.json.bak` before the error surfaces, so a later save cannot destroy the only copy
- Dynamic desktops use HEIC with Apple's XMP metadata (`h24` time mode, or the light/dark appearance pair). Per-monitor HEICs share the same time metadata so all screens transition together

### App Sandbox

Entitlements: sandbox enabled, user-selected read-only file access, network client (for update checking). App is not code-signed with a paid Apple Developer ID.

## Release Process

Automated via GitHub Actions with `release-please`:
- Pushes to `main` trigger release-please to create/update release PRs
- On release, the app is archived with `xcodebuild`, ad-hoc signed, and distributed as both DMG and ZIP
- Version is sourced from `.release-please-manifest.json` and synced into the Xcode project's `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`

## Conventions

- Swift 6 language mode (`SWIFT_VERSION = 6.0`) with default `MainActor` isolation and approachable concurrency, so data-race violations are compile errors
- Wallpaper rendering and gallery thumbnails run in detached tasks over `Sendable` specs; HEIC encoding runs inside the detached render task; everything else is main-actor isolated by default
- async/await for asynchronous work (update checker, rendering); no Combine
- SwiftUI with `@Observable` macro for managers, `@State` for local UI state, `UserDefaults` behind `AppSettings` for persisted settings
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) and cover the pure helpers, not the views
- Conventional commits (feat/fix/chore) — release-please generates CHANGELOG.md from these
