// SpreadPaper/Theme/ClockSettings.swift

import Foundation
import SwiftUI

/// Hands the system locale down the view tree and hands it down again when the
/// user changes their region or their 24-Hour Time setting, so written
/// times follow System Settings without a relaunch.
private struct ClockSettingsWatcher: ViewModifier {
    @State private var locale = Locale.current

    func body(content: Content) -> some View {
        content
            .environment(\.locale, locale)
            .task {
                let changes = NotificationCenter.default
                    .notifications(named: NSLocale.currentLocaleDidChangeNotification)
                    .map { _ in Locale.current }
                for await changed in changes { locale = changed }
            }
    }
}

extension View {
    /// Keeps every time written below this view on the user's own clock, live.
    func followsClockSettings() -> some View {
        modifier(ClockSettingsWatcher())
    }
}
