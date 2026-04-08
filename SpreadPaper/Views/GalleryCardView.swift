// SpreadPaper/Views/GalleryCardView.swift

import SwiftUI

struct GalleryCardView: View {
    let preset: SavedPreset
    let thumbnail: NSImage?
    let isActive: Bool
    let onTap: () -> Void
    let onApply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Image — cover fill, no aspect distortion
                if let thumbnail {
                    GeometryReader { geo in
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    Color.cdBgElevated
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.cdTextTertiary)
                        }
                }

                // Gradient overlay with info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(preset.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        if isActive {
                            Circle()
                                .fill(Color.cdSuccess)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(typeLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                )
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.cdAccent : Color.cdBorder, lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: isActive ? Color.cdAccentGlow : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Apply") { onApply() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var typeLabel: String {
        let type = preset.wallpaperType
        if type == "Dynamic" {
            return "☀ Dynamic · \(preset.timeVariants.count) images"
        } else if type == "Light/Dark" {
            return "◐ Light / Dark"
        }
        return "🖼 Static"
    }
}
