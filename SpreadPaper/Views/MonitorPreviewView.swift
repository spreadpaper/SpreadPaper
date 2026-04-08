// SpreadPaper/Views/MonitorPreviewView.swift

import SwiftUI

struct MonitorPreviewView: View {
    let screens: [DisplayInfo]
    let totalCanvas: CGRect
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    var body: some View {
        ZStack {
            ForEach(screens) { display in
                let norm = normalize(frame: display.frame)
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)

                    Text(display.screen.localizedName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(width: norm.width, height: norm.height)
                .position(x: norm.midX, y: norm.midY)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .allowsHitTesting(false)
    }

    private func normalize(frame: CGRect) -> CGRect {
        let x = (frame.origin.x - totalCanvas.origin.x) * previewScale
        let y = (totalCanvas.height - (frame.origin.y - totalCanvas.origin.y) - frame.height) * previewScale
        return CGRect(x: x, y: y, width: frame.width * previewScale, height: frame.height * previewScale)
    }
}
