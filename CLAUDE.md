# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpreadPaper is a native macOS app (Swift 6 / SwiftUI) that spreads images across multiple monitors as wallpaper: one static image, a Light & Dark pair, or a time-of-day schedule. Requires macOS 15.0+ (Sequoia) and Apple Silicon. The marketing site lives in its own repository, [spreadpaper/website](https://github.com/spreadpaper/website).

## Build & Run

**macOS App (Xcode):**
```bash
open SpreadPaper.xcodeproj    # Open in Xcode, then Cmd+R to build/run
xcodebuild -scheme SpreadPaper -configuration Debug build       # CLI build
xcodebuild test -scheme SpreadPaper -destination 'platform=macOS'   # Swift Testing suites in SpreadPaperTests/
```

**App icon:** `design/make-icon.swift` renders `design/app-icon-source.png` into every size in `SpreadPaper/Assets.xcassets/AppIcon.appiconset/`.

## Architecture

Source files organized under `SpreadPaper/`. One external package: PhosphorSwift (icons), resolved by Xcode from `https://github.com/phosphor-icons/swift`.

### App

- **App/SpreadPaperApp.swift** — App entry point. ZStack with route-based main content and CreationModal overlay. Forces dark appearance, hidden title bar, wizard on first launch, `Settings` scene. Checks for updates two seconds after launch.

### Theme (Cool Dark design system)

- **Theme/CoolDarkTheme.swift** — Color tokens (`Color.cd*` extensions), `CoolDarkButtonStyle`, `SectionHeader`, and `CoolDarkMetrics`, the dialog, field and type sizes every control is cut to
- **Theme/CoolDarkComponents.swift** — Reusable styled components: `CoolDarkTextField`, `ToastView`, the `.toast(_:)` modifier that floats and clears one, `Image.cdIcon(_:size:)`, which tints every Phosphor glyph by template rendering, and `HoverReader`, which owns the pointer state a `ButtonStyle` cannot hold
- **Theme/CoolDarkTimeField.swift** — `CoolDarkTimeField`, the row of short menus one wall-clock time is set from, and `TimeFieldMath`, the minutes-since-midnight arithmetic behind it (pure, unit-tested). The menus bridge to `NSPopUpButton` so the digits keep the size the theme gives them
- **Theme/ClockSettings.swift** — `.followsClockSettings()`, which hands the system locale down the view tree and hands it down again when the user changes their region or their 24-Hour Time setting, so written times follow System Settings without a relaunch

### Navigation

- **Navigation/AppNavigation.swift** — `@Observable` navigation model with `AppRoute` enum (wizard/gallery/editor/editorNew), `WallpaperType` enum (owns each kind's title, subtitle, SF Symbol and tint), `GalleryFilter` enum, and the pending image URLs handed to a new editor

### Views

- **Views/WizardView.swift** — 2-step first-run wizard: display count, then an image picker that also accepts drops. One image opens a static editor, several open a dynamic one
- **Views/GalleryView.swift** — Home screen: sidebar filters, search, preset grid, error banner, New Wallpaper button, rename alert and delete confirmation
- **Views/GalleryCardView.swift** — Preset card with thumbnail, type badge and a Rename / Duplicate / Show in Finder / Delete menu
- **Views/CreationModal.swift** — Overlay modal picking the wallpaper type (Static / Light & Dark / Dynamic) before a new preset, with an animated monitor hero, a photo credit, a time readout for the Dynamic schedule and arrow-key navigation
- **Views/EditorView.swift** — Full editor: header, canvas with a floating zoom/fit/flip HUD, and an inspector with type, images, zoom and orientation sections, plus a displays section for bezels that appears only with two or more displays
- **Views/EditorCanvasView.swift** — Monitor canvas rendering with image overlay, drag, zoom, snap and image drops
- **Views/MonitorPreviewView.swift** — Individual monitor outline for the canvas
- **Views/SpreadPhoto.swift** — `PanelSlice`, `SpreadContent` and `SpreadPhoto`: one scene laid out across several illustration panels, each panel clipped to its own part of it. Used by the creation modal hero and the wizard. Also `HeroPhoto`, the two bundled photographs with their attribution, `HeroCrossfade` (pure, unit-tested), the day-to-night loop the Light & Dark hero reads off the wall clock, `HeroDayPhoto` and `HeroDayCycle` (pure, unit-tested), the four photographs the Dynamic hero runs through a day with the hour each stands for, and `HeroClock`, the one instant both loops are read from
- **Views/ScheduleView.swift** — `ScheduleDetailModal`, opened from an editor schedule row: the image it schedules, its name, and the time it starts, set from an hour menu, a minute menu and, where the locale names one, a menu for the half of the day, with the following image named in a sentence beside them. Also `ScheduleEntryText` (pure, unit-tested)
- **Views/SaveDialog.swift** — Overlay that names a preset before Save or Save & Apply
- **Views/SettingsView.swift** — Native Settings window with General (default display gap, plus the import row while an earlier version's wallpapers are waiting and the remove row once they are in) and Updates tabs
- **Views/LegacyImport.swift** — Gallery banner offering to bring in wallpapers an earlier version saved, plus the folder picker both it and Settings run

### Services

- **Services/WallpaperManager.swift** — `@Observable` class: screen detection, preset persistence, render orchestration and wallpaper application for all three kinds. Applies are serialized behind `isApplying`
- **Services/WallpaperRenderer.swift** — Pure, `nonisolated` CGContext rendering of one `RenderSpec` (a `Sendable` placement) plus PNG encoding
- **Services/DynamicWallpaperGenerator.swift** — HEIC dynamic desktop file generation with Apple XMP metadata, time-based and appearance-based (based on wallpapper's reverse engineering)
- **Services/ThumbnailRenderer.swift** — ImageIO downsampling for gallery thumbnails, safe off the main actor
- **Services/GalleryLoading.swift** — The gallery's thumbnail run, with no view of its own. `renderThumbnails` reports one event per job as it goes, `ThumbnailRun.consume` applies each one and gives up on a run that stops moving, and `GalleryLoading` holds the idle wait, the phase rules, the per-card pending rule and the log lines. Pure and unit-tested
- **Services/PresetStore.swift** — Reads and writes the presets JSON, backs up a corrupt file, flags legacy files needing a migration rewrite
- **Services/LegacyDataMigration.swift** — Detects a library left by an unsandboxed build, copies a user-chosen folder into the app's own, and moves it to the Trash on request
- **Services/DisplayLayout.swift** — `Bezel` struct and the frame spacing that pushes displays apart by the bezels between them
- **Services/WallpaperFilenames.swift** — Names of the rendered per-display files, the display ID a name is keyed on, the tests for pre-1.7.1 legacy names, and the folders under `dynamic/` no preset claims any more
- **Services/FilenameUtils.swift** — Stored image filenames (`UUID_original.ext`) and the display name read back out
- **Services/ImageFileFilter.swift** — Keeps only local image file URLs from a drop
- **Services/UpdateChecker.swift** — Fetches the latest GitHub release, compares versions, parses CHANGELOG.md for the version and date of each release header, read at the release tag and falling back to `main`. Note bodies are never read, so the Updates tab lists versions and links out to GitHub. Non-2xx replies become a `GitHubStatusError` with plain UI copy
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
- A fresh timestamp per apply, static and dynamic alike, is what makes macOS reload the image, and macOS stores a wallpaper path per Space, so each display keeps its newest `WallpaperFilenames.retainedRendersPerDisplay` renders rather than only the one just written. `WallpaperFilenames.removableStaticFiles` and `removableDynamicFiles` decide what the wallpapers directory and a preset directory may lose. Renders keyed on a display that is no longer connected are collected there too, on the same clean-apply gate the legacy names use, so a partial failure never triggers the sweep
- Deleting a preset takes its `dynamic/<presetId>/` folder with it, and a folder left by a preset that is already gone is collected at launch, once the presets file has been read without error
- Rendering runs in a detached task over `Sendable` specs, HEIC encoding inside it; only screen detection and applying touch the main actor
- Bezel compensation spreads the display frames apart by the physical frame widths, per display or uniform (`AppSettings.bezelGap` as the fallback), so a spanned image lines up across the gaps
- Presets are serialized to `spreadpaper_presets.json` in the app support directory, written atomically; a file that fails to decode is moved to `spreadpaper_presets.json.bak` before the error surfaces, so a later save cannot destroy the only copy
- Dynamic desktops use HEIC with Apple's XMP metadata (`h24` time mode, or the light/dark appearance pair). Per-monitor HEICs share the same time metadata so all screens transition together

### App Sandbox

Entitlements: sandbox enabled, user-selected read-write file access, network client (for update checking). App is not code-signed with a paid Apple Developer ID.

A sandboxed build cannot list `~/Library/Application Support/SpreadPaper`, where unsandboxed builds kept their data: `fileExists` succeeds on it, `contentsOfDirectory` fails with `NSCocoaErrorDomain` 257. The user therefore picks that folder in an `NSOpenPanel`, which is what grants access, and `LegacyDataMigration` copies it in. Read-write is what lets the same picked folder be moved to the Trash afterwards.

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
- A file under `Views/` declares a view. A helper with a file to itself and nothing to draw belongs under `Services/`; a helper small enough to read beside the one view that uses it stays in that view's file, as `HeroCrossfade` and `ScheduleEntryText` do
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) and cover the pure helpers, not the views
- Conventional commits (feat/fix/chore) — release-please generates CHANGELOG.md from these
