// SpreadPaper/Views/ScheduleView.swift

import SwiftUI

struct ScheduleView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedIndex: Int
    @Binding var editingIndex: Int?
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
    }

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
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.cdTextTertiary.opacity(0.4))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cdBgPrimary)
                    .frame(width: 32, height: 20)

                Text(phaseNames[safe: index] ?? "Image \(index + 1)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cdTextPrimary)

                Spacer()

                Text("\(variant.timeString) – \(nextVariant.timeString)")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.cdAccent : Color.cdTextSecondary)

                Text("\(duration)h")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.cdTextTertiary)

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
            Button("Edit...") { selectedIndex = index; editingIndex = index }
            Button("Remove", role: .destructive) { onRemoveVariant(index) }
        }
    }

    func nextVariantAfter(index: Int) -> TimeVariant {
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

// MARK: - Centered Detail Modal

struct ScheduleDetailModal: View {
    @Binding var variant: TimeVariant
    let name: String
    let nextVariant: TimeVariant
    let onRemove: () -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDone() }

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
                    // Active period
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Active Period")
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("From")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.cdTextTertiary)
                                Text(variant.timeString)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.cdTextPrimary)
                            }
                            Image(systemName: "arrow.right")
                                .foregroundStyle(Color.cdTextTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Until")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.cdTextTertiary)
                                Text(nextVariant.timeString)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.cdTextSecondary)
                            }
                            Spacer()
                        }
                    }

                    // Range bar
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
                        .frame(height: 24)

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

                    // Remove
                    Button(action: onRemove) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Remove from Schedule")
                            Spacer()
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cdDanger)
                        .padding(.vertical, 10)
                        .background(Color.cdDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .frame(width: 420, height: 340)
            .background(Color.cdBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 20)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
