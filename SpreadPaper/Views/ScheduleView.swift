// SpreadPaper/Views/ScheduleView.swift

import SwiftUI
import PhosphorSwift

// MARK: - Centered Detail Modal

/// Centered sheet for renaming a variant and dragging its start time on a range bar.
struct ScheduleDetailModal: View {
    @Binding var variant: TimeVariant
    let defaultName: String
    let nextVariant: TimeVariant
    let onRemove: () -> Void
    let onDone: () -> Void

    /// Hours marked under the range bar, midnight to midnight.
    private static let axisHours = [0, 6, 12, 18, 24]

    var body: some View {
        ZStack {
            Color.cdOverlayScrim
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
                            .cdIcon(Color.cdDanger, size: 14)
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
                                .cdIcon(Color.cdTextTertiary, size: 14)
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
                                    let minutes = RangeBarMath.minutes(for: newVal)
                                    variant.hour = minutes / 60
                                    variant.minute = minutes % 60
                                }
                            ),
                            endFraction: nextVariant.dayFraction,
                            isSelected: true
                        )
                        .frame(height: 24)

                        HStack {
                            ForEach(Array(Self.axisHours.enumerated()), id: \.offset) { index, hour in
                                if index > 0 { Spacer() }
                                Text(TimeVariant.hourString(hour: hour))
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.cdTextTertiary)
                            }
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
            .shadow(color: .cdShadow, radius: 20)
        }
    }
}

