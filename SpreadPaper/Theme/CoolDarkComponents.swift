// SpreadPaper/Theme/CoolDarkComponents.swift

import SwiftUI
import PhosphorSwift

// MARK: - Custom Text Field

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
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Dashed Add Button

struct DashedAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Spacer()
                Ph.plus.bold
                    .color(Color.cdTextTertiary)
                    .frame(width: 10, height: 10)
                Text(label.replacingOccurrences(of: "+ ", with: ""))
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Color.cdTextTertiary)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.cdBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
