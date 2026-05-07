// SpreadPaper/Views/CreationModal.swift

import SwiftUI
import AppKit

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

            Color.black.opacity(0.55)
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
                colors: [Color.white.opacity(0.04), .clear],
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
        .shadow(color: .black.opacity(0.6), radius: 80, y: 30)
    }

    // MARK: - Behavior

    private func handleTypeChange(from old: WallpaperType, to new: WallpaperType) {
        guard old != new, !reduceMotion else { return }
        monitorScale = 0.96
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            withAnimation(.easeOut(duration: 0.26)) {
                monitorScale = 1.0
            }
        }
    }

    private func cycle(by delta: Int) {
        let order: [WallpaperType] = [.standard, .appearance, .dynamic]
        guard let idx = order.firstIndex(of: selectedType) else { return }
        let next = order[(idx + delta + order.count) % order.count]
        let prev = selectedType
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)) {
            selectedType = next
        }
        handleTypeChange(from: prev, to: next)
    }

    private func confirm() {
        navigation.navigateToNewEditor(type: selectedType)
    }

    private func dismiss() {
        navigation.showCreationModal = false
    }
}

// MARK: - Backdrop blur

private struct BackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .withinWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Close button

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

private struct HeroView: View {
    let selectedType: WallpaperType
    let monitorScale: CGFloat

    var body: some View {
        ZStack {
            Color.cdCanvasBg
            RadialGradient(
                colors: [tint(for: selectedType), .clear],
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
                MonitorGroup(selectedType: selectedType)
                    .frame(width: groupRect.width, height: groupRect.height)
                    .position(x: groupRect.midX, y: groupRect.midY)
                    .scaleEffect(monitorScale)
            }
        }
    }

    private func tint(for type: WallpaperType) -> Color {
        switch type {
        case .standard:   return Color(hex: 0xc97a3a).opacity(0.28)
        case .appearance: return Color(hex: 0xcaa060).opacity(0.18)
        case .dynamic:    return Color(hex: 0x8c7ad9).opacity(0.28)
        }
    }
}

private struct MonitorGroup: View {
    let selectedType: WallpaperType

    var body: some View {
        GeometryReader { geo in
            // Layout: side(0.85), main(1.0), side(0.85) — main is full height with 16:10 aspect.
            let h = geo.size.height
            let mainH = h
            let mainW = mainH * (16.0 / 10.0)
            let sideH = h * 0.82
            let sideW = sideH * (16.0 / 10.0)
            let gap: CGFloat = 6
            let totalW = sideW + gap + mainW + gap + sideW
            let startX = (geo.size.width - totalW) / 2

            HStack(spacing: gap) {
                Monitor(width: sideW, height: sideH) {
                    SceneStack(
                        selectedType: selectedType,
                        position: .leftSide
                    )
                }
                Monitor(width: mainW, height: mainH) {
                    SceneStack(
                        selectedType: selectedType,
                        position: .main
                    )
                }
                Monitor(width: sideW, height: sideH) {
                    SceneStack(
                        selectedType: selectedType,
                        position: .rightSide
                    )
                }
            }
            .frame(width: totalW, height: h, alignment: .center)
            .offset(x: startX)
        }
    }
}

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
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .inset(by: 1)
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 40, y: 20)
    }
}

// MARK: - Scenes

private enum MonitorPosition {
    case leftSide, main, rightSide
}

private struct SceneStack: View {
    let selectedType: WallpaperType
    let position: MonitorPosition

    var body: some View {
        ZStack {
            StaticScene(position: position)
                .opacity(selectedType == .standard ? 1 : 0)
            ThemedScene(position: position)
                .opacity(selectedType == .appearance ? 1 : 0)
            DynamicScene(position: position)
                .opacity(selectedType == .dynamic ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.4), value: selectedType)
    }
}

// Static — one warm sunset image, continuous across the 3 monitors
private struct StaticScene: View {
    let position: MonitorPosition

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let extraScale: CGFloat = 1.7
            let contentW = w * extraScale
            let xOffset: CGFloat = {
                switch position {
                case .leftSide:  return  0.35 * w
                case .main:      return  0
                case .rightSide: return -0.35 * w
                }
            }()

            ZStack {
                // Background gradients
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0x3a3050), Color(hex: 0x1d2036)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [Color(hex: 0x8a4fa3).opacity(0.85), .clear],
                        center: UnitPoint(x: 0.85, y: 0.9),
                        startRadius: 0,
                        endRadius: contentW * 0.55
                    )
                    RadialGradient(
                        colors: [Color(hex: 0xd79a55).opacity(0.95), .clear],
                        center: UnitPoint(x: 0.20, y: 0.20),
                        startRadius: 0,
                        endRadius: contentW * 0.5
                    )

                    // Sun (only visible when un-clipped portion includes 0.18 x of contentW)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: 0xf4e4a0), Color(hex: 0xd69a2a)],
                                center: .center,
                                startRadius: 0,
                                endRadius: contentW * 0.075
                            )
                        )
                        .frame(width: contentW * 0.14, height: contentW * 0.14)
                        .shadow(color: Color(hex: 0xd69a2a).opacity(0.7), radius: 30)
                        .position(x: contentW * 0.18, y: h * 0.22 + (contentW * 0.07))
                }

                // Hills silhouette
                HillsShape()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: 0x1d1a2b)],
                            startPoint: .top,
                            endPoint: .init(x: 0.5, y: 0.85)
                        )
                    )
                    .frame(height: h * 0.4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: contentW, height: h)
            .offset(x: xOffset - (contentW - w) / 2)
        }
    }
}

private struct HillsShape: Shape {
    // Polygon: 0,100  0,55  18,30  35,50  55,25  75,48  100,30  100,100
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        func pt(_ xPct: CGFloat, _ yPct: CGFloat) -> CGPoint {
            CGPoint(x: w * xPct / 100, y: h * yPct / 100)
        }
        p.move(to: pt(0, 100))
        p.addLine(to: pt(0, 55))
        p.addLine(to: pt(18, 30))
        p.addLine(to: pt(35, 50))
        p.addLine(to: pt(55, 25))
        p.addLine(to: pt(75, 48))
        p.addLine(to: pt(100, 30))
        p.addLine(to: pt(100, 100))
        p.closeSubpath()
        return p
    }
}

// Themed — light variant on left monitor, dark on main + right (with moon + stars on main)
private struct ThemedScene: View {
    let position: MonitorPosition

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            switch position {
            case .leftSide:
                lightVariant(w: w, h: h)
            case .main:
                darkVariant(w: w, h: h, showMoon: true, showStars: true)
            case .rightSide:
                darkVariant(w: w, h: h, showMoon: false, showStars: true)
            }
        }
    }

    private func lightVariant(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xe4cf8e), Color(hex: 0xcba06f)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(hex: 0xebdeb2).opacity(0.95), .clear],
                center: UnitPoint(x: 0.30, y: 0.30),
                startRadius: 0,
                endRadius: w * 0.55
            )
            // Sun
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xf6e9a4), Color(hex: 0xd7a742)],
                        center: .center,
                        startRadius: 0,
                        endRadius: w * 0.11
                    )
                )
                .frame(width: w * 0.22, height: w * 0.22)
                .shadow(color: Color(hex: 0xd7a742).opacity(0.7), radius: 30)
                .position(x: w * 0.18 + w * 0.11, y: h * 0.20 + w * 0.11)
        }
    }

    private func darkVariant(w: CGFloat, h: CGFloat, showMoon: Bool, showStars: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2b2442), Color(hex: 0x14102a)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(hex: 0x4c3d78).opacity(0.95), .clear],
                center: UnitPoint(x: 0.70, y: 0.70),
                startRadius: 0,
                endRadius: w * 0.55
            )

            if showStars {
                StarsView()
            }

            if showMoon {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0xe4e1d5), Color(hex: 0xa6a4b0)],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: w * 0.11
                        )
                    )
                    .frame(width: w * 0.22, height: w * 0.22)
                    .shadow(color: Color(hex: 0xa6a4b0).opacity(0.45), radius: 22)
                    .position(x: w - (w * 0.18 + w * 0.11), y: h * 0.22 + w * 0.11)
            }
        }
    }
}

private struct StarsView: View {
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.30, 0.25, 1.5, 0.9),
        (0.55, 0.40, 1.0, 0.7),
        (0.75, 0.20, 1.5, 0.85),
        (0.40, 0.65, 1.0, 0.6),
        (0.88, 0.55, 1.5, 0.8)
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                let s = stars[i]
                Circle()
                    .fill(Color.white.opacity(s.3))
                    .frame(width: s.2, height: s.2)
                    .position(x: geo.size.width * s.0, y: geo.size.height * s.1)
            }
        }
    }
}

// Dynamic — flowing color ribbon with traveling sun + filling timeline
private struct DynamicScene: View {
    let position: MonitorPosition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cycle: TimeInterval = 8.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x2a2748), location: 0.0),
                        .init(color: Color(hex: 0x503470), location: 0.2),
                        .init(color: Color(hex: 0x9a6944), location: 0.42),
                        .init(color: Color(hex: 0xe2b965), location: 0.55),
                        .init(color: Color(hex: 0x4e6a9e), location: 0.8),
                        .init(color: Color(hex: 0x2a2748), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
                    let phase = phase(at: context.date)
                    ZStack {
                        // Traveling dot (main monitor only)
                        if position == .main {
                            let dotSize = w * 0.12
                            let dotX = w * (0.10 + 0.80 * phase)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.3), .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: dotSize / 2
                                    )
                                )
                                .frame(width: dotSize, height: dotSize)
                                .blur(radius: 1)
                                .position(x: dotX, y: h * 0.24 + dotSize / 2)
                        }

                        // Timeline track + fill (all monitors)
                        let trackInset: CGFloat = w * 0.12
                        let trackWidth = w - trackInset * 2
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.22))
                                .frame(width: trackWidth, height: 2)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.9)],
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

    private func phase(at date: Date) -> CGFloat {
        if reduceMotion { return 0.5 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        return CGFloat(t / cycle)
    }
}

// MARK: - Pill picker

private struct PillPicker: View {
    @Binding var selection: WallpaperType
    let namespace: Namespace.ID
    let onChange: (WallpaperType, WallpaperType) -> Void

    private struct Pill: Identifiable {
        let id: WallpaperType
        let label: String
        let symbol: String
    }

    private let pills: [Pill] = [
        Pill(id: .standard,   label: "Static",  symbol: "photo.fill"),
        Pill(id: .appearance, label: "Themed",  symbol: "circle.lefthalf.filled"),
        Pill(id: .dynamic,    label: "Dynamic", symbol: "clock")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(pills) { pill in
                let isActive = pill.id == selection
                Button(action: { tap(pill.id) }) {
                    HStack(spacing: 8) {
                        Image(systemName: pill.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 14, height: 14)
                        Text(pill.label)
                            .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                    }
                    .foregroundStyle(isActive ? Color.white : Color.cdTextSecondary)
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
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
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

private struct Caption: View {
    let type: WallpaperType

    private var copy: (lead: String, body: String) {
        switch type {
        case .standard:
            return ("Static.", " One image, stretched seamlessly across every display.")
        case .appearance:
            return ("Themed.", " A light image by day, a darker one by night — switched by macOS appearance.")
        case .dynamic:
            return ("Dynamic.", " A schedule of images that shifts through the day, in sync across all screens.")
        }
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

    private var typeLabel: String {
        switch selectedType {
        case .standard:   return "Static"
        case .appearance: return "Themed"
        case .dynamic:    return "Dynamic"
        }
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
                    Text("Continue with \(typeLabel)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.cdAccent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
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

private struct KeyboardHandler: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onReturn: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let v = KeyView()
        v.onLeft = onLeft
        v.onRight = onRight
        v.onReturn = onReturn
        v.onEscape = onEscape
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onLeft = onLeft
        nsView.onRight = onRight
        nsView.onReturn = onReturn
        nsView.onEscape = onEscape
    }

    final class KeyView: NSView {
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        var onReturn: (() -> Void)?
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }

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
