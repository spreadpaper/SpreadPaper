import AppKit
import SwiftUI
import Testing
@testable import SpreadPaper

/// Issue #131: the hover flag of a button style lives in a view SwiftUI
/// installs, so a write to it reaches the next render. The scan is the
/// guard, the render checks the wiring.
@MainActor
struct HoverReaderTests {
    /// Lays a view out in an offscreen window, where it can track a pointer.
    ///
    /// - Parameter view: The view to draw at `side` by `side` points.
    /// - Returns: The hosting view, still attached to its window.
    private static func host<V: View>(_ view: V, side: CGFloat = 40) -> NSHostingView<AnyView> {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let frame = NSRect(x: 0, y: 0, width: side, height: side)
        let host = NSHostingView(rootView: AnyView(view.frame(width: side, height: side)))
        host.frame = frame
        let window = NSWindow(
            contentRect: NSRect(x: -40000, y: -40000, width: side, height: side),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        return host
    }

    /// Tracking areas installed anywhere below a view.
    ///
    /// - Parameter view: The root of the hierarchy to walk.
    /// - Returns: Every tracking area found, the root's included.
    private static func trackingAreas(below view: NSView) -> [NSTrackingArea] {
        view.trackingAreas + view.subviews.flatMap { trackingAreas(below: $0) }
    }

    /// Style types in the app sources that declare SwiftUI state.
    ///
    /// - Returns: One `file:line: text` entry per offending declaration.
    private static func stylesDeclaringState() throws -> [String] {
        var offenders: [String] = []
        for file in try AppSources.all() {
            let source = try String(contentsOf: file, encoding: .utf8)
            var declaration: String?
            for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if line.first == "}" {
                    declaration = nil
                } else if line.first != " ", line.contains("struct "), let colon = line.firstIndex(of: ":"),
                          line[colon...].contains("Style") {
                    declaration = "\(file.lastPathComponent):\(number + 1)"
                } else if let declaration, line.contains("@State") {
                    offenders.append("\(declaration): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        return offenders
    }

    @Test func noStyleTypeKeepsItsHoverFlagOutsideAView() throws {
        let offenders = try Self.stylesDeclaringState()
        #expect(offenders.isEmpty, "style types holding state SwiftUI never installs:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func hoverHoldsWhileThePointerSitsInsideAnActiveApp() {
        #expect(HoverReader<EmptyView>.isHovered(pointerInside: true, activeState: .key))
        #expect(HoverReader<EmptyView>.isHovered(pointerInside: true, activeState: .active))
    }

    @Test func hoverClearsWhenThePointerLeaves() {
        #expect(!HoverReader<EmptyView>.isHovered(pointerInside: false, activeState: .key))
    }

    @Test func hoverClearsWhenTheAppGoesInactive() {
        #expect(!HoverReader<EmptyView>.isHovered(pointerInside: true, activeState: .inactive))
    }

    @Test func aHostedReaderTracksThePointerOverItsContent() {
        let host = Self.host(HoverReader { hovering in
            Rectangle().fill(hovering ? Color.cdBgElevated : Color.clear)
        })
        let tracked = Self.trackingAreas(below: host).contains { $0.options.contains(.mouseEnteredAndExited) }
        #expect(tracked, "the hosted reader installed no pointer tracking")
    }

    @Test func aHostedReaderDrawsItsRestingBranchWithNoPointerOverIt() {
        var seen: [Bool] = []
        let host = Self.host(HoverReader { hovering in
            Rectangle().fill(hovering ? Color.cdBgElevated : Color.cdBgPrimary)
                .onAppear { seen.append(hovering) }
        })
        host.displayIfNeeded()
        #expect(seen == [false], "the reader drew its content with hover \(seen)")
    }
}
