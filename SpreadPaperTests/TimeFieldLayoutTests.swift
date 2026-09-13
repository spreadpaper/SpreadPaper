import AppKit
import SwiftUI
import Testing
@testable import SpreadPaper

/// Issue #129: the time menus stand on the same grid as the name field.
/// The scan holds the tokens, the render holds the measurements.
@MainActor
struct TimeFieldLayoutTests {
    /// Height one view takes when nothing stretches it.
    private static func height<V: View>(of view: V) -> CGFloat {
        let host = NSHostingView(rootView: AnyView(view))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    /// Text of one app source file, found by name.
    private func source(_ name: String) throws -> String {
        let file = try #require(AppSources.all().first { $0.lastPathComponent == name })
        return try String(contentsOf: file, encoding: .utf8)
    }

    /// Face the handover sentence is set in.
    private static let sentenceFont = Font.system(size: 12.5)

    /// Locales the menus are measured in: both hour cycles, the widest writings
    /// of a half of the day, and a region whose clock reads one way
    /// where its language reads the other.
    private static let clocks = [
        "en_US", "en_GB", "de_DE", "fr_CA", "es_MX", "zh_Hant_TW", "ko_KR", "ar_001", "en_001"
    ]

    /// Width the whole row of menus takes in one locale's writing.
    private static func fieldWidth(locale: Locale) -> CGFloat {
        let field = NSHostingView(rootView: AnyView(
            CoolDarkTimeField(minutes: .constant(545), label: "Starts at", locale: locale).fixedSize()
        ))
        field.layoutSubtreeIfNeeded()
        return field.fittingSize.width
    }

    /// Width the handover sentence is given beside the menus.
    private static func sentenceColumn(locale: Locale) -> CGFloat {
        ScheduleDetailModal.cardWidth
            - CoolDarkMetrics.dialogPadding * 2
            - fieldWidth(locale: locale)
            - ScheduleDetailModal.handoverGap
    }

    /// Lines the sentence takes in a column of that width.
    private static func sentenceLines(_ sentence: String, column: CGFloat) -> Int {
        let unit = height(of: Text("One").font(sentenceFont))
        let block = Text(sentence)
            .font(sentenceFont)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: column, alignment: .leading)
        return Int((height(of: block) / unit).rounded())
    }

    /// Contrast between two tokens, by the WCAG ratio.
    private static func contrast(_ text: Color, on ground: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            let sRGB = NSColor(color).usingColorSpace(.sRGB) ?? .black
            let channels = [sRGB.redComponent, sRGB.greenComponent, sRGB.blueComponent]
                .map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
        }
        let pair = [luminance(text), luminance(ground)].sorted()
        return (pair[1] + 0.05) / (pair[0] + 0.05)
    }

    @Test func theTimeMenusStandAsTallAsTheNameField() {
        let time = Self.height(of: CoolDarkTimeField(minutes: .constant(545), label: "Starts at"))
        let name = Self.height(of: CoolDarkTextField(placeholder: "Name", text: .constant("")))
        #expect(time == name, "the time menus render \(time)pt against the name field's \(name)pt")
        #expect(time == CoolDarkMetrics.fieldHeight)
    }

    @Test func theTimeMenusTakeTheirChromeFromTheSharedMetrics() throws {
        let text = try source("CoolDarkTimeField.swift")
        for token in ["fieldHeight", "controlCornerRadius", "fieldTextInset"] {
            #expect(text.contains("CoolDarkMetrics.\(token)"), "the time menus do not read \(token)")
        }
        #expect(text.contains("Color.cdBgPrimary"), "the time menus do not share the name field's fill")
        #expect(text.contains("Color.cdBorder"), "the time menus do not share the name field's border")
    }

    /// A menu styled SwiftUI picker measures the same at any type size, so the
    /// digits only keep theirs through AppKit.
    @Test func theMenusBridgeToAppKitSoTheDigitsKeepTheirSize() throws {
        let text = try source("CoolDarkTimeField.swift")
        #expect(text.contains("NSPopUpButton"), "the time menus no longer bridge to AppKit")
        #expect(!text.contains("pickerStyle"), "a SwiftUI picker would drop the digit size")
    }

    @Test func theDigitsLeadTheRowAboveTheTypeAroundThem() {
        #expect(CoolDarkMetrics.timeFontSize > CoolDarkMetrics.fieldFontSize)
        #expect(CoolDarkMetrics.timeFontSize >= 16)
    }

    /// The menus are no wider in a twelve hour locale than the sentence can spare.
    @Test func theMenusLeaveTheSentenceRoomInBothHourCycles() {
        let twelve = Self.sentenceColumn(locale: Locale(identifier: "en_US"))
        let twentyFour = Self.sentenceColumn(locale: Locale(identifier: "en_GB"))
        #expect(twelve > 0 && twentyFour > 0)
        #expect(twelve <= twentyFour, "a twelve hour clock takes a third menu, so its column cannot be the wider one")
    }

    @Test func everyHandoverSentenceHoldsOneLineBesideTheMenus() {
        for identifier in Self.clocks {
            let locale = Locale(identifier: identifier)
            let column = Self.sentenceColumn(locale: locale)
            for next in [0, 5, 6 * 60, 9 * 60 + 5, 12 * 60 + 30, 22 * 60 + 45, 23 * 60 + 59] {
                for (start, isOnly) in [(12 * 60, false), (next, false), (next + 60, false), (12 * 60, true)] {
                    let sentence = ScheduleEntryText.handover(
                        start: start, next: next, isOnly: isOnly, locale: locale
                    )
                    let lines = Self.sentenceLines(sentence, column: column)
                    #expect(
                        lines == 1,
                        "\"\(sentence)\" takes \(lines) lines in \(identifier)'s \(Int(column))pt column"
                    )
                }
            }
        }
    }

    @Test func theHandoverSentenceReadsAsBodyTextAgainstTheCard() {
        let ratio = Self.contrast(ScheduleDetailModal.handoverColor, on: .cdBgSecondary)
        #expect(ratio >= 4.5, "the handover sentence clears only \(String(format: "%.2f", ratio)) to one")
    }

    @Test func theDialogAnswersTheKeysADialogAnswers() throws {
        let dialog = try source("ScheduleView.swift")
        #expect(dialog.contains(".onExitCommand"), "the dialog cannot be dismissed from the keyboard")
        #expect(dialog.contains("keyboardShortcut(.defaultAction)"), "the dialog has no default action")
    }

    /// Two entries that read alike would collapse into one row of a menu.
    @Test func everyEntryOfAMenuIsWrittenDifferently() {
        for identifier in Self.clocks {
            let locale = Locale(identifier: identifier)
            let namingHalf = TimeFieldMath.namesHalfOfDay(locale)
            let hours = TimeFieldMath.hourOptions(namingHalf: namingHalf)
                .map { TimeVariant.hourString(hour: $0, locale: locale) }
            #expect(Set(hours).count == hours.count, "\(identifier) writes two of its hours the same way")
            let minutes = TimeFieldMath.minuteOptions(including: 6 * 60 + 47)
                .map { TimeVariant.minuteString(minute: $0, locale: locale) }
            #expect(Set(minutes).count == minutes.count, "\(identifier) writes two of its minutes the same way")
            guard namingHalf else { continue }
            for hour in TimeFieldMath.hourOptions(namingHalf: true) {
                let morning = TimeVariant.halfOfDayString(hour: hour, locale: locale)
                let evening = TimeVariant.halfOfDayString(hour: hour + 12, locale: locale)
                #expect(morning != evening, "\(identifier) names both halves of hour \(hour) \"\(morning)\"")
            }
        }
    }

    /// Opening a schedule never nudges a time saved before the step existed.
    @Test func aStoredTimeOffTheStepSurvivesBeingShown() {
        final class Stored { var minutes = 6 * 60 + 47 }
        let stored = Stored()
        let host = NSHostingView(rootView: AnyView(
            CoolDarkTimeField(
                minutes: Binding(get: { stored.minutes }, set: { stored.minutes = $0 }),
                label: "Starts at"
            ).fixedSize()
        ))
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        #expect(stored.minutes == 6 * 60 + 47)
    }

    @Test func theDialogNoLongerHangsADatePickerOffTheGrid() throws {
        let text = try source("ScheduleView.swift")
        #expect(!text.contains("DatePicker"), "the schedule dialog still draws a free-running clock")
        #expect(text.contains("CoolDarkTimeField"))
    }
}
