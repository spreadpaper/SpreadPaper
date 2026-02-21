import SwiftUI

struct ImageDropZone: View {
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                VStack(spacing: 4) {
                    Text("Click or Drag Image Here")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Select a file to begin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
        }
        .buttonStyle(.plain)
    }
}
