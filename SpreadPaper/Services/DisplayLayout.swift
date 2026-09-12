import CoreGraphics

/// Spreads display frames apart by the physical bezels between monitors. Each display
/// carries its own frame width; the gap between neighbours is the sum of both, and a
/// display shifts by every gap it crosses, so a spanned image lines up.
enum DisplayLayout {
    /// Uniform gap: every display gets half of `gap` as its bezel on each side.
    static func spacedFrames(_ frames: [CGRect], gap: CGFloat) -> [CGRect] {
        spacedFrames(frames, bezels: Array(repeating: gap / 2, count: frames.count))
    }

    /// Returns `frames` shifted by the bezels crossed, in the same order. `bezels[i]`
    /// is the frame width of display `i` in points; the counts must match.
    static func spacedFrames(_ frames: [CGRect], bezels: [CGFloat]) -> [CGRect] {
        guard frames.count > 1, frames.count == bezels.count, bezels.contains(where: { $0 > 0 }) else {
            return frames
        }
        let tolerance: CGFloat = 0.5

        /// Sum of gaps between `index` and the canvas edge along one axis.
        func crossedGaps(for index: Int, end: (CGRect) -> CGFloat, start: (CGRect) -> CGFloat) -> CGFloat {
            let origin = start(frames[index])
            let edges = Set(
                frames.filter { end($0) <= origin + tolerance }.map { end($0).rounded() }
            ).sorted()

            return edges.reduce(0) { total, edge in
                let before = frames.indices
                    .filter { end(frames[$0]).rounded() == edge }
                    .map { bezels[$0] }
                    .max() ?? 0
                let afterIndices = frames.indices.filter { abs(start(frames[$0]) - edge) <= tolerance }
                let after = afterIndices.isEmpty ? bezels[index] : afterIndices.map { bezels[$0] }.max()!
                return total + before + after
            }
        }

        return frames.indices.map { index in
            frames[index].offsetBy(
                dx: crossedGaps(for: index, end: \.maxX, start: \.minX),
                dy: crossedGaps(for: index, end: \.maxY, start: \.minY)
            )
        }
    }
}
