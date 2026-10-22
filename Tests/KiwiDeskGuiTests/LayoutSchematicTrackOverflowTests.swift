import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The preview's overflow track keeps the layout's contract
/// (#1354, #2235): below the stand-in fit every window tiles, and
/// past it as many as fit are shown while the rest wait hidden
/// behind the edge slot — never a pile from window one, which the
/// owner saw the preview draw on the device (2026-09-13).
///
/// Main-actor spend: three geometry cases over a view fixture —
/// the view's stored properties are main-actor, so the suite is;
/// no AppKit measurement, no source scan.
@Suite("Track preview overflow track")
@MainActor
struct LayoutSchematicTrackOverflowTests {
    private static let fits = LayoutSchematic.trackSpillCapacity
    private let size = CGSize(width: 40, height: 120)

    /// `windows` in a limit-2 space under `own_track`: one normal
    /// track and the overflow holding the other `windows - 1`.
    private func track(
        windows: Int,
        placement: SpawnPlacement = .first
    ) -> TrackSchematic {
        TrackSchematic(
            axis: .vertical,
            newWindow: .ownTrack,
            placement: placement,
            limit: TrackParams.minLimit,
            autoTracks: false,
            windows: windows
        )
    }

    /// Rects that never overlap along the axis: every top at or
    /// below the previous bottom.
    private func tiled(_ rects: [CGRect]) -> Bool {
        zip(rects, rects.dropFirst()).allSatisfy { a, b in
            b.minY >= a.maxY
        }
    }

    @Test("below the fit the overflow track tiles every window")
    func belowTheFitTiles() {
        for overflow in 1...Self.fits {
            let s = track(windows: overflow + 1)
            #expect(s.overflowWindows == overflow)
            let slots = s.overflowSlots(size)
            #expect(slots.count == overflow)
            #expect(slots.allSatisfy { !$0.hidden })
            #expect(tiled(slots.map(\.rect)), "\(overflow) overlapped")
        }
    }

    @Test("past the fit the rest wait behind the last shown slot")
    func pastTheFitHides() {
        let s = track(windows: Self.fits + 3)
        let slots = s.overflowSlots(size)
        #expect(slots.count == Self.fits + 2)
        let shown = Array(slots.prefix(Self.fits))
        let hidden = Array(slots.dropFirst(Self.fits))
        let edge = shown.last?.rect
        let shownVisible = shown.allSatisfy { !$0.hidden }
        let hiddenBehind = hidden.allSatisfy {
            $0.hidden && $0.rect == edge
        }
        #expect(shownVisible)
        #expect(tiled(shown.map(\.rect)))
        #expect(hiddenBehind)
    }

    @Test("an incoming window folding in ends the run at itself")
    func incomingEndsTheRun() throws {
        let s = track(windows: Self.fits + 3, placement: .last)
        try #require(s.incomingFolds)
        let slots = s.overflowSlots(size)
        let last = try #require(slots.last)
        #expect(!last.hidden)
        #expect(slots.first?.hidden == true)
        #expect(slots.first?.rect == slots[slots.count - Self.fits].rect)
    }
}
