import SwiftUI

struct ToolbarView: View {
    @Binding var imageScale: CGFloat
    @Binding var isFlipped: Bool
    let hasImage: Bool
    let canSave: Bool
    let colorScheme: ColorScheme
    let onSelectImage: () -> Void
    let onSave: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 20) {

                // Zoom Group
                HStack(spacing: 12) {
                    Button(action: { imageScale = max(0.1, imageScale - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!hasImage)

                    Slider(value: $imageScale, in: 0.1...5.0)
                        .frame(width: 100)
                        .controlSize(.small)
                        .disabled(!hasImage)

                    Button(action: { imageScale = min(5.0, imageScale + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!hasImage)
                }

                Divider().frame(height: 20).opacity(0.3)

                // Flip
                Toggle(isOn: $isFlipped.animation()) {
                    Label("Flip", systemImage: "arrow.left.and.right")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .disabled(!hasImage)

                Divider().frame(height: 20).opacity(0.3)

                // Actions
                Button(action: onSelectImage) {
                    Label("Open", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(action: onSave) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(!canSave)

                Button(action: onApply) {
                    Label("Apply Wallpaper", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasImage)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 20, x: 0, y: 8)
            .padding(.bottom, 40)
        }
    }
}
