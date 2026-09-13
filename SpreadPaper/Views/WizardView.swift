// SpreadPaper/Views/WizardView.swift

import SwiftUI
import UniformTypeIdentifiers
import PhosphorSwift

/// Two-step first-launch flow: display count, then image selection that opens the editor.
struct WizardView: View {
    @Bindable var navigation: AppNavigation
    @State private var settings = AppSettings.shared
    @State private var step = 1
    @State private var displayCount = NSScreen.screens.count
    @State private var isDropTargeted = false

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
                    .fill(Color.cdAccent)
                    .frame(width: 80, height: 52)
                    .shadow(color: Color.cdAccentGlow, radius: 8)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(colors: [Color.cdAccent, Color.cdAccentSecondary],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 52)
                    .shadow(color: Color.cdAccentSecondary.opacity(0.2), radius: 8)
            }

            Text("Welcome to SpreadPaper")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("One wallpaper across all your monitors.\nPick an image, position it, and your desk comes alive.")
                .font(.system(size: 14))
                .foregroundStyle(Color.cdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Text("\(displayCount) display\(displayCount == 1 ? "" : "s") detected")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.cdAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.cdBgElevated)
                .clipShape(Capsule())
        }
    }

    private var pickImageStep: some View {
        VStack(spacing: 12) {
            Text("Choose your wallpaper images")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("Drop images or click to browse.\nSelect multiple for dynamic wallpapers.")
                .font(.system(size: 14))
                .foregroundStyle(Color.cdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Drop zone
            Button(action: pickImage) {
                VStack(spacing: 10) {
                    Color.cdAccent
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            Ph.arrowDown.bold
                                .cdIcon(Color.cdTextPrimary, size: 22)
                        }

                    Text("Drag & drop images here")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.cdTextSecondary)

                    Text("or browse files")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cdAccent)
                }
                .frame(maxWidth: 300)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(isDropTargeted ? Color.cdAccent : Color.cdBorder)
                )
                .background(Color.cdBgElevated.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
            .dropDestination(for: URL.self) { urls, _ in
                acceptDrop(urls)
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
        }
    }

    /// Opens a multi-select image panel and hands the chosen files to the editor.
    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.message = "Select one or more images"
        guard panel.runModal() == .OK else { return }
        openEditor(with: panel.urls)
    }

    /// Opens the editor with the dropped images; refuses drops that carry none.
    private func acceptDrop(_ urls: [URL]) -> Bool {
        let images = ImageFileFilter.imageURLs(from: urls)
        guard !images.isEmpty else { return false }
        openEditor(with: images)
        return true
    }

    /// Finishes the wizard and hands the images to a new editor.
    /// One image means static, two or more mean dynamic.
    private func openEditor(with urls: [URL]) {
        guard !urls.isEmpty else { return }
        settings.hasCompletedWizard = true
        let type: WallpaperType = urls.count == 1 ? .standard : .dynamic
        navigation.navigateToNewEditor(type: type, imageURLs: urls)
    }
}
