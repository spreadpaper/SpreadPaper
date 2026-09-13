// SpreadPaper/Views/EditorView.swift

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PhosphorSwift

/// Editor screen: canvas, inspector and the save and apply flow for one preset.
struct EditorView: View {
    @Bindable var manager: WallpaperManager
    @Bindable var navigation: AppNavigation
    let presetId: UUID?

    @Environment(\.locale) private var locale

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
    @State private var hoveringAddSlot = false
    @State private var toastMessage: String? = nil
    @State private var settings = AppSettings.shared

    @State private var showingSaveDialog = false
    @State private var saveDialogApplyOnSave = false
    @State private var isApplying = false
    @State private var applyPulse = false

    /// Seeds the kind from the route so later switches stay local to the view.
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
        case .standard, .dynamic: return !loadedImages.isEmpty
        case .appearance: return loadedImages.count == 2
        }
    }

    /// A dynamic schedule with a single image is saved and applied as a static wallpaper.
    private var effectiveType: WallpaperType {
        wallpaperType == .dynamic && loadedImages.count < 2 ? .standard : wallpaperType
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
                    defaultName: fallbackScheduleName(for: idx),
                    nextVariant: nextVariantAfter(index: idx),
                    imageURL: idx < originalUrls.count ? originalUrls[idx] : nil,
                    position: schedulePosition(of: idx),
                    count: variants.count,
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
            if let presetId {
                if let preset = manager.presets.first(where: { $0.id == presetId }) {
                    loadExistingPreset(preset)
                }
            } else {
                importImages(navigation.takePendingImageURLs(), quiet: true)
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
            // Traffic-light horizontal clearance (vertical alignment is handled
            // by sizing the header to the traffic-light band).
            Color.clear.frame(width: 72, height: 1)

            Button(action: backToGallery) {
                HStack(spacing: 4) {
                    Ph.caretLeft.regular
                        .cdIcon(Color.cdTextSecondary, size: 12)
                    Text("Gallery")
                        .font(.cd(.body, .medium))
                        .foregroundStyle(Color.cdTextSecondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverRowButtonStyle())

            Rectangle().fill(Color.cdBorder).frame(width: 1, height: 18)

            Text(presetName.isEmpty ? "Untitled" : presetName)
                .font(.cd(.body, .semibold))
                .foregroundStyle(Color.cdTextPrimary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button(action: previewWallpaper) {
                HStack(spacing: 5) {
                    Ph.eye.regular
                        .cdIcon(Color.cdTextPrimary, size: 13)
                    Text("Preview")
                        .font(.cd(.body, .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
                }
                .padding(.horizontal, 12)
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(HeaderSecondaryButtonStyle())
            .disabled(!canSave || manager.isApplying)

            Button(action: { openSaveDialog(applyOnSave: false) }) {
                Text("Save")
                    .font(.cd(.body, .semibold))
                    .foregroundStyle(Color.cdTextPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HeaderSecondaryButtonStyle())
            .disabled(!canSave)

            Button(action: { openSaveDialog(applyOnSave: true) }) {
                HStack(spacing: 6) {
                    if isApplying {
                        ProgressView().controlSize(.small).tint(Color.cdTextPrimary)
                    }
                    Text(isApplying ? "Applying…" : "Save & Apply")
                        .font(.cd(.body, .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
                }
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.cdAccent)
                )
                .shadow(color: Color.cdAccent.opacity(0.3), radius: 8, y: 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isApplying || manager.isApplying)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
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
                onDropImages: { importImages($0) },
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
            hudIconButton(icon: Ph.minus.regular, label: "Zoom out", isActive: false, isEnabled: currentImage != nil) {
                setZoom(imageScaleBinding.wrappedValue - 0.1)
            }

            Text("\(Int((imageScaleBinding.wrappedValue * 100).rounded()))%")
                .font(.cd(.callout, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.cdTextPrimary)
                .frame(minWidth: 44)

            hudIconButton(icon: Ph.plus.regular, label: "Zoom in", isActive: false, isEnabled: currentImage != nil) {
                setZoom(imageScaleBinding.wrappedValue + 0.1)
            }

            Rectangle().fill(Color.cdHighlightStrokeSoft).frame(width: 1, height: 16).padding(.horizontal, 4)

            hudIconButton(icon: Ph.arrowsOutSimple.regular, label: "Fit to canvas", isActive: false, isEnabled: currentImage != nil) {
                fitImage()
            }

            hudIconButton(icon: Ph.arrowsLeftRight.regular, label: "Flip horizontally", isActive: isFlippedBinding.wrappedValue, isEnabled: currentImage != nil) {
                isFlippedBinding.wrappedValue.toggle()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cdBgPrimary.opacity(0.72))
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cdHighlightStrokeSoft, lineWidth: 1)
        )
        .shadow(color: .cdShadow, radius: 24, y: 8)
    }

    /// Icon-only HUD button with an active highlight. `label` carries its
    /// VoiceOver name.
    @ViewBuilder
    private func hudIconButton<I: View>(icon: I, label: LocalizedStringKey, isActive: Bool, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .frame(width: 14, height: 14)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(HUDButtonStyle(isActive: isActive))
        .accessibilityLabel(label)
        .disabled(!isEnabled)
    }

    /// Clamps zoom to 0.1...3 and animates the change.
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
                if manager.connectedScreens.count > 1 {
                    InspectorDivider()
                    displaysSection
                }
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
                options: WallpaperType.allCases.map { ($0, $0.title) }
            )
        } hint: {
            Text(wallpaperType.subtitle)
                .font(.cd(.callout))
                .foregroundStyle(Color.cdTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
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
                    Text("^[\(variants.count) time slot](inflect: true)")
                        .font(.cd(.callout))
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
        return dimensions(for: img)
    }

    /// Light or Dark slot row; an empty slot opens the file picker.
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

    /// Schedule row for one variant; tapping opens its detail modal.
    private func dynamicImageRow(index: Int) -> some View {
        let v = variants[index]
        let hasImage = index < loadedImages.count
        return ImageRow(
            thumb: hasImage ? loadedImages[index] : nil,
            title: defaultScheduleName(for: index),
            subtitle: v.timeString(locale: locale),
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
                    .cdIcon(hoveringAddSlot ? Color.cdTextSecondary : Color.cdTextTertiary, size: 12)
                Text("Add time slot")
                    .font(.cd(.callout, .medium))
                    .foregroundStyle(hoveringAddSlot ? Color.cdTextSecondary : Color.cdTextTertiary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(hoveringAddSlot ? Color.cdHoverFill : Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(
                        hoveringAddSlot ? Color.cdBorderStrong : Color.cdBorder,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(InspectorRowButtonStyle())
        .onHover { hoveringAddSlot = $0 }
        .animation(.easeInOut(duration: 0.12), value: hoveringAddSlot)
    }

    /// Pixel size as "width×height".
    private func dimensions(for image: NSImage) -> String {
        let pixelSize = image.pixelSize
        return "\(Int(pixelSize.width))×\(Int(pixelSize.height))"
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
                    .font(.cd(.callout, .medium))
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

    // MARK: - Displays

    /// Bezel widths live in AppSettings (hardware property) but are tuned here, against the
    /// live canvas. One synced pair of sliders by default; a toggle reveals per-display
    /// pairs for arrays with mixed frames. Only shown with two or more displays.
    private var displaysSection: some View {
        InspectorField(label: "Display bezels") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    bezelSlider(label: "Horizontal", value: allDisplaysBezelBinding(\.horizontal), disabled: settings.bezelPerDisplay)
                    bezelSlider(label: "Vertical", value: allDisplaysBezelBinding(\.vertical), disabled: settings.bezelPerDisplay)
                }

                NativeCheckbox(
                    label: "Set per display",
                    isOn: Binding(
                        get: { settings.bezelPerDisplay },
                        set: { perDisplay in
                            if !perDisplay { syncBezelsToFirstDisplay() }
                            settings.bezelPerDisplay = perDisplay
                        }
                    )
                )

                if settings.bezelPerDisplay {
                    ForEach(manager.connectedScreens) { display in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(display.name)
                                .font(.cd(.callout, .medium))
                                .foregroundStyle(Color.cdTextPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            bezelSlider(label: "Horizontal", value: displayBezelBinding(display.displayID, \.horizontal))
                            bezelSlider(label: "Vertical", value: displayBezelBinding(display.displayID, \.vertical))
                        }
                    }
                }
            }
            .onChange(of: settings.bezelWidths) { _, _ in manager.refreshScreens() }
        } hint: {
            Text("Frame width around each panel: horizontal for the left and right edges, vertical for top and bottom.")
                .font(.cd(.callout))
                .foregroundStyle(Color.cdTextTertiary)
        }
    }

    /// Reads the first display's edge and writes the value to every connected display.
    private func allDisplaysBezelBinding(_ edge: WritableKeyPath<Bezel, CGFloat>) -> Binding<CGFloat> {
        Binding(
            get: {
                guard let first = manager.connectedScreens.first else { return 0 }
                return settings.bezel(for: first.displayID)[keyPath: edge]
            },
            set: { newValue in
                for display in manager.connectedScreens {
                    var bezel = settings.bezel(for: display.displayID)
                    bezel[keyPath: edge] = newValue.rounded()
                    settings.setBezel(bezel, for: display.displayID)
                }
            }
        )
    }

    /// Reads and writes one edge of one display's bezel.
    private func displayBezelBinding(_ displayID: CGDirectDisplayID, _ edge: WritableKeyPath<Bezel, CGFloat>) -> Binding<CGFloat> {
        Binding(
            get: { settings.bezel(for: displayID)[keyPath: edge] },
            set: { newValue in
                var bezel = settings.bezel(for: displayID)
                bezel[keyPath: edge] = newValue.rounded()
                settings.setBezel(bezel, for: displayID)
            }
        )
    }

    /// Copies the first display's bezel to all others when leaving per-display mode.
    private func syncBezelsToFirstDisplay() {
        guard let first = manager.connectedScreens.first else { return }
        let bezel = settings.bezel(for: first.displayID)
        for display in manager.connectedScreens.dropFirst() {
            settings.setBezel(bezel, for: display.displayID)
        }
    }

    /// One labelled slider plus numeric field for a single bezel edge.
    private func bezelSlider(label: String, value: Binding<CGFloat>, disabled: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.cd(.subheadline))
                .foregroundStyle(Color.cdTextTertiary)
                .frame(width: 62, alignment: .leading)
            NativeRange(value: value, range: 0...150)
            TextField("0", value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = CGFloat($0) }),
                      format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.cd(.callout, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.cdTextPrimary)
                .frame(width: 34)
            Text("pt")
                .font(.cd(.callout))
                .foregroundStyle(Color.cdTextTertiary)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    // MARK: - Schedule helpers

    /// The image's own name, else a numbered stand-in when its file carries none.
    private func fallbackScheduleName(for index: Int) -> String {
        guard index < variants.count else { return "" }
        let resolved = FilenameUtils.displayName(for: variants[index].imageFilename)
        return resolved.isEmpty ? "Image \(index + 1)" : resolved
    }

    /// Variant's custom name, else the name its image carries.
    private func defaultScheduleName(for index: Int) -> String {
        guard index < variants.count else { return "" }
        let custom = variants[index].name
        return custom.isEmpty ? fallbackScheduleName(for: index) : custom
    }

    /// Where the variant sits once the day is read in time order.
    private func schedulePosition(of index: Int) -> Int {
        sortedVariantIndices.prefix { $0 != index }.count
    }

    /// The variant that starts next in the day, wrapping to the earliest one past midnight.
    private func nextVariantAfter(index: Int) -> TimeVariant {
        let sorted = sortedVariantIndices
        guard let pos = sorted.firstIndex(of: index) else { return variants[index] }
        let nextPos = (pos + 1) % sorted.count
        return variants[sorted[nextPos]]
    }

    // MARK: - Save flow

    /// Shows the name dialog, remembering whether saving should also apply.
    private func openSaveDialog(applyOnSave: Bool) {
        saveDialogApplyOnSave = applyOnSave
        showingSaveDialog = true
    }

    /// Persists the preset, then optionally applies it, marks it active and returns to the gallery.
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

    /// Flashes the canvas border once to confirm an apply.
    private func triggerApplyPulse() {
        applyPulse = true
        withAnimation(.easeOut(duration: 0.6)) {
            applyPulse = false
        }
    }

    /// Leaves the editor without saving.
    private func backToGallery() {
        navigation.navigateToGallery()
    }

    // MARK: - Behavior

    /// Changes the wallpaper kind and trims images the new kind cannot hold.
    /// Static and light/dark pin their slots to noon and midnight.
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

    /// Shows a message for two seconds unless a newer one has replaced it.
    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    /// Scales the selected image to cover the render canvas and centres it.
    private func fitImage() {
        guard let image = currentImage else { return }
        let canvas = manager.totalCanvas
        guard canvas.width > 0, canvas.height > 0 else { return }
        let pixelSize = image.pixelSize
        let widthRatio = canvas.width / pixelSize.width
        let heightRatio = canvas.height / pixelSize.height
        withAnimation(.spring()) {
            guard selectedVariantIndex < variants.count else { return }
            variants[selectedVariantIndex].scale = max(widthRatio, heightRatio)
            variants[selectedVariantIndex].offsetX = 0
            variants[selectedVariantIndex].offsetY = 0
        }
    }

    /// Opens the file picker; multiple selection only for dynamic wallpapers.
    private func addImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = wallpaperType == .dynamic
        guard panel.runModal() == .OK else { return }
        importImages(panel.urls)
    }

    /// Loads image files past the duplicate and limit checks and reports the outcome.
    /// With `quiet` the toast only appears when a file was left out.
    private func importImages(_ urls: [URL], quiet: Bool = false) {
        let fresh = urls.filter { !originalUrls.contains($0) }
        guard !fresh.isEmpty else {
            if !urls.isEmpty { showToast("Already added") }
            return
        }
        let room = maxImages - loadedImages.count
        guard room > 0 else {
            showToast("Limit is \(maxImages) image\(maxImages == 1 ? "" : "s")")
            return
        }
        let added = addImages(from: fresh)
        let overLimit = max(0, fresh.count - room)
        let unreadable = fresh.count - added - overLimit
        if overLimit > 0 {
            showToast("Added \(added), limit is \(maxImages)")
        } else if unreadable > 0 {
            showToast(added == 0 ? "Couldn't read image" : "Added \(added), skipped \(unreadable) unreadable")
        } else if !quiet {
            showToast("Added \(added) image\(added == 1 ? "" : "s")")
        }
    }

    /// Most images the current wallpaper type can hold.
    private var maxImages: Int {
        wallpaperType == .appearance ? 2 : wallpaperType == .dynamic ? 16 : 1
    }

    /// Appends readable images up to the type's limit and returns how many were added.
    /// Each slot gets the default time of day for its position.
    @discardableResult
    private func addImages(from urls: [URL]) -> Int {
        let dayPhases = [(7,0),(9,0),(12,0),(15,0),(17,0),(19,0),(21,0),(23,0),(1,0),(3,0),(5,0),(6,0),(8,0),(10,0),(14,0),(16,0)]
        let countBefore = loadedImages.count

        for url in urls {
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
        return loadedImages.count - countBefore
    }

    /// Drops a variant with its image and keeps the selection in range.
    private func removeVariant(at index: Int) {
        guard index < variants.count else { return }
        variants.remove(at: index)
        loadedImages.remove(at: index)
        originalUrls.remove(at: index)
        if selectedVariantIndex >= variants.count {
            selectedVariantIndex = max(0, variants.count - 1)
        }
    }

    /// Fills the editor from a saved preset, reading each variant's image from the app data directory.
    /// Light/dark variants are ordered light first.
    private func loadExistingPreset(_ preset: SavedPreset) {
        presetName = preset.name

        if preset.isDynamic && !preset.timeVariants.isEmpty {
            let sortedVariants: [TimeVariant]
            if preset.kind == .appearance {
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

    /// Applies the current state to the desktop without saving.
    private func previewWallpaper() {
        Task { await previewApply() }
    }

    /// Applies the current state through the manager call that matches the effective kind.
    /// Stamps the current preview scale on every variant first.
    private func previewApply() async {
        guard !loadedImages.isEmpty else { return }

        for i in variants.indices {
            variants[i].previewScale = currentPreviewScale
        }

        switch effectiveType {
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

    /// Updates the existing preset in place or saves a new one through the manager.
    private func persistCurrentPreset() {
        let name = presetName.isEmpty ? "Untitled" : presetName

        for i in variants.indices {
            variants[i].previewScale = currentPreviewScale
        }

        if let presetId, let index = manager.presets.firstIndex(where: { $0.id == presetId }) {
            manager.presets[index].name = name
            manager.presets[index].timeVariants = variants
            manager.presets[index].isAppearanceBased = (effectiveType == .appearance)
            manager.presets[index].isDynamic = (effectiveType != .standard)
            if let first = variants.first {
                manager.presets[index].offsetX = first.offsetX
                manager.presets[index].offsetY = first.offsetY
                manager.presets[index].scale = first.scale
                manager.presets[index].previewScale = currentPreviewScale
                manager.presets[index].isFlipped = first.isFlipped
            }
            manager.persistPresetsPublic()
        } else {
            if effectiveType == .standard, let firstUrl = originalUrls.first, let v = variants.first {
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
                    flipped: variants.map(\.isFlipped),
                    isAppearanceBased: wallpaperType == .appearance
                )
            }
        }
    }
}

// MARK: - Inspector primitives

/// Labelled inspector block with an optional hint under the control.
private struct InspectorField<Control: View>: View {
    let label: String
    @ViewBuilder var control: () -> Control
    var hint: (() -> AnyView)? = nil

    /// Field without a hint.
    init(label: String, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.control = control
        self.hint = nil
    }

    /// Field with a hint rendered under the control.
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
                .font(.cd(.callout, .medium))
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

/// Thin rule between inspector blocks.
private struct InspectorDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.cdBorder)
            .frame(height: 1)
            .padding(.bottom, 22)
    }
}

// MARK: - Native-styled select

/// Button-driven popover select for the inspector, used instead of `Menu` because its
/// borderless style draws a caret that ignores `.menuIndicator(.hidden)`.
struct NativeSelect<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
    @State private var isOpen = false

    var body: some View {
        Button(action: { isOpen.toggle() }) {
            HStack(spacing: 6) {
                Text(currentLabel)
                    .font(.cd(.body))
                    .foregroundStyle(Color.cdTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Ph.caretDown.regular
                    .cdIcon(Color.cdTextTertiary, size: 12)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(Color.cdBgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(options, id: \.0) { opt in
                    NativeSelectRow(
                        label: opt.1,
                        isSelected: opt.0 == selection,
                        action: {
                            selection = opt.0
                            isOpen = false
                        }
                    )
                }
            }
            .padding(.vertical, 4)
            .frame(minWidth: 220)
            .background(Color.cdBgElevated)
        }
    }

    private var currentLabel: String {
        options.first(where: { $0.0 == selection })?.1 ?? ""
    }
}

/// One popover option with hover highlight and a checkmark when selected.
private struct NativeSelectRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.cd(.body))
                    .foregroundStyle(Color.cdTextPrimary)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.cd(.subheadline, .semibold))
                        .foregroundStyle(Color.cdAccent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.cdBgHover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Native-feel range

/// Slider with a filled track and a round thumb, driven by a drag anywhere on the track.
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
                    .fill(Color.cdKnob)
                    .overlay(Circle().stroke(Color.cdOutlineOnLight, lineWidth: 0.5))
                    .frame(width: 18, height: 18)
                    .shadow(color: .cdShadow, radius: 1.5, y: 1)
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

/// Checkbox with a label; the whole row toggles.
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
                            .font(.cd(.caption, .bold))
                            .foregroundStyle(Color.cdTextPrimary)
                    }
                }
                Text(label)
                    .font(.cd(.body))
                    .foregroundStyle(Color.cdTextPrimary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ImageRow

/// Inspector row showing an image thumbnail, title and subtitle, or a dashed empty slot.
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
                        .font(.cd(.body, .medium))
                        .foregroundStyle(Color.cdTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .font(.cd(.subheadline))
                        .foregroundStyle(Color.cdTextTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
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
        .buttonStyle(InspectorRowButtonStyle())
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
                    .cdIcon(Color.cdTextTertiary, size: 12)
            }
            .frame(width: 56, height: 36)
        }
    }

    /// Resting, hovered and selected fills. Selection tints with the accent,
    /// hover only washes, so the two never read alike.
    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(fillColor)
    }

    /// Fill for the row's current state.
    private var fillColor: Color {
        if isSelected {
            return Color.cdAccent.opacity(hovering ? 0.30 : 0.22)
        }
        return hovering ? Color.cdHoverFill : Color.clear
    }

    private var borderColor: Color {
        isSelected ? Color.cdAccent : hovering ? Color.cdBorder : Color.clear
    }
}

/// Inspector row chrome: dips while the row is held down.
/// Hover and selection are drawn by the row itself.
private struct InspectorRowButtonStyle: ButtonStyle {
    /// Dims the row while it is pressed.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Button styles for editor

/// Transparent button that fills on hover.
private struct HoverRowButtonStyle: ButtonStyle {
    /// Elevated fill on hover, dimmed while pressed.
    func makeBody(configuration: Configuration) -> some View {
        HoverReader { hovering in
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hovering ? Color.cdBgElevated : Color.clear)
                )
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        }
    }
}

/// Header button chrome for Preview and Save. Dims when the button is disabled so
/// the enabled state is readable against the panel background.
private struct HeaderSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Bordered fill that brightens on hover and fades when disabled.
    func makeBody(configuration: Configuration) -> some View {
        HoverReader { hovering in
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hovering && isEnabled ? Color.cdBgHover : Color.cdBgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.cdBorderStrong, lineWidth: 1)
                )
                .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.8 : 1.0)
        }
    }
}

/// Translucent HUD button, highlighted while active.
private struct HUDButtonStyle: ButtonStyle {
    let isActive: Bool

    /// White wash for the active or hovered state, dimmed while pressed.
    func makeBody(configuration: Configuration) -> some View {
        HoverReader { hovering in
            configuration.label
                .foregroundStyle(isActive ? Color.cdTextPrimary : Color.cdTextSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            isActive
                                ? Color.cdActiveFill
                                : hovering ? Color.cdHoverFill : Color.clear
                        )
                )
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        }
    }
}

// MARK: - Small helpers

private extension String {
    /// The string itself, or `fallback` when it is empty.
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
