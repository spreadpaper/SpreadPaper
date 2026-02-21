import SwiftUI

private let monitorCornerRadius: CGFloat = 8
private let monitorStrokeWidth: CGFloat = 2.5

struct MonitorOverlayView: View {
    let screens: [DisplayInfo]
    let totalCanvas: CGRect
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    var body: some View {
        ZStack {
            ForEach(screens) { display in
                let norm = normalize(frame: display.frame, total: totalCanvas, scale: previewScale)
                ZStack {
                    RoundedRectangle(cornerRadius: monitorCornerRadius)
                        .strokeBorder(.clear, lineWidth: monitorStrokeWidth)

                    Text(display.screen.localizedName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .adaptiveGlass(in: Capsule())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(width: norm.width, height: norm.height)
                .position(x: norm.midX, y: norm.midY)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .allowsHitTesting(false)
    }

    private func normalize(frame: CGRect, total: CGRect, scale: CGFloat) -> CGRect {
        let x = (frame.origin.x - total.origin.x) * scale
        let y = (total.height - (frame.origin.y - total.origin.y) - frame.height) * scale
        return CGRect(x: x, y: y, width: frame.width * scale, height: frame.height * scale)
    }
}

struct MonitorMaskView: View {
    let screens: [DisplayInfo]
    let totalCanvas: CGRect
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    var body: some View {
        ZStack {
            ForEach(screens) { display in
                let norm = normalize(frame: display.frame, total: totalCanvas, scale: previewScale)
                RoundedRectangle(cornerRadius: monitorCornerRadius)
                    .fill(.white)
                    .padding(monitorStrokeWidth / 2)
                    .frame(width: norm.width, height: norm.height)
                    .position(x: norm.midX, y: norm.midY)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    private func normalize(frame: CGRect, total: CGRect, scale: CGFloat) -> CGRect {
        let x = (frame.origin.x - total.origin.x) * scale
        let y = (total.height - (frame.origin.y - total.origin.y) - frame.height) * scale
        return CGRect(x: x, y: y, width: frame.width * scale, height: frame.height * scale)
    }
}
