import CoreGraphics

/// Spreads display frames apart to account for the physical bezels between monitors.
///
/// Each display is shifted right by one gap per distinct column edge to its left, and up by one
/// gap per distinct row edge below it. The image crop for each display then skips the strip
/// hidden behind the bezels, so a spanned image lines up across the array.
enum DisplayLayout {
    /// Returns `frames` shifted by `gap` points per bezel crossed, in the same order.
    static func spacedFrames(_ frames: [CGRect], gap: CGFloat) -> [CGRect] {
        guard gap > 0, frames.count > 1 else { return frames }
        let tolerance: CGFloat = 0.5

        return frames.map { frame in
            let columnsLeft = Set(
                frames
                    .filter { $0.maxX <= frame.minX + tolerance }
                    .map { ($0.maxX / 1).rounded() }
            ).count
            let rowsBelow = Set(
                frames
                    .filter { $0.maxY <= frame.minY + tolerance }
                    .map { ($0.maxY / 1).rounded() }
            ).count
            return frame.offsetBy(dx: CGFloat(columnsLeft) * gap, dy: CGFloat(rowsBelow) * gap)
        }
    }
}
