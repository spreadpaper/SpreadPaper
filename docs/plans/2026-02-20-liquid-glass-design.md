# Liquid Glass Adoption Design

**Date:** 2026-02-20
**Approach:** Conditional `@available(macOS 26, *)` checks with macOS 15 fallback

## Goal

Adopt Liquid Glass UI on macOS 26 while maintaining macOS 15 as minimum deployment target.

## Elements

| Element | Current | Glass (macOS 26) | Fallback (macOS 15) |
|---------|---------|-------------------|---------------------|
| Floating toolbar | `.ultraThinMaterial` in Capsule | `.glassEffect(.regular, in: Capsule())` | `.ultraThinMaterial` in Capsule |
| Monitor labels | `.ultraThinMaterial` Capsule | `.glassEffect(.regular, in: Capsule())` | `.ultraThinMaterial` Capsule |
| Sidebar | Manual `.ultraThinMaterial` | System automatic glass | `.ultraThinMaterial` |

Canvas container and image drop zone are NOT glassed (content layer, not navigation).

## Implementation

Single helper file with conditional view extensions. Each UI element replaces its material with the adaptive glass modifier.

## Files

- Create: `SpreadPaper/Helpers/GlassModifiers.swift`
- Modify: `SpreadPaper/Views/ToolbarView.swift`
- Modify: `SpreadPaper/Views/MonitorOverlayView.swift`
- Modify: `SpreadPaper/Views/SidebarView.swift`
