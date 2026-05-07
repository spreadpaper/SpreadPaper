// SpreadPaper/Views/GalleryView.swift

import SwiftUI
import AppKit
import PhosphorSwift

struct GalleryView: View {
    @Bindable var manager: WallpaperManager
    @Bindable var navigation: AppNavigation
    @Environment(\.colorScheme) var colorScheme

    @State private var filterIndex: Int = 0
    @State private var searchQuery: String = ""
    @State private var thumbnailCache: [UUID: NSImage] = [:]
    @State private var isLoadingThumbnails: Bool = true
    @State private var selectedPresetId: UUID? = nil
    @State private var applyingPresetId: UUID? = nil
    @State private var presetPendingDelete: SavedPreset? = nil
    @State private var presetPendingRename: SavedPreset? = nil
    @State private var renameDraft: String = ""
    @State private var showSettings: Bool = false
    @FocusState private var searchFocused: Bool

    // MARK: - Derived

    private var currentFilter: GalleryFilter {
        GalleryFilter(rawValue: filterIndex) ?? .all
    }

    private var filteredPresets: [SavedPreset] {
        let byFilter: [SavedPreset]
        switch currentFilter {
        case .all:        byFilter = manager.presets
        case .standard:   byFilter = manager.presets.filter { !$0.isDynamic }
        case .dynamic:    byFilter = manager.presets.filter { $0.isDynamic && $0.wallpaperType == "Dynamic" }
        case .appearance: byFilter = manager.presets.filter { $0.wallpaperType == "Light/Dark" }
        }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return byFilter }
        return byFilter.filter { $0.name.range(of: q, options: .caseInsensitive) != nil }
    }

    var body: some View {
        Group {
            if showSettings {
                SettingsShell(onClose: { showSettings = false })
            } else {
                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 220)
                        .background(Color.cdBgSecondary)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(Color.cdBorder).frame(width: 1)
                        }
                    VStack(spacing: 0) {
                        toolbar
                        Rectangle().fill(Color.cdBorder).frame(height: 1)
                        mainContent
                    }
                    .background(Color.cdBgPrimary)
                }
            }
        }
            .task { reloadThumbnails() }
            .onChange(of: colorScheme) { _, _ in reloadThumbnails() }
            .onChange(of: manager.presets.map(\.id)) { _, _ in reloadThumbnails() }
            .confirmationDialog(
                "Delete '\(presetPendingDelete?.name ?? "")'?",
                isPresented: Binding(
                    get: { presetPendingDelete != nil },
                    set: { if !$0 { presetPendingDelete = nil } }
                ),
                presenting: presetPendingDelete
            ) { preset in
                Button("Delete", role: .destructive) { manager.deletePreset(preset) }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("This preset will be removed. The source image isn't affected.")
            }
            .alert(
                "Rename preset",
                isPresented: Binding(
                    get: { presetPendingRename != nil },
                    set: { if !$0 { presetPendingRename = nil } }
                )
            ) {
                TextField("Name", text: $renameDraft)
                Button("Rename") { commitRename() }
                Button("Cancel", role: .cancel) { presetPendingRename = nil }
            }
    }

    // MARK: - Toolbar (height 52)

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(toolbarTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("\(filteredPresets.count) item\(filteredPresets.count == 1 ? "" : "s")")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(Color.cdTextTertiary)

            Spacer(minLength: 0)

            searchField

            Button(action: { navigation.showCreationModal = true }) {
                HStack(spacing: 6) {
                    Ph.plus.bold
                        .color(.white)
                        .frame(width: 12, height: 12)
                    Text("New Wallpaper")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cdAccent)
                )
                .shadow(color: Color.cdAccent.opacity(0.22), radius: 12, y: 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .frame(height: 52)
        .background(Color.cdBgPrimary)
    }

    private var toolbarTitle: String {
        switch currentFilter {
        case .all:        return "All Wallpapers"
        case .standard:   return "Static"
        case .dynamic:    return "Dynamic"
        case .appearance: return "Light & Dark"
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Ph.magnifyingGlass.regular
                .color(Color.cdTextTertiary)
                .frame(width: 12, height: 12)
            TextField("Search", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.cdTextPrimary)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Text("esc")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cdTextTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.cdBgHover)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 220, height: 28)
        .background(Color.cdBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(searchFocused ? Color.cdAccent : Color.cdBorder, lineWidth: 1)
        )
        .background(
            Button(action: { searchFocused = true }) { EmptyView() }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
        )
        .background(
            Button(action: {
                if !searchQuery.isEmpty { searchQuery = "" }
                else if selectedPresetId != nil { selectedPresetId = nil }
                searchFocused = false
            }) { EmptyView() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Traffic-light clearance (40pt top)
            Color.clear.frame(height: 40)

            // LIBRARY header (4/10/14 padding per prototype)
            Text("LIBRARY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.cdTextTertiary)
                .padding(.top, 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            VStack(spacing: 1) {
                ForEach(GalleryFilter.allCases, id: \.self) { filter in
                    FilterRow(
                        filter: filter,
                        label: sidebarLabel(for: filter),
                        isSelected: filterIndex == filter.rawValue,
                        count: countFor(filter),
                        onTap: { filterIndex = filter.rawValue }
                    )
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            Button(action: { showSettings = true }) {
                HStack(spacing: 8) {
                    Ph.gear.regular
                        .color(Color.cdTextSecondary)
                        .frame(width: 13, height: 13)
                    Text("Settings")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.cdTextSecondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
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
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func sidebarLabel(for filter: GalleryFilter) -> String {
        switch filter {
        case .all:        return "All Wallpapers"
        case .standard:   return "Static"
        case .dynamic:    return "Dynamic"
        case .appearance: return "Light & Dark"
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        let presets = filteredPresets
        Group {
            if isLoadingThumbnails && manager.presets.isEmpty == false && thumbnailCache.isEmpty {
                loadingSkeleton
            } else if manager.presets.isEmpty {
                emptyLibrary
            } else if presets.isEmpty {
                noResults
            } else {
                grid(presets: presets)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func grid(presets: [SavedPreset]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: 14, alignment: .top)],
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(presets) { preset in
                    GalleryCardView(
                        preset: preset,
                        thumbnail: thumbnailCache[preset.id],
                        isActive: manager.activePresetId == preset.id,
                        isSelected: selectedPresetId == preset.id,
                        isApplying: applyingPresetId == preset.id,
                        onTap: {
                            selectedPresetId = (selectedPresetId == preset.id) ? nil : preset.id
                        },
                        onApply: { applyPreset(preset) },
                        onEdit: {
                            selectedPresetId = nil
                            navigation.navigateToEditor(presetId: preset.id)
                        },
                        onDuplicate: { duplicate(preset) },
                        onRename: { startRename(preset) },
                        onRevealInFinder: { revealInFinder(preset) },
                        onDelete: { presetPendingDelete = preset }
                    )
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { selectedPresetId = nil }
        )
    }

    // MARK: - Empty states

    private var emptyLibrary: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.cdBgElevated, Color.cdBgSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.cdBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
                    .frame(width: 96, height: 96)
                Ph.image.regular
                    .color(Color.cdTextTertiary)
                    .frame(width: 40, height: 40)
            }

            VStack(spacing: 6) {
                Text("No wallpapers yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                Text("Create your first wallpaper to spread an image across your monitors. Static, dynamic, and light/dark presets are all supported.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cdTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button(action: { navigation.showCreationModal = true }) {
                HStack(spacing: 6) {
                    Ph.plus.bold
                        .color(.white)
                        .frame(width: 12, height: 12)
                    Text("New Wallpaper")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cdAccent)
                )
                .shadow(color: Color.cdAccent.opacity(0.32), radius: 12, y: 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cdBgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cdBorder, lineWidth: 1)
                    )
                    .frame(width: 64, height: 64)
                Ph.magnifyingGlass.regular
                    .color(Color.cdTextTertiary)
                    .frame(width: 24, height: 24)
            }

            Text("No matches")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.cdTextPrimary)

            Text(noResultsBody)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.cdTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Button(action: {
                filterIndex = 0
                searchQuery = ""
            }) {
                Text("Clear filters")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
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
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsBody: String {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            return "No wallpapers match \"\(q)\" in \(currentFilter.label)."
        }
        return "You don't have any \(currentFilter.label) wallpapers yet."
    }

    // MARK: - Skeleton

    private var loadingSkeleton: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: 14, alignment: .top)],
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(0..<8, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock()
                            .aspectRatio(16.0 / 10.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        HStack {
                            SkeletonBlock()
                                .frame(height: 14)
                                .clipShape(Capsule())
                                .frame(maxWidth: 140)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Actions

    private func countFor(_ filter: GalleryFilter) -> Int {
        switch filter {
        case .all:        return manager.presets.count
        case .standard:   return manager.presets.filter { !$0.isDynamic }.count
        case .dynamic:    return manager.presets.filter { $0.isDynamic && $0.wallpaperType == "Dynamic" }.count
        case .appearance: return manager.presets.filter { $0.wallpaperType == "Light/Dark" }.count
        }
    }

    private func reloadThumbnails() {
        isLoadingThumbnails = true
        thumbnailCache.removeAll()
        Task {
            await loadThumbnailsAsync()
            isLoadingThumbnails = false
        }
    }

    @MainActor
    private func loadThumbnailsAsync() async {
        let isDark = colorScheme == .dark
        for preset in manager.presets {
            let activeVariant: TimeVariant?
            if preset.wallpaperType == "Light/Dark" && preset.timeVariants.count == 2 {
                let sorted = preset.timeVariants.sorted { $0.hour > $1.hour }
                activeVariant = isDark ? sorted.last : sorted.first
            } else if preset.wallpaperType == "Dynamic" && !preset.timeVariants.isEmpty {
                let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
                let currentFraction = Double(now.hour ?? 12) / 24.0 + Double(now.minute ?? 0) / 1440.0
                activeVariant = preset.timeVariants.min(by: {
                    abs($0.dayFraction - currentFraction) < abs($1.dayFraction - currentFraction)
                })
            } else {
                activeVariant = nil
            }
            let filename = activeVariant?.imageFilename ?? preset.imageFilename
            let shouldFlip = activeVariant?.isFlipped ?? preset.isFlipped

            let dummy = SavedPreset(
                name: "", imageFilename: filename,
                offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
            )
            let url = manager.getImageUrl(for: dummy)
            guard let image = NSImage(contentsOf: url) else { continue }
            let maxDim: CGFloat = 480
            let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
            let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let thumb = NSImage(size: newSize)
            thumb.lockFocus()
            if shouldFlip {
                let t = NSAffineTransform()
                t.translateX(by: newSize.width, yBy: 0)
                t.scaleX(by: -1, yBy: 1)
                t.concat()
            }
            image.draw(in: NSRect(origin: .zero, size: newSize))
            thumb.unlockFocus()
            thumbnailCache[preset.id] = thumb
        }
    }

    private func applyPreset(_ preset: SavedPreset) {
        applyingPresetId = preset.id
        let url = manager.getImageUrl(for: preset)
        guard let image = NSImage(contentsOf: url) else {
            applyingPresetId = nil
            return
        }
        Task {
            await manager.setWallpaper(
                originalImage: image,
                imageOffset: CGSize(width: preset.offsetX, height: preset.offsetY),
                scale: preset.scale,
                previewScale: preset.previewScale,
                isFlipped: preset.isFlipped
            )
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    manager.setActivePreset(preset.id)
                }
                applyingPresetId = nil
                selectedPresetId = nil
            }
        }
    }

    private func duplicate(_ preset: SavedPreset) {
        var copy = preset
        copy.id = UUID()
        copy.name = "\(preset.name) copy"
        manager.presets.append(copy)
        manager.persistPresetsPublic()
        reloadThumbnails()
    }

    private func startRename(_ preset: SavedPreset) {
        renameDraft = preset.name
        presetPendingRename = preset
    }

    private func commitRename() {
        guard let target = presetPendingRename else { return }
        let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty,
           let idx = manager.presets.firstIndex(where: { $0.id == target.id }) {
            manager.presets[idx].name = trimmed
            manager.persistPresetsPublic()
        }
        presetPendingRename = nil
    }

    private func revealInFinder(_ preset: SavedPreset) {
        let url = manager.getImageUrl(for: preset)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Sidebar filter row

private struct FilterRow: View {
    let filter: GalleryFilter
    let label: String
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                icon
                    .frame(width: 14, height: 14)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.cdTextTertiary)
            }
            .foregroundStyle(isSelected ? Color.white : Color.cdTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.cdAccent : (hovering ? Color.cdBgHover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var icon: some View {
        let color: Color = isSelected ? .white : Color.cdTextSecondary
        switch filter {
        case .all:        Ph.squaresFour.regular.color(color)
        case .standard:   Ph.image.regular.color(color)
        case .dynamic:    Ph.sun.regular.color(color)
        case .appearance: Ph.circleHalf.regular.color(color)
        }
    }
}

// MARK: - Settings shell (in-window)

struct SettingsShell: View {
    let onClose: () -> Void

    var body: some View {
        SettingsInWindowView(onClose: onClose)
    }
}

// MARK: - Skeleton shimmer

private struct SkeletonBlock: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [Color.cdBgSecondary, Color.cdBgElevated, Color.cdBgSecondary],
                startPoint: .init(x: max(0, phase - 0.3), y: 0),
                endPoint: .init(x: min(1.3, phase + 0.3), y: 0)
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 2.0
            }
        }
    }
}
