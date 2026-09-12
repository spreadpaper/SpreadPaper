import CoreGraphics

/// Frame widths of one display in points: `horizontal` for the left and right edges,
/// `vertical` for the top and bottom edges.
struct Bezel: Equatable, Sendable {
    var horizontal: CGFloat
    var vertical: CGFloat

    static let zero = Bezel(horizontal: 0, vertical: 0)
}

/// Spreads display frames apart by the physical bezels between monitors. Each display
/// carries its own frame widths; the gap between neighbours is the sum of both, so
/// a display shifts by every gap it crosses and a spanned image lines up.
enum DisplayLayout {
    /// Uniform gap: every display gets half of `gap` on every edge.
    static func spacedFrames(_ frames: [CGRect], gap: CGFloat) -> [CGRect] {
        let bezel = Bezel(horizontal: gap / 2, vertical: gap / 2)
        return spacedFrames(frames, bezels: Array(repeating: bezel, count: frames.count))
    }

    /// Returns `frames` shifted by the bezels crossed, in the same order. `bezels[i]`
    /// belongs to display `i`; the counts must match or frames come back untouched.
    static func spacedFrames(_ frames: [CGRect], bezels: [Bezel]) -> [CGRect] {
        guard frames.count > 1, frames.count == bezels.count, bezels.contains(where: { $0 != .zero }) else {
            return frames
        }
        let tolerance: CGFloat = 0.5

        /// Sum of gaps between `index` and the canvas edge along one axis.
        func crossedGaps(
            for index: Int,
            end: (CGRect) -> CGFloat,
            start: (CGRect) -> CGFloat,
            width: (Bezel) -> CGFloat
        ) -> CGFloat {
            let origin = start(frames[index])
            let edges = Set(
                frames.filter { end($0) <= origin + tolerance }.map { end($0).rounded() }
            ).sorted()

            return edges.reduce(0) { total, edge in
                let before = frames.indices
                    .filter { end(frames[$0]).rounded() == edge }
                    .map { width(bezels[$0]) }
                    .max() ?? 0
                let afterIndices = frames.indices.filter { abs(start(frames[$0]) - edge) <= tolerance }
                let after = afterIndices.isEmpty ? width(bezels[index]) : afterIndices.map { width(bezels[$0]) }.max()!
                return total + before + after
            }
        }

        return frames.indices.map { index in
            frames[index].offsetBy(
                dx: crossedGaps(for: index, end: \.maxX, start: \.minX, width: \.horizontal),
                dy: crossedGaps(for: index, end: \.maxY, start: \.minY, width: \.vertical)
            )
        }
    }
}
