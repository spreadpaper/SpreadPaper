// SpreadPaper/Views/GalleryView.swift

import SwiftUI
import AppKit
import os
import PhosphorSwift

/// Thumbnail trouble goes here; the gallery banner carries only plain copy for the user.
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpreadPaper", category: "gallery")

/// Home screen: filter sidebar, search toolbar and the preset grid with apply, edit and manage actions.
struct GalleryView: View {
    @Bindable var manager: WallpaperManager
    @Bindable var navigation: AppNavigation
    @Environment(\.colorScheme) var colorScheme

    @State private var filterIndex: Int = 0
    @State private var searchQuery: String = ""
    @State private var thumbnailCache: [UUID: NSImage] = [:]
    @State private var loadPhase: GalleryPhase = .loading
    @State private var loadRun: UUID = UUID()
    @State private var loadDelivery: Task<Void, Never>? = nil
    @State private var passGate = ThumbnailPassGate.shared
    @State private var reportedPresets: Set<UUID> = []
    @State private var hasDismissedFailure: Bool = false
    @State private var selectedPresetId: UUID? = nil
    @State private var applyingPresetId: UUID? = nil
    @State private var presetPendingDelete: SavedPreset? = nil
    @State private var presetPendingRename: SavedPreset? = nil
    @State private var renameDraft: String = ""
    @State private var toastMessage: String? = nil
    @State private var isImportingLegacy: Bool = false
    @FocusState private var searchFocused: Bool
    @Environment(\.openSettings) private var openSettings

    // MARK: - Derived

    private var currentFilter: GalleryFilter {
        GalleryFilter(rawValue: filterIndex) ?? .all
    }

    private var filteredPresets: [SavedPreset] {
        let byFilter = presets(matching: currentFilter)

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return byFilter }
        return byFilter.filter { $0.name.range(of: q, options: .caseInsensitive) != nil }
    }

    var body: some View {
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
                if let error = manager.lastError {
                    errorBanner(error)
                }
                if manager.needsLegacyImport && !manager.hasDismissedLegacyImport {
                    LegacyImportBanner(
                        isImporting: isImportingLegacy,
                        onImport: { runLegacyImport() },
                        onDismiss: { manager.hasDismissedLegacyImport = true },
                        onSuppress: { manager.suppressLegacyImportBanner() }
                    )
                }
                if loadPhase == .failed && !hasDismissedFailure {
                    thumbnailFailureBanner
                }
                mainContent
            }
            .background(Color.cdBgPrimary)
        }
        .toast($toastMessage)
        .task { reloadThumbnails() }
        .onChange(of: colorScheme) { _, _ in reloadThumbnails() }
        .onChange(of: manager.presets.map(\.id)) { _, _ in reloadThumbnails() }
        .onChange(of: passGate.outstanding) { _, outstanding in
            guard outstanding == 0, passGate.takeHeldRequest() else { return }
            reloadThumbnails()
        }
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

    // MARK: - Error banner

    /// Surfaces `WallpaperManager.lastError` until dismissed.
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.cdDanger)
            Text(message)
                .font(.cd(.callout))
                .foregroundStyle(Color.cdTextPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button {
                manager.lastError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.cd(.subheadline, .semibold))
                    .foregroundStyle(Color.cdTextSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.cdDanger.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cdBorder).frame(height: 1)
        }
    }

    // MARK: - Thumbnail failure banner

    /// Says the previews stopped arriving, and offers another attempt at them.
    /// The attempt is withheld while the pass that stopped is still parked
    /// inside its read, since a second pass cannot reach it.
    private var thumbnailFailureBanner: some View {
        let canRetry = passGate.canStart
        return HStack(spacing: 10) {
            Ph.image.regular
                .cdIcon(Color.cdTextSecondary, size: 14)
            Text(GalleryLoading.failureMessage(outstandingPasses: passGate.outstanding))
                .font(.cd(.callout))
                .foregroundStyle(Color.cdTextPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button(action: { reloadThumbnails() }) {
                Text("Try again")
                    .font(.cd(.callout, .medium))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.cdBgElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cdBorder, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRetry)
            .opacity(canRetry ? 1 : 0.45)
            .help(canRetry ? "Load the previews again" : "Waiting for the last attempt to stop")
            Button {
                hasDismissedFailure = true
            } label: {
                Image(systemName: "xmark")
                    .font(.cd(.subheadline, .semibold))
                    .foregroundStyle(Color.cdTextSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.cdBgSecondary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cdBorder).frame(height: 1)
        }
    }

    // MARK: - Toolbar (height 52)

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(toolbarTitle)
                .font(.cd(.body, .semibold))
                .foregroundStyle(Color.cdTextPrimary)

            Text("^[\(filteredPresets.count) item](inflect: true)")
                .font(.cd(.callout))
                .monospacedDigit()
                .foregroundStyle(Color.cdTextTertiary)

            Spacer(minLength: 0)

            searchField

            Button(action: { navigation.showCreationModal = true }) {
                HStack(spacing: 6) {
                    Ph.plus.bold
                        .cdIcon(Color.cdTextPrimary, size: 12)
                    Text("New Wallpaper")
                        .font(.cd(.callout, .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
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
        currentFilter.label
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Ph.magnifyingGlass.regular
                .cdIcon(Color.cdTextTertiary, size: 12)
            TextField("Search", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.cd(.callout))
                .foregroundStyle(Color.cdTextPrimary)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Text("esc")
                        .font(.cd(.subheadline))
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
        .animation(.easeInOut(duration: 0.12), value: searchFocused)
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
                .font(.cd(.subheadline, .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.cdTextTertiary)
                .padding(.top, 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            VStack(spacing: 1) {
                ForEach(GalleryFilter.allCases, id: \.self) { filter in
                    FilterRow(
                        filter: filter,
                        label: filter.label,
                        isSelected: filterIndex == filter.rawValue,
                        count: countFor(filter),
                        onTap: { filterIndex = filter.rawValue }
                    )
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            Button(action: { openSettings() }) {
                HStack(spacing: 8) {
                    Ph.gear.regular
                        .cdIcon(Color.cdTextSecondary, size: 13)
                    Text("Settings")
                        .font(.cd(.callout, .medium))
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

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        let presets = filteredPresets
        Group {
            if loadPhase == .loading && manager.presets.isEmpty == false && thumbnailCache.isEmpty {
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

    /// Adaptive card grid; tapping the empty background clears the selection.
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
                        isThumbnailPending: GalleryLoading.isPending(
                            presetId: preset.id,
                            reported: reportedPresets,
                            phase: loadPhase
                        ),
                        isActive: manager.activePresetId == preset.id,
                        isSelected: selectedPresetId == preset.id,
                        isApplying: applyingPresetId == preset.id,
                        applyDisabled: manager.isApplying && applyingPresetId != preset.id,
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
                    .shadow(color: .cdShadow, radius: 18, y: 6)
                    .frame(width: 96, height: 96)
                Ph.image.regular
                    .cdIcon(Color.cdTextTertiary, size: 40)
            }

            VStack(spacing: 6) {
                Text("No wallpapers yet")
                    .font(.cd(.title2, .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                Text("Create your first wallpaper to spread an image across your monitors. Static, dynamic, and light/dark presets are all supported.")
                    .font(.cd(.body))
                    .foregroundStyle(Color.cdTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button(action: { navigation.showCreationModal = true }) {
                HStack(spacing: 6) {
                    Ph.plus.bold
                        .cdIcon(Color.cdTextPrimary, size: 12)
                    Text("New Wallpaper")
                        .font(.cd(.body, .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
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
                    .cdIcon(Color.cdTextTertiary, size: 24)
            }

            Text("No matches")
                .font(.cd(.title3, .semibold))
                .foregroundStyle(Color.cdTextPrimary)

            Text(noResultsBody)
                .font(.cd(.callout))
                .foregroundStyle(Color.cdTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Button(action: {
                filterIndex = 0
                searchQuery = ""
            }) {
                Text("Clear filters")
                    .font(.cd(.callout, .medium))
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

    /// Number of presets the sidebar row for `filter` would show.
    private func countFor(_ filter: GalleryFilter) -> Int {
        presets(matching: filter).count
    }

    /// Presets whose kind the filter selects; every preset for `.all`.
    private func presets(matching filter: GalleryFilter) -> [SavedPreset] {
        guard let type = filter.type else { return manager.presets }
        return manager.presets.filter { $0.kind == type }
    }

    /// Rebuilds every card thumbnail off-main from a main-actor snapshot of the presets,
    /// picking the variant that matches the current appearance or time of day. A pass
    /// already out is left to finish, its request held until that one is back.
    private func reloadThumbnails() {
        guard passGate.request() else { return }
        let run = UUID()
        loadRun = run
        loadPhase = .loading
        hasDismissedFailure = false
        thumbnailCache.removeAll()
        reportedPresets.removeAll()

        // Snapshot all main-actor data on main, then hand the rest off.
        let isDark = colorScheme == .dark
        let jobs: [ThumbnailJob] = manager.presets.map { preset in
            let activeVariant: TimeVariant?
            if preset.isAppearanceBased && preset.timeVariants.count == 2 {
                let sorted = preset.timeVariants.sorted { $0.hour > $1.hour }
                activeVariant = isDark ? sorted.last : sorted.first
            } else if preset.isDynamic && !preset.isAppearanceBased && !preset.timeVariants.isEmpty {
                let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
                let currentFraction = Double(now.hour ?? 12) / 24.0 + Double(now.minute ?? 0) / 1440.0
                activeVariant = preset.timeVariants.min(by: {
                    abs($0.dayFraction - currentFraction) < abs($1.dayFraction - currentFraction)
                })
            } else {
                activeVariant = nil
            }
            let filename = activeVariant?.imageFilename ?? preset.imageFilename
            let dummy = SavedPreset(
                name: "", imageFilename: filename,
                offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
            )
            return ThumbnailJob(
                presetId: preset.id,
                imageURL: manager.getImageUrl(for: dummy),
                shouldFlip: activeVariant?.isFlipped ?? preset.isFlipped
            )
        }

        // Match the screen's backing scale so Retina cards stay sharp.
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let maxPixelSize = Int((CGFloat(thumbnailMaxPointSize) * scale).rounded())

        let requested = jobs.count

        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        let render = Task.detached(priority: .userInitiated) {
            renderThumbnails(jobs: jobs, maxPixelSize: maxPixelSize) { event in
                continuation.yield(event)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in render.cancel() }

        // Never cancelled: the count has to come down even when the gallery
        // that started the pass is long gone.
        Task {
            await render.value
            passGate.passReturned()
        }

        loadDelivery?.cancel()
        loadDelivery = Task {
            let outcome = await ThumbnailRun.consume(
                events,
                stopping: continuation,
                requested: requested,
                onEvent: { event in report(event, run: run, scale: scale) }
            )
            finish(run: run, outcome: outcome)
        }
    }

    /// Settles one card, unless a newer run replaced this one. A card whose
    /// image could not be read is settled too, and stops waiting.
    ///
    /// - Parameters:
    ///   - event: What came of that card's job.
    ///   - run: Identifier of the run that reported it.
    ///   - scale: Backing scale it was rendered for.
    private func report(_ event: ThumbnailEvent, run: UUID, scale: CGFloat) {
        guard loadRun == run else { return }
        reportedPresets.insert(event.presetId)
        guard case .rendered(let result) = event else { return }
        let size = NSSize(
            width: CGFloat(result.image.width) / scale,
            height: CGFloat(result.image.height) / scale
        )
        thumbnailCache[result.presetId] = NSImage(cgImage: result.image, size: size)
    }

    /// Leaves the loading state, unless a newer run has replaced this one.
    /// Whatever went short reaches the log, not the user.
    ///
    /// - Parameters:
    ///   - run: Identifier of the run that ended.
    ///   - outcome: How it ended.
    private func finish(run: UUID, outcome: ThumbnailRunOutcome) {
        guard loadRun == run else { return }
        loadPhase = GalleryLoading.phase(after: outcome)
        guard let note = GalleryLoading.logNote(for: outcome) else { return }
        switch note.level {
        case .info:
            logger.info("\(note.message, privacy: .public)")
        case .error:
            logger.error("\(note.message, privacy: .public)")
        }
    }

    /// Loads the preset's images and hands them to the matching apply call, marking the card busy.
    /// The preset becomes active once the apply finishes.
    private func applyPreset(_ preset: SavedPreset) {
        applyingPresetId = preset.id

        if preset.isDynamic {
            let variants = preset.timeVariants.sorted { $0.dayFraction < $1.dayFraction }
            var images: [NSImage] = []
            for variant in variants {
                let dummy = SavedPreset(
                    name: "", imageFilename: variant.imageFilename,
                    offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
                )
                if let img = NSImage(contentsOf: manager.getImageUrl(for: dummy)) {
                    images.append(img)
                }
            }
            guard images.count == variants.count else {
                applyingPresetId = nil
                return
            }
            Task {
                if preset.kind == .appearance, images.count == 2, variants.count == 2 {
                    await manager.applyAppearanceWallpaper(
                        preset: preset,
                        lightImage: images[0], darkImage: images[1],
                        lightVariant: variants[0], darkVariant: variants[1]
                    )
                } else {
                    await manager.applyDynamicWallpaper(
                        preset: preset,
                        images: images,
                        previewScale: preset.previewScale
                    )
                }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        manager.setActivePreset(preset.id)
                    }
                    applyingPresetId = nil
                    selectedPresetId = nil
                }
            }
        } else {
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
    }

    /// Appends a copy with a fresh id and a " copy" suffix, then persists.
    private func duplicate(_ preset: SavedPreset) {
        var copy = preset
        copy.id = UUID()
        copy.name = "\(preset.name) copy"
        manager.presets.append(copy)
        manager.persistPresetsPublic()
        reloadThumbnails()
    }

    /// Opens the rename alert seeded with the preset's current name.
    private func startRename(_ preset: SavedPreset) {
        renameDraft = preset.name
        presetPendingRename = preset
    }

    /// Applies the trimmed draft name, ignoring blank input, and closes the alert.
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

    /// Asks for the folder holding an earlier version's wallpapers, then confirms what arrived.
    private func runLegacyImport() {
        guard let url = LegacyImportFlow.chooseFolderToImport(manager: manager) else { return }
        isImportingLegacy = true
        Task {
            let count = await manager.importLegacyLibrary(from: url)
            isImportingLegacy = false
            if let count {
                toastMessage = LegacyImportFlow.importedMessage(count: count)
            }
        }
    }

    /// Selects the preset's stored image in Finder.
    private func revealInFinder(_ preset: SavedPreset) {
        let url = manager.getImageUrl(for: preset)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Sidebar filter row

/// One sidebar row: icon, label and count; accent-filled when selected.
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
                    .font(.cd(.body, isSelected ? .semibold : .medium))
                Spacer()
                Text("\(count)")
                    .font(.cd(.subheadline, .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.cdTextPrimary.opacity(0.75) : Color.cdTextTertiary)
            }
            .foregroundStyle(isSelected ? Color.cdTextPrimary : Color.cdTextSecondary)
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

    private var icon: some View {
        Image(systemName: filter.systemImage)
            .font(.cd(.subheadline, .semibold))
            .foregroundStyle(isSelected ? Color.cdTextPrimary : Color.cdTextSecondary)
    }
}

// MARK: - Skeleton shimmer

/// Shimmering placeholder shown while thumbnails render.
struct SkeletonBlock: View {
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
        // Scoped to `phase` on purpose. A repeating `withAnimation` started from `onAppear` leaks
        // into unrelated state changes elsewhere in the window, e.g. the search field's border.
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false), value: phase)
        .onAppear { phase = 2.0 }
    }
}
