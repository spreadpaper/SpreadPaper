// SpreadPaper/Theme/CoolDarkTimeField.swift

import AppKit
import SwiftUI

// MARK: - Time Field Math

/// Clock work the time menus need, held apart from the view that draws them.
/// Minutes since midnight are the only value it carries, and
/// every result lands inside a day.
nonisolated enum TimeFieldMath {
    /// Minutes a day holds, and the modulus every value wraps through.
    static let minutesPerDay = 1440

    /// Minutes between one entry of the minute menu and the next.
    static let minuteStep = 15

    /// The minute of the day a raw count lands on, midnight either side of it.
    static func wrapped(_ minutes: Int) -> Int {
        let remainder = minutes % minutesPerDay
        return remainder < 0 ? remainder + minutesPerDay : remainder
    }

    /// The locale's writing of a minute count, as a clock shows it.
    static func text(for minutes: Int, locale: Locale = .current) -> String {
        let minute = wrapped(minutes)
        return TimeVariant.clockString(hour: minute / 60, minute: minute % 60, locale: locale)
    }

    /// Whether the locale runs its clock to twelve, so the day needs a half naming.
    static func namesHalfOfDay(_ locale: Locale) -> Bool {
        TimeVariant.namesHalfOfDay(locale)
    }

    /// Hours the hour menu offers, as hours of a day. A clock running to twelve
    /// offers a morning's worth and leaves the half to its own menu.
    static func hourOptions(namingHalf: Bool) -> [Int] {
        Array(0..<(namingHalf ? 12 : 24))
    }

    /// The hour menu entry a time sits on.
    static func hourOption(of minutes: Int, namingHalf: Bool) -> Int {
        let hour = wrapped(minutes) / 60
        return namingHalf ? hour % 12 : hour
    }

    /// Whether a time falls in the second half of the day.
    static func isAfternoon(_ minutes: Int) -> Bool {
        wrapped(minutes) >= minutesPerDay / 2
    }

    /// Minutes the minute menu offers: the hour at its step, plus a stored value
    /// that falls between two of them, kept in its own place so
    /// opening a schedule cannot move it.
    static func minuteOptions(including stored: Int) -> [Int] {
        let grid = Array(stride(from: 0, to: 60, by: minuteStep))
        let kept = wrapped(stored) % 60
        guard kept % minuteStep != 0 else { return grid }
        return (grid + [kept]).sorted()
    }

    /// The minute of the day the menus together name.
    static func minutes(hourOption: Int, minute: Int, isAfternoon: Bool, namingHalf: Bool) -> Int {
        let hour = namingHalf ? hourOption % 12 + (isAfternoon ? 12 : 0) : hourOption
        return wrapped(hour * 60 + minute)
    }
}

// MARK: - Time Field

/// Row of short menus holding one wall-clock time: an hour, a minute, and the
/// half of the day where a locale names one. Each menu stands on the
/// grid the name field below it stands on.
struct CoolDarkTimeField: View {
    @Binding var minutes: Int
    let label: String
    var locale: Locale = .current

    /// Gap between one menu and the next.
    private static let menuGap: CGFloat = 6

    /// Face the digits are set in, so a changing value cannot jog them.
    private static let digitFont = NSFont.monospacedDigitSystemFont(
        ofSize: CoolDarkMetrics.timeFontSize, weight: .semibold
    )

    /// Face the half of the day is set in, a step behind the digits it follows.
    private static let halfOfDayFont = NSFont.systemFont(
        ofSize: CoolDarkMetrics.fieldFontSize, weight: .semibold
    )

    /// Whether this locale hands the half of the day its own menu.
    private var namesHalfOfDay: Bool {
        TimeFieldMath.namesHalfOfDay(locale)
    }

    var body: some View {
        HStack(spacing: Self.menuGap) {
            hourMenu
            Text(TimeVariant.clockSeparator(locale: locale))
                .font(.system(size: CoolDarkMetrics.timeFontSize, weight: .semibold))
                .foregroundStyle(Color.cdTextTertiary)
            minuteMenu
            if namesHalfOfDay { halfOfDayMenu }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(TimeFieldMath.text(for: minutes, locale: locale))
    }

    // MARK: - Menus

    /// Hour of the day, twelve entries or twenty four depending on the clock.
    private var hourMenu: some View {
        menuField(
            values: TimeFieldMath.hourOptions(namingHalf: namesHalfOfDay),
            selected: TimeFieldMath.hourOption(of: minutes, namingHalf: namesHalfOfDay),
            label: "Hour",
            font: Self.digitFont,
            title: { TimeVariant.hourString(hour: $0, locale: locale) },
            onSelect: { hour in
                minutes = TimeFieldMath.minutes(
                    hourOption: hour,
                    minute: TimeFieldMath.wrapped(minutes) % 60,
                    isAfternoon: TimeFieldMath.isAfternoon(minutes),
                    namingHalf: namesHalfOfDay
                )
            }
        )
    }

    /// Minute of the hour, on the schedule's step.
    private var minuteMenu: some View {
        menuField(
            values: TimeFieldMath.minuteOptions(including: minutes),
            selected: TimeFieldMath.wrapped(minutes) % 60,
            label: "Minute",
            font: Self.digitFont,
            title: { TimeVariant.minuteString(minute: $0, locale: locale) },
            onSelect: { minute in
                minutes = TimeFieldMath.minutes(
                    hourOption: TimeFieldMath.hourOption(of: minutes, namingHalf: namesHalfOfDay),
                    minute: minute,
                    isAfternoon: TimeFieldMath.isAfternoon(minutes),
                    namingHalf: namesHalfOfDay
                )
            }
        )
    }

    /// Which half of the day the hour belongs to, on a twelve hour clock.
    /// Each entry is named for the hour picking it would land on.
    private var halfOfDayMenu: some View {
        let morningHour = TimeFieldMath.hourOption(of: minutes, namingHalf: true)
        return menuField(
            values: [0, 1],
            selected: TimeFieldMath.isAfternoon(minutes) ? 1 : 0,
            label: "Half of the day",
            font: Self.halfOfDayFont,
            title: { TimeVariant.halfOfDayString(hour: morningHour + $0 * 12, locale: locale) },
            onSelect: { half in
                minutes = TimeFieldMath.minutes(
                    hourOption: TimeFieldMath.hourOption(of: minutes, namingHalf: true),
                    minute: TimeFieldMath.wrapped(minutes) % 60,
                    isAfternoon: half == 1,
                    namingHalf: true
                )
            }
        )
    }

    // MARK: - Chrome

    /// One menu dressed as a field, its own indicator marking it as one that opens.
    private func menuField(
        values: [Int],
        selected: Int,
        label: String,
        font: NSFont,
        title: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        ClockMenu(
            values: values,
            selected: selected,
            label: label,
            font: font,
            color: NSColor(Color.cdTextPrimary),
            title: title,
            onSelect: onSelect
        )
        .padding(.horizontal, CoolDarkMetrics.fieldTextInset)
        .frame(height: CoolDarkMetrics.fieldHeight)
        .background(Color.cdBgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
    }
}

// MARK: - Clock Menu

/// Native popup that opens on the entry it is showing, drawn bare so the field
/// around it owns every edge. A pick reports the value it names.
private struct ClockMenu: NSViewRepresentable {
    /// Room left between the entry and the indicator at the menu's edge.
    static let indicatorGap: CGFloat = 4

    let values: [Int]
    let selected: Int
    let label: String
    let font: NSFont
    let color: NSColor
    let title: (Int) -> String
    let onSelect: (Int) -> Void

    /// Builds the bare popup the entries hang off.
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.alignment = .left
        button.target = context.coordinator
        button.action = #selector(Coordinator.pick(_:))
        button.setAccessibilityLabel(label)
        return button
    }

    /// Puts the current face, the entries on offer and the selection onto the popup.
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.font = font
        let titles = values.map(title)
        if button.itemTitles != titles {
            let menu = NSMenu()
            for (value, name) in zip(values, titles) {
                let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                // Colour only: the closed button and the open menu keep their own faces.
                item.attributedTitle = NSAttributedString(string: name, attributes: [.foregroundColor: color])
                item.representedObject = value
                menu.addItem(item)
            }
            menu.font = .menuFont(ofSize: 0)
            button.menu = menu
        }
        if let index = values.firstIndex(of: selected), button.indexOfSelectedItem != index {
            button.selectItem(at: index)
        }
    }

    /// Widest entry the menu holds, with the room its indicator takes.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        return CGSize(width: intrinsic.width + Self.indicatorGap, height: intrinsic.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Carries a pick from the popup back into the bound value.
    final class Coordinator: NSObject {
        var parent: ClockMenu

        init(parent: ClockMenu) {
            self.parent = parent
        }

        @objc func pick(_ sender: NSPopUpButton) {
            guard let value = sender.selectedItem?.representedObject as? Int else { return }
            parent.onSelect(value)
        }
    }
}
