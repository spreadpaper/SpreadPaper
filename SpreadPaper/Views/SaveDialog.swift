// SpreadPaper/Views/SaveDialog.swift

import SwiftUI
import AppKit

struct SaveDialog: View {
    let initialName: String
    let applyOnSave: Bool
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var name: String = ""
    @State private var hasAppeared = false
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty }

    var body: some View {
        ZStack {
            backdrop

            card
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1.0 : 0.97)
                .offset(y: hasAppeared ? 0 : 6)
        }
        .onAppear {
            name = initialName
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.24)) {
                hasAppeared = true
            }
            DispatchQueue.main.async {
                nameFocused = true
                selectAllInFirstResponder()
            }
        }
    }

    private var backdrop: some View {
        Color(red: 10/255, green: 10/255, blue: 14/255).opacity(0.55)
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            .onTapGesture { onCancel() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save wallpaper")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                Text("Give this wallpaper a name so you can find it later.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.cdTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cdTextSecondary)

                TextField("", text: $name)
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.horizontal, 11)
                    .frame(height: 36)
                    .background(Color.cdBgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(nameFocused ? Color.cdAccent : Color.cdBorder, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.cdAccent.opacity(nameFocused ? 0.35 : 0), lineWidth: 3)
                            .blur(radius: nameFocused ? 0.5 : 0)
                    )
                    .animation(.easeInOut(duration: 0.12), value: nameFocused)
                    .onSubmit { commit() }
            }

            HStack(spacing: 8) {
                Spacer()

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cdTextSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.cdBgElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.cdBorder, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: commit) {
                    Text(applyOnSave ? "Save & Apply" : "Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.cdAccent.opacity(canSave ? 1.0 : 0.4))
                        )
                        .shadow(color: Color.cdAccent.opacity(canSave ? 0.3 : 0), radius: 8, y: 3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 380)
        .background(Color.cdBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 80, y: 30)
    }

    private func commit() {
        guard canSave else { return }
        onSave(trimmed)
    }

    private func selectAllInFirstResponder() {
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
            textView.selectAll(nil)
        }
    }
}
