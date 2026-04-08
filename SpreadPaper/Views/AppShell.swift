// SpreadPaper/Views/AppShell.swift

import SwiftUI

/// Shared layout shell for Gallery and Editor views.
/// Wizard bypasses this entirely (full-screen onboarding).
struct AppShell<MainContent: View, SidebarContent: View>: View {
    let title: String
    let subtitle: String?
    let showBack: Bool
    let onBack: (() -> Void)?
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let sidebarContent: () -> SidebarContent

    init(
        title: String,
        subtitle: String? = nil,
        showBack: Bool = false,
        onBack: (() -> Void)? = nil,
        @ViewBuilder mainContent: @escaping () -> MainContent,
        @ViewBuilder sidebarContent: @escaping () -> SidebarContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showBack = showBack
        self.onBack = onBack
        self.mainContent = mainContent
        self.sidebarContent = sidebarContent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                if showBack, let onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10))
                            Text("Gallery")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.cdAccent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("SpreadPaper")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.cdTextPrimary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
                    if let subtitle {
                        Text("· \(subtitle)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cdTextTertiary)
                    }
                }

                Spacer()

                // Balance spacer
                Color.clear.frame(width: 80, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.cdBgSecondary)

            Divider().overlay(Color.cdBorder)

            // Main area + sidebar
            HStack(spacing: 0) {
                mainContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(Color.cdBorder)

                // Sidebar
                VStack(spacing: 0) {
                    sidebarContent()
                }
                .frame(width: 240)
                .background(Color.cdBgSecondary)
            }
        }
        .background(Color.cdBgPrimary)
    }
}
