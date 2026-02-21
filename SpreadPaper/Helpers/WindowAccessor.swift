import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.insert(.fullSizeContentView)
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.isMovableByWindowBackground = false
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.cornerRadius = 16
                window.contentView?.layer?.masksToBounds = true
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
