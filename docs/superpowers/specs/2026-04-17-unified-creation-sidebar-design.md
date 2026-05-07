# Unified Wallpaper Creation Sidebar — Design

**Date:** 2026-04-17
**Status:** Approved, implementation starting

## Goal

Unify the three wallpaper types (Static, Themed, Dynamic) behind a single sidebar UI with a three-way toggle, so users can switch between types mid-edit without losing their work. Also: preserve original image filenames in thumbnail labels, and prevent the sidebar from growing as filenames get long.

## UX Flow

**Entry:** "+ New" in Gallery opens the existing `CreationModal`, stripped down:
- Title, 3-way segmented toggle (Static · Themed · Dynamic, default Static), live description, "Start" CTA.
- No icon rows.

**Editor sidebar:** Same toggle at top. Switching it reshapes the sidebar live:
- Static → 1-slot uploader
- Themed → Light/Dark stacked slots (drag-to-swap)
- Dynamic → schedule list (existing)

**Type-switch handling:** Preserve + adapt. When a switch discards images, a toast ("Removed N images") appears on the editor for ~2s.

## Components

**New:**
- `WallpaperTypeToggle` — 3-way segmented toggle + description subtitle. Used in modal and sidebar.
- `ToastView` — transient top-anchored overlay on the editor, auto-dismisses.

**Modified:**
- `CreationModal` — simplified to {title, toggle, description, Start}.
- `EditorView.wallpaperType` becomes `@State`; gains `switchType(to:)` handler.

**Sidebar sections (per type):**
- Static: single image row (shared row component).
- Themed: existing `appearanceSection`, cards draggable for swap.
- Dynamic: existing `ScheduleView`.

**Shared row component** for thumbnails — fixed width for the text area, filename uses `.lineLimit(1) + .truncationMode(.middle)` so the sidebar width never grows.

## On-disk filenames

**New files:** `{UUID}_{sanitized-original}.{ext}`
- Sanitize: replace `/`, `\`, null chars with `-`; cap original portion at 80 chars.
- Legacy files (pre-change): `{UUID}.{ext}` stay as-is. No migration.

**Resolution:** `displayFilename(for storedFilename:)` strips the extension, splits on the first `_`, returns the trailing portion. If there's no `_`, returns the base (legacy UUID).

**Save path:** `WallpaperManager.savePreset` + `saveDynamicPreset` build the new format. Models unchanged.

## Drag-to-swap (Themed)

Light and Dark cards use `.draggable(VariantDragID)` + `.dropDestination(for: VariantDragID.self)` — same pattern as `ScheduleView`. On drop, swap `(hour, minute)` so the Light/Dark roles flip.

## Type-switch table

| From → To      | Action                                             | Toast                |
|----------------|----------------------------------------------------|----------------------|
| Static→Themed  | Keep image as Light; empty Dark slot               | —                    |
| Static→Dynamic | Keep image as first time slot (hour=7)             | —                    |
| Themed→Static  | Keep Light, drop Dark                              | "Removed 1 image"    |
| Themed→Dynamic | Both become time slots (Light=12:00, Dark=0:00)    | —                    |
| Dynamic→Themed | Keep first 2 variants, retag Light/Dark by index   | "Removed N images" (if N>0) |
| Dynamic→Static | Keep variants[0] image only                        | "Removed N images" (if N>0) |

## Out of scope

- Undo for lossy switches — the toast is the mitigation.
- Editing filenames inline — existing Name field covers this.
- Backfill migration for legacy UUID-only filenames.
