import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the Track strip DRAWS, as opposed to what its fold
/// computes (#708 follow-up, 2026-08-16).
///
/// Split from `LayoutSchematicTrackFoldTests` at the §2.1
/// ceiling, and they fail apart anyway: that suite holds the
/// arithmetic, this one holds the frame the arithmetic feeds.
/// The split is the lesson of the two holes below — every
/// assertion over there reads a derived quantity, and a derived
/// quantity cannot say whether the view still branches on it.
@Suite("Layout preview track frame")
@MainActor
struct LayoutSchematicTrackFrameTests {
    private func track(
        limit: Int,
        windows: Int,
        auto: Bool = false,
        rule: TrackParams.NewWindowTrack = .ownTrack
    ) -> TrackSchematic {
        TrackSchematic(
            axis: .vertical,
            overflowStyle: .cascadeAll,
            newWindow: rule,
            placement: .last,
            limit: limit,
            autoTracks: auto,
            windows: windows
        )
    }

    /// The STRIP draws the overflow track only when something
    /// overflows, and rings the fold's own focused track.
    ///
    /// Both holes guard-prover found, and both let shipped
    /// behaviour break with all 3317 tests green (2026-08-16):
    ///
    /// - `trackViews`' `if overflowWindows > 0` could be deleted
    ///   — the strip drawing a far-edge pile at every count —
    ///   because every other assertion here reads
    ///   `drawsOverflowTrack`, which IS `overflowWindows > 0`.
    ///   The sweep below it compared `x > 0` with `x > 0`.
    /// - `focusIdx` could revert to the pre-#708 `trackCount / 2`
    ///   convention. `drawnFocusMatchesTheFold` pins that the run
    ///   and the slot share ONE index, never which — so the strip
    ///   would ring the middle track while the engine focuses the
    ///   newest.
    ///
    /// A source needle rather than an arithmetic read, because
    /// the subject is the view BODY: no property can say whether
    /// a branch around `overflowTrack` still exists.
    @Test("the strip's own branches survive")
    func stripDrawsWhatTheFoldDecides() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "TrackSchematic.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .filter { !$0.isWhitespace }
        #expect(source.count > 1000, "the scan read the strip")
        // The far-edge track is conditional on the fold.
        #expect(
            source.contains("ifdrawsOverflowTrack{overflowTrack}")
                || source.contains(
                    "ifoverflowWindows>0{overflowTrack}"
                ),
            Comment(
                rawValue:
                    "the strip draws its overflow track "
                    + "unconditionally — the caption says nothing "
                    + "about one at the shipped defaults"
            )
        )
        // And the drawn focus comes from the fold, not from a
        // fixed slot.
        #expect(
            source.contains("markerTracks.focus"),
            Comment(
                rawValue:
                    "focusIdx no longer reads the fold — the "
                    + "strip rings a track the engine does not "
                    + "focus"
            )
        )
        #expect(
            !source.contains("mintrackCount/2"),
            Comment(
                rawValue:
                    "the pre-#708 middle-slot convention is back"
            )
        )
    }

    /// HOLE 3: `trackGeoCap`'s VALUE was pinned by the assertion
    /// retired from `LayoutSchematicCountTests.trackOverflow`
    /// (`auto: true` at 12 windows drew 3 normal tracks) and the
    /// move did not replace it — the constant could be changed
    /// with the suite green (guard-prover, 2026-08-16). Every
    /// other retired assertion IS re-asserted here; this one was
    /// the gap.
    ///
    /// Stated WITHOUT reading `trackGeoCap`, which is the trap
    /// the first draft fell into: asserting `trackCount ==
    /// trackGeoCap - 1` moves with the constant and pins
    /// nothing (`rule-authoring.md` — a number-pin must derive
    /// the number from something INDEPENDENT, not from itself).
    ///
    /// What is independent: under auto-tracks the fold is the
    /// stand-in's and not the user's, so the typed limit stops
    /// mattering — and the count stays bounded while the window
    /// count grows. A retuned constant keeps both; a constant
    /// wired to the wrong arm, or dropped, breaks them.
    @Test("auto-tracks folds independently of the typed limit")
    func autoTracksFoldsAtTheStandIn() {
        let low = track(limit: 2, windows: 12, auto: true)
        let high = track(limit: 9, windows: 12, auto: true)
        #expect(
            low.trackCount == high.trackCount,
            "under auto-tracks the typed limit decides nothing"
        )
        #expect(low.drawsOverflowTrack)
        // Bounded ABOVE the fold, not everywhere: below it the
        // count still grows one track per window, because there
        // is nothing to fold yet. Asserting equality at 6
        // windows was simply false — 5 tracks there against 4 at
        // 12 — and the fixture caught it.
        let shallow = track(limit: 9, windows: 6, auto: true)
        #expect(high.trackCount < shallow.trackCount)
        // And the fixed arm is genuinely a different rule — a
        // typed 9 draws more than the auto fold allows, so the
        // stand-in is demonstrably scoped to auto.
        #expect(
            track(limit: 9, windows: 12).trackCount
                > high.trackCount
        )
    }

}
