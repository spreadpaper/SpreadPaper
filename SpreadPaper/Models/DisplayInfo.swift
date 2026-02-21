import AppKit

struct DisplayInfo: Identifiable {
    let id = UUID()
    let screen: NSScreen
    let frame: CGRect
}
