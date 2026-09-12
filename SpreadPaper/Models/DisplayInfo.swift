import AppKit

/// A connected display, identified by its `CGDirectDisplayID` so identical monitors stay distinct.
struct DisplayInfo: Identifiable {
    let displayID: CGDirectDisplayID
    let screen: NSScreen
    let frame: CGRect

    var id: CGDirectDisplayID { displayID }

    /// Human-readable name for messages. Not unique across identical monitors.
    var name: String { screen.localizedName }

    /// - Parameter frame: Layout frame to use instead of `screen.frame`, e.g. after bezel spacing.
    init(screen: NSScreen, frame: CGRect? = nil) {
        self.screen = screen
        self.frame = frame ?? screen.frame
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        self.displayID = number?.uint32Value ?? 0
    }
}
