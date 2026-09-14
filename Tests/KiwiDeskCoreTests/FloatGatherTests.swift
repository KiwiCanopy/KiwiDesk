import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The gather decision's algebra (#1177): visibility is the
/// TRIGGER — partly-outside counts, a corner counts — and once
/// tripped every framed member takes the quit grid over the
/// region, as at the exit; with nothing outside, nothing moves.
@Suite("Float gather decision (#1177)")
struct FloatGatherTests {
    private static let region = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )

    private static let inside = CGRect(
        x: 100,
        y: 100,
        width: 800,
        height: 600
    )

    @Test("A frame fully inside is not outside")
    func insideIsInside() {
        #expect(!FloatGather.isOutside(Self.inside, of: Self.region))
    }

    @Test("A frame flush against an edge, within tolerance, is inside")
    func flushIsInside() {
        let flush = CGRect(
            x: Self.region.maxX - 800 + AppBarGeometry.clampTolerance,
            y: 100,
            width: 800,
            height: 600
        )
        #expect(!FloatGather.isOutside(flush, of: Self.region))
    }

    @Test("A sliver past an edge is outside")
    func partlyOutsideCounts() {
        let sliver = CGRect(
            x: Self.region.maxX - 790,
            y: 100,
            width: 800,
            height: 600
        )
        #expect(FloatGather.isOutside(sliver, of: Self.region))
    }

    @Test("A frame past the top edge is outside")
    func aboveCounts() {
        let above = CGRect(x: 100, y: 0, width: 800, height: 600)
        #expect(FloatGather.isOutside(above, of: Self.region))
    }

    @Test("One outside member gathers the whole space, in member order")
    func gathersAllOnceAnyIsOutside() {
        let a = WindowID(1)
        let b = WindowID(2)
        let c = WindowID(3)
        let scrolledOut = CGRect(
            x: 2000,
            y: 100,
            width: 800,
            height: 600
        )
        let parked = TilingEngine.stashFrame(
            CGRect(origin: .zero, size: CGSize(width: 800, height: 600)),
            in: Self.region,
            corner: .bottomRight
        )
        let targets = FloatGather.targets(
            members: [a, b, c],
            frames: [a: Self.inside, b: scrolledOut, c: parked],
            region: Self.region,
            minSize: 100,
            targetDepth: 5
        )
        #expect(targets[a] != nil)
        #expect(
            targets
                == QuitGridLayout.frames(
                    for: [a, b, c],
                    in: Self.region,
                    minSize: 100,
                    targetDepth: 5
                )
        )
        for frame in targets.values {
            #expect(Self.region.contains(frame))
        }
    }

    /// The judgment takes `region`; the grid may take a smaller
    /// one, so a member flush with a screen edge trips nothing
    /// while a gathered space lands inside the ring's reserve.
    @Test("The grid region is where a target lands, never the judge")
    func gridRegionLaysButNeverJudges() {
        let a = WindowID(1)
        let b = WindowID(2)
        let flush = CGRect(
            x: Self.region.maxX - 800,
            y: 100,
            width: 800,
            height: 600
        )
        let out = CGRect(x: 2100, y: 100, width: 800, height: 600)
        let grid = Self.region.insetBy(dx: 5, dy: 5)
        let untripped = FloatGather.targets(
            members: [a],
            frames: [a: flush],
            region: Self.region,
            grid: grid,
            minSize: 100,
            targetDepth: 5
        )
        #expect(untripped.isEmpty)
        let tripped = FloatGather.targets(
            members: [a, b],
            frames: [a: flush, b: out],
            region: Self.region,
            grid: grid,
            minSize: 100,
            targetDepth: 5
        )
        #expect(
            tripped
                == QuitGridLayout.frames(
                    for: [a, b],
                    in: grid,
                    minSize: 100,
                    targetDepth: 5
                )
        )
    }

    @Test("A member with no frame is not gathered")
    func unknownFrameIsSkipped() {
        let targets = FloatGather.targets(
            members: [WindowID(1)],
            frames: [:],
            region: Self.region,
            minSize: 100,
            targetDepth: 5
        )
        #expect(targets.isEmpty)
    }

    @Test("Nothing outside, nothing gathered")
    func nothingToGather() {
        let targets = FloatGather.targets(
            members: [WindowID(1)],
            frames: [WindowID(1): Self.inside],
            region: Self.region,
            minSize: 100,
            targetDepth: 5
        )
        #expect(targets.isEmpty)
    }
}
