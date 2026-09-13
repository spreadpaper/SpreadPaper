import Foundation
import Testing
@testable import SpreadPaper

/// The gallery's skeleton always gives way, whatever the thumbnail run does.
struct GalleryLoadingTests {
    /// Every way a run can end, as the gallery sees them.
    private static let everyOutcome: [ThumbnailRunOutcome] = [
        .delivered(rendered: 6, requested: 6),
        .delivered(rendered: 0, requested: 0),
        .delivered(rendered: 2, requested: 6),
        .delivered(rendered: 0, requested: 6),
        .timedOut(requested: 6),
        .timedOut(requested: 0),
        .cancelled
    ]

    @Test func noOutcomeLeavesTheGalleryLoading() {
        for outcome in Self.everyOutcome {
            #expect(GalleryLoading.phase(after: outcome) != .loading, "\(outcome) keeps the skeleton up")
        }
    }

    @Test func aFullDeliveryShowsTheCards() {
        #expect(GalleryLoading.phase(after: .delivered(rendered: 6, requested: 6)) == .loaded)
    }

    @Test func anEmptyLibraryShowsItsOwnEmptyState() {
        #expect(GalleryLoading.phase(after: .delivered(rendered: 0, requested: 0)) == .loaded)
        #expect(GalleryLoading.phase(after: .timedOut(requested: 0)) == .loaded)
    }

    @Test func aPartialDeliveryShowsTheCardsItHas() {
        #expect(GalleryLoading.phase(after: .delivered(rendered: 2, requested: 6)) == .loaded)
    }

    @Test func aRunThatRendersNothingOffersARetry() {
        #expect(GalleryLoading.phase(after: .delivered(rendered: 0, requested: 6)) == .failed)
    }

    @Test func aRunThatRunsOutOfTimeOffersARetry() {
        #expect(GalleryLoading.phase(after: .timedOut(requested: 6)) == .failed)
    }

    @Test func aCancelledRunHandsTheGalleryBack() {
        #expect(GalleryLoading.phase(after: .cancelled) == .loaded)
    }

    @Test func onlyATroubledRunIsWorthLogging() {
        #expect(GalleryLoading.logNote(for: .delivered(rendered: 6, requested: 6)) == nil)
        #expect(GalleryLoading.logNote(for: .delivered(rendered: 0, requested: 0)) == nil)
        #expect(GalleryLoading.logNote(for: .cancelled) == nil)
        #expect(GalleryLoading.logNote(for: .delivered(rendered: 2, requested: 6)) != nil)
        #expect(GalleryLoading.logNote(for: .delivered(rendered: 0, requested: 6)) != nil)
        #expect(GalleryLoading.logNote(for: .timedOut(requested: 6)) != nil)
    }

    @Test func theLogSaysHowMuchArrived() {
        let note = GalleryLoading.logNote(for: .delivered(rendered: 2, requested: 6))
        #expect(note?.contains("2 of 6") == true)
    }

    @Test func theWaitIsLongEnoughForABigLibraryAndShortEnoughToNotice() {
        #expect(GalleryLoading.timeout >= .seconds(20))
        #expect(GalleryLoading.timeout <= .seconds(60))
    }
}
