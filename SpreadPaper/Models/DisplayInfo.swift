import AppKit

/// A connected display, identified by its `CGDirectDisplayID` so identical monitors stay distinct.
struct DisplayInfo: Identifiable {
    let displayID: CGDirectDisplayID
    let screen: NSScreen
    let frame: CGRect
    /// Physical frame widths around the panel, used for layout spacing and the canvas preview.
    let bezel: Bezel

    var id: CGDirectDisplayID { displayID }

    /// Human-readable name for messages. Not unique across identical monitors.
    var name: String { screen.localizedName }

    /// The panel plus its bezel, in layout points.
    var frameWithBezel: CGRect {
        frame.insetBy(dx: -bezel.horizontal, dy: -bezel.vertical)
    }

    /// - Parameter frame: Layout frame to use instead of `screen.frame`, e.g. after bezel spacing.
    init(screen: NSScreen, frame: CGRect? = nil, bezel: Bezel = .zero) {
        self.screen = screen
        self.frame = frame ?? screen.frame
        self.bezel = bezel
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        self.displayID = number?.uint32Value ?? 0
    }
}
