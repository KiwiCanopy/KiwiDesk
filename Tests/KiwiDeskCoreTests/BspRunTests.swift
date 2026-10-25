import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let ids = (1...8).map { WindowID(UInt32($0)) }

private func rect(
    _ x: CGFloat,
    _ y: CGFloat,
    _ width: CGFloat,
    _ height: CGFloat
) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}

/// A corroborated learned floor of `span` (two refused asks).
private func floor(_ span: CGFloat) -> [EffectiveSizeBound.Axis] {
    [
        .init(asked: 250, answered: span),
        .init(asked: 200, answered: span),
    ]
}

/// Alternating dwindle at gap 10, min 300, over `width` × 720:
/// usable is (10, 10, width − 20, 700).
private func context(
    width: CGFloat = 1000,
    focused: WindowID? = nil
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: width, height: 720),
        gaps: .uniform(10),
        focused: focused
    )
    context.bsp.strategy = .alternating
    return context
}

@MainActor
private func isParked(_ frame: CGRect?, in context: LayoutContext) -> Bool {
    guard let frame else { return false }
    return TilingEngine.looksStashed(frame, in: context.bounds)
}

/// BSP's overflow scrolls the trailing chain of same-direction
/// splits along the last split (#2542): the windows split off the
/// other way stay put, the chain is as thick as its widest floor,
/// and only a region too small for one window still piles.
@Suite("BSP run")
@MainActor
struct BspRunTests {
    @Test("Before anything overflows, the dwindle is unchanged")
    func fittingLayoutIsUnchanged() throws {
        let ctx = context()
        let three = Array(ids.prefix(3))
        #expect(BspLayout.zones(for: three, in: ctx)?.isEmpty == true)
        let frames = BspLayout().calculateGeometry(for: three, in: ctx)
        #expect(frames[ids[0]] == rect(10, 10, 485, 700))
        #expect(frames[ids[1]] == rect(505, 10, 485, 345))
        #expect(frames[ids[2]] == rect(505, 365, 485, 345))
    }

    @Test("The last split's chain scrolls along it; the rest stay")
    func chainScrollsAlongTheLastSplit() throws {
        // w1 | (w2 over w3): the next side-by-side split cannot
        // hold two, so the vertical chain w2…w4 scrolls.
        let ctx = context()
        let four = Array(ids.prefix(4))
        let zone = try #require(BspLayout.zones(for: four, in: ctx)?.first)
        #expect(zone.vertical)
        #expect(zone.members == Array(ids[1..<4]))
        #expect(zone.region == rect(505, 10, 485, 700))
        let frames = BspLayout().calculateGeometry(for: four, in: ctx)
        #expect(frames[ids[0]] == rect(10, 10, 485, 700))
        let top = try #require(frames[ids[1]])
        let bottom = try #require(frames[ids[2]])
        #expect(top.minY == 10)
        #expect(abs(bottom.maxY - 710) < 0.01)
        #expect(isParked(frames[ids[3]], in: ctx))
    }

    @Test("Focus on a hidden window scrolls it in")
    func focusScrollsIn() throws {
        let ctx = context(focused: ids[3])
        let frames = BspLayout().calculateGeometry(
            for: Array(ids.prefix(4)),
            in: ctx
        )
        #expect(isParked(frames[ids[1]], in: ctx))
        let last = try #require(frames[ids[3]])
        #expect(abs(last.maxY - 710) < 0.01)
        #expect(frames[ids[0]]?.width == 485)
    }

    @Test("The chain is as thick as its widest floor, hidden or not")
    func chainTakesItsWidestFloor() throws {
        var ctx = context()
        ctx.sizeBounds = [ids[3]: EffectiveSizeBound(width: floor(600))]
        let frames = BspLayout().calculateGeometry(
            for: Array(ids.prefix(4)),
            in: ctx
        )
        #expect(isParked(frames[ids[3]], in: ctx))
        let shown = try #require(frames[ids[1]])
        #expect(abs(shown.width - 600) < 0.01)
        let fixed = try #require(frames[ids[0]])
        #expect(abs(fixed.width - 370) < 0.01)
    }

    @Test("A mark facing a fixed window straddles the inner gap")
    func innerEndStraddlesTheGap() throws {
        // w1 | (w2 over (w3 | rest)): the side-by-side chain from
        // w3 starts beside w1 and runs to the screen edge.
        let ctx = context(width: 1320, focused: ids[5])
        let six = Array(ids.prefix(6))
        let zone = try #require(BspLayout.zones(for: six, in: ctx)?.first)
        #expect(!zone.vertical)
        #expect(zone.members == Array(ids[2..<6]))
        let bounds = zone.markBounds(in: ctx)
        #expect(bounds.minX == zone.region.minX - 5 - OverflowMark.depth / 2)
        #expect(bounds.maxX == ctx.bounds.maxX)
        let cover = try #require(
            RunCover.of(space: SpaceID("1"), mode: .bsp, tiled: six, in: ctx)
        )
        let mark = try #require(
            OverflowMark.marks(of: cover).first { $0.end == .left }
        )
        let frames = BspLayout().calculateGeometry(for: six, in: ctx)
        let anchor = try #require(frames[mark.anchor])
        let fixed = try #require(frames[ids[0]])
        let rect = OverflowMark.frame(
            end: .left,
            size: OverflowMark.size(end: .left, textWidth: 8),
            anchor: anchor,
            bounds: mark.bounds
        )
        #expect(rect.minX < fixed.maxX)
        #expect(rect.maxX > anchor.minX)
    }

    @Test("A screen too narrow for two scrolls everything")
    func wholeSpaceScrolls() throws {
        let ctx = context(width: 500)
        let zone = try #require(
            BspLayout.zones(for: Array(ids.prefix(3)), in: ctx)?.first
        )
        #expect(!zone.vertical)
        #expect(zone.members == Array(ids.prefix(3)))
        #expect(zone.run(in: ctx)?.visible == 0..<1)
    }

    @Test("Any run's end inside the screen straddles; one at it, not")
    func markBoundsAreLayoutAgnostic() throws {
        // A Stack master zone beside its stack zone takes the
        // same reading as a BSP chain (#2542).
        let ctx = context()
        let usable = ctx.usable
        let inner = RunZone(
            members: Array(ids.prefix(2)),
            region: rect(usable.minX, usable.minY, 400, usable.height),
            vertical: false
        )
        let bounds = inner.markBounds(in: ctx)
        #expect(bounds.minX == ctx.bounds.minX)
        #expect(bounds.maxX == usable.minX + 400 + 5 + OverflowMark.depth / 2)
        let column = RunZone(
            members: Array(ids.prefix(2)),
            region: usable,
            vertical: true
        )
        #expect(column.markBounds(in: ctx) == ctx.bounds)
    }
}
