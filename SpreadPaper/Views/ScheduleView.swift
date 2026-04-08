// SpreadPaper/Views/ScheduleView.swift

import SwiftUI

struct ScheduleView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedIndex: Int
    let onAddImage: () -> Void
    let onRemoveVariant: (Int) -> Void

    private let phaseNames = ["Sunrise", "Morning", "Noon", "Afternoon", "Late Afternoon", "Sunset", "Dusk", "Night",
                              "Late Night", "Pre-dawn", "Dawn", "Early Morning", "Mid-morning", "Early Afternoon", "Late Evening", "Midnight"]

    private var sortedIndices: [Int] {
        variants.indices.sorted { variants[$0].dayFraction < variants[$1].dayFraction }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Schedule · \(variants.count) images")

            // Use ForEach with onMove for drag-to-reorder
            List {
                ForEach(sortedIndices, id: \.self) { index in
                    scheduleRow(index: index)
                        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    reorderVariants(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(minHeight: CGFloat(variants.count) * 58)

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
                    set: { _ in }
                ),
                isSelected: isSelected
            )
            .frame(height: 12)
            .padding(.leading, 18)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.cdBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.cdAccent : Color.cdBorder, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedIndex = index }
        .contextMenu {
            Button("Remove", role: .destructive) { onRemoveVariant(index) }
        }
    }

    private func reorderVariants(from source: IndexSet, to destination: Int) {
        // Map sorted indices back to original array positions
        var sorted = sortedIndices
        sorted.move(fromOffsets: source, toOffset: destination)

        // Redistribute times evenly based on new order
        let dayPhases = [(7,0),(9,0),(12,0),(15,0),(17,0),(19,0),(21,0),(23,0),(1,0),(3,0),(5,0),(6,0),(8,0),(10,0),(14,0),(16,0)]
        for (newPosition, originalIndex) in sorted.enumerated() {
            if newPosition < dayPhases.count {
                variants[originalIndex].hour = dayPhases[newPosition].0
                variants[originalIndex].minute = dayPhases[newPosition].1
            }
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
