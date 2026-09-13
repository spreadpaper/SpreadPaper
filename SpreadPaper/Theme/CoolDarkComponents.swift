// SpreadPaper/Theme/CoolDarkComponents.swift

import SwiftUI

// MARK: - Icon

extension Image {
    /// Draws a glyph at a square size in one theme colour.
    /// The token reaches it through `foregroundStyle`.
    func cdIcon(_ token: Color, size: CGFloat) -> some View {
        renderingMode(.template)
            .foregroundStyle(token)
            .frame(width: size, height: size)
    }
}

// MARK: - Custom Text Field

/// Plain text field on the dark fill with an accent ring while focused.
struct CoolDarkTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .font(.system(size: 14))
            .foregroundStyle(Color.cdTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cdBgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.cdAccent : Color.cdBorder.opacity(0.6),
                            lineWidth: isFocused ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

// MARK: - Toast

/// Elevated pill for a short transient confirmation.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.cdTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: .cdShadow, radius: 8, y: 4)
    }
}

/// Floats a toast over a view and clears it again on its own.
private struct ToastOverlay: ViewModifier {
    @Binding var message: String?
    let topPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    ToastView(message: message)
                        .padding(.top, topPadding)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: message)
            .onChange(of: message) { _, shown in
                guard let shown else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    if message == shown { message = nil }
                }
            }
    }
}

extension View {
    /// Shows `message` as a toast for two seconds, then clears the binding.
    /// A newer message replaces the one on screen.
    func toast(_ message: Binding<String?>, topPadding: CGFloat = 70) -> some View {
        modifier(ToastOverlay(message: message, topPadding: topPadding))
    }
}
