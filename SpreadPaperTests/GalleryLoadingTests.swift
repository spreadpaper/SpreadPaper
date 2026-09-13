import CoreGraphics
import Foundation
import Testing
@testable import SpreadPaper

/// Thumbnails a run handed over, counted as they land.
@MainActor
private final class Delivery {
    var count = 0
}

/// Holds the watchdog's wait open until the test lets it through.
@MainActor
private final class Gate {
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// Waits here until the gate opens, or returns at once once it has.
    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Opens the gate and lets everything waiting on it through.
    func open() {
        isOpen = true
        let resuming = waiting
        waiting.removeAll()
        for continuation in resuming { continuation.resume() }
    }
}

/// A run that stops moving is given up on, and one that keeps moving is not.
@MainActor
struct GalleryLoadingTests {
    /// Fails the test rather than hanging the suite when a run never returns.
    ///
    /// - Parameters:
    ///   - limit: How long the work may take.
    ///   - work: What to run under that limit.
    /// - Returns: What the work produced, or nil once the limit passed.
    private func within<Value: Sendable>(
        _ limit: Duration,
        _ work: @escaping @Sendable () async -> Value
    ) async -> Value? {
        await withTaskGroup(of: Value?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: limit)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// A one pixel image, enough to stand in for a thumbnail.
    private func pixel() throws -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try #require(context.makeImage())
    }

    /// One rendered event for a fresh preset.
    private func rendered() throws -> ThumbnailEvent {
        .rendered(ThumbnailResult(presetId: UUID(), image: try pixel()))
    }

    // MARK: - The run stops moving

    @Test func aRunThatNeverDeliversStalls() async {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        defer { continuation.finish() }

        let outcome = await within(.seconds(5)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: 4, idle: .milliseconds(40), onEvent: { _ in }
            )
        }

        #expect(outcome == .stalled(delivered: 0, requested: 4), "a run that never moves has to be given up on")
    }

    @Test func aRunThatStopsPartWayStalls() async throws {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        continuation.yield(try rendered())
        continuation.yield(try rendered())
        defer { continuation.finish() }

        let applied = Delivery()
        let outcome = await within(.seconds(5)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: 5, idle: .milliseconds(40),
                onEvent: { _ in applied.count += 1 }
            )
        }

        #expect(outcome == .stalled(delivered: 2, requested: 5))
        #expect(applied.count == 2, "the thumbnails that did arrive belong on their cards")
    }

    @Test func theCardsFillInAsThumbnailsArriveRatherThanAtTheEnd() async throws {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        continuation.yield(try rendered())

        let seenBeforeTheRunEnded = Delivery()
        let outcome = await within(.seconds(5)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: 2, idle: .milliseconds(40),
                onEvent: { _ in seenBeforeTheRunEnded.count += 1 }
            )
        }

        #expect(outcome == .stalled(delivered: 1, requested: 2))
        #expect(seenBeforeTheRunEnded.count == 1, "a thumbnail reached its card before the run was over")
    }

    // MARK: - The run keeps moving

    @Test func theIdleWaitRestartsOnEveryThumbnail() async throws {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        let arrivals = 8

        let feeder = Task {
            for _ in 0..<arrivals {
                try? await Task.sleep(for: .milliseconds(30))
                continuation.yield(.skipped(presetId: UUID()))
            }
            continuation.finish()
        }
        defer { feeder.cancel() }

        let outcome = await within(.seconds(10)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: arrivals, idle: .milliseconds(150), onEvent: { _ in }
            )
        }

        #expect(
            outcome == .delivered(rendered: 0, skipped: arrivals, requested: arrivals),
            "a run spread over longer than one idle wait is still moving"
        )
    }

    @Test func aRunThatFinishesIsDelivered() async throws {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        continuation.yield(try rendered())
        continuation.yield(try rendered())
        continuation.yield(try rendered())
        continuation.finish()

        let outcome = await within(.seconds(5)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: 3, idle: .milliseconds(40), onEvent: { _ in }
            )
        }

        #expect(outcome == .delivered(rendered: 3, skipped: 0, requested: 3))
    }

    @Test func anEmptyLibraryEndsAtOnce() async {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        continuation.finish()

        let outcome = await within(.seconds(5)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: 0, idle: .milliseconds(40), onEvent: { _ in }
            )
        }

        #expect(outcome == .delivered(rendered: 0, skipped: 0, requested: 0))
        #expect(GalleryLoading.phase(after: .delivered(rendered: 0, skipped: 0, requested: 0)) == .loaded)
    }

    @Test func aRunThatReportedEveryJobIsNeverCalledStalled() async {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        let jobs = 4
        let gate = Gate()
        for _ in 0..<jobs { continuation.yield(.skipped(presetId: UUID())) }

        let seen = Delivery()
        let outcome = await within(.seconds(5)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: jobs, idle: .milliseconds(1),
                sleep: { _ in await gate.wait() },
                onEvent: { _ in
                    seen.count += 1
                    if seen.count == jobs { gate.open() }
                }
            )
        }

        #expect(
            outcome == .delivered(rendered: 0, skipped: jobs, requested: jobs),
            "the watchdog firing last, on a run that reported every job, is not a stall"
        )
    }

    // MARK: - Unreadable images are not a failure

    @Test func aLibraryWhoseImagesAreAllGoneKeepsItsCards() async {
        let (events, continuation) = AsyncStream<ThumbnailEvent>.makeStream()
        for _ in 0..<6 { continuation.yield(.skipped(presetId: UUID())) }
        continuation.finish()

        let outcome = await within(.seconds(5)) {
            await ThumbnailRun.consume(
                events, stopping: continuation, requested: 6, idle: .milliseconds(40), onEvent: { _ in }
            )
        }

        #expect(outcome == .delivered(rendered: 0, skipped: 6, requested: 6))
        #expect(
            GalleryLoading.phase(after: .delivered(rendered: 0, skipped: 6, requested: 6)) == .loaded,
            "images the app cannot read are not a stuck gallery, so no retry is offered"
        )
    }

    // MARK: - A card that has not had its turn yet

    @Test func aCardWaitingOnItsOwnJobIsNotCalledPreviewless() {
        let waiting = UUID()
        let done = UUID()

        #expect(
            GalleryLoading.isPending(presetId: waiting, reported: [done], phase: .loading),
            "a card whose job has not reported yet is still waiting, not previewless"
        )
        #expect(!GalleryLoading.isPending(presetId: done, reported: [done], phase: .loading))
    }

    @Test func aRunThatEndedLeavesNoCardWaiting() {
        let unreported = UUID()

        #expect(!GalleryLoading.isPending(presetId: unreported, reported: [], phase: .loaded))
        #expect(!GalleryLoading.isPending(presetId: unreported, reported: [], phase: .failed))
    }

    @Test func anUnreadableImageSettlesItsOwnCard() throws {
        let job = ThumbnailJob(
            presetId: UUID(), imageURL: URL(filePath: "/dev/null"), shouldFlip: false
        )

        var reported: Set<UUID> = []
        renderThumbnails(jobs: [job], maxPixelSize: 64) { reported.insert($0.presetId) }

        #expect(reported == [job.presetId], "a skipped job names the card it settles")
        #expect(!GalleryLoading.isPending(presetId: job.presetId, reported: reported, phase: .loading))
    }

    // MARK: - Phases

    @Test func noOutcomeLeavesTheGalleryLoading() {
        let outcomes: [ThumbnailRunOutcome] = [
            .delivered(rendered: 6, skipped: 0, requested: 6),
            .delivered(rendered: 0, skipped: 0, requested: 0),
            .delivered(rendered: 2, skipped: 4, requested: 6),
            .delivered(rendered: 0, skipped: 6, requested: 6),
            .stalled(delivered: 0, requested: 6),
            .stalled(delivered: 3, requested: 6),
            .stalled(delivered: 0, requested: 0)
        ]
        for outcome in outcomes {
            #expect(GalleryLoading.phase(after: outcome) != .loading, "\(outcome) keeps the skeleton up")
        }
    }

    @Test func onlyAStalledRunOffersARetry() {
        #expect(GalleryLoading.phase(after: .stalled(delivered: 0, requested: 6)) == .failed)
        #expect(GalleryLoading.phase(after: .stalled(delivered: 3, requested: 6)) == .failed)
        #expect(GalleryLoading.phase(after: .stalled(delivered: 0, requested: 0)) == .loaded)
    }

    // MARK: - Logging

    @Test func onlyATroubledRunIsWorthLogging() {
        #expect(GalleryLoading.logNote(for: .delivered(rendered: 6, skipped: 0, requested: 6)) == nil)
        #expect(GalleryLoading.logNote(for: .delivered(rendered: 0, skipped: 0, requested: 0)) == nil)
        #expect(GalleryLoading.logNote(for: .delivered(rendered: 2, skipped: 4, requested: 6))?.level == .info)
        #expect(GalleryLoading.logNote(for: .stalled(delivered: 3, requested: 6))?.level == .error)
    }

    @Test func theLogSaysHowFarTheRunGot() {
        #expect(GalleryLoading.logNote(for: .stalled(delivered: 3, requested: 6))?.message.contains("3 of 6") == true)
        #expect(
            GalleryLoading.logNote(for: .delivered(rendered: 2, skipped: 4, requested: 6))?
                .message.contains("4 of 6") == true
        )
    }

    // MARK: - The renderer

    @Test func aCancelledRenderStopsInsteadOfFinishingTheLibrary() async throws {
        let jobs = (0..<50).map { _ in
            ThumbnailJob(presetId: UUID(), imageURL: URL(filePath: "/dev/null"), shouldFlip: false)
        }

        let render = Task.detached { () -> Int in
            while !Task.isCancelled { await Task.yield() }
            var events = 0
            renderThumbnails(jobs: jobs, maxPixelSize: 64) { _ in events += 1 }
            return events
        }
        render.cancel()

        #expect(await render.value == 0, "a cancelled run must not keep working through the library")
    }

    @Test func anUnreadableImageIsReportedRatherThanDropped() {
        let jobs = (0..<3).map { _ in
            ThumbnailJob(presetId: UUID(), imageURL: URL(filePath: "/dev/null"), shouldFlip: false)
        }

        var skipped = 0
        renderThumbnails(jobs: jobs, maxPixelSize: 64) { event in
            if case .skipped = event { skipped += 1 }
        }

        #expect(skipped == 3, "a job the renderer cannot read still counts as movement")
    }

    // MARK: - The wait itself

    @Test func theIdleWaitIsFarLongerThanOneImageTakes() {
        #expect(GalleryLoading.idleTimeout >= .seconds(5))
        #expect(GalleryLoading.idleTimeout <= .seconds(15))
    }

    // MARK: - Retrying while a pass has not returned

    @Test func pressingTryAgainTenTimesLeavesOnePass() {
        let gate = ThumbnailPassGate()
        #expect(gate.request(), "the first pass has nothing in its way")

        for press in 1...10 {
            #expect(!gate.request(), "press \(press) arrived while a pass was still out")
        }

        #expect(gate.outstanding == 1, "ten presses left \(gate.outstanding) passes running")
    }

    @Test func theRetryIsNotOfferedWhileAPassIsStillParked() {
        let gate = ThumbnailPassGate()
        #expect(gate.canStart, "an idle gallery has a retry to offer")

        _ = gate.request()
        #expect(!gate.canStart, "a pass is parked inside its read, so a retry cannot reach it")

        gate.passReturned()
        #expect(gate.canStart, "the read came back, so another pass may go")
    }

    @Test func aRequestHeldWhileAPassWasOutRunsWhenItReturns() {
        let gate = ThumbnailPassGate()
        _ = gate.request()
        _ = gate.request()

        #expect(gate.isHolding, "the second request is held rather than dropped")
        gate.passReturned()
        #expect(gate.takeHeldRequest(), "the held request goes once the pass is back")
        #expect(gate.request(), "and it starts a pass of its own")
    }

    @Test func onlyOneCallerEverRunsAHeldRequest() {
        let gate = ThumbnailPassGate()
        _ = gate.request()
        _ = gate.request()
        gate.passReturned()

        #expect(gate.takeHeldRequest(), "the gallery on screen takes the held request")
        #expect(!gate.takeHeldRequest(), "a second asker must not run it all over again")
    }

    @Test func aPassReturningWithNothingHeldStartsNothing() {
        let gate = ThumbnailPassGate()
        _ = gate.request()
        gate.passReturned()

        #expect(!gate.takeHeldRequest(), "nobody asked for another pass while that one ran")
        #expect(gate.outstanding == 0)
    }

    @Test func theGalleryNeverCountsFewerPassesThanNone() {
        let gate = ThumbnailPassGate()
        gate.passReturned()
        gate.passReturned()

        #expect(gate.outstanding == 0, "a stray return must not leave the count below zero")
        #expect(gate.canStart)
    }

    @Test func leavingTheGalleryAndComingBackCannotStartASecondPass() throws {
        let built = try AppSources.lines(
            in: try AppSources.all().filter { $0.lastPathComponent == "GalleryView.swift" },
            containing: ["ThumbnailPassGate("]
        )

        #expect(
            built.isEmpty,
            """
            the gallery builds its own gate at \(built.joined(separator: ", ")), \
            so the route switch rebuilding it forgets the passes already out
            """
        )
    }

    @Test func theBannerSaysWhyTheRetryIsWithheld() {
        let offered = GalleryLoading.failureMessage(outstandingPasses: 0)
        let withheld = GalleryLoading.failureMessage(outstandingPasses: 1)

        #expect(offered != withheld, "a withheld retry needs a reason the user can read")
        #expect(withheld.contains("still being read"), "the line has to name what is holding it up")
    }
}
