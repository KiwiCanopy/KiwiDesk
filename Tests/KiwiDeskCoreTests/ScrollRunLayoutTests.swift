import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...6).map { WindowID(UInt32($0)) }
private let screen = CGRect(x: 0, y: 0, width: 1920, height: 800)

/// A hidden window is parked at the hide corner (#2235 ruling,
/// 2026-10-22), never inside the screen's usable area.
@MainActor
private func isParked(_ frame: CGRect?) -> Bool {
    guard let frame else { return false }
    return TilingEngine.looksStashed(frame, in: screen)
}

/// Usable 1900 × 780: a stack zone of five fits two at 300 pt.
private func context(
    focused: WindowID? = nil,
    heads: Set<WindowID> = []
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1920, height: 800),
        gaps: .uniform(10),
        focused: focused
    )
    context.runHeads = heads
    return context
}

/// The Stack and Track layouts placing a scrolled run (#2235):
/// focus scrolls it, a resting head holds it, each zone and each
/// track scrolls on its own, and `RunCover` reads what it hides.
@Suite("Scroll run layouts")
@MainActor
struct ScrollRunLayoutTests {
    /// Master w1, stack w2…w6.
    private let tiled = Array(ids)

    @Test("Focus on a hidden window scrolls it into the run")
    func focusScrollsIn() throws {
        let frames = StackLayout().calculateGeometry(
            for: tiled,
            in: context(focused: ids[5])
        )
        let last = try #require(frames[ids[5]])
        #expect(abs(last.maxY - 790) < 0.01)
        // w5 shares the zone with w6; w2…w4 wait parked.
        let edge = try #require(frames[ids[4]])
        #expect(edge.maxY + 10 == last.minY)
        #expect(isParked(frames[ids[1]]))
        #expect(isParked(frames[ids[3]]))
        #expect(!isParked(edge))
    }

    @Test("A resting head holds the run while focus is elsewhere")
    func headHolds() throws {
        let held = StackLayout().calculateGeometry(
            for: tiled,
            in: context(focused: ids[0], heads: [ids[3]])
        )
        let fresh = StackLayout().calculateGeometry(
            for: tiled,
            in: context(focused: ids[0])
        )
        #expect(held[ids[3]]?.minY == 10)
        #expect(fresh[ids[1]]?.minY == 10)
        // The master never moves for the run.
        #expect(held[ids[0]] == fresh[ids[0]])
    }

    @Test("A learned floor larger than the zone is shown alone")
    func learnedFloorAlone() throws {
        var ctx = context(focused: ids[2])
        ctx.sizeBounds = [
            ids[2]: EffectiveSizeBound(height: [
                .init(asked: 250, answered: 900),
                .init(asked: 200, answered: 900),
            ])
        ]
        let frames = StackLayout().calculateGeometry(for: tiled, in: ctx)
        let alone = try #require(frames[ids[2]])
        #expect(abs(alone.height - 780) < 0.01)
        #expect(isParked(frames[ids[1]]))
        #expect(isParked(frames[ids[3]]))
    }

    /// The device case: an app whose minimum exceeds the slot
    /// grew down from the slot into the shown run (Zen, 495 pt in
    /// a 432 pt slot). Parked at its own size, it shows nowhere.
    @Test("A hidden window larger than its slot parks at its size")
    func oversizedHiddenParks() throws {
        var ctx = context(focused: ids[5])
        ctx.sizeBounds = [
            ids[1]: EffectiveSizeBound(height: [
                .init(asked: 385, answered: 500),
                .init(asked: 300, answered: 500),
            ])
        ]
        let frames = StackLayout().calculateGeometry(for: tiled, in: ctx)
        let hidden = try #require(frames[ids[1]])
        #expect(isParked(hidden))
        #expect(abs(hidden.height - 500) < 0.01)
        let usable = screen.insetBy(dx: 10, dy: 10)
        #expect(
            hidden.intersection(usable).height <= TilingEngine.stashPeekY
        )
    }

    /// A shelf on the right reserves its strip off `bounds`; the
    /// park still lands at the screen's corner, or it reads as no
    /// park and flies (#2235 review).
    @Test("A run parks at the screen's corner past a reserved shelf")
    func parkIgnoresTheShelf() throws {
        var ctx = context(focused: ids[5])
        ctx.bounds = CGRect(x: 0, y: 0, width: 1860, height: 800)
        ctx.parkBounds = screen
        let frames = StackLayout().calculateGeometry(for: tiled, in: ctx)
        #expect(isParked(frames[ids[1]]))
    }

    @Test("Monocle parks at the screen's corner past a reserved shelf")
    func monocleParkIgnoresTheShelf() throws {
        var ctx = context(focused: ids[0])
        ctx.bounds = CGRect(x: 0, y: 0, width: 1860, height: 800)
        ctx.parkBounds = screen
        ctx.monocle.hideStyle = .park
        let frames = MonocleLayout().calculateGeometry(for: tiled, in: ctx)
        #expect(isParked(frames[ids[1]]))
    }

    @Test("Every overflowing track scrolls on its own")
    func tracksScrollApart() throws {
        var ctx = context(focused: ids[5])
        ctx.track.autoTracks = false
        ctx.track.limit = 2
        // Two tracks: w1…w3 and w4…w6, three each in 780 pt.
        ctx.trackBreaks = [ids[3]]
        let frames = TrackLayout().calculateGeometry(for: tiled, in: ctx)
        // The first track rests at its head; the second ends at
        // its focus.
        #expect(frames[ids[0]]?.minY == 10)
        #expect(isParked(frames[ids[2]]))
        #expect(!isParked(frames[ids[1]]))
        #expect(abs((frames[ids[5]]?.maxY ?? 0) - 790) < 0.01)
        #expect(isParked(frames[ids[3]]))
        #expect(!isParked(frames[ids[4]]))
    }

    @Test("The cover names each hidden window's edge and the heads")
    func coverReadsTheRun() throws {
        let cover = try #require(
            RunCover.of(
                space: "s",
                mode: .stack,
                tiled: tiled,
                in: context(focused: ids[5])
            )
        )
        #expect(cover.heads == [ids[4]])
        #expect(cover.behind[ids[1]] == ids[4])
        #expect(cover.behind[ids[3]] == ids[4])
        #expect(cover.behind[ids[5]] == nil)
    }

    @Test("A zone that fits draws no run and no cover")
    func fittingZoneHasNoCover() throws {
        let cover = try #require(
            RunCover.of(
                space: "s",
                mode: .stack,
                tiled: Array(tiled.prefix(3)),
                in: context()
            )
        )
        #expect(cover.behind.isEmpty)
        #expect(cover.heads.isEmpty)
    }

    @Test("A run's extra is what the shown floors leave the weights")
    func extraIsTheWeightSpan() throws {
        let cover = try #require(
            RunCover.of(
                space: "s",
                mode: .stack,
                tiled: tiled,
                in: context(focused: ids[5])
            )
        )
        let run = try #require(cover.runs.first)
        // The fixture's own numbers: the zone's span inside the
        // outer gaps, less each shown floor and the gaps between.
        let probe = context()
        let gap = CGFloat(10)
        let span = probe.bounds.height - 2 * gap
        let shown = CGFloat(run.shown.count)
        let floor = probe.minWindowSize.height
        #expect(shown >= 2)
        let expected = span - shown * floor - (shown - 1) * gap
        #expect(abs(run.extra - expected) < 0.01)
    }
}
