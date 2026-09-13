// SpreadPaper/Theme/CoolDarkTimeField.swift

import AppKit
import SwiftUI

// MARK: - Time Field Math

/// Clock work the time menu needs, held apart from the view that draws one.
/// Minutes since midnight are the only value it carries, and every
/// result lands inside a day.
nonisolated enum TimeFieldMath {
    /// Minutes a day holds, and the modulus every value wraps through.
    static let minutesPerDay = 1440

    /// Minutes between one time the menu offers and the next.
    static let increment = 15

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

    /// Every time the menu offers: the day at its increment, plus a stored
    /// value that falls between two of them, kept in its own place
    /// so opening a schedule cannot move it.
    static func offered(including stored: Int) -> [Int] {
        let grid = Array(stride(from: 0, to: minutesPerDay, by: increment))
        let kept = wrapped(stored)
        guard kept % increment != 0 else { return grid }
        return (grid + [kept]).sorted()
    }
}

// MARK: - Time Field

/// Field holding one wall-clock time, chosen from a menu of the times a
/// schedule offers. Every entry is written the way the user's own
/// clock setting writes it.
struct CoolDarkTimeField: View {
    @Binding var minutes: Int
    let label: String
    var locale: Locale = .current

    /// Face the digits are set in, so a changing value cannot jog them.
    private var digitFont: NSFont {
        .monospacedDigitSystemFont(ofSize: CoolDarkMetrics.timeFontSize, weight: .semibold)
    }

    var body: some View {
        ClockMenu(
            times: TimeFieldMath.offered(including: minutes),
            selected: minutes,
            label: label,
            font: digitFont,
            color: NSColor(Color.cdTextPrimary),
            title: { TimeFieldMath.text(for: $0, locale: locale) },
            onSelect: { minutes = $0 }
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

/// Native popup that opens on the time it is showing, drawn bare so the field
/// around it owns every edge. A pick reports the minute it names.
private struct ClockMenu: NSViewRepresentable {
    let times: [Int]
    let selected: Int
    let label: String
    let font: NSFont
    let color: NSColor
    let title: (Int) -> String
    let onSelect: (Int) -> Void

    /// Builds the bare popup the times hang off.
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.pick(_:))
        button.setAccessibilityLabel(label)
        return button
    }

    /// Puts the current face, the times on offer and the selection onto the popup.
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.font = font
        let titles = times.map(title)
        if button.itemTitles != titles {
            let menu = NSMenu()
            for (minute, name) in zip(times, titles) {
                let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                // Colour only: the closed button and the open menu keep their own faces.
                item.attributedTitle = NSAttributedString(string: name, attributes: [.foregroundColor: color])
                item.representedObject = minute
                menu.addItem(item)
            }
            menu.font = .menuFont(ofSize: 0)
            button.menu = menu
        }
        if let index = times.firstIndex(of: selected), button.indexOfSelectedItem != index {
            button.selectItem(at: index)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Carries a pick from the popup back into the bound minute.
    final class Coordinator: NSObject {
        var parent: ClockMenu

        init(parent: ClockMenu) {
            self.parent = parent
        }

        @objc func pick(_ sender: NSPopUpButton) {
            guard let minute = sender.selectedItem?.representedObject as? Int else { return }
            parent.onSelect(minute)
        }
    }
}
