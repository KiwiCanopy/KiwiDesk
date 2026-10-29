import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...6).map { WindowID(UInt32($0)) }
private let screen = CGRect(x: 0, y: 0, width: 1920, height: 800)

@MainActor
private func isParked(_ frame: CGRect?, in rect: CGRect = screen) -> Bool {
    guard let frame else { return false }
    return TilingEngine.looksStashed(frame, in: rect)
}

/// Usable 1900 × 780: master w1, a stack zone of w2 and w3 that
/// fits both at the configured minimum.
private func context() -> LayoutContext {
    var context = LayoutContext(
        bounds: screen,
        gaps: .uniform(10),
        focused: ids[1]
    )
    context.minWindowSize = .square(300)
    return context
}

/// One refusal: `answered` to an ask of `asked`, never corroborated.
private func refusal(
    _ asked: CGFloat,
    _ answered: CGFloat
) -> EffectiveSizeBound {
    EffectiveSizeBound(height: [.init(asked: asked, answered: answered)])
}

/// A run plans each member no smaller than its least refusal on the
/// run axis (#2774): an app that answers each span differently —
/// one entry, never corroborated, the way Telegram answered 550,
/// 623 and 584 — scrolls the run rather than landing inward over
/// its neighbour, whichever span the zone asks it next.
@Suite("Run floors from a refusal")
@MainActor
struct RunAskedFloorTests {
    private let tiled = Array(ids[0...2])

    /// The span the zone asks w3 with nothing learned, read off the
    /// layout so the entry keys an ask the layout issues.
    private func askedShare() throws -> CGFloat {
        let frames = StackLayout().calculateGeometry(
            for: tiled,
            in: context()
        )
        return try #require(frames[ids[2]]).height
    }

    private func frames(
        _ bound: EffectiveSizeBound,
        _ edit: (inout LayoutContext) -> Void = { _ in }
    ) -> [WindowID: CGRect] {
        var ctx = context()
        ctx.sizeBounds = [ids[2]: bound]
        edit(&ctx)
        return StackLayout().calculateGeometry(for: tiled, in: ctx)
    }

    @Test("A refused share makes the zone scroll")
    func refusedShareScrolls() throws {
        let share = try askedShare()
        #expect(share >= 300)
        let frames = frames(refusal(share, 600))
        // 600 + 300 + gap overflows 780: w3 waits parked, the
        // focused w2 stays shown.
        #expect(!isParked(frames[ids[1]]))
        #expect(isParked(frames[ids[2]]))
    }

    @Test("A weight press keeps the run")
    func weightPressKeepsTheRun() throws {
        let share = try askedShare()
        let frames = frames(refusal(share, 600)) {
            $0.stackWeights = [ids[2]: 1.4]
        }
        #expect(isParked(frames[ids[2]]))
    }

    @Test("A snap's few points leave the zone fitting")
    func snapNoiseFits() throws {
        let share = try askedShare()
        let snap = EffectiveSizeBound.corroborationDistinctness
        let frames = frames(refusal(share, share + snap))
        #expect(!isParked(frames[ids[2]]))
    }

    @Test("An answer below its ask plans nothing")
    func ceilingPlansNothing() throws {
        let share = try askedShare()
        let frames = frames(refusal(share + 200, share + 100))
        #expect(!isParked(frames[ids[2]]))
    }

    @Test("A forced pass asks past the refusal")
    func forcedPassProbes() throws {
        let share = try askedShare()
        let frames = frames(refusal(share, 600)) {
            $0.probesBeyondBounds = true
        }
        #expect(!isParked(frames[ids[2]]))
    }

    /// The planning floor never reaches what the layout emits: a
    /// fresh ask stays the app's to answer.
    @Test("The refusal never consumes a fresh ask")
    func refusalNeverEmits() {
        let bound = refusal(300, 600)
        #expect(bound.refusedFloor(horizontal: false) == 600)
        #expect(bound.consumedHeight(asking: 450) == nil)
        #expect(bound.minHeight == nil)
    }

    @Test("A fixed Grid's last track lays a refused cell at its answer")
    func fixedGridCell() throws {
        let grid = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        var ctx = LayoutContext(bounds: grid, gaps: .uniform(10))
        ctx.minWindowSize = .square(300)
        ctx.grid.type = .rigid
        ctx.grid.columns = 3
        ctx.grid.rows = 2
        let members = Array(ids)
        let plain = GridLayout().calculateGeometry(for: members, in: ctx)
        let cell = try #require(plain[ids[3]]).width
        ctx.sizeBounds = [
            ids[3]: EffectiveSizeBound(width: [
                .init(asked: cell, answered: cell + 300)
            ])
        ]
        let frames = GridLayout().calculateGeometry(for: members, in: ctx)
        let shown = try #require(frames[ids[3]])
        #expect(
            isParked(shown, in: grid)
                || shown.width >= cell + 300 - 0.5
        )
    }
}
