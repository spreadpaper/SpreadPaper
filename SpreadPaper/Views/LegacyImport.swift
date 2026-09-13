// SpreadPaper/Views/LegacyImport.swift

import SwiftUI
import AppKit

/// Gallery banner offering to bring in wallpapers an earlier version saved.
/// Sits above the grid until the user imports or waves it away.
struct LegacyImportBanner: View {
    let isImporting: Bool
    let onImport: () -> Void
    let onDismiss: () -> Void
    let onSuppress: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                message
                    .frame(idealWidth: 280, maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 12)
                actions
            }
            VStack(alignment: .leading, spacing: 10) {
                message
                actions
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cdAccent.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cdBorder).frame(height: 1)
        }
    }

    /// Icon, title and the line explaining why the wallpapers are missing.
    private var message: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.cdAccent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Import your saved wallpapers")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                Text("Wallpapers you saved in earlier versions won't show up until you import them. They're still on this Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The three actions, one row, all 30pt tall and centred on each other.
    /// The quiet one keeps its distance from the pair.
    private var actions: some View {
        HStack(spacing: 8) {
            Button("Don't ask again", action: onSuppress)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cdTextSecondary)
                .padding(.horizontal, 8)
                .frame(height: 30)
                .contentShape(Rectangle())
                .padding(.trailing, 12)

            Button("Not now", action: onDismiss)
                .buttonStyle(CoolDarkButtonStyle(size: .compact))
            if isImporting {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 30)
            } else {
                Button("Import", action: onImport)
                    .buttonStyle(CoolDarkButtonStyle(isPrimary: true, size: .compact))
            }
        }
        .disabled(isImporting)
        .fixedSize()
    }
}

/// The one place that asks for a folder and hands it to the manager.
/// Shared by the gallery banner and the Settings rows.
enum LegacyImportFlow {
    /// Asks which folder to bring the wallpapers in from.
    static func chooseFolderToImport(manager: WallpaperManager) -> URL? {
        chooseFolder(
            prompt: "Import",
            message: "Choose the SpreadPaper folder to import your wallpapers from.",
            startingAt: manager.legacyLibraryURL
        )
    }

    /// Asks which folder to throw away, and checks it holds wallpapers.
    /// Returns nil when the user backs out or picks elsewhere.
    static func chooseFolderToRemove(manager: WallpaperManager) -> URL? {
        guard let url = chooseFolder(
            prompt: "Choose",
            message: "Choose the SpreadPaper folder holding your older wallpapers.",
            startingAt: manager.legacyLibraryURL
        ) else { return nil }
        return manager.legacyLibraryLooksRight(at: url) ? url : nil
    }

    /// Confirmation for a finished import, singular or plural.
    static func importedMessage(count: Int) -> String {
        "Imported \(count) wallpaper\(count == 1 ? "" : "s")."
    }

    /// Opens a folder picker with the caller's wording, starting at `startingAt`.
    /// Only a folder the user picks becomes readable, so nothing is assumed.
    private static func chooseFolder(prompt: String, message: String, startingAt: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = startingAt
        panel.prompt = prompt
        panel.message = message
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
