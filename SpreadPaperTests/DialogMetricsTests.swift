import Foundation
import Testing
@testable import SpreadPaper

/// Issue #129: both overlay dialogs measure themselves from one place.
/// A literal in either file lets the two drift apart.
struct DialogMetricsTests {
    /// Files that must take their measurements from `CoolDarkMetrics`.
    private static let dialogs = ["SaveDialog.swift", "ScheduleView.swift"]

    /// Measurements both dialogs name rather than restate.
    private static let shared = [
        "dialogPadding", "dialogCornerRadius", "controlCornerRadius", "labelGap"
    ]

    /// Numbers that would put a dialog back on its own grid.
    private static let strayLiterals = [
        "cornerRadius: 7", "cornerRadius: 8", "cornerRadius: 12",
        ".padding(20)", ".padding(22)", "height: 30", "height: 36",
        ".horizontal, 11"
    ]

    /// Text of one app source file, found by name.
    private func source(_ name: String) throws -> String {
        let file = try #require(AppSources.all().first { $0.lastPathComponent == name })
        return try String(contentsOf: file, encoding: .utf8)
    }

    @Test func everyDialogReadsTheSharedMetrics() throws {
        for dialog in Self.dialogs {
            let text = try source(dialog)
            for name in Self.shared {
                #expect(text.contains("CoolDarkMetrics.\(name)"), "\(dialog) does not read \(name)")
            }
        }
    }

    @Test func noDialogRestatesAMeasurement() throws {
        for dialog in Self.dialogs {
            let text = try source(dialog)
            for literal in Self.strayLiterals {
                #expect(!text.contains(literal), "\(dialog) restates \(literal)")
            }
        }
    }

    @Test func aCompactButtonMatchesTheQuietActionBesideIt() {
        #expect(CoolDarkButtonStyle.Size.compact.minHeight == CoolDarkMetrics.compactControlHeight)
    }

    @Test func aFieldIsTallerThanTheButtonsUnderIt() {
        #expect(CoolDarkMetrics.fieldHeight > CoolDarkMetrics.compactControlHeight)
    }
}
