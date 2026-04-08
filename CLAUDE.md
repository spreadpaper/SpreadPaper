# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpreadPaper is a native macOS app (Swift 6 / SwiftUI) that spreads a single high-resolution image across multiple monitors as wallpaper. Requires macOS 15.0+ (Sequoia) and Apple Silicon. The repo also contains a Vite + Tailwind CSS marketing website.

## Build & Run

**macOS App (Xcode):**
```bash
open SpreadPaper.xcodeproj    # Open in Xcode, then Cmd+R to build/run
xcodebuild -scheme SpreadPaper -configuration Debug build   # CLI build
```

**Website:**
```bash
npm ci
npm run dev      # Local dev server
npm run build    # Production build to dist/
```

## Architecture

Source files organized under `SpreadPaper/`:

- **App/SpreadPaperApp.swift** — App entry point, integrates UpdateChecker on launch
- **Views/ContentView.swift** — Main NavigationSplitView layout, routes between static and dynamic editors
- **Views/SidebarView.swift** — Preset list with static/dynamic badges
- **Views/CanvasView.swift** — Monitor canvas with image overlay, drag, zoom, snap
- **Views/DynamicEditorView.swift** — Detail pane for dynamic presets (wraps CanvasView + TimelineView)
- **Views/TimelineView.swift** — Time scrubber slider and image thumbnail strip
- **Views/MonitorOverlayView.swift** — Monitor outlines and mask for canvas
- **Views/ImageDropZone.swift** — Drag-and-drop / click-to-open target
- **Views/SettingsView.swift** — Settings window with appearance and update tabs
- **Services/WallpaperManager.swift** — `@Observable` class: screen detection, CGContext rendering, wallpaper application, preset persistence, dynamic wallpaper HEIC generation
- **Services/DynamicWallpaperGenerator.swift** — HEIC dynamic desktop file generation with Apple XMP metadata (based on wallpapper's reverse engineering)
- **Services/UpdateChecker.swift** — Fetches latest GitHub release, parses CHANGELOG.md for version history
- **Models/SavedPreset.swift** — Preset data model (supports both static and dynamic presets)
- **Models/TimeVariant.swift** — Time-of-day image variant for dynamic presets
- **Models/DisplayInfo.swift** — Connected display info
- **Models/AppSettings.swift** — Persisted app settings
- **Helpers/WindowAccessor.swift**, **WindowDragHandler.swift**, **GlassModifiers.swift** — Window utilities

### Key Implementation Details

- Images are stored in `~/Library/Application Support/SpreadPaper/` with UUID filenames
- Per-screen wallpapers saved as `spreadpaper_wall_{screenName}_{timestamp}.png`
- Old wallpapers are auto-cleaned on reapplication
- Multi-monitor rendering uses CGContext with coordinate transforms to handle scaling, offsets, and image flipping across displays
- Dynamic desktop wallpapers use HEIC files with Apple's XMP metadata (time-based h24 mode). Per-monitor HEIC files are generated with synchronized time metadata so all screens transition together. Format based on wallpapper's reverse engineering.
- Presets serialized to `spreadpaper_presets.json` in the app support directory (supports both static and dynamic presets via `isDynamic` flag)

### App Sandbox

Entitlements: sandbox enabled, user-selected read-only file access, network client (for update checking). App is not code-signed with a paid Apple Developer ID.

## Release Process

Automated via GitHub Actions with `release-please`:
- Pushes to `main` trigger release-please to create/update release PRs
- On release, the app is archived with `xcodebuild`, ad-hoc signed, and distributed as both DMG and ZIP
- Version is sourced from `.release-please-manifest.json` and synced into the Xcode project's `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`

## Conventions

- Swift 6 strict concurrency
- SwiftUI with `@Observable` macro for managers, `@State` for local UI state, `@AppStorage` for persisted settings
- Combine for async operations (update checker)
- Conventional commits (feat/fix/chore) — release-please generates CHANGELOG.md from these

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
