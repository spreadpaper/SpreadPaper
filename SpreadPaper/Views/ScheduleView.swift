// SpreadPaper/Views/ScheduleView.swift

import SwiftUI

struct ScheduleView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedIndex: Int
    let onAddImage: () -> Void
    let onRemoveVariant: (Int) -> Void

    @State private var editingIndex: Int? = nil

    private let phaseNames = ["Sunrise", "Morning", "Noon", "Afternoon", "Late Afternoon", "Sunset", "Dusk", "Night",
                              "Late Night", "Pre-dawn", "Dawn", "Early Morning", "Mid-morning", "Early Afternoon", "Late Evening", "Midnight"]

    private var sortedIndices: [Int] {
        variants.indices.sorted { variants[$0].dayFraction < variants[$1].dayFraction }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Schedule · \(variants.count) images")

            // Simple reorderable list
            VStack(spacing: 3) {
                ForEach(sortedIndices, id: \.self) { index in
                    compactRow(index: index)
                }
            }

            Button(action: onAddImage) {
                HStack {
                    Spacer()
                    Text("+ Add Image")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cdTextTertiary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(Color.cdBorder)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sheet(item: editingBinding) { index in
            ScheduleDetailSheet(
                variant: $variants[index],
                name: phaseNames[safe: index] ?? "Image \(index + 1)",
                nextVariant: nextVariantAfter(index: index),
                onRemove: {
                    editingIndex = nil
                    onRemoveVariant(index)
                },
                onDone: { editingIndex = nil }
            )
        }
    }

    /// Compact row — just thumbnail, name, time. Click to edit.
    private func compactRow(index: Int) -> some View {
        let variant = variants[index]
        let isSelected = index == selectedIndex
        let nextVariant = nextVariantAfter(index: index)
        let duration = durationHours(from: variant, to: nextVariant)

        return Button(action: {
            selectedIndex = index
            editingIndex = index
        }) {
            HStack(spacing: 8) {
                // Drag indicator
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.cdTextTertiary.opacity(0.4))

                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cdBgPrimary)
                    .frame(width: 32, height: 20)

                // Name
                Text(phaseNames[safe: index] ?? "Image \(index + 1)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cdTextPrimary)

                Spacer()

                // Time range
                Text("\(variant.timeString) – \(nextVariant.timeString)")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.cdAccent : Color.cdTextSecondary)

                // Duration
                Text("\(duration)h")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.cdTextTertiary)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.cdTextTertiary.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cdAccent : Color.cdBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit...") {
                selectedIndex = index
                editingIndex = index
            }
            Button("Remove", role: .destructive) { onRemoveVariant(index) }
        }
    }

    private var editingBinding: Binding<Int?> {
        Binding(
            get: { editingIndex },
            set: { editingIndex = $0 }
        )
    }

    private func nextVariantAfter(index: Int) -> TimeVariant {
        let sorted = sortedIndices
        guard let pos = sorted.firstIndex(of: index) else { return variants[index] }
        let nextPos = (pos + 1) % sorted.count
        return variants[sorted[nextPos]]
    }

    private func durationHours(from: TimeVariant, to: TimeVariant) -> Int {
        var diff = to.dayFraction - from.dayFraction
        if diff <= 0 { diff += 1.0 }
        return max(1, Int((diff * 24).rounded()))
    }
}

// MARK: - Detail Sheet

private struct ScheduleDetailSheet: View {
    @Binding var variant: TimeVariant
    let name: String
    let nextVariant: TimeVariant
    let onRemove: () -> Void
    let onDone: () -> Void

    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Schedule Entry")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.cdTextPrimary)
                Spacer()
                Button("Done") { onDone() }
                    .buttonStyle(CoolDarkButtonStyle(isPrimary: true))
            }
            .padding(20)

            Divider().overlay(Color.cdBorder)

            VStack(alignment: .leading, spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Name")
                    CoolDarkTextField(placeholder: "e.g. Sunrise, Golden Hour", text: $editingName)
                }

                // Time range display
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Active Period")
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("From")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.cdTextTertiary)
                            Text(variant.timeString)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.cdTextPrimary)
                        }
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Color.cdTextTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Until")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.cdTextTertiary)
                            Text(nextVariant.timeString)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.cdTextSecondary)
                        }
                        Spacer()
                    }
                }

                // Range bar — full width, easy to drag
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Drag to Adjust Start Time")

                    RangeBarView(
                        startFraction: Binding(
                            get: { variant.dayFraction },
                            set: { newVal in
                                let totalMinutes = Int(newVal * 24 * 60)
                                let snapped = (totalMinutes / 10) * 10
                                variant.hour = snapped / 60
                                variant.minute = snapped % 60
                            }
                        ),
                        endFraction: .constant(nextVariant.dayFraction),
                        isSelected: true
                    )
                    .frame(height: 20)

                    // Time scale
                    HStack {
                        Text("12 AM").font(.system(size: 8)).foregroundStyle(Color.cdTextTertiary)
                        Spacer()
                        Text("6 AM").font(.system(size: 8)).foregroundStyle(Color.cdTextTertiary)
                        Spacer()
                        Text("12 PM").font(.system(size: 8)).foregroundStyle(Color.cdTextTertiary)
                        Spacer()
                        Text("6 PM").font(.system(size: 8)).foregroundStyle(Color.cdTextTertiary)
                        Spacer()
                        Text("12 AM").font(.system(size: 8)).foregroundStyle(Color.cdTextTertiary)
                    }
                }

                Spacer()

                // Remove button
                Button(action: onRemove) {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Remove from Schedule")
                        Spacer()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdDanger)
                    .padding(.vertical, 8)
                    .background(Color.cdDanger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .frame(width: 400, height: 380)
        .background(Color.cdBgSecondary)
        .onAppear { editingName = name }
    }
}

// MARK: - Int: Identifiable for sheet binding

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
