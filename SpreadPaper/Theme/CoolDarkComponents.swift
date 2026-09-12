// SpreadPaper/Theme/CoolDarkComponents.swift

import SwiftUI

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
