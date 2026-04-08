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
                            // Snap to closest variant for preview
                            if let closest = variants.enumerated().min(by: {
                                abs(Double($0.element.hour) + Double($0.element.minute) / 60.0 - newValue) <
                                abs(Double($1.element.hour) + Double($1.element.minute) / 60.0 - newValue)
                            }) {
                                selectedVariantIndex = closest.offset
                            }
                        }

                    // Time markers
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
                            VStack(spacing: 4) {
                                if index < thumbnails.count {
                                    Image(nsImage: thumbnails[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 72, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(index == selectedVariantIndex ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                }
                                Text(variant.timeString)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .onTapGesture {
                                selectedVariantIndex = index
                                scrubberTime = Double(variant.hour) + Double(variant.minute) / 60.0
                            }
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    onRemoveVariant(index)
                                }
                            }
                        }

                        // Add button
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
