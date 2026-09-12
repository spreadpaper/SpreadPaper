// SpreadPaper/Views/AppShell.swift

import SwiftUI

/// Top bar, main content and a fixed-width sidebar shared by Gallery and Editor.
/// The wizard renders full-screen without it.
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
                .frame(minWidth: 280)
                .fixedSize(horizontal: true, vertical: false)
                .background(Color.cdBgSecondary)
            }
        }
        .background(Color.cdBgPrimary)
    }
}
