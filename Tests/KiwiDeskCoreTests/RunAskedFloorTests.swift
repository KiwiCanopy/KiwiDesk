import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...9).map { WindowID(UInt32($0)) }
private let screen = CGRect(x: 0, y: 0, width: 1920, height: 800)

@MainActor
private func isParked(_ frame: CGRect?, in rect: CGRect = screen) -> Bool {
    guard let frame else { return false }
    return TilingEngine.looksStashed(frame, in: rect)
}

/// Usable 1900 × 780: master w1, a stack zone of w2 and w3 that
/// fits both at the configured minimum.
private func context(minimum: CGFloat = 300) -> LayoutContext {
    var context = LayoutContext(
        bounds: screen,
        gaps: .uniform(10),
        focused: ids[1]
    )
    context.minWindowSize = .square(minimum)
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
        minimum: CGFloat = 300,
        _ edit: (inout LayoutContext) -> Void = { _ in }
    ) -> [WindowID: CGRect] {
        var ctx = context(minimum: minimum)
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

    /// At the margin the zone still fits whole, every member at
    /// its share; one point past it the refusal plans the run.
    @Test("A snap's few points leave the zone fitting")
    func snapNoiseFits() throws {
        let share = try askedShare()
        let margin = EffectiveSizeBound.refusalMargin
        let atMargin = frames(refusal(share, share + margin))
        #expect(abs((atMargin[ids[2]]?.height ?? 0) - share) < 0.5)
        let past = frames(refusal(share, share + margin + 1))
        #expect((past[ids[2]]?.height ?? 0) >= share + margin + 0.5)
    }

    /// Two refusals that disagree, the way Telegram's did: the run
    /// plans the smaller, the one the app showed it can stand at.
    @Test("The least refusal plans the run")
    func leastRefusalPlans() {
        let bound = EffectiveSizeBound(height: [
            .init(asked: 300, answered: 550),
            .init(asked: 400, answered: 700),
        ])
        // 200 + 550 + gap fits 780; 700 would not.
        let frames = frames(bound, minimum: 200)
        #expect(!isParked(frames[ids[2]]))
        #expect((frames[ids[2]]?.height ?? 0) >= 549.5)
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
        ctx.focused = ids[3]
        // Nine windows: the last row is a run showing three cells.
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
        #expect(!isParked(shown, in: grid))
        #expect(shown.width >= cell + 300 - 0.5)
        // The width refusal plans the row's run, never its height.
        let height = try #require(plain[ids[3]]).height
        #expect(abs(shown.height - height) < 0.5)
    }

    /// A refusal plans a run and never the shape (#2687's cap
    /// stays corroborated): an auto-sized Grid keeps its columns
    /// and rows beside one.
    @Test("A refusal leaves an auto Grid's shape alone")
    func refusalKeepsTheGridShape() throws {
        let grid = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        var ctx = LayoutContext(bounds: grid, gaps: .uniform(10))
        ctx.minWindowSize = .square(300)
        ctx.grid.autoSize = true
        let members = Array(ids[0...3])
        let plain = try #require(
            GridLayout.shape(for: members, in: ctx)
        )
        ctx.sizeBounds = [
            ids[0]: EffectiveSizeBound(
                width: [.init(asked: 300, answered: 1200)],
                height: [.init(asked: 300, answered: 900)]
            )
        ]
        let refused = try #require(
            GridLayout.shape(for: members, in: ctx)
        )
        #expect(refused.columns == plain.columns)
        #expect(refused.rows == plain.rows)
    }
}
