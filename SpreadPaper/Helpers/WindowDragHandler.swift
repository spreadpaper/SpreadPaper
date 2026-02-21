import SwiftUI
import AppKit

struct WindowDragHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggableView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    class DraggableView: NSView { override var mouseDownCanMoveWindow: Bool { true } }
}
