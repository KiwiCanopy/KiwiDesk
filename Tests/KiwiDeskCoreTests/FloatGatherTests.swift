import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The gather decision's algebra (#1177): visibility is the
/// scope, partly-outside counts, a corner counts, a fully
/// visible member is untouched, and the gathered take the quit
/// grid over the region.
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

    @Test("Only the outside members are gathered, in member order")
    func gathersOutsideOnly() {
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
        #expect(targets[a] == nil)
        #expect(
            targets
                == QuitGridLayout.frames(
                    for: [b, c],
                    in: Self.region,
                    minSize: 100,
                    targetDepth: 5
                )
        )
        for frame in targets.values {
            #expect(Self.region.contains(frame))
        }
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
