import AppKit
import SwiftUI
import Testing
@testable import SpreadPaper

/// Issue #129: the time field stands on the same grid as the name field.
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

    @Test func theTimeFieldStandsAsTallAsTheNameField() {
        let time = Self.height(of: CoolDarkTimeField(minutes: .constant(545), label: "Starts at"))
        let name = Self.height(of: CoolDarkTextField(placeholder: "Name", text: .constant("")))
        #expect(time == name, "the time field renders \(time)pt against the name field's \(name)pt")
        #expect(time == CoolDarkMetrics.fieldHeight)
    }

    @Test func theTimeFieldTakesItsChromeFromTheSharedMetrics() throws {
        let text = try source("CoolDarkTimeField.swift")
        for token in ["fieldHeight", "controlCornerRadius", "fieldTextInset"] {
            #expect(text.contains("CoolDarkMetrics.\(token)"), "the time field does not read \(token)")
        }
        #expect(text.contains("Color.cdBgPrimary"), "the time field does not share the name field's fill")
        #expect(text.contains("Color.cdAccent"), "the time field does not share the name field's focus ring")
    }

    @Test func theDigitsLeadTheRowAboveTheTypeAroundThem() {
        #expect(CoolDarkMetrics.timeFontSize > CoolDarkMetrics.fieldFontSize)
        #expect(CoolDarkMetrics.timeFontSize >= 16)
    }

    @Test func theStepperPairFitsInsideTheField() {
        let pair = CoolDarkMetrics.stepperButtonHeight * 2 + 1
        #expect(pair < CoolDarkMetrics.fieldHeight)
        #expect(CoolDarkMetrics.stepperIconSize < CoolDarkMetrics.stepperWidth)
    }

    @Test func theDialogNoLongerHangsASystemPickerOffTheGrid() throws {
        let text = try source("ScheduleView.swift")
        #expect(!text.contains("DatePicker"), "the schedule dialog still draws a system picker")
        #expect(text.contains("CoolDarkTimeField"))
    }
}
