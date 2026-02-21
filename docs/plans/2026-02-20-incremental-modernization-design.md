# SpreadPaper Incremental Modernization Design

**Date:** 2026-02-20
**Approach:** Incremental modernization — step-by-step refactor keeping the app working at each stage

## Goals

1. Break up the 953-line ContentView.swift monolith into focused, organized files
2. Adopt modern Swift/SwiftUI patterns: `@Observable` macro, async/await
3. Review and improve the rendering pipeline (color space, async rendering, error handling)
4. Clean up UI code by extracting subviews

## File Organization

```
SpreadPaper/
├── App/
│   └── SpreadPaperApp.swift
├── Models/
│   ├── AppSettings.swift             # AppearanceMode enum + AppSettings
│   ├── SavedPreset.swift             # SavedPreset (Identifiable, Codable, Hashable)
│   └── DisplayInfo.swift             # DisplayInfo (Identifiable)
├── Services/
│   ├── WallpaperManager.swift        # Screen detection, rendering, file I/O, presets
│   └── UpdateChecker.swift           # GitHub release checking + changelog parsing
├── Views/
│   ├── ContentView.swift             # Main composition view (~100 lines)
│   ├── CanvasView.swift              # Image canvas with drag/zoom/snapping
│   ├── ToolbarView.swift             # Floating bottom toolbar (zoom, flip, open, save, apply)
│   ├── SidebarView.swift             # Preset list sidebar
│   ├── ImageDropZone.swift           # Empty state "click or drag" prompt
│   ├── MonitorOverlayView.swift      # Monitor outline overlays on canvas
│   ├── SettingsView.swift            # macOS Settings window (General + Updates tabs)
│   └── UpdatePopupView.swift         # Update notification popup
├── Helpers/
│   ├── WindowAccessor.swift          # NSViewRepresentable for window styling
│   └── WindowDragHandler.swift       # NSViewRepresentable for window dragging
└── Assets.xcassets/
```

## @Observable Modernization

Replace `ObservableObject`/`@Published`/`@StateObject` with modern Observation framework:

- `WallpaperManager` -> `@Observable class WallpaperManager`
- `AppSettings` -> `@Observable class AppSettings`
- `UpdateChecker` -> `@Observable class UpdateChecker`
- `@StateObject var manager` -> `@State var manager`
- `@ObservedObject var updateChecker` -> pass directly or use `@Environment`
- Remove all `@Published` property wrappers (automatic with `@Observable`)
- Inject `UpdateChecker` via `@Environment` instead of singleton pattern

## Async/Await Conversion

### UpdateChecker
- `checkForUpdates()` -> `async` function using `try await URLSession.shared.data(for:)`
- `fetchChangelog()` -> `async` function
- Remove `cancellables: Set<AnyCancellable>`
- Callers use `.task {}` modifier or `Task {}`

### WallpaperManager
- Screen change notification: `for await _ in NotificationCenter.default.notifications(named:)` in a task
- Start the notification listener from the view via `.task {}` modifier

## Rendering Pipeline Improvements

### Color space
- Detect screen's native color space via `screen.colorSpace?.cgColorSpace`
- Fall back to sRGB if unavailable
- Renders with better color accuracy on P3/wide-gamut displays

### Async rendering
- Move `renderAndSet` off main thread — heavy CGContext pixel work shouldn't block UI
- Use `Task.detached` or a dedicated actor
- Keep `NSWorkspace.setDesktopImageURL` on main thread (AppKit requirement)

### Error handling
- Surface rendering/wallpaper-setting failures to the UI instead of silent `return`/`print`
- Add an `error` published property or throw from `setWallpaper`

## UI Cleanup

- Extract long `body` into named subview structs
- Simplify hardcoded gradient colors — use semantic system colors where possible
- Consider `Transferable` protocol for drag-and-drop instead of `NSItemProvider`
- Keep `WindowAccessor` and `WindowDragHandler` as necessary AppKit bridges

## Implementation Order

1. **Step 1:** Extract files — move models, manager, views, helpers to separate files (no behavior changes)
2. **Step 2:** Adopt `@Observable` — convert all 3 classes, update all view bindings
3. **Step 3:** Async/await — convert UpdateChecker networking, convert WallpaperManager notifications
4. **Step 4:** Rendering improvements — color space, async rendering, error propagation
5. **Step 5:** UI cleanup — extract subviews, simplify styling, modernize drag-and-drop

Each step produces a compilable, working app.
