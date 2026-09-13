// SpreadPaper/Theme/CoolDarkTypography.swift

import SwiftUI

extension Font {
    /// System font at `style`'s scalable size, carrying `weight`. Every type
    /// size in the app is set through here, so text follows the
    /// system text size setting.
    ///
    /// - Parameters:
    ///   - style: Named text style the size is taken from.
    ///   - weight: Face weight, regular unless given.
    /// - Returns: A font that scales with the system setting.
    ///
    /// - Example:
    ///   `Text("Apply").font(.cd(.callout, .semibold))`
    static func cd(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style).weight(weight)
    }
}
