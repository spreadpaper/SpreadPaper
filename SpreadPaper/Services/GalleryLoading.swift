// SpreadPaper/Services/GalleryLoading.swift

import CoreGraphics
import Foundation

/// What the gallery draws where its cards belong.
enum GalleryPhase: Equatable {
    case loading
    case loaded
    case failed
}

/// Everything the renderer needs for one preset, snapshotted on the main actor.
struct ThumbnailJob: Sendable {
    let presetId: UUID
    let imageURL: URL
    let shouldFlip: Bool
}

/// One finished thumbnail, keyed by the preset it belongs to.
struct ThumbnailResult: Sendable {
    let presetId: UUID
    let image: CGImage
}

/// What came of one job, reported the moment the renderer is done with it.
enum ThumbnailEvent: Sendable {
    case rendered(ThumbnailResult)
    case skipped(presetId: UUID)

    /// The preset this event settles, whether or not it produced an image.
    var presetId: UUID {
        switch self {
        case .rendered(let result):
            return result.presetId
        case .skipped(let presetId):
            return presetId
        }
    }
}

/// How a thumbnail run ended, and how much of it arrived. A run goes
/// quiet either because it finished or because it stopped.
enum ThumbnailRunOutcome: Equatable {
    case delivered(rendered: Int, skipped: Int, requested: Int)
    case stalled(delivered: Int, requested: Int)
}

/// A line for the log, at the level the condition deserves.
struct ThumbnailLogNote: Equatable {
    /// How much attention the line is worth, following `WallpaperManager`.
    enum Level: Equatable {
        case info
        case error
    }

    let level: Level
    let message: String
}

/// Longest side of a gallery thumbnail, in points.
nonisolated let thumbnailMaxPointSize = 480

/// Downsamples every job in turn, handing each one to `emit` as it lands.
/// A job whose file cannot be read is skipped, not dropped in silence.
/// Cancellation ends the pass at the next job.
///
/// - Parameters:
///   - jobs: What to render, in the order the gallery wants it.
///   - maxPixelSize: Longest side of the output, in pixels.
///   - emit: Takes what came of one job.
nonisolated func renderThumbnails(
    jobs: [ThumbnailJob],
    maxPixelSize: Int,
    emit: (ThumbnailEvent) -> Void
) {
    for job in jobs {
        if Task.isCancelled { return }
        guard let image = ThumbnailRenderer.thumbnail(
            for: job.imageURL, maxPixelSize: maxPixelSize, flipped: job.shouldFlip
        ) else {
            emit(.skipped(presetId: job.presetId))
            continue
        }
        emit(.rendered(ThumbnailResult(presetId: job.presetId, image: image)))
    }
}

/// Rules the gallery follows while thumbnails arrive. A run that keeps
/// moving is fine, however little it can read.
enum GalleryLoading {
    /// How long the gallery waits for the next thumbnail before giving up.
    /// One image downsamples in well under a second, even cold.
    ///
    /// The watchdog samples at this interval rather than timing each gap,
    /// so a stall is noticed between one and two of these.
    nonisolated static let idleTimeout: Duration = .seconds(10)

    /// Whether a card is still waiting on its own job. A run that has
    /// ended leaves nothing to wait for, however it ended.
    ///
    /// - Parameters:
    ///   - presetId: The card's preset.
    ///   - reported: Presets the run has settled, rendered or skipped.
    ///   - phase: Where the gallery is in its run.
    /// - Returns: True while that card's own job is still outstanding.
    static func isPending(presetId: UUID, reported: Set<UUID>, phase: GalleryPhase) -> Bool {
        phase == .loading && !reported.contains(presetId)
    }

    /// Phase the outcome leaves the gallery in. Only a run that stopped
    /// moving is a failure; unreadable images are not.
    ///
    /// - Parameter outcome: How the run that just ended finished.
    /// - Returns: The phase the gallery should move to.
    static func phase(after outcome: ThumbnailRunOutcome) -> GalleryPhase {
        switch outcome {
        case .delivered:
            return .loaded
        case .stalled(_, let requested):
            return requested > 0 ? .failed : .loaded
        }
    }

    /// What the log keeps about the outcome, or nil when it went as asked.
    /// Images it could not read are expected, so they stay at info.
    ///
    /// - Parameter outcome: How the run that just ended finished.
    /// - Returns: A line for the log, or nil when there is nothing to record.
    static func logNote(for outcome: ThumbnailRunOutcome) -> ThumbnailLogNote? {
        switch outcome {
        case .delivered(_, let skipped, let requested):
            guard skipped > 0 else { return nil }
            return ThumbnailLogNote(
                level: .info,
                message: "Thumbnail run skipped \(skipped) of \(requested) unreadable images"
            )
        case .stalled(let delivered, let requested):
            return ThumbnailLogNote(
                level: .error,
                message: "Thumbnail run stalled at \(delivered) of \(requested) images"
            )
        }
    }
}

/// How far along a run is, for the watchdog and the consumer both.
@MainActor
private final class RunProgress {
    var rendered = 0
    var skipped = 0
    var events = 0
    var stalled = false
}

/// Drives one thumbnail run and decides when it has stopped moving. The
/// idle wait restarts on every event, so a long library is safe.
enum ThumbnailRun {
    /// Consumes `events` until the run finishes or goes quiet for `idle`,
    /// handing each thumbnail on as it lands. A quiet run has its stream
    /// closed, which stops the renderer too.
    ///
    /// - Parameters:
    ///   - events: What the renderer reports, one per job.
    ///   - continuation: The end of that stream, closed when the run goes quiet.
    ///   - requested: How many jobs the run was given.
    ///   - idle: Longest gap between events the run may have.
    ///   - sleep: How that gap is waited out; the tests hand in their own.
    ///   - onEvent: Takes what came of one job, as it comes.
    /// - Returns: How the run ended.
    @MainActor
    static func consume(
        _ events: AsyncStream<ThumbnailEvent>,
        stopping continuation: AsyncStream<ThumbnailEvent>.Continuation,
        requested: Int,
        idle: Duration = GalleryLoading.idleTimeout,
        sleep: @escaping @Sendable (Duration) async -> Void = { duration in
            _ = try? await Task.sleep(for: duration)
        },
        onEvent: @MainActor (ThumbnailEvent) -> Void
    ) async -> ThumbnailRunOutcome {
        let progress = RunProgress()

        let watchdog = Task { @MainActor in
            var seen = -1
            while seen != progress.events {
                seen = progress.events
                await sleep(idle)
                if Task.isCancelled { return }
            }
            progress.stalled = true
            continuation.finish()
        }

        for await event in events {
            switch event {
            case .rendered:
                progress.rendered += 1
            case .skipped:
                progress.skipped += 1
            }
            onEvent(event)
            progress.events += 1
        }
        watchdog.cancel()

        guard progress.stalled, progress.events < requested else {
            return .delivered(
                rendered: progress.rendered,
                skipped: progress.skipped,
                requested: requested
            )
        }
        return .stalled(delivered: progress.rendered, requested: requested)
    }
}
