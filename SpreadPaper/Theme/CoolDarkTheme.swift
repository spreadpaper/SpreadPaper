// SpreadPaper/Theme/CoolDarkTheme.swift

import SwiftUI

// MARK: - Color Tokens

extension Color {
    static let cdBgPrimary = Color(hex: 0x16161a)
    static let cdBgSecondary = Color(hex: 0x1e1e24)
    static let cdBgElevated = Color(hex: 0x24242c)
    static let cdBorder = Color(hex: 0x2a2a32)
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

struct CoolDarkButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    var isSuccess: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isPrimary || isSuccess ? .white : Color.cdTextSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSuccess ? Color.cdSuccess : isPrimary ? Color.cdAccent : Color.cdBgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isPrimary || isSuccess ? Color.clear : Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: isSuccess ? Color.cdSuccess.opacity(0.3) : isPrimary ? Color.cdAccent.opacity(0.3) : .clear, radius: 8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CoolDarkIconButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(isDisabled ? Color.cdTextTertiary : Color.cdTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cdBgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - View Modifiers

struct CoolDarkPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cdBgSecondary)
    }
}

struct CoolDarkCard: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cdAccent : Color.cdBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Color.cdAccentGlow : .clear, radius: 8)
    }
}

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

// MARK: - Convenience Extensions

extension View {
    func coolDarkPanel() -> some View {
        modifier(CoolDarkPanel())
    }

    func coolDarkCard(isSelected: Bool = false) -> some View {
        modifier(CoolDarkCard(isSelected: isSelected))
    }
}
