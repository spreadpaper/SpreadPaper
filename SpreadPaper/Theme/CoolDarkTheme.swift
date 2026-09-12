// SpreadPaper/Theme/CoolDarkTheme.swift

import SwiftUI

// MARK: - Color Tokens

extension Color {
    static let cdBgPrimary = Color(hex: 0x16161a)
    static let cdBgSecondary = Color(hex: 0x1e1e24)
    static let cdBgElevated = Color(hex: 0x24242c)
    static let cdBgHover = Color(hex: 0x2a2a34)
    static let cdBorder = Color(hex: 0x2a2a32)
    static let cdBorderStrong = Color(hex: 0x3a3a44)
    static let cdTextPrimary = Color(hex: 0xe8e8ed)
    static let cdTextSecondary = Color(hex: 0x9e9eaa)
    static let cdTextTertiary = Color(hex: 0x6e6e7a)
    static let cdAccent = Color(hex: 0x5e5ce6)
    static let cdAccentGlow = Color(hex: 0x5e5ce6).opacity(0.2)
    static let cdSuccess = Color(hex: 0x34C759)
    static let cdCanvasBg = Color(hex: 0x111114)
    static let cdDanger = Color(hex: 0xFF453A)

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Button Styles

/// Shared chrome for primary, success and secondary buttons. `size` picks the
/// regular or compact metrics; a disabled button fades and loses its glow.
struct CoolDarkButtonStyle: ButtonStyle {
    /// Button metrics. Compact is the 30 pt height used in dialogs and on
    /// gallery cards.
    enum Size {
        case regular
        case compact

        var fontSize: CGFloat {
            switch self {
            case .regular: 14
            case .compact: 13
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .regular: 16
            case .compact: 12
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .regular: 10
            case .compact: 7
            }
        }

        /// Pinned height so compact buttons line up with 30 pt neighbours.
        var minHeight: CGFloat? {
            switch self {
            case .regular: nil
            case .compact: 30
            }
        }
    }

    var isPrimary: Bool = false
    var isSuccess: Bool = false
    var size: Size = .regular

    @Environment(\.isEnabled) var isEnabled

    /// True for the accent and success variants, which drop the border.
    private var isFilled: Bool { isPrimary || isSuccess }

    /// Background colour for the current variant.
    private var fill: Color {
        isSuccess ? Color.cdSuccess : isPrimary ? Color.cdAccent : Color.cdBgElevated
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .foregroundStyle(isFilled ? .white : Color.cdTextSecondary)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.minHeight)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isFilled ? Color.clear : Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: isFilled && isEnabled ? fill.opacity(0.3) : .clear, radius: 8)
            .opacity(!isEnabled ? 0.5 : configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.cdTextTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
