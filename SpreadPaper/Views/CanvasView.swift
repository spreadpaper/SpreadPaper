import SwiftUI
import UniformTypeIdentifiers

struct CanvasView: View {
    let selectedImage: NSImage?
    @Binding var imageOffset: CGSize
    @Binding var dragStartOffset: CGSize
    @Binding var isDragging: Bool
    @Binding var imageScale: CGFloat
    let isFlipped: Bool
    let previewScale: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let colorScheme: ColorScheme
    var manager: WallpaperManager
    let onSelectImage: () -> Void
    let onDropImage: ([NSItemProvider]) -> Void

    var body: some View {
        ZStack {
            // A. Image Layer
            ZStack {
                if let img = selectedImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
                        .frame(
                            width: img.size.width * previewScale * imageScale,
                            height: img.size.height * previewScale * imageScale
                        )
                        .offset(imageOffset)
                        .opacity(isDragging ? 0.7 : 1.0)
                        .animation(isDragging ? .none : .spring(response: 0.4, dampingFraction: 0.7), value: imageOffset)
                        .highPriorityGesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    let raw = CGSize(width: dragStartOffset.width + value.translation.width, height: dragStartOffset.height + value.translation.height)
                                    imageOffset = calculateSnapping(raw: raw, imgSize: img.size, canvasSize: manager.totalCanvas.size, previewScale: previewScale, zoomScale: imageScale)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    dragStartOffset = imageOffset
                                }
                        )
                } else {
                    ImageDropZone(
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        onSelect: onSelectImage
                    )
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .clipped()

            // B. Monitor Outlines
            if selectedImage != nil {
                MonitorOverlayView(
                    screens: manager.connectedScreens,
                    totalCanvas: manager.totalCanvas,
                    previewScale: previewScale,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight
                )
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ?
                      Color(white: 0.15).opacity(0.5) :
                      Color(white: 1.0).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: colorScheme == .dark ?
                            [Color.blue.opacity(0.3), Color.purple.opacity(0.2)] :
                            [Color.blue.opacity(0.4), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .shadow(color: colorScheme == .dark ?
                Color.black.opacity(0.3) :
                Color.blue.opacity(0.15),
                radius: 30, x: 0, y: 10)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            onDropImage(providers)
            return true
        }
        .focusable(false)
    }

    private func calculateSnapping(raw: CGSize, imgSize: NSSize, canvasSize: CGSize, previewScale: CGFloat, zoomScale: CGFloat) -> CGSize {
        var newX = raw.width
        var newY = raw.height
        let threshold: CGFloat = 10.0

        let w = imgSize.width * previewScale * zoomScale
        let h = imgSize.height * previewScale * zoomScale
        let cw = canvasSize.width * previewScale
        let ch = canvasSize.height * previewScale

        if abs(newX) < threshold { newX = 0 }
        if abs(newX - (w - cw)/2.0) < threshold { newX = (w - cw)/2.0 }
        if abs(newX - -(w - cw)/2.0) < threshold { newX = -(w - cw)/2.0 }

        if abs(newY) < threshold { newY = 0 }
        if abs(newY - (h - ch)/2.0) < threshold { newY = (h - ch)/2.0 }
        if abs(newY - -(h - ch)/2.0) < threshold { newY = -(h - ch)/2.0 }

        return CGSize(width: newX, height: newY)
    }
}
