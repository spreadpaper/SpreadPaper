// SpreadPaper/Views/CreationModal.swift

import SwiftUI

struct CreationModal: View {
    @Bindable var navigation: AppNavigation

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { navigation.showCreationModal = false }

            // Modal
            VStack(spacing: 0) {
                Text("New Wallpaper")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.top, 20)

                Text("Choose what kind of wallpaper to create")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdTextTertiary)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                VStack(spacing: 8) {
                    CreationRow(
                        icon: "photo",
                        iconGradient: [Color(hex: 0x007AFF), Color(hex: 0x5856D6)],
                        title: "Standard Wallpaper",
                        subtitle: "One image spread across your monitors"
                    ) {
                        navigation.navigateToNewEditor(type: .standard)
                    }

                    CreationRow(
                        icon: "sun.max.fill",
                        iconGradient: [Color(hex: 0xFF9500), Color(hex: 0xFF2D55)],
                        title: "Time of Day",
                        subtitle: "Wallpaper shifts throughout the day"
                    ) {
                        navigation.navigateToNewEditor(type: .dynamic)
                    }

                    CreationRow(
                        icon: "circle.lefthalf.filled",
                        iconGradient: [Color(hex: 0x636366), Color(hex: 0x48484a)],
                        title: "Light & Dark",
                        subtitle: "Different image for each appearance mode"
                    ) {
                        navigation.navigateToNewEditor(type: .appearance)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 340)
            .background(Color.cdBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 20)
        }
    }
}

private struct CreationRow: View {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cdTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cdTextTertiary)
            }
            .padding(10)
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
