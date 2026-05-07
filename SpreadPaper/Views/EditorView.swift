// SpreadPaper/Views/EditorView.swift

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PhosphorSwift

struct EditorView: View {
    @Bindable var manager: WallpaperManager
    @Bindable var navigation: AppNavigation
    let presetId: UUID?

    @State private var wallpaperType: WallpaperType
    @State private var loadedImages: [NSImage] = []
    @State private var originalUrls: [URL] = []
    @State private var variants: [TimeVariant] = []
    @State private var selectedVariantIndex: Int = 0
    /// Stable session ID used as the HEIC directory key for unsaved appearance presets.
    @State private var editorSessionId = UUID()

    @State private var currentPreviewScale: CGFloat = 1.0
    @State private var presetName = ""
    @State private var editingScheduleIndex: Int? = nil
    @State private var toastMessage: String? = nil

    @State private var showingSaveDialog = false
    @State private var saveDialogApplyOnSave = false
    @State private var isApplying = false
    @State private var applyPulse = false

    init(manager: WallpaperManager, navigation: AppNavigation, wallpaperType: WallpaperType, presetId: UUID?) {
        self.manager = manager
        self.navigation = navigation
        self.presetId = presetId
        _wallpaperType = State(initialValue: wallpaperType)
    }

    private var currentImage: NSImage? {
        guard !loadedImages.isEmpty, selectedVariantIndex < loadedImages.count else { return nil }
        return loadedImages[selectedVariantIndex]
    }

    private var imageOffsetBinding: Binding<CGSize> {
        Binding(
            get: {
                guard selectedVariantIndex < variants.count else { return .zero }
                let v = variants[selectedVariantIndex]
                return CGSize(width: v.offsetX, height: v.offsetY)
            },
            set: {
                guard selectedVariantIndex < variants.count else { return }
                variants[selectedVariantIndex].offsetX = $0.width
                variants[selectedVariantIndex].offsetY = $0.height
            }
        )
    }

    private var imageScaleBinding: Binding<CGFloat> {
        Binding(
            get: { selectedVariantIndex < variants.count ? variants[selectedVariantIndex].scale : 1.0 },
            set: { if selectedVariantIndex < variants.count { variants[selectedVariantIndex].scale = $0 } }
        )
    }

    private var isFlippedBinding: Binding<Bool> {
        Binding(
            get: { selectedVariantIndex < variants.count ? variants[selectedVariantIndex].isFlipped : false },
            set: { if selectedVariantIndex < variants.count { variants[selectedVariantIndex].isFlipped = $0 } }
        )
    }

    private var canSave: Bool {
        switch wallpaperType {
        case .standard: return !loadedImages.isEmpty
        case .appearance: return loadedImages.count == 2
        case .dynamic: return loadedImages.count >= 2
        }
    }

    var body: some View {
        ZStack {
            mainLayout

            if showingSaveDialog {
                SaveDialog(
                    initialName: presetName.isEmpty ? "Untitled" : presetName,
                    applyOnSave: saveDialogApplyOnSave,
                    onCancel: { showingSaveDialog = false },
                    onSave: { name in
                        presetName = name
                        showingSaveDialog = false
                        handleSaveCommit(apply: saveDialogApplyOnSave)
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }

            if let idx = editingScheduleIndex, idx < variants.count {
                ScheduleDetailModal(
                    variant: $variants[idx],
                    defaultName: defaultScheduleName(for: idx),
                    nextVariant: nextVariantAfter(index: idx),
                    onRemove: {
                        editingScheduleIndex = nil
                        removeVariant(at: idx)
                    },
                    onDone: { editingScheduleIndex = nil }
                )
                .zIndex(11)
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .animation(.easeInOut(duration: 0.18), value: showingSaveDialog)
        .onChange(of: selectedVariantIndex) { _, newIndex in
            if newIndex < variants.count && variants[newIndex].scale <= 0.1 {
                fitImage()
            }
        }
        .onAppear {
            if let presetId, let preset = manager.presets.first(where: { $0.id == presetId }) {
                loadExistingPreset(preset)
            }
        }
    }

    // MARK: - Main layout

    private var mainLayout: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.cdBorder).frame(height: 1)

            HStack(spacing: 0) {
                canvasArea
                Rectangle().fill(Color.cdBorder).frame(width: 1)
                inspector
            }
        }
        .background(Color.cdBgPrimary)
    }

    // MARK: - Header (56pt)

    private var header: some View {
        HStack(spacing: 14) {
            // Traffic-light clearance handled by window; left-padding = 80pt
            Color.clear.frame(width: 72, height: 1)

            Button(action: backToGallery) {
                HStack(spacing: 4) {
                    Ph.caretLeft.regular
                        .color(Color.cdTextSecondary)
                        .frame(width: 12, height: 12)
                    Text("Gallery")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.cdTextSecondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverRowButtonStyle())

            Rectangle().fill(Color.cdBorder).frame(width: 1, height: 18)

            Text(presetName.isEmpty ? "Untitled" : presetName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cdTextPrimary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button(action: previewWallpaper) {
                HStack(spacing: 5) {
                    Ph.eye.regular
                        .color(Color.cdTextSecondary)
                        .frame(width: 13, height: 13)
                    Text("Preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.cdTextSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(HeaderSecondaryButtonStyle())
            .disabled(!canSave)

            Button(action: { openSaveDialog(applyOnSave: false) }) {
                Text("Save")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HeaderSecondaryButtonStyle())
            .disabled(!canSave)

            Button(action: { openSaveDialog(applyOnSave: true) }) {
                HStack(spacing: 6) {
                    if isApplying {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(isApplying ? "Applying…" : "Save & Apply")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.cdAccent)
                )
                .shadow(color: Color.cdAccent.opacity(0.3), radius: 8, y: 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isApplying)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.cdBgPrimary)
    }

    // MARK: - Canvas area

    private var canvasArea: some View {
        ZStack {
            Color.cdCanvasBg

            EditorCanvasView(
                selectedImage: currentImage,
                imageOffset: imageOffsetBinding,
                imageScale: imageScaleBinding,
                isFlipped: isFlippedBinding,
                manager: manager,
                onSelectImage: addImages,
                onDropImage: { _ in },
                currentPreviewScale: $currentPreviewScale
            )
            .padding(64)

            VStack {
                Spacer()
                canvasHUD
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.cdAccent.opacity(applyPulse ? 0.5 : 0), lineWidth: 2)
        )
    }

    // MARK: - Floating canvas HUD

    private var canvasHUD: some View {
        HStack(spacing: 2) {
            hudIconButton(icon: Ph.minus.regular, isActive: false, isEnabled: currentImage != nil) {
                setZoom(imageScaleBinding.wrappedValue - 0.1)
            }

            Text("\(Int((imageScaleBinding.wrappedValue * 100).rounded()))%")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.cdTextPrimary)
                .frame(minWidth: 44)

            hudIconButton(icon: Ph.plus.regular, isActive: false, isEnabled: currentImage != nil) {
                setZoom(imageScaleBinding.wrappedValue + 0.1)
            }

            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 16).padding(.horizontal, 4)

            hudIconButton(icon: Ph.arrowsOutSimple.regular, isActive: false, isEnabled: currentImage != nil) {
                fitImage()
            }

            hudIconButton(icon: Ph.arrowsLeftRight.regular, isActive: isFlippedBinding.wrappedValue, isEnabled: currentImage != nil) {
                isFlippedBinding.wrappedValue.toggle()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0x18181c).opacity(0.72))
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, y: 8)
    }

    @ViewBuilder
    private func hudIconButton<I: View>(icon: I, isActive: Bool, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .frame(width: 14, height: 14)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(HUDButtonStyle(isActive: isActive))
        .disabled(!isEnabled)
    }

    private func setZoom(_ v: CGFloat) {
        let clamped = min(3.0, max(0.1, v))
        withAnimation(.easeOut(duration: 0.12)) {
            imageScaleBinding.wrappedValue = clamped
        }
    }

    // MARK: - Inspector

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                typeSection
                InspectorDivider()
                imagesSection
                InspectorDivider()
                zoomSection
                InspectorDivider()
                orientationSection
                Spacer(minLength: 0)
            }
            .padding(28)
        }
        .frame(width: 340)
        .background(Color.cdBgSecondary)
    }

    private var typeSection: some View {
        InspectorField(label: "Type") {
            NativeSelect<WallpaperType>(
                selection: Binding(
                    get: { wallpaperType },
                    set: { switchType(to: $0) }
                ),
                options: [
                    (.standard, "Static"),
                    (.appearance, "Light & Dark"),
                    (.dynamic, "Dynamic (time of day)")
                ]
            )
        } hint: {
            Text(typeHint)
                .font(.system(size: 12))
                .foregroundStyle(Color.cdTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var typeHint: String {
        switch wallpaperType {
        case .standard:   return "One image, stretched seamlessly across every display."
        case .appearance: return "A light image by day, a darker one by night — switched by macOS appearance."
        case .dynamic:    return "A schedule of images that shifts through the day, in sync across all screens."
        }
    }

    // MARK: - Images

    @ViewBuilder
    private var imagesSection: some View {
        switch wallpaperType {
        case .standard:
            InspectorField(label: "Image") {
                staticImageRow
            }
        case .appearance:
            InspectorField(label: "Images") {
                VStack(spacing: 6) {
                    appearanceImageRow(index: 0, label: "Light")
                    appearanceImageRow(index: 1, label: "Dark")
                }
            }
        case .dynamic:
            InspectorField(label: "Schedule") {
                VStack(spacing: 6) {
                    ForEach(Array(sortedVariantIndices.enumerated()), id: \.element) { _, idx in
                        dynamicImageRow(index: idx)
                    }
                    dashedAddSlot
                }
            } hint: {
                if !variants.isEmpty {
                    Text("\(variants.count) time slot\(variants.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cdTextTertiary)
                }
            }
        }
    }

    private var staticImageRow: some View {
        ImageRow(
            thumb: loadedImages.first,
            title: variants.first.map { FilenameUtils.displayName(for: $0.imageFilename).ifEmpty("Untitled") } ?? "",
            subtitle: staticSubtitle,
            isSelected: !loadedImages.isEmpty,
            isEmpty: loadedImages.isEmpty,
            onTap: {
                if loadedImages.isEmpty { addImages() }
                else { selectedVariantIndex = 0 }
            }
        )
    }

    private var staticSubtitle: String {
        guard let img = loadedImages.first else { return "Choose image…" }
        return "\(Int(img.size.width))×\(Int(img.size.height))"
    }

    private func appearanceImageRow(index: Int, label: String) -> some View {
        let hasImage = index < loadedImages.count
        return ImageRow(
            thumb: hasImage ? loadedImages[index] : nil,
            title: label,
            subtitle: hasImage ? dimensions(for: loadedImages[index]) : "Choose image…",
            isSelected: hasImage && selectedVariantIndex == index,
            isEmpty: !hasImage,
            onTap: {
                if hasImage {
                    selectedVariantIndex = index
                } else {
                    addImages()
                }
            }
        )
    }

    private var sortedVariantIndices: [Int] {
        variants.indices.sorted { variants[$0].dayFraction < variants[$1].dayFraction }
    }

    private func dynamicImageRow(index: Int) -> some View {
        let v = variants[index]
        let hasImage = index < loadedImages.count
        return ImageRow(
            thumb: hasImage ? loadedImages[index] : nil,
            title: defaultScheduleName(for: index),
            subtitle: "\(v.timeString) · tap to edit",
            isSelected: selectedVariantIndex == index,
            isEmpty: !hasImage,
            onTap: {
                selectedVariantIndex = index
                editingScheduleIndex = index
            },
            onDelete: { removeVariant(at: index) }
        )
    }

    private var dashedAddSlot: some View {
        Button(action: addImages) {
            HStack(spacing: 8) {
                Ph.plus.regular
                    .color(Color.cdTextTertiary)
                    .frame(width: 12, height: 12)
                Text("Add time slot")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.cdTextTertiary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(
                        Color.cdBorder,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dimensions(for image: NSImage) -> String {
        "\(Int(image.size.width))×\(Int(image.size.height))"
    }

    // MARK: - Zoom

    private var zoomSection: some View {
        InspectorField(label: "Zoom") {
            HStack(spacing: 12) {
                NativeRange(
                    value: imageScaleBinding,
                    range: 0.5...3.0
                )
                Text("\(Int((imageScaleBinding.wrappedValue * 100).rounded()))%")
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.cdTextPrimary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    // MARK: - Orientation

    private var orientationSection: some View {
        InspectorField(label: "Orientation") {
            NativeCheckbox(
                label: "Mirror horizontally",
                isOn: isFlippedBinding
            )
        }
    }

    // MARK: - Schedule helpers

    private func defaultScheduleName(for index: Int) -> String {
        guard index < variants.count else { return "" }
        let variant = variants[index]
        if !variant.name.isEmpty { return variant.name }
        let resolved = FilenameUtils.displayName(for: variant.imageFilename)
        return resolved.isEmpty ? "Image \(index + 1)" : resolved
    }

    private func nextVariantAfter(index: Int) -> TimeVariant {
        let sorted = sortedVariantIndices
        guard let pos = sorted.firstIndex(of: index) else { return variants[index] }
        let nextPos = (pos + 1) % sorted.count
        return variants[sorted[nextPos]]
    }

    // MARK: - Save flow

    private func openSaveDialog(applyOnSave: Bool) {
        saveDialogApplyOnSave = applyOnSave
        showingSaveDialog = true
    }

    private func handleSaveCommit(apply: Bool) {
        persistCurrentPreset()
        if apply {
            isApplying = true
            Task {
                await previewApply()
                await MainActor.run {
                    isApplying = false
                    triggerApplyPulse()
                    navigation.navigateToGallery()
                    if let pid = presetId ?? manager.presets.last?.id {
                        manager.setActivePreset(pid)
                    }
                }
            }
        } else {
            showToast("Saved")
        }
    }

    private func triggerApplyPulse() {
        applyPulse = true
        withAnimation(.easeOut(duration: 0.6)) {
            applyPulse = false
        }
    }

    private func backToGallery() {
        navigation.navigateToGallery()
    }

    // MARK: - Behavior (reused from prior version)

    private func switchType(to newType: WallpaperType) {
        guard newType != wallpaperType else { return }
        let oldCount = loadedImages.count

        let keep: Int
        switch newType {
        case .standard: keep = min(1, oldCount)
        case .appearance: keep = min(2, oldCount)
        case .dynamic: keep = oldCount
        }

        if keep < oldCount {
            variants = Array(variants.prefix(keep))
            loadedImages = Array(loadedImages.prefix(keep))
            originalUrls = Array(originalUrls.prefix(keep))
            let removed = oldCount - keep
            showToast("Removed \(removed) image\(removed == 1 ? "" : "s")")
        }

        switch newType {
        case .standard:
            if !variants.isEmpty {
                variants[0].hour = 12
                variants[0].minute = 0
            }
        case .appearance:
            if variants.indices.contains(0) {
                variants[0].hour = 12
                variants[0].minute = 0
            }
            if variants.indices.contains(1) {
                variants[1].hour = 0
                variants[1].minute = 0
            }
        case .dynamic:
            break
        }

        selectedVariantIndex = min(selectedVariantIndex, max(0, variants.count - 1))
        withAnimation(.easeInOut(duration: 0.12)) {
            wallpaperType = newType
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func fitImage() {
        guard let image = currentImage else { return }
        let canvas = manager.totalCanvas
        guard canvas.width > 0, canvas.height > 0 else { return }
        let widthRatio = canvas.width / image.size.width
        let heightRatio = canvas.height / image.size.height
        withAnimation(.spring()) {
            guard selectedVariantIndex < variants.count else { return }
            variants[selectedVariantIndex].scale = max(widthRatio, heightRatio)
            variants[selectedVariantIndex].offsetX = 0
            variants[selectedVariantIndex].offsetY = 0
        }
    }

    private func addImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = wallpaperType == .dynamic
        guard panel.runModal() == .OK else { return }

        let dayPhases = [(7,0),(9,0),(12,0),(15,0),(17,0),(19,0),(21,0),(23,0),(1,0),(3,0),(5,0),(6,0),(8,0),(10,0),(14,0),(16,0)]
        let maxImages = wallpaperType == .appearance ? 2 : wallpaperType == .dynamic ? 16 : 1

        for url in panel.urls {
            guard loadedImages.count < maxImages else { break }
            guard let image = NSImage(contentsOf: url) else { continue }

            let slot = loadedImages.count
            let hour: Int
            let minute: Int
            if wallpaperType == .appearance {
                hour = slot == 0 ? 12 : 0; minute = 0
            } else if wallpaperType == .dynamic {
                (hour, minute) = slot < dayPhases.count ? dayPhases[slot] : (min(slot + 7, 23), 0)
            } else {
                hour = 12; minute = 0
            }

            loadedImages.append(image)
            originalUrls.append(url)
            variants.append(TimeVariant(imageFilename: url.lastPathComponent, hour: hour, minute: minute))
        }

        if !loadedImages.isEmpty {
            selectedVariantIndex = loadedImages.count - 1
            if loadedImages.count == 1 {
                fitImage()
            }
        }
    }

    private func removeVariant(at index: Int) {
        guard index < variants.count else { return }
        variants.remove(at: index)
        loadedImages.remove(at: index)
        originalUrls.remove(at: index)
        if selectedVariantIndex >= variants.count {
            selectedVariantIndex = max(0, variants.count - 1)
        }
    }

    private func loadExistingPreset(_ preset: SavedPreset) {
        presetName = preset.name

        if preset.isDynamic && !preset.timeVariants.isEmpty {
            let sortedVariants: [TimeVariant]
            if preset.wallpaperType == "Light/Dark" {
                sortedVariants = preset.timeVariants.sorted { $0.hour > $1.hour }
            } else {
                sortedVariants = preset.timeVariants
            }
            variants = sortedVariants
            loadedImages = []
            originalUrls = []
            for variant in sortedVariants {
                let url = manager.getImageUrl(for: SavedPreset(
                    name: "", imageFilename: variant.imageFilename,
                    offsetX: 0, offsetY: 0, scale: 1, previewScale: 1, isFlipped: false
                ))
                if let img = NSImage(contentsOf: url) {
                    loadedImages.append(img)
                    originalUrls.append(url)
                }
            }
            selectedVariantIndex = 0
        } else {
            let url = manager.getImageUrl(for: preset)
            if let img = NSImage(contentsOf: url) {
                loadedImages = [img]
                originalUrls = [url]
                variants = [
                    TimeVariant(
                        imageFilename: preset.imageFilename,
                        hour: 12,
                        minute: 0
                    )
                ]
                variants[0].offsetX = preset.offsetX
                variants[0].offsetY = preset.offsetY
                variants[0].scale = preset.scale
                variants[0].previewScale = preset.previewScale
                variants[0].isFlipped = preset.isFlipped
            }
        }
    }

    private var currentOffset: CGSize {
        guard selectedVariantIndex < variants.count else { return .zero }
        let v = variants[selectedVariantIndex]
        return CGSize(width: v.offsetX, height: v.offsetY)
    }
    private var currentScale: CGFloat {
        selectedVariantIndex < variants.count ? variants[selectedVariantIndex].scale : 1.0
    }
    private var currentFlip: Bool {
        selectedVariantIndex < variants.count ? variants[selectedVariantIndex].isFlipped : false
    }

    private func previewWallpaper() {
        Task { await previewApply() }
    }

    private func previewApply() async {
        guard !loadedImages.isEmpty else { return }

        for i in variants.indices {
            variants[i].previewScale = currentPreviewScale
        }

        switch wallpaperType {
        case .standard:
            guard let image = loadedImages.first else { return }
            await manager.setWallpaper(
                originalImage: image, imageOffset: currentOffset,
                scale: currentScale, previewScale: currentPreviewScale, isFlipped: currentFlip
            )
        case .dynamic:
            guard variants.count >= 2 else { return }
            let v = variants.first ?? variants[0]
            let preset = SavedPreset(
                name: presetName.isEmpty ? "Untitled" : presetName, imageFilename: "",
                offsetX: v.offsetX, offsetY: v.offsetY,
                scale: v.scale, previewScale: currentPreviewScale, isFlipped: v.isFlipped,
                isDynamic: true, timeVariants: variants
            )
            await manager.applyDynamicWallpaper(preset: preset, images: loadedImages, previewScale: currentPreviewScale)
        case .appearance:
            guard loadedImages.count == 2, variants.count == 2 else { return }
            let appearancePreset = SavedPreset(
                id: presetId ?? editorSessionId,
                name: presetName.isEmpty ? "Untitled" : presetName,
                imageFilename: variants[0].imageFilename,
                offsetX: variants[0].offsetX, offsetY: variants[0].offsetY,
                scale: variants[0].scale, previewScale: currentPreviewScale,
                isFlipped: variants[0].isFlipped,
                isDynamic: true, timeVariants: variants
            )
            await manager.applyAppearanceWallpaper(
                preset: appearancePreset,
                lightImage: loadedImages[0], darkImage: loadedImages[1],
                lightVariant: variants[0], darkVariant: variants[1]
            )
        }
    }

    private func persistCurrentPreset() {
        let name = presetName.isEmpty ? "Untitled" : presetName

        for i in variants.indices {
            variants[i].previewScale = currentPreviewScale
        }

        if let presetId, let index = manager.presets.firstIndex(where: { $0.id == presetId }) {
            manager.presets[index].name = name
            manager.presets[index].timeVariants = variants
            if let first = variants.first {
                manager.presets[index].offsetX = first.offsetX
                manager.presets[index].offsetY = first.offsetY
                manager.presets[index].scale = first.scale
                manager.presets[index].previewScale = currentPreviewScale
                manager.presets[index].isFlipped = first.isFlipped
            }
            manager.persistPresetsPublic()
        } else {
            if wallpaperType == .standard, let firstUrl = originalUrls.first, let v = variants.first {
                manager.savePreset(
                    name: name,
                    originalUrl: firstUrl,
                    offset: CGSize(width: v.offsetX, height: v.offsetY),
                    scale: v.scale,
                    previewScale: currentPreviewScale,
                    isFlipped: v.isFlipped
                )
            } else {
                manager.saveDynamicPreset(
                    name: name,
                    imageUrls: originalUrls,
                    hours: variants.map(\.hour),
                    minutes: variants.map(\.minute),
                    offsets: variants.map { CGSize(width: $0.offsetX, height: $0.offsetY) },
                    scales: variants.map(\.scale),
                    previewScale: currentPreviewScale,
                    flipped: variants.map(\.isFlipped)
                )
            }
        }
    }
}

// MARK: - Inspector primitives

private struct InspectorField<Control: View>: View {
    let label: String
    @ViewBuilder var control: () -> Control
    var hint: (() -> AnyView)? = nil

    init(label: String, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.control = control
        self.hint = nil
    }

    init<H: View>(
        label: String,
        @ViewBuilder control: @escaping () -> Control,
        @ViewBuilder hint: @escaping () -> H
    ) {
        self.label = label
        self.control = control
        self.hint = { AnyView(hint()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cdTextSecondary)

            control()

            if let hint {
                hint()
                    .padding(.top, -2)
            }
        }
        .padding(.bottom, 28)
    }
}

private struct InspectorDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.cdBorder)
            .frame(height: 1)
            .padding(.bottom, 22)
    }
}

// MARK: - Native-styled select

struct NativeSelect<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { opt in
                Button(opt.1) { selection = opt.0 }
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cdTextPrimary)
                Spacer()
                Ph.caretDown.regular
                    .color(Color.cdTextTertiary)
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.cdBgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var currentLabel: String {
        options.first(where: { $0.0 == selection })?.1 ?? ""
    }
}

// MARK: - Native-feel range

struct NativeRange: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        GeometryReader { geo in
            let fraction = max(0, min(1, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            let w = geo.size.width
            let thumbX = w * CGFloat(fraction)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.cdBgElevated)
                    .frame(height: 4)

                Capsule()
                    .fill(Color.cdTextSecondary)
                    .frame(width: thumbX, height: 4)

                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                    .offset(x: thumbX - 9)
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let frac = max(0, min(1, v.location.x / w))
                        value = range.lowerBound + CGFloat(frac) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 18)
    }
}

// MARK: - Native-feel checkbox

struct NativeCheckbox: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isOn ? Color.cdAccent : Color.cdBgPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isOn ? Color.cdAccent : Color.cdBorder, lineWidth: 1)
                        )
                        .frame(width: 18, height: 18)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cdTextPrimary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ImageRow

struct ImageRow: View {
    let thumb: NSImage?
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isEmpty: Bool
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                thumbnailView
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.isEmpty ? "Untitled" : title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.cdTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.cdTextTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                if isSelected && !isEmpty {
                    Circle()
                        .fill(Color.cdAccent)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.cdAccent.opacity(0.5), radius: 3)
                        .padding(.trailing, 2)
                }
            }
            .padding(8)
            .frame(minHeight: 52)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .contextMenu {
            if let onDelete {
                Button("Remove", role: .destructive, action: onDelete)
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 36)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.cdBgPrimary)
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.cdBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                Ph.plus.regular
                    .color(Color.cdTextTertiary)
                    .frame(width: 12, height: 12)
            }
            .frame(width: 56, height: 36)
        }
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(
                isSelected
                    ? Color.cdBgElevated
                    : hovering ? Color.cdBgHover : Color.clear
            )
    }

    private var borderColor: Color {
        isSelected ? Color.cdBorderStrong : Color.clear
    }
}

// MARK: - Button styles for editor

private struct HoverRowButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hovering ? Color.cdBgElevated : Color.clear)
            )
            .onHover { hovering = $0 }
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

private struct HeaderSecondaryButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hovering ? Color.cdBgElevated : Color.cdBgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .onHover { hovering = $0 }
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

private struct HUDButtonStyle: ButtonStyle {
    let isActive: Bool
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? Color.cdTextPrimary : Color.cdTextSecondary)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        isActive
                            ? Color.white.opacity(0.08)
                            : hovering ? Color.white.opacity(0.05) : Color.clear
                    )
            )
            .onHover { hovering = $0 }
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Small helpers

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
