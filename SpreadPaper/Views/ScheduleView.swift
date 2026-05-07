// SpreadPaper/Views/ScheduleView.swift

import SwiftUI
import AppKit
import CoreTransferable
import UniformTypeIdentifiers
import PhosphorSwift

struct VariantDragID: Codable, Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct ScheduleView: View {
    @Binding var variants: [TimeVariant]
    @Binding var selectedIndex: Int
    @Binding var editingIndex: Int?
    var loadedImages: [NSImage] = []
    let onAddImage: () -> Void
    let onRemoveVariant: (Int) -> Void

    @State private var dropTargetIndex: Int? = nil

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

            DashedAddButton(label: "+ Add Image", action: onAddImage)
        }
    }

    private func compactRow(index: Int) -> some View {
        let variant = variants[index]
        let isSelected = index == selectedIndex
        let isDropTarget = dropTargetIndex == index
        let nextVariant = nextVariantAfter(index: index)

        return HStack(spacing: 10) {
            Ph.dotsSixVertical.regular
                .color(Color.cdTextTertiary)
                .frame(width: 12, height: 16)

            Group {
                if index < loadedImages.count {
                    Image(nsImage: loadedImages[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.cdBgPrimary
                }
            }
            .frame(width: 40, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: index))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(variant.timeString) – \(nextVariant.timeString)")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.cdAccent : Color.cdTextTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 140, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: {
                selectedIndex = index
                editingIndex = index
            }) {
                Ph.pencilSimple.regular
                    .color(Color.cdTextSecondary)
                    .frame(width: 14, height: 14)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit schedule entry")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isDropTarget ? Color.cdAccent.opacity(0.15) : Color.cdBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isDropTarget ? Color.cdAccent : (isSelected ? Color.cdAccent : Color.cdBorder),
                    style: StrokeStyle(
                        lineWidth: isDropTarget ? 2 : (isSelected ? 1.5 : 1),
                        dash: isDropTarget ? [5, 3] : []
                    )
                )
        )
        .animation(.easeInOut(duration: 0.1), value: isDropTarget)
        .contentShape(Rectangle())
        .onTapGesture { selectedIndex = index }
        .draggable(VariantDragID(id: variant.id))
        .dropDestination(for: VariantDragID.self) { items, _ in
            dropTargetIndex = nil
            guard let dragged = items.first,
                  let srcIdx = variants.firstIndex(where: { $0.id == dragged.id }),
                  srcIdx != index else { return false }
            let srcHour = variants[srcIdx].hour
            let srcMinute = variants[srcIdx].minute
            variants[srcIdx].hour = variants[index].hour
            variants[srcIdx].minute = variants[index].minute
            variants[index].hour = srcHour
            variants[index].minute = srcMinute
            selectedIndex = srcIdx
            return true
        } isTargeted: { targeted in
            dropTargetIndex = targeted ? index : (dropTargetIndex == index ? nil : dropTargetIndex)
        }
        .contextMenu {
            Button("Edit...") { selectedIndex = index; editingIndex = index }
            Button("Remove", role: .destructive) { onRemoveVariant(index) }
        }
    }

    func displayName(for index: Int) -> String {
        let variant = variants[index]
        if !variant.name.isEmpty { return variant.name }
        let resolved = FilenameUtils.displayName(for: variant.imageFilename)
        return resolved.isEmpty ? "Image \(index + 1)" : resolved
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
    let defaultName: String
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
                    Button(action: onRemove) {
                        Ph.trash.regular
                            .color(Color.cdDanger)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)

                Divider().overlay(Color.cdBorder)

                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Name")
                        CoolDarkTextField(
                            placeholder: defaultName,
                            text: $variant.name
                        )
                    }

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
                            Ph.arrowRight.regular
                                .color(Color.cdTextTertiary)
                                .frame(width: 14, height: 14)
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
                            isSelected: true,
                            endInteractive: false
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

                    // Done button at bottom
                    Button(action: onDone) {
                        HStack {
                            Spacer()
                            Text("Done")
                            Spacer()
                        }
                    }
                    .buttonStyle(CoolDarkButtonStyle(isPrimary: true))
                }
                .padding(20)
            }
            .frame(width: 420, height: 400)
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

