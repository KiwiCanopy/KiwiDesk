import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The preview's overflow track keeps the layout's contract
/// (`set_overflow_style`, #1354): a cascade begins only WHEN the
/// track overflows — more windows than the stand-in fit — and
/// the two styles differ only past that point. Drawn from the
/// first window, `cascade_all` read as "piles from window one",
/// which the layout never does; the owner saw the two disagree
/// on the device (2026-09-13).
///
/// Main-actor spend: three geometry cases over a view fixture —
/// the view's stored properties are main-actor, so the suite is;
/// no AppKit measurement, no source scan.
@Suite("Track preview overflow track")
@MainActor
struct LayoutSchematicTrackOverflowTests {
    private static let fits = LayoutSchematic.trackSpillCapacity
    private let size = CGSize(width: 40, height: 120)

    /// `windows` in a limit-2 space under `own_track`, the
    /// incoming placed first: one normal track (the `+`) and the
    /// overflow holding the other `windows - 1`.
    private func track(
        windows: Int,
        style: StackParams.OverflowStyle
    ) -> TrackSchematic {
        TrackSchematic(
            axis: .vertical,
            overflowStyle: style,
            newWindow: .ownTrack,
            placement: .first,
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

    @Test("below the fit both styles tile the overflow track")
    func belowTheFitTiles() {
        for style in [StackParams.OverflowStyle.cascadeAll, .cascadeOverflow] {
            for overflow in 1...Self.fits {
                // The `+` alone in the normal track, the rest in
                // the overflow.
                let s = track(windows: overflow + 1, style: style)
                #expect(s.overflowWindows == overflow)
                let rects = s.overflowSlots(size)
                #expect(rects.count == overflow)
                #expect(tiled(rects), "\(style) at \(overflow) piled")
            }
        }
    }

    @Test("past the fit, cascade_all piles every window")
    func pastTheFitCascadeAllPiles() {
        let s = track(windows: Self.fits + 3, style: .cascadeAll)
        let rects = s.overflowSlots(size)
        #expect(rects.count == Self.fits + 2)
        #expect(!tiled(rects))
        // Every pair overlaps: the pile, not a tiled prefix.
        #expect(
            zip(rects, rects.dropFirst()).allSatisfy { a, b in
                b.minY < a.maxY
            }
        )
    }

    @Test("past the fit, cascade_overflow keeps the fitting prefix tiled")
    func pastTheFitCascadeOverflowTilesThePrefix() {
        let s = track(windows: Self.fits + 3, style: .cascadeOverflow)
        let rects = s.overflowSlots(size)
        #expect(rects.count == Self.fits + 2)
        #expect(tiled(Array(rects.prefix(Self.fits))))
        // The rest pile under the prefix.
        let pile = Array(rects.dropFirst(Self.fits))
        #expect(pile.count == 2)
        #expect(pile[1].minY < pile[0].maxY)
        #expect(pile[0].minY >= rects[Self.fits - 1].maxY)
    }
}
