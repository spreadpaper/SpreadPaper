import SwiftUI

struct TimelineView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedVariantIndex: Int
    @Binding var scrubberTime: Double  // 0.0–24.0 (hours)

    let thumbnails: [NSImage]  // Downsampled thumbnails matching variants order
    let onAddImages: () -> Void
    let onRemoveVariant: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Time Variants (\(variants.count) of 16 max)")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(timeLabel(for: scrubberTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Time scrubber
                VStack(spacing: 4) {
                    Slider(value: $scrubberTime, in: 0...24, step: 0.25)
                        .onChange(of: scrubberTime) { _, newValue in
                            if let closest = variants.enumerated().min(by: {
                                abs(Double($0.element.hour) + Double($0.element.minute) / 60.0 - newValue) <
                                abs(Double($1.element.hour) + Double($1.element.minute) / 60.0 - newValue)
                            }) {
                                selectedVariantIndex = closest.offset
                            }
                        }

                    HStack {
                        Text("12 AM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("6 AM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("12 PM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("6 PM").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Spacer()
                        Text("12 AM").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                }

                // Thumbnail strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(zip(variants.indices, variants)), id: \.1.id) { index, variant in
                            VariantThumbnail(
                                variant: $variants[index],
                                thumbnail: index < thumbnails.count ? thumbnails[index] : nil,
                                isSelected: index == selectedVariantIndex,
                                onSelect: {
                                    selectedVariantIndex = index
                                    scrubberTime = Double(variant.hour) + Double(variant.minute) / 60.0
                                },
                                onRemove: { onRemoveVariant(index) }
                            )
                        }

                        if variants.count < 16 {
                            Button(action: onAddImages) {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 72, height: 44)
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
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private func timeLabel(for hours: Double) -> String {
        let h = Int(hours) % 24
        let m = Int((hours.truncatingRemainder(dividingBy: 1)) * 60)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = h
        components.minute = m
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Per-variant thumbnail with time editing popover

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
        VStack(spacing: 4) {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }

            // Clickable time label — opens time editor
            Button {
                editingHour = variant.hour
                editingMinute = variant.minute
                showingTimePicker = true
            } label: {
                Text(variant.timeString)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .underline(isSelected)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingTimePicker, arrowEdge: .bottom) {
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
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Set Time...") {
                editingHour = variant.hour
                editingMinute = variant.minute
                showingTimePicker = true
            }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        }
    }
}
