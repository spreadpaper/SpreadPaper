import SwiftUI

struct TimelineView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedVariantIndex: Int
    @Binding var scrubberTime: Double

    let thumbnails: [NSImage]
    let onAddImages: () -> Void
    let onRemoveVariant: (Int) -> Void

    /// Variants and thumbnails sorted by time, with original indices preserved
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

                // Thumbnail strip — sorted by time
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sortedEntries, id: \.variant.id) { entry in
                            VariantThumbnail(
                                variant: $variants[entry.originalIndex],
                                thumbnail: entry.thumbnail,
                                isSelected: entry.originalIndex == selectedVariantIndex,
                                onSelect: {
                                    selectedVariantIndex = entry.originalIndex
                                    scrubberTime = Double(entry.variant.hour) + Double(entry.variant.minute) / 60.0
                                },
                                onRemove: { onRemoveVariant(entry.originalIndex) }
                            )
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

// MARK: - Per-variant thumbnail with inline time editing

private struct VariantThumbnail: View {
    @Binding var variant: TimeVariant
    let thumbnail: NSImage?
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    @State private var showingTimePicker = false
    @State private var editingHour: Int = 0
    @State private var editingMinute: Int = 0

    var body: some View {
        VStack(spacing: 3) {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }

            // Time label — click to edit
            Button {
                editingHour = variant.hour
                editingMinute = variant.minute
                showingTimePicker = true
            } label: {
                HStack(spacing: 2) {
                    Text(variant.timeString)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6))
                }
                .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingTimePicker, arrowEdge: .bottom) {
                timePickerContent
            }
        }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Set Time...") {
                editingHour = variant.hour
                editingMinute = variant.minute
                showingTimePicker = true
            }
            Button("Remove", role: .destructive) { onRemove() }
        }
    }

    private var timePickerContent: some View {
        VStack(spacing: 8) {
            Text("Set Time")
                .font(.system(size: 11, weight: .semibold))

            HStack(spacing: 4) {
                Picker("Hour", selection: $editingHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%d", h == 0 ? 12 : (h > 12 ? h - 12 : h)))
                            .tag(h)
                    }
                }
                .labelsHidden()
                .frame(width: 50)

                Text(":")
                    .font(.system(size: 13, weight: .medium))

                Picker("Minute", selection: $editingMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 50)

                Text(editingHour < 12 ? "AM" : "PM")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            Button("Done") {
                variant.hour = editingHour
                variant.minute = editingMinute
                showingTimePicker = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
    }
}
