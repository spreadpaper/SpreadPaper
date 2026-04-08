// SpreadPaper/Views/RangeBarView.swift

import SwiftUI
import AppKit

struct RangeBarView: NSViewRepresentable {
    @Binding var startFraction: Double  // 0.0–1.0 (fraction of 24h)
    @Binding var endFraction: Double    // 0.0–1.0
    var accentColor: NSColor = NSColor(Color.cdAccent)
    var isSelected: Bool = false

    func makeNSView(context: Context) -> RangeBarNSView {
        let view = RangeBarNSView()
        view.onRangeChanged = { start, end in
            startFraction = start
            endFraction = end
        }
        return view
    }

    func updateNSView(_ nsView: RangeBarNSView, context: Context) {
        nsView.startFraction = startFraction
        nsView.endFraction = endFraction
        nsView.accentColor = accentColor
        nsView.isSelected = isSelected
        nsView.needsDisplay = true
    }
}

class RangeBarNSView: NSView {
    var startFraction: Double = 0.0
    var endFraction: Double = 1.0
    var accentColor: NSColor = .systemIndigo
    var isSelected: Bool = false
    var onRangeChanged: ((Double, Double) -> Void)?

    private var dragging: DragTarget = .none
    private let handleWidth: CGFloat = 8
    private let barHeight: CGFloat = 8
    private let snapInterval: Double = 10.0 / (24.0 * 60.0) // 10 minutes as fraction of day

    private enum DragTarget {
        case none, start, end
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let barY = (bounds.height - barHeight) / 2
        let barRect = CGRect(x: 0, y: barY, width: bounds.width, height: barHeight)

        // Background track
        ctx.setFillColor(NSColor(Color.cdBorder).cgColor)
        let bgPath = CGPath(roundedRect: barRect, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil)
        ctx.addPath(bgPath)
        ctx.fillPath()

        // 6-hour tick marks
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.06).cgColor)
        ctx.setLineWidth(1)
        for tick in [0.25, 0.5, 0.75] {
            let x = bounds.width * tick
            ctx.move(to: CGPoint(x: x, y: barY))
            ctx.addLine(to: CGPoint(x: x, y: barY + barHeight))
            ctx.strokePath()
        }

        // Active range fill
        let wraps = endFraction < startFraction
        let alpha: CGFloat = isSelected ? 0.45 : 0.25
        ctx.setFillColor(accentColor.withAlphaComponent(alpha).cgColor)

        if wraps {
            // Wraps around midnight: fill end..1.0 and 0.0..start
            let rightRect = CGRect(x: bounds.width * startFraction, y: barY, width: bounds.width * (1.0 - startFraction), height: barHeight)
            ctx.fill(rightRect)
            let leftRect = CGRect(x: 0, y: barY, width: bounds.width * endFraction, height: barHeight)
            ctx.fill(leftRect)
        } else {
            let fillRect = CGRect(x: bounds.width * startFraction, y: barY, width: bounds.width * (endFraction - startFraction), height: barHeight)
            ctx.fill(fillRect)
        }

        // Draw handles
        drawHandle(ctx: ctx, fraction: startFraction, barY: barY)
        drawHandle(ctx: ctx, fraction: endFraction, barY: barY)
    }

    private func drawHandle(ctx: CGContext, fraction: Double, barY: CGFloat) {
        let x = bounds.width * fraction
        let handleRect = CGRect(x: x - handleWidth / 2, y: barY - 2, width: handleWidth, height: barHeight + 4)

        // Handle body
        ctx.setFillColor(NSColor.white.cgColor)
        let handlePath = CGPath(roundedRect: handleRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.addPath(handlePath)
        ctx.fillPath()

        // Handle border
        let borderColor = isSelected ? accentColor : NSColor(Color.cdBorder)
        ctx.setStrokeColor(borderColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.addPath(handlePath)
        ctx.strokePath()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let x = point.x / bounds.width

        let startX = startFraction
        let endX = endFraction

        if abs(x - startX) < 0.03 {
            dragging = .start
        } else if abs(x - endX) < 0.03 {
            dragging = .end
        } else {
            dragging = .none
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging != .none else { return }
        let point = convert(event.locationInWindow, from: nil)
        let raw = max(0, min(1, point.x / bounds.width))

        // Snap to 10-minute marks
        let snapped = (raw / snapInterval).rounded() * snapInterval

        switch dragging {
        case .start:
            startFraction = snapped
        case .end:
            endFraction = snapped
        case .none:
            break
        }

        onRangeChanged?(startFraction, endFraction)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragging = .none
    }

    override func resetCursorRects() {
        let barY = (bounds.height - barHeight) / 2
        let startX = bounds.width * startFraction
        let endX = bounds.width * endFraction

        let startRect = CGRect(x: startX - handleWidth, y: barY - 4, width: handleWidth * 2, height: barHeight + 8)
        let endRect = CGRect(x: endX - handleWidth, y: barY - 4, width: handleWidth * 2, height: barHeight + 8)

        addCursorRect(startRect, cursor: .resizeLeftRight)
        addCursorRect(endRect, cursor: .resizeLeftRight)
    }
}
