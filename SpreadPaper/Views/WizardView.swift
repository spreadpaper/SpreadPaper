// SpreadPaper/Views/WizardView.swift

import SwiftUI
import UniformTypeIdentifiers

struct WizardView: View {
    @Bindable var navigation: AppNavigation
    @State private var settings = AppSettings.shared
    @State private var step = 1
    @State private var displayCount = NSScreen.screens.count

    var body: some View {
        VStack(spacing: 0) {
            // Step indicators
            HStack(spacing: 6) {
                ForEach(1...2, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= step ? Color.cdAccent : Color.cdBorder)
                        .frame(width: 24, height: 4)
                }
            }
            .padding(.top, 24)

            Spacer()

            if step == 1 {
                welcomeStep
            } else {
                pickImageStep
            }

            Spacer()

            // Navigation buttons
            HStack {
                if step > 1 {
                    Button(action: { withAnimation { step -= 1 } }) {
                        Text("← Back")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cdTextTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if step == 1 {
                    Button("Get Started") {
                        withAnimation { step = 2 }
                    }
                    .buttonStyle(CoolDarkButtonStyle(isPrimary: true))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cdBgPrimary)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            // Monitor illustration
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(colors: [Color.cdAccent, Color(hex: 0x5856D6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 52)
                    .shadow(color: Color.cdAccentGlow, radius: 8)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x5856D6), Color(hex: 0xAF52DE)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 52)
                    .shadow(color: Color(hex: 0xAF52DE).opacity(0.2), radius: 8)
            }

            Text("Welcome to SpreadPaper")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("One wallpaper across all your monitors.\nPick an image, position it, and your desk comes alive.")
                .font(.system(size: 12))
                .foregroundStyle(Color.cdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("\(displayCount) display\(displayCount == 1 ? "" : "s") detected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cdAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.cdBgElevated)
                .clipShape(Capsule())
        }
    }

    private var pickImageStep: some View {
        VStack(spacing: 12) {
            Text("Choose your first wallpaper")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("Drop an image or click to browse")
                .font(.system(size: 12))
                .foregroundStyle(Color.cdTextSecondary)

            // Drop zone
            Button(action: pickImage) {
                VStack(spacing: 10) {
                    LinearGradient(colors: [Color.cdAccent, Color(hex: 0x5856D6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                        }

                    Text("Drag & drop an image here")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cdTextSecondary)

                    Text("or browse files")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cdAccent)
                }
                .frame(maxWidth: 300)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(Color.cdBorder)
                )
                .background(Color.cdBgElevated.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return }

        // Mark wizard complete and go to editor
        settings.hasCompletedWizard = true
        navigation.navigateToNewEditor(type: .standard)
    }
}
