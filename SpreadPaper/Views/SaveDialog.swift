// SpreadPaper/Views/SaveDialog.swift

import SwiftUI

/// Overlay that names a preset before it is saved. Focuses the name field
/// on appear so the initial text is selected and typing replaces it.
struct SaveDialog: View {
    let applyOnSave: Bool
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var name: String
    @State private var hasAppeared = false
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty }

    /// Seeds the name state from `initialName` before the first render.
    init(initialName: String, applyOnSave: Bool, onCancel: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        self.applyOnSave = applyOnSave
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        ZStack {
            backdrop

            card
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1.0 : 0.97)
                .offset(y: hasAppeared ? 0 : 6)
        }
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.24)) {
                hasAppeared = true
            }
        }
        // Runs after the field is attached.
        .task { nameFocused = true }
    }

    private var backdrop: some View {
        Color.cdOverlayScrim
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            .onTapGesture { onCancel() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: CoolDarkMetrics.labelGap) {
                Text("Save wallpaper")
                    .font(.cd(.title3, .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                Text("Give this wallpaper a name so you can find it later.")
                    .font(.cd(.callout))
                    .foregroundStyle(Color.cdTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: CoolDarkMetrics.labelGap) {
                Text("Name")
                    .font(.cd(.callout, .medium))
                    .foregroundStyle(Color.cdTextSecondary)

                TextField("", text: $name)
                    .accessibilityLabel("Wallpaper name")
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                    .font(.cd(.body))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.horizontal, CoolDarkMetrics.fieldTextInset)
                    .frame(minHeight: CoolDarkMetrics.fieldHeight)
                    .background(Color.cdBgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius)
                            .stroke(nameFocused ? Color.cdAccent : Color.cdBorder, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius)
                            .stroke(Color.cdAccent.opacity(nameFocused ? 0.35 : 0), lineWidth: 3)
                            .blur(radius: nameFocused ? 0.5 : 0)
                    )
                    .animation(.easeInOut(duration: 0.12), value: nameFocused)
                    .onSubmit { commit() }
            }

            HStack(spacing: 8) {
                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(CoolDarkButtonStyle(size: .compact))
                    .keyboardShortcut(.cancelAction)

                Button(applyOnSave ? "Save & Apply" : "Save", action: commit)
                    .buttonStyle(CoolDarkButtonStyle(isPrimary: true, size: .compact))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(CoolDarkMetrics.dialogPadding)
        .frame(width: 380)
        .background(Color.cdBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CoolDarkMetrics.dialogCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CoolDarkMetrics.dialogCornerRadius)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
        .shadow(color: .cdShadowStrong, radius: 80, y: 30)
    }

    /// Saves the trimmed name; ignored while the name is blank.
    private func commit() {
        guard canSave else { return }
        onSave(trimmed)
    }
}
