// SpreadPaper/Views/MonitorPreviewView.swift

import SwiftUI

/// Draws each display's outline and a solid bezel frame over the image strip the
/// frame hides, so the user sees exactly what lands behind the plastic.
struct MonitorPreviewView: View {
    let screens: [DisplayInfo]
    /// Canvas rectangle in layout points, including bezels.
    let bounds: CGRect
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    var body: some View {
        ZStack {
            ForEach(screens) { display in
                let panel = normalize(frame: display.frame)
                let outer = normalize(frame: display.frameWithBezel)

                if display.bezel != .zero {
                    BezelFrameShape(outer: outer, inner: panel)
                        .fill(Color.cdBgSecondary, style: FillStyle(eoFill: true))
                    Rectangle()
                        .strokeBorder(Color.cdBorderStrong, lineWidth: 1)
                        .frame(width: outer.width, height: outer.height)
                        .position(x: outer.midX, y: outer.midY)
                }

                ZStack {
                    Rectangle()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)

                    Text(display.name)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
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

    /// Maps a layout-point rect (origin bottom-left) into canvas points (origin top-left).
    private func normalize(frame: CGRect) -> CGRect {
        let x = (frame.origin.x - bounds.origin.x) * previewScale
        let y = (bounds.height - (frame.origin.y - bounds.origin.y) - frame.height) * previewScale
        return CGRect(x: x, y: y, width: frame.width * previewScale, height: frame.height * previewScale)
    }
}

/// The ring between a display's outer bezel rect and its panel, filled with even-odd.
private struct BezelFrameShape: Shape {
    let outer: CGRect
    let inner: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(outer)
        path.addRect(inner)
        return path
    }
}
