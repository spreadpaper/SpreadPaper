// SpreadPaper/Views/CreationModal.swift

import SwiftUI
import AppKit

/// Overlay for picking a wallpaper kind before a new editor opens, with an animated preview of each.
/// Arrow keys cycle, Return confirms, Escape dismisses.
struct CreationModal: View {
    @Bindable var navigation: AppNavigation
    let manager: WallpaperManager

    @State private var selectedType: WallpaperType = .standard
    @State private var monitorScale: CGFloat = 1.0
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNs

    private var displayCount: Int { manager.connectedScreens.count }

    var body: some View {
        ZStack {
            BackdropBlur()
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            Color.cdOverlayScrim
                .ignoresSafeArea()
                .allowsHitTesting(false)

            modalCard
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1.0 : 0.985)
                .offset(y: hasAppeared ? 0 : 8)
        }
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.34)) {
                hasAppeared = true
            }
        }
        .background(KeyboardHandler(
            onLeft: { cycle(by: -1) },
            onRight: { cycle(by: 1) },
            onReturn: { confirm() },
            onEscape: { dismiss() }
        ))
    }

    // MARK: - Card

    private var modalCard: some View {
        VStack(spacing: 0) {
            HeroView(selectedType: selectedType, monitorScale: monitorScale)
                .frame(height: 260)
                .clipped()
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.cdBorder).frame(height: 1)
                }

            VStack(spacing: 20) {
                // Head
                VStack(spacing: 6) {
                    Text("NEW WALLPAPER")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Color.cdAccent.opacity(0.9))
                    Text("Let's make something beautiful.")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.48)
                        .foregroundStyle(Color.cdTextPrimary)
                }

                PillPicker(selection: $selectedType, namespace: pillNs, onChange: handleTypeChange)

                Caption(type: selectedType)

                Footer(
                    displayCount: displayCount,
                    selectedType: selectedType,
                    onCancel: { dismiss() },
                    onContinue: { confirm() }
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 26)
            .padding(.bottom, 26)
        }
        .frame(width: 600)
        .background(Color.cdBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            // Subtle inner highlight on the top edge
            LinearGradient(
                colors: [Color.cdHighlightStrokeSoft, .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 1)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            CloseButton(action: dismiss)
                .padding(14)
        }
        .shadow(color: .cdShadowStrong, radius: 80, y: 30)
    }

    // MARK: - Behavior

    /// Bounces the monitor illustration on a kind change; skipped under Reduce Motion.
    private func handleTypeChange(from old: WallpaperType, to new: WallpaperType) {
        guard old != new, !reduceMotion else { return }
        monitorScale = 0.96
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            withAnimation(.easeOut(duration: 0.26)) {
                monitorScale = 1.0
            }
        }
    }

    /// Moves the selection by `delta` through the kinds, wrapping at both ends.
    private func cycle(by delta: Int) {
        let order = WallpaperType.allCases
        guard let idx = order.firstIndex(of: selectedType) else { return }
        let next = order[(idx + delta + order.count) % order.count]
        let prev = selectedType
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)) {
            selectedType = next
        }
        handleTypeChange(from: prev, to: next)
    }

    /// Opens a new editor for the selected kind.
    private func confirm() {
        navigation.navigateToNewEditor(type: selectedType)
    }

    /// Closes the modal without creating anything.
    private func dismiss() {
        navigation.showCreationModal = false
    }
}

// MARK: - Backdrop blur

/// In-window HUD blur behind the card.
private struct BackdropBlur: NSViewRepresentable {
    /// Built once; material and state never change afterwards.
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .withinWindow
        v.state = .active
        return v
    }
    /// Nothing changes after creation.
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Close button

/// Glass close button in the card's top-right corner.
private struct CloseButton: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cdBgElevated.opacity(0.75))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cdBorder, lineWidth: 1)
                    )
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(hover ? Color.cdTextPrimary : Color.cdTextSecondary)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Hero

/// Card header: tinted glow plus the three-monitor illustration for the selected kind.
private struct HeroView: View {
    let selectedType: WallpaperType
    let monitorScale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Nothing in the hero moves unless Light & Dark is up and motion is allowed.
    private var isStill: Bool {
        reduceMotion || selectedType != .appearance
    }

    var body: some View {
        // One clock for every panel and the credit, so the whole spread turns on the same instant.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isStill)) { context in
            let elapsed = HeroCrossfade.elapsed(at: context.date, reduceMotion: reduceMotion)
            scene(elapsed: elapsed)
                .overlay(alignment: .bottom) { credit(elapsed: elapsed) }
        }
    }

    /// Tinted glow behind the three-monitor illustration for the selected kind.
    private func scene(elapsed: TimeInterval) -> some View {
        ZStack {
            Color.cdCanvasBg
            RadialGradient(
                colors: [selectedType.tint.opacity(0.28), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 280
            )
            .animation(.easeInOut(duration: 0.4), value: selectedType)

            GeometryReader { geo in
                let inset = (top: 40.0, sides: 40.0, bottom: 50.0)
                let groupRect = CGRect(
                    x: inset.sides,
                    y: inset.top,
                    width: geo.size.width - inset.sides * 2,
                    height: geo.size.height - inset.top - inset.bottom
                )
                MonitorGroup(selectedType: selectedType, elapsed: elapsed)
                    .frame(width: groupRect.width, height: groupRect.height)
                    .position(x: groupRect.midX, y: groupRect.midY)
                    .scaleEffect(monitorScale)
            }
        }
    }

    /// Attribution for the kind on screen, hidden outright for the kind that has none.
    private func credit(elapsed: TimeInterval) -> some View {
        ZStack {
            // A faded-out credit still hit-tests and still reads aloud, over the one on show.
            PhotoCredit(photo: .day)
                .opacity(selectedType == .standard ? 1 : 0)
                .allowsHitTesting(selectedType == .standard)
                .accessibilityHidden(selectedType != .standard)
            ThemedCredit(elapsed: elapsed)
                .opacity(selectedType == .appearance ? 1 : 0)
                .allowsHitTesting(selectedType == .appearance)
                .accessibilityHidden(selectedType != .appearance)
        }
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.4), value: selectedType)
    }
}

/// Attribution for one hero photograph, linking the photographer and Unsplash.
private struct PhotoCredit: View {
    let photo: HeroPhoto

    var body: some View {
        HStack(spacing: 0) {
            Text("Photo by ")
            Link(photo.photographer, destination: photo.profile)
                .underline()
            Text(" on ")
            Link("Unsplash", destination: photo.page)
                .underline()
        }
        .font(.system(size: 10))
        .foregroundStyle(Color.cdTextSecondary)
        .tint(Color.cdTextSecondary)
    }
}

/// Credit for whichever photograph the Light & Dark hero is showing.
/// One name hands over to the other as the dissolve passes halfway.
private struct ThemedCredit: View {
    let elapsed: TimeInterval

    var body: some View {
        ZStack {
            ForEach(HeroPhoto.allCases, id: \.self) { photo in
                let opacity = HeroCrossfade.creditOpacity(of: photo, at: elapsed)
                PhotoCredit(photo: photo)
                    .opacity(opacity)
                    .allowsHitTesting(opacity > 0)
                    .accessibilityHidden(opacity == 0)
            }
        }
    }
}

/// Where the three hero panels sit inside the one scene they share.
/// Side panels are shorter than the main one and centred on it.
struct HeroSpread: Equatable {
    /// Space between two panels, which the scene runs on behind.
    static let gap: CGFloat = 6

    /// Panel width over panel height.
    static let aspectRatio: CGFloat = 16.0 / 10.0

    /// Side panel height over the main one's.
    static let sideRatio: CGFloat = 0.82

    /// Size of the scene the three panels are cut from.
    let spread: CGSize

    /// The left panel's rectangle inside the scene.
    let left: CGRect

    /// The main panel's rectangle inside the scene.
    let main: CGRect

    /// The right panel's rectangle inside the scene.
    let right: CGRect

    /// Lays the three panels out for a hero of the given height.
    init(height: CGFloat) {
        let mainWidth = height * Self.aspectRatio
        let sideHeight = height * Self.sideRatio
        let sideWidth = sideHeight * Self.aspectRatio
        let sideTop = (height - sideHeight) / 2
        spread = CGSize(width: sideWidth * 2 + mainWidth + Self.gap * 2, height: height)
        left = CGRect(x: 0, y: sideTop, width: sideWidth, height: sideHeight)
        main = CGRect(x: left.maxX + Self.gap, y: 0, width: mainWidth, height: height)
        right = CGRect(x: main.maxX + Self.gap, y: sideTop, width: sideWidth, height: sideHeight)
    }

    /// The part of the scene one panel shows.
    func slice(_ position: MonitorPosition) -> PanelSlice {
        switch position {
        case .leftSide: PanelSlice(spread: spread, frame: left)
        case .main: PanelSlice(spread: spread, frame: main)
        case .rightSide: PanelSlice(spread: spread, frame: right)
        }
    }
}

/// Three 16:10 monitors, a full-height main one flanked by two smaller, centred in the hero.
private struct MonitorGroup: View {
    let selectedType: WallpaperType
    let elapsed: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let layout = HeroSpread(height: geo.size.height)

            HStack(spacing: HeroSpread.gap) {
                ForEach(MonitorPosition.allCases, id: \.self) { position in
                    let slice = layout.slice(position)
                    Monitor(width: slice.frame.width, height: slice.frame.height) {
                        SceneStack(selectedType: selectedType, slice: slice, elapsed: elapsed)
                    }
                }
            }
            .frame(width: layout.spread.width, height: layout.spread.height, alignment: .center)
            .offset(x: (geo.size.width - layout.spread.width) / 2)
        }
    }
}

/// Rounded monitor bezel that clips its scene content.
private struct Monitor<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
        }
        .frame(width: width, height: height)
        .background(Color.cdBgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.cdHighlightStroke, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .inset(by: 1)
                .stroke(Color.cdHighlightStrokeSoft, lineWidth: 1)
        )
        .shadow(color: .cdShadowStrong, radius: 40, y: 20)
    }
}

// MARK: - Scenes

/// Which of the three illustration monitors a scene is drawn on.
enum MonitorPosition: CaseIterable {
    case leftSide, main, rightSide
}

/// Cross-fades the three kind scenes so switching kinds animates in place.
private struct SceneStack: View {
    let selectedType: WallpaperType
    let slice: PanelSlice
    let elapsed: TimeInterval

    var body: some View {
        ZStack {
            SpreadPhoto(slice: slice)
                .opacity(selectedType == .standard ? 1 : 0)
            ThemedScene(slice: slice, elapsed: elapsed)
                .opacity(selectedType == .appearance ? 1 : 0)
            DynamicScene(slice: slice)
                .opacity(selectedType == .dynamic ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.4), value: selectedType)
    }
}

/// The day photograph turning into the night one and back, on a slow loop.
/// Both slice alike, so this panel stays continuous with its neighbours.
private struct ThemedScene: View {
    let slice: PanelSlice
    let elapsed: TimeInterval

    var body: some View {
        ZStack {
            SpreadPhoto(slice: slice, photo: .day)
            SpreadPhoto(slice: slice, photo: .night)
                .opacity(HeroCrossfade.nightOpacity(at: elapsed))
        }
    }
}

/// One day-cycle ribbon spread across the monitors, with a travelling sun dot and a filling timeline.
/// Ribbon, dot and timeline run on behind the gaps, so one loop crosses all three.
private struct DynamicScene: View {
    let slice: PanelSlice
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cycle: TimeInterval = 8.0

    var body: some View {
        SpreadContent(slice: slice) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    LinearGradient(
                        stops: SceneArt.dayCycleStops,
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
                        let phase = phase(at: context.date)
                        ZStack {
                            let dotSize = h * 0.18
                            let dotX = w * (0.06 + 0.88 * phase)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: SceneArt.dayCycleMarker,
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: dotSize / 2
                                    )
                                )
                                .frame(width: dotSize, height: dotSize)
                                .blur(radius: 1)
                                .position(x: dotX, y: h * 0.24 + dotSize / 2)

                            let trackInset: CGFloat = w * 0.06
                            let trackWidth = w - trackInset * 2
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(SceneArt.timelineTrack)
                                    .frame(width: trackWidth, height: 2)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: SceneArt.timelineFill,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(2, trackWidth * (0.05 + 0.95 * phase)), height: 6)
                                    .offset(y: -2)
                            }
                            .position(x: w / 2, y: h * (1 - 0.14))
                        }
                    }
                }
            }
        }
    }

    /// Position in the loop from 0 to 1; fixed at midway under Reduce Motion.
    private func phase(at date: Date) -> CGFloat {
        if reduceMotion { return 0.5 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        return CGFloat(t / cycle)
    }
}

// MARK: - Pill picker

/// Segmented kind picker whose accent indicator slides between pills.
private struct PillPicker: View {
    @Binding var selection: WallpaperType
    let namespace: Namespace.ID
    let onChange: (WallpaperType, WallpaperType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WallpaperType.allCases, id: \.self) { type in
                let isActive = type == selection
                Button(action: { tap(type) }) {
                    HStack(spacing: 8) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 14, height: 14)
                        Text(type.title)
                            .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                    }
                    .foregroundStyle(isActive ? Color.cdTextPrimary : Color.cdTextSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .background {
                        if isActive {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cdAccent)
                                .matchedGeometryEffect(id: "pillIndicator", in: namespace)
                                .shadow(color: Color.cdAccent.opacity(0.32), radius: 12, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cdHighlightStroke, lineWidth: 1)
                                        .mask(
                                            LinearGradient(
                                                colors: [Color.white, .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.cdBgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
    }

    /// Animates the selection change and reports it to the parent.
    private func tap(_ new: WallpaperType) {
        let old = selection
        guard old != new else { return }
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)) {
            selection = new
        }
        onChange(old, new)
    }
}

// MARK: - Caption

/// Kind title and subtitle as one centred run of text.
private struct Caption: View {
    let type: WallpaperType

    private var copy: (lead: String, body: String) {
        ("\(type.title).", " \(type.subtitle)")
    }

    var body: some View {
        let c = copy
        (
            Text(c.lead)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.cdTextPrimary)
            +
            Text(c.body)
                .font(.system(size: 14))
                .foregroundColor(Color.cdTextSecondary)
        )
        .multilineTextAlignment(.center)
        .lineSpacing(14 * 0.5)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
    }
}

// MARK: - Footer

/// Display-count hint plus the Cancel and Continue buttons.
private struct Footer: View {
    let displayCount: Int
    let selectedType: WallpaperType
    let onCancel: () -> Void
    let onContinue: () -> Void

    private var hintText: String {
        if displayCount > 0 {
            return "\(displayCount) display\(displayCount == 1 ? "" : "s") detected"
        }
        return "displays detected"
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.cdSuccess)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.cdSuccess.opacity(0.6), radius: 4)
                Text(hintText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdTextTertiary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cdTextSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.cdBorder, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onContinue) {
                    Text("Continue with \(selectedType.title)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cdTextPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.cdAccent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.cdHighlightStroke, lineWidth: 1)
                                .mask(
                                    LinearGradient(
                                        colors: [Color.white, .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: Color.cdAccent.opacity(0.32), radius: 12, y: 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

// MARK: - Keyboard handler

/// Invisible first responder that maps arrow, Return and Escape keys to the modal's actions.
private struct KeyboardHandler: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onReturn: () -> Void
    let onEscape: () -> Void

    /// Creates the key view and tries for first responder on the next run-loop turn.
    func makeNSView(context: Context) -> KeyView {
        let v = KeyView()
        v.onLeft = onLeft
        v.onRight = onRight
        v.onReturn = onReturn
        v.onEscape = onEscape
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }

    /// Keeps the callbacks current across re-renders.
    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onLeft = onLeft
        nsView.onRight = onRight
        nsView.onReturn = onReturn
        nsView.onEscape = onEscape
    }

    /// NSView that accepts first responder and forwards key presses.
    final class KeyView: NSView {
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        var onReturn: (() -> Void)?
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        /// Reclaims first responder whenever the view lands in a window.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }

        /// Routes the handled key codes; everything else passes up the chain.
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: onLeft?()    // ←
            case 124: onRight?()   // →
            case 36, 76: onReturn?() // Return / numpad enter
            case 53: onEscape?()   // Esc
            default: super.keyDown(with: event)
            }
        }
    }
}
