// SpreadPaper/Theme/CoolDarkTypography.swift

import SwiftUI

extension Font {
    /// System font at `style`'s scalable size, carrying `weight`. Every type
    /// size in the app is set here, so text follows the system setting.
    static func cd(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style).weight(weight)
    }
}
