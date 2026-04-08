import SwiftUI

struct TimelineView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedVariantIndex: Int
    @Binding var scrubberTime: Double

    let thumbnails: [NSImage]
    let onAddImages: () -> Void
    let onRemoveVariant: (Int) -> Void

    /// Variants sorted by time, preserving original indices
    private var sortedEntries: [(originalIndex: Int, variant: TimeVariant, thumbnail: NSImage?)] {
        variants.indices.map { i in
            (originalIndex: i,
             variant: variants[i],
             thumbnail: i < thumbnails.count ? thumbnails[i] : nil)
        }
        .sorted { $0.variant.dayFraction < $1.variant.dayFraction }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 10) {
                HStack {
                    Text("Timeline")
                        .font(.system(size: 12, weight: .semibold))
                    Text("(\(variants.count)/16)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sortedEntries, id: \.variant.id) { entry in
                            VStack(spacing: 3) {
                                if let thumb = entry.thumbnail {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(entry.originalIndex == selectedVariantIndex ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                }
                                Text(entry.variant.timeString)
                                    .font(.system(size: 10, weight: entry.originalIndex == selectedVariantIndex ? .semibold : .regular))
                                    .foregroundStyle(entry.originalIndex == selectedVariantIndex ? .primary : .secondary)
                            }
                            .onTapGesture {
                                selectedVariantIndex = entry.originalIndex
                                scrubberTime = Double(entry.variant.hour) + Double(entry.variant.minute) / 60.0
                            }
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    onRemoveVariant(entry.originalIndex)
                                }
                            }
                        }

                        if variants.count < 16 {
                            Button(action: onAddImages) {
                                VStack(spacing: 3) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 80, height: 50)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .foregroundStyle(.secondary)
                                        }
                                    Text("Add")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}
