import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...3).map { WindowID(UInt32($0)) }
private let screen = CGRect(x: 0, y: 0, width: 1920, height: 800)

@MainActor
private func isParked(_ frame: CGRect?) -> Bool {
    guard let frame else { return false }
    return TilingEngine.looksStashed(frame, in: screen)
}

/// Usable 1900 × 780: master w1, a stack zone of w2 and w3 that
/// fits both at the configured minimum.
private func context(focused: WindowID? = ids[1]) -> LayoutContext {
    var context = LayoutContext(
        bounds: screen,
        gaps: .uniform(10),
        focused: focused
    )
    context.minWindowSize = .square(300)
    return context
}

/// A run plans each member with the app's own answer at the span
/// the zone asks it (#2774): an app that refused its share once —
/// one per-ask entry, never corroborated, the way Telegram answers
/// each height differently — is laid at that answer rather than
/// at the configured minimum, so the zone scrolls instead of
/// landing the residue over its neighbour.
@Suite("Run floors from the asked span")
@MainActor
struct RunAskedFloorTests {
    private let tiled = Array(ids)

    /// The share the zone asks w3 with no learning, read off the
    /// layout itself so the entry keys the ask the layout issues.
    private func askedShare() throws -> CGFloat {
        let frames = StackLayout().calculateGeometry(
            for: tiled,
            in: context()
        )
        return try #require(frames[ids[2]]).height
    }

    @Test("A refused share makes the zone scroll")
    func refusedShareScrolls() throws {
        let share = try askedShare()
        #expect(share >= 300)
        var ctx = context()
        ctx.sizeBounds = [
            ids[2]: EffectiveSizeBound(height: [
                .init(asked: share, answered: 600)
            ])
        ]
        let frames = StackLayout().calculateGeometry(for: tiled, in: ctx)
        // 600 + 300 + gap overflows 780: one of the pair waits
        // parked, the focused w2 stays shown.
        #expect(!isParked(frames[ids[1]]))
        #expect(isParked(frames[ids[2]]))
    }

    @Test("A complied share keeps both shown")
    func compliedShareFits() throws {
        let share = try askedShare()
        var ctx = context()
        ctx.sizeBounds = [
            ids[2]: EffectiveSizeBound(height: [
                .init(asked: share - 40, answered: 600)
            ])
        ]
        let frames = StackLayout().calculateGeometry(for: tiled, in: ctx)
        #expect(!isParked(frames[ids[1]]))
        #expect(!isParked(frames[ids[2]]))
    }

    @Test("A forced pass asks past the learned answer")
    func forcedPassProbes() throws {
        let share = try askedShare()
        var ctx = context()
        ctx.probesBeyondBounds = true
        ctx.sizeBounds = [
            ids[2]: EffectiveSizeBound(height: [
                .init(asked: share, answered: 600)
            ])
        ]
        let frames = StackLayout().calculateGeometry(for: tiled, in: ctx)
        #expect(!isParked(frames[ids[2]]))
    }
}
