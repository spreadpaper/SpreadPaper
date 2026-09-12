// SpreadPaper/Views/RangeBarView.swift

import SwiftUI

/// Value math for the schedule time bar, kept pure so it can be unit tested.
/// Fractions run 0...1 over a day; values snap to ten-minute marks.
/// The last valid mark is 23:50, so a start never lands on 24:00.
nonisolated enum RangeBarMath {
    static let minutesPerDay = 1440
    static let stepMinutes = 10
    static let maxMinutes = minutesPerDay - stepMinutes

    /// Minutes since midnight for a day fraction, snapped to the step and clamped.
    static func minutes(for fraction: Double) -> Int {
        guard fraction.isFinite else { return 0 }
        let steps = (fraction * Double(minutesPerDay) / Double(stepMinutes)).rounded()
        let bounded = min(max(steps, 0), Double(maxMinutes / stepMinutes))
        return Int(bounded) * stepMinutes
    }

    /// Day fraction for a minute count.
    static func fraction(forMinutes minutes: Int) -> Double {
        Double(minutes) / Double(minutesPerDay)
    }

    /// Snapped and clamped day fraction under a pointer x on a track of the given width.
    static func fraction(atX x: CGFloat, trackWidth: CGFloat) -> Double {
        guard trackWidth > 0 else { return 0 }
        return fraction(forMinutes: minutes(for: Double(x / trackWidth)))
    }

    /// Day fraction moved by a number of steps from the given one, clamped.
    static func fraction(_ base: Double, steppedBy steps: Int) -> Double {
        fraction(forMinutes: clamped(minutes(for: base) + steps * stepMinutes))
    }

    /// Minutes pinned to the 0...23:50 range.
    private static func clamped(_ minutes: Int) -> Int {
        min(max(minutes, 0), maxMinutes)
    }
}

/// Schedule time bar: a day-long track with one draggable start handle.
/// The end marker is display-only; the fill wraps past midnight.
struct RangeBarView: View {
    @Binding var startFraction: Double
    var endFraction: Double
    var accentColor: Color = .cdAccent
    var isSelected: Bool = false

    @GestureState private var grabOffset: CGFloat?

    private static let barHeight: CGFloat = 8
    private static let handleWidth: CGFloat = 8
    private static let hitRadius: CGFloat = 12
    private static let ticks: [Double] = [0.25, 0.5, 0.75]
    private static let tickColor = Color.cdHighlightStrokeSoft
    private static let dividerColor = Color.cdTextTertiary.opacity(0.6)
    private static let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened)
    private static let dayStart = Calendar.current.startOfDay(for: .now)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.cdBorder)
                    .frame(height: Self.barHeight)

                ForEach(Self.ticks, id: \.self) { tick in
                    Rectangle()
                        .fill(Self.tickColor)
                        .frame(width: 1, height: Self.barHeight)
                        .offset(x: width * tick)
                }

                activeFill(width: width)

                Rectangle()
                    .fill(Self.dividerColor)
                    .frame(width: 1, height: Self.barHeight + 6)
                    .offset(x: width * endFraction - 0.5)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cdKnob)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isSelected ? accentColor : Color.cdBorder, lineWidth: 1.5)
                    )
                    .frame(width: Self.handleWidth, height: Self.barHeight + 4)
                    .offset(x: width * startFraction - Self.handleWidth / 2)
                    .pointerStyle(.columnResize(directions: .all))
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Start time")
        .accessibilityValue(accessibilityTime)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: startFraction = RangeBarMath.fraction(startFraction, steppedBy: 1)
            case .decrement: startFraction = RangeBarMath.fraction(startFraction, steppedBy: -1)
            @unknown default: break
            }
        }
    }

    /// Accent fill from start to end, split in two when the range crosses midnight.
    @ViewBuilder
    private func activeFill(width: CGFloat) -> some View {
        let color = accentColor.opacity(isSelected ? 0.45 : 0.25)
        if endFraction < startFraction {
            Rectangle()
                .fill(color)
                .frame(width: width * (1 - startFraction), height: Self.barHeight)
                .offset(x: width * startFraction)
            Rectangle()
                .fill(color)
                .frame(width: width * endFraction, height: Self.barHeight)
        } else {
            Rectangle()
                .fill(color)
                .frame(width: width * (endFraction - startFraction), height: Self.barHeight)
                .offset(x: width * startFraction)
        }
    }

    /// Drag that engages only when it begins on the handle and keeps the grab point under the pointer.
    /// The grab offset lives in gesture state so a cancelled drag resets it.
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($grabOffset) { value, state, _ in
                guard state == nil else { return }
                let delta = value.startLocation.x - width * startFraction
                if abs(delta) <= Self.hitRadius { state = delta }
            }
            .onChanged { value in
                guard let grabOffset else { return }
                startFraction = RangeBarMath.fraction(atX: value.location.x - grabOffset, trackWidth: width)
            }
    }

    /// Spoken start time for VoiceOver.
    private var accessibilityTime: String {
        let minutes = RangeBarMath.minutes(for: startFraction)
        return Self.dayStart.addingTimeInterval(TimeInterval(minutes * 60)).formatted(Self.timeStyle)
    }
}
