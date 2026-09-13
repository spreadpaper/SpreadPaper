// SpreadPaper/Views/GalleryLoading.swift

import Foundation

/// What the gallery draws where its cards belong.
enum GalleryPhase: Equatable {
    case loading
    case loaded
    case failed
}

/// How one run of the thumbnail renderer ended, and how much of it arrived.
enum ThumbnailRunOutcome: Equatable {
    case delivered(rendered: Int, requested: Int)
    case timedOut(requested: Int)
    case cancelled
}

/// Rules the gallery follows once a thumbnail run ends. No outcome keeps
/// the skeleton up, so the grid is never a dead end.
enum GalleryLoading {
    /// How long the gallery waits for thumbnails before it offers to try again.
    /// A cold library of several hundred images downsamples well inside this.
    static let timeout: Duration = .seconds(30)

    /// Phase the outcome leaves the gallery in. Only a run that asked for
    /// images and received none of them counts as a failure.
    ///
    /// - Parameter outcome: How the run that just ended finished.
    /// - Returns: The phase the gallery should move to.
    static func phase(after outcome: ThumbnailRunOutcome) -> GalleryPhase {
        switch outcome {
        case .delivered(let rendered, let requested):
            return rendered == 0 && requested > 0 ? .failed : .loaded
        case .timedOut(let requested):
            return requested > 0 ? .failed : .loaded
        case .cancelled:
            return .loaded
        }
    }

    /// What the log keeps about the outcome, or nil when the run went as asked.
    /// A short delivery is diagnosable without reaching the user.
    ///
    /// - Parameter outcome: How the run that just ended finished.
    /// - Returns: A line for the log, or nil when there is nothing to record.
    static func logNote(for outcome: ThumbnailRunOutcome) -> String? {
        switch outcome {
        case .delivered(let rendered, let requested):
            guard rendered < requested else { return nil }
            return "Thumbnail run delivered \(rendered) of \(requested) images"
        case .timedOut(let requested):
            return "Thumbnail run for \(requested) presets gave up after \(timeout.components.seconds) seconds"
        case .cancelled:
            return nil
        }
    }
}
