// SpreadPaper/Views/MonitorPreviewView.swift

import SwiftUI

/// Draws each display's outline and a solid bezel frame over the image strip the
/// frame hides, and darkens everything the wallpaper will not keep, so the user
/// sees exactly what lands on the panels.
struct MonitorPreviewView: View {
    let screens: [DisplayInfo]
    /// Canvas rectangle in layout points, including bezels.
    let bounds: CGRect
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    /// Opacity of the scrim over the parts of the image no display shows.
    private let clippedDimming: Double = 0.62

    var body: some View {
        let panels = screens.map { normalize(frame: $0.frame) }

        ZStack {
            // Everything outside a panel is cropped away on apply; show that.
            OutsidePanelsShape(canvas: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight), panels: panels)
                .fill(Color.black.opacity(clippedDimming), style: FillStyle(eoFill: true))

            ForEach(screens) { display in
                let panel = normalize(frame: display.frame)
                let outer = normalize(frame: display.frameWithBezel)

                if display.bezel != .zero {
                    BezelFrameShape(outer: outer, inner: panel)
                        .fill(Self.bezelFace, style: FillStyle(eoFill: true))
                    Rectangle()
                        .strokeBorder(Self.edgeHighlight, lineWidth: 1.5)
                        .frame(width: outer.width, height: outer.height)
                        .position(x: outer.midX, y: outer.midY)
                }

                ZStack {
                    Rectangle()
                        .strokeBorder(Self.edgeHighlight, lineWidth: 1)

                    DisplayNameLabel(name: display.name)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(width: panel.width, height: panel.height)
                .position(x: panel.midX, y: panel.midY)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .allowsHitTesting(false)
    }

    /// Face of a monitor frame: dark plastic, so the lit edges carry the shape.
    private static let bezelFace = LinearGradient(
        colors: [Color.cdBgSecondary, Color.cdBgPrimary],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Hairline along a frame's edges, in the accent colours, so a display reads against any photograph.
    private static let edgeHighlight = LinearGradient(
        colors: [Color.cdAppearanceTint, Color.cdAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Maps a layout-point rect (origin bottom-left) into canvas points (origin top-left).
    private func normalize(frame: CGRect) -> CGRect {
        let x = (frame.origin.x - bounds.origin.x) * previewScale
        let y = (bounds.height - (frame.origin.y - bounds.origin.y) - frame.height) * previewScale
        return CGRect(x: x, y: y, width: frame.width * previewScale, height: frame.height * previewScale)
    }
}

/// A display's name on a scrim, so it reads over a bright photograph as well as a dark one.
private struct DisplayNameLabel: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.cd(.caption2, .medium))
            .foregroundStyle(Color.cdTextPrimary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.black.opacity(0.6))
            )
            .overlay(
                Capsule().strokeBorder(Color.cdHighlightStroke, lineWidth: 1)
            )
    }
}

/// The canvas with every panel punched out of it, filled with even-odd.
private struct OutsidePanelsShape: Shape {
    let canvas: CGRect
    let panels: [CGRect]

    /// The canvas and each panel on one path; the even-odd fill leaves only what no panel covers.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(canvas)
        for panel in panels {
            path.addRect(panel)
        }
        return path
    }
}

/// The ring between a display's outer bezel rect and its panel, filled with even-odd.
private struct BezelFrameShape: Shape {
    let outer: CGRect
    let inner: CGRect

    /// Outer and inner rects on one path; the even-odd fill leaves only the ring.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(outer)
        path.addRect(inner)
        return path
    }
}
