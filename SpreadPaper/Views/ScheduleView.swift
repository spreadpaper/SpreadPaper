// SpreadPaper/Views/ScheduleView.swift

import SwiftUI

struct ScheduleView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedIndex: Int
    let onAddImage: () -> Void
    let onRemoveVariant: (Int) -> Void

    /// Auto-generated day-phase names
    private let phaseNames = ["Sunrise", "Morning", "Noon", "Afternoon", "Late Afternoon", "Sunset", "Dusk", "Night",
                              "Late Night", "Pre-dawn", "Dawn", "Early Morning", "Mid-morning", "Early Afternoon", "Late Evening", "Midnight"]

    private var sortedIndices: [Int] {
        variants.indices.sorted { variants[$0].dayFraction < variants[$1].dayFraction }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Schedule · \(variants.count) images")

            VStack(spacing: 3) {
                ForEach(sortedIndices, id: \.self) { index in
                    scheduleRow(index: index)
                }
            }

            DashedAddButton(label: "+ Add Image", action: onAddImage)
        }
    }

    private func scheduleRow(index: Int) -> some View {
        let variant = variants[index]
        let isSelected = index == selectedIndex
        let nextVariant = nextVariantAfter(index: index)
        let duration = durationHours(from: variant, to: nextVariant)

        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                // Drag handle
                VStack(spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.cdTextTertiary.opacity(0.3))
                            .frame(width: 8, height: 1.5)
                    }
                }
                .padding(.vertical, 2)

                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cdBgPrimary)
                    .frame(width: 28, height: 18)

                // Name
                Text(phaseNames[safe: index] ?? "Image \(index + 1)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)

                Spacer()

                // Time range
                Text("\(variant.timeString) – \(nextVariant.timeString)")
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.cdAccent : Color.cdTextSecondary)

                // Duration
                Text("\(duration)h")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.cdTextTertiary)
                    .frame(width: 20, alignment: .trailing)
            }

            // Range bar
            RangeBarView(
                startFraction: Binding(
                    get: { variant.dayFraction },
                    set: { newVal in
                        let totalMinutes = Int(newVal * 24 * 60)
                        let snappedMinutes = (totalMinutes / 10) * 10
                        variants[index].hour = snappedMinutes / 60
                        variants[index].minute = snappedMinutes % 60
                    }
                ),
                endFraction: Binding(
                    get: { nextVariant.dayFraction },
                    set: { _ in } // End is derived from next variant
                ),
                isSelected: isSelected
            )
            .frame(height: 12)
            .padding(.leading, 18) // Align with content after drag handle
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.cdBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.cdAccent : Color.cdBorder, lineWidth: isSelected ? 1.5 : 1)
        )
        .onTapGesture { selectedIndex = index }
        .contextMenu {
            Button("Remove", role: .destructive) { onRemoveVariant(index) }
        }
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

// Safe array access
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
