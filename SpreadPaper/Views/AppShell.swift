// SpreadPaper/Views/AppShell.swift

import SwiftUI

/// Shared layout shell for Gallery and Editor views.
/// Wizard bypasses this entirely (full-screen onboarding).
struct AppShell<TopBar: View, MainContent: View, SidebarContent: View>: View {
    @ViewBuilder let topBar: () -> TopBar
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let sidebarContent: () -> SidebarContent

    var body: some View {
        VStack(spacing: 0) {
            topBar()

            Divider().overlay(Color.cdBorder)

            HStack(spacing: 0) {
                mainContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(Color.cdBorder)

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
