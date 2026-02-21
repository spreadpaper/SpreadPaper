import SwiftUI

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
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 0)

                    // Monitor Label
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
