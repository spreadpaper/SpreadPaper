// SpreadPaper/Theme/CoolDarkTimeField.swift

import AppKit
import PhosphorSwift
import SwiftUI

// MARK: - Time Field Math

/// Clock arithmetic a time field needs, held apart from the view that draws one.
/// Minutes since midnight are the only value it moves, and every result
/// lands inside a day.
nonisolated enum TimeFieldMath {
    /// Minutes a day holds, and the modulus every value wraps through.
    static let minutesPerDay = 1440

    /// Minutes one arrow press or one click moves the value.
    static let step = 1

    /// Minutes the same press moves it with Shift held.
    static let coarseStep = 15

    /// Span an AM or a PM designator names.
    private static let halfDay = 12

    /// Half of the day a designator names.
    private enum Designator {
        case morning
        case afternoon
    }

    /// Whether the locale writes the hour on a twelve hour clock.
    /// A user's 24-hour setting reaches this through the locale.
    static func usesTwelveHourClock(_ locale: Locale = .current) -> Bool {
        switch locale.hourCycle {
        case .zeroToEleven, .oneToTwelve: true
        default: false
        }
    }

    /// The minute of the day a raw count lands on, midnight either side of it.
    static func wrapped(_ minutes: Int) -> Int {
        let remainder = minutes % minutesPerDay
        return remainder < 0 ? remainder + minutesPerDay : remainder
    }

    /// The value a step lands on, carrying past midnight in both directions.
    static func stepped(_ minutes: Int, by step: Int) -> Int {
        wrapped(minutes + step)
    }

    /// The locale's writing of a minute count, as a clock shows it.
    static func text(for minutes: Int, locale: Locale = .current) -> String {
        let minute = wrapped(minutes)
        return TimeVariant.clockString(hour: minute / 60, minute: minute % 60, locale: locale)
    }

    /// One clock string per hour, for sizing a field no value can jog.
    static func widthSamples(locale: Locale = .current) -> [String] {
        (0..<24).map { text(for: $0 * 60 + 55, locale: locale) }
    }

    /// Minutes since midnight read out of typed text, nil when it says nothing.
    /// Bare digits, a separator and a designator all read.
    static func minutes(from text: String, locale: Locale = .current) -> Int? {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let designator = takeDesignator(from: &body, locale: locale)
        guard let clock = hourAndMinute(in: body) else { return nil }
        return minutes(hour: clock.hour, minute: clock.minute, designator: designator)
    }

    /// Strips a leading or trailing AM or PM marker, naming the half it read.
    private static func takeDesignator(from body: inout String, locale: Locale) -> Designator? {
        for (marker, half) in designators(locale: locale) where !marker.isEmpty {
            if body.hasSuffix(marker) {
                body = String(body.dropLast(marker.count)).trimmingCharacters(in: .whitespaces)
                return half
            }
            if body.hasPrefix(marker) {
                body = String(body.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                return half
            }
        }
        return nil
    }

    /// Markers that name a half of the day, the locale's own ones among them.
    /// Longest first, so a short marker cannot claim a long one.
    private static func designators(locale: Locale) -> [(String, Designator)] {
        let formatter = DateFormatter()
        formatter.locale = locale
        let markers: [(String, Designator)] = [
            (formatter.pmSymbol, .afternoon), (formatter.amSymbol, .morning),
            ("p.m.", .afternoon), ("a.m.", .morning),
            ("pm", .afternoon), ("am", .morning),
            ("p", .afternoon), ("a", .morning)
        ]
        return markers.map { ($0.0.lowercased(), $0.1) }.sorted { $0.0.count > $1.0.count }
    }

    /// Hour and minute read out of the digits, once any designator is gone.
    /// Four bare digits read as an hour and a minute.
    private static func hourAndMinute(in body: String) -> (hour: Int, minute: Int)? {
        let fields = body.split(whereSeparator: { ":.h \u{00a0}".contains($0) })
        guard fields.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        switch fields.count {
        case 1:
            guard let value = Int(fields[0]) else { return nil }
            switch fields[0].count {
            case 1, 2: return (value, 0)
            case 3, 4: return (value / 100, value % 100)
            default: return nil
            }
        case 2:
            guard let hour = Int(fields[0]), let minute = Int(fields[1]) else { return nil }
            return (hour, minute)
        default:
            return nil
        }
    }

    /// The minute of the day an hour, a minute and a designator name.
    /// Anything off the clock reads as nothing at all.
    private static func minutes(hour: Int, minute: Int, designator: Designator?) -> Int? {
        guard (0...59).contains(minute) else { return nil }
        guard let designator else {
            guard (0...23).contains(hour) else { return nil }
            return hour * 60 + minute
        }
        guard (1...halfDay).contains(hour) else { return nil }
        return (hour % halfDay + (designator == .afternoon ? halfDay : 0)) * 60 + minute
    }
}

// MARK: - Time Field

/// Field holding one wall-clock time: large locale-written digits leading the
/// row, a stepper pair on the trailing edge. Typing sets the time, the arrow
/// keys and the buttons move it.
struct CoolDarkTimeField: View {
    @Binding var minutes: Int
    let label: String
    var locale: Locale = .current

    @State private var text = ""
    @State private var isEditing = false

    /// Gap between the digits and the stepper beside them.
    private static let stepperGap: CGFloat = 12

    /// Inset from the trailing edge to the stepper.
    private static let stepperInset: CGFloat = 5

    /// Face the digits are set in, so a changing value cannot jog them.
    private var digitFont: NSFont {
        .monospacedDigitSystemFont(ofSize: CoolDarkMetrics.timeFontSize, weight: .semibold)
    }

    /// Widest the digits can draw in this locale, designator included.
    private var digitWidth: CGFloat {
        let widest = TimeFieldMath.widthSamples(locale: locale)
            .map { NSAttributedString(string: $0, attributes: [.font: digitFont]).size().width }
            .max() ?? 0
        return ceil(widest) + 2
    }

    var body: some View {
        HStack(spacing: 0) {
            ClockTextField(
                text: $text,
                label: label,
                font: digitFont,
                color: NSColor(Color.cdTextPrimary),
                onStep: step,
                onEditing: { isEditing = $0 },
                onCommit: commit,
                onRevert: revert
            )
            .frame(width: digitWidth, height: CoolDarkMetrics.timeFontSize + 6)

            Spacer(minLength: Self.stepperGap)
            stepper
        }
        .padding(.leading, CoolDarkMetrics.fieldTextInset)
        .padding(.trailing, Self.stepperInset)
        .frame(height: CoolDarkMetrics.fieldHeight)
        .background(Color.cdBgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius)
                .stroke(isEditing ? Color.cdAccent : Color.cdBorder, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius)
                .stroke(Color.cdAccent.opacity(isEditing ? 0.35 : 0), lineWidth: 3)
                .blur(radius: isEditing ? 0.5 : 0)
        )
        .animation(.easeInOut(duration: 0.12), value: isEditing)
        .onAppear { revert() }
        .onChange(of: minutes) { _, value in
            text = TimeFieldMath.text(for: value, locale: locale)
        }
    }

    /// The two halves that move the value, stacked on the trailing edge.
    private var stepper: some View {
        VStack(spacing: 0) {
            TimeStepButton(icon: Ph.caretUp.bold, label: "Later") { step(amount(up: true)) }
            Rectangle()
                .fill(Color.cdBorder)
                .frame(height: 1)
            TimeStepButton(icon: Ph.caretDown.bold, label: "Earlier") { step(amount(up: false)) }
        }
        .frame(width: CoolDarkMetrics.stepperWidth)
        .background(Color.cdBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CoolDarkMetrics.stepperCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CoolDarkMetrics.stepperCornerRadius)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
    }

    /// Minutes a click moves the value, coarser while Shift is held.
    private func amount(up: Bool) -> Int {
        let held = NSEvent.modifierFlags.contains(.shift)
        let size = held ? TimeFieldMath.coarseStep : TimeFieldMath.step
        return up ? size : -size
    }

    /// Moves the value on from whatever the field currently reads.
    private func step(_ amount: Int) {
        let base = TimeFieldMath.minutes(from: text, locale: locale) ?? minutes
        minutes = TimeFieldMath.stepped(base, by: amount)
        text = TimeFieldMath.text(for: minutes, locale: locale)
    }

    /// Reads the typed text back into the value, keeping the last good time.
    private func commit() {
        if let typed = TimeFieldMath.minutes(from: text, locale: locale) {
            minutes = TimeFieldMath.wrapped(typed)
        }
        revert()
    }

    /// Writes the stored value back over whatever the field reads.
    private func revert() {
        text = TimeFieldMath.text(for: minutes, locale: locale)
    }
}

// MARK: - Step Button

/// One half of a stepper pair, washing on hover and again while held.
/// A held button keeps stepping until the press ends.
private struct TimeStepButton: View {
    let icon: Image
    let label: String
    let onStep: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false
    @State private var repeater: Task<Void, Never>?

    /// Rest before a held button starts repeating.
    private static let repeatDelay = Duration.milliseconds(400)

    /// Gap between one repeat and the next.
    private static let repeatGap = Duration.milliseconds(55)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isPressed ? Color.cdActiveFill : isHovering ? Color.cdHoverFill : Color.clear)
            icon.cdIcon(
                isHovering || isPressed ? Color.cdTextPrimary : Color.cdTextSecondary,
                size: CoolDarkMetrics.stepperIconSize
            )
        }
        .frame(height: CoolDarkMetrics.stepperButtonHeight)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginPress() }
                .onEnded { _ in endPress() }
        )
        .onDisappear(perform: endPress)
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(label)
        .accessibilityAction { onStep() }
        .animation(.easeInOut(duration: 0.1), value: isHovering)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }

    /// Steps once, then keeps stepping for as long as the press lasts.
    private func beginPress() {
        guard !isPressed else { return }
        isPressed = true
        onStep()
        repeater = Task {
            try? await Task.sleep(for: Self.repeatDelay)
            while !Task.isCancelled {
                onStep()
                try? await Task.sleep(for: Self.repeatGap)
            }
        }
    }

    /// Ends the press and stops whatever repeat it started.
    private func endPress() {
        isPressed = false
        repeater?.cancel()
        repeater = nil
    }
}

// MARK: - Clock Text Field

/// Native editor for the digits, drawn bare so the field around it owns every
/// edge. It reports the arrow keys as steps and each edit boundary
/// as that boundary comes.
private struct ClockTextField: NSViewRepresentable {
    @Binding var text: String
    let label: String
    let font: NSFont
    let color: NSColor
    let onStep: (Int) -> Void
    let onEditing: (Bool) -> Void
    let onCommit: () -> Void
    let onRevert: () -> Void

    /// Builds the bare field the digits are typed into.
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.alignment = .left
        field.cell?.isScrollable = true
        field.setAccessibilityLabel(label)
        return field
    }

    /// Pushes the current face and value onto the field without disturbing the caret.
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.font = font
        field.textColor = color
        let shown = field.currentEditor()?.string ?? field.stringValue
        guard shown != text else { return }
        if let editor = field.currentEditor() {
            editor.string = text
            editor.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        } else {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Carries the field's editing callbacks back into the SwiftUI value.
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ClockTextField

        init(parent: ClockTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.onEditing(true)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onEditing(false)
            parent.onCommit()
        }

        /// Turns the arrow keys into steps and leaves the rest to the field.
        /// Shift makes a step coarse, Return commits and Escape reverts.
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onStep(TimeFieldMath.step)
            case #selector(NSResponder.moveDown(_:)):
                parent.onStep(-TimeFieldMath.step)
            case #selector(NSResponder.moveUpAndModifySelection(_:)):
                parent.onStep(TimeFieldMath.coarseStep)
            case #selector(NSResponder.moveDownAndModifySelection(_:)):
                parent.onStep(-TimeFieldMath.coarseStep)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onCommit()
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onRevert()
            default:
                return false
            }
            return true
        }
    }
}
