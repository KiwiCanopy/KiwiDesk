import Foundation
import Testing

/// A Space item's boxed glass and its tint round from the one
/// `SpaceBarItemView.boxRadius` the item's layer reads (#1682).
/// Glass never renders under test, so the wiring is held by the
/// shape of `updateBoxGlasses`: the radius it hands both the
/// glass and the tint is that derivation's, never the uncapped
/// shelf radius.
@Suite("Box glass radius wiring")
struct BoxGlassRadiusNeedleTests {
    private func body() throws -> String {
        try SourceScan.functionBody(
            of: "updateBoxGlasses",
            in: "SpaceBarOverlay+BoxGlass.swift",
            under: "Bar"
        )
    }

    @Test("updateBoxGlasses takes the item's box radius")
    func radiusIsTheItems() throws {
        let body = try body()
        #expect(body.contains("let radius = SpaceBarItemView.boxRadius("))
        #expect(!body.contains("resolvedCornerRadius("))
        // Each item's own box, not one size for the run.
        let args = try #require(
            SourceScan.callArguments(
                of: "SpaceBarItemView.boxRadius(",
                in: body
            )
        )
        #expect(args.contains("size: frames[i].size"))
    }

    /// The front-app chip is a box too: its fill, glass, rim and
    /// indicator round from the same derivation, handed the
    /// chip's size, measured once in `frontChipRect` (#1856).
    @Test("the front-app chip takes its own box radius")
    func frontChipTakesIt() throws {
        let body = try SourceScan.functionBody(
            of: "frontChipRect",
            in: "SpaceBarOverlay+FrontAppBox.swift",
            under: "Bar"
        )
        let args = try #require(
            SourceScan.callArguments(
                of: "SpaceBarItemView.boxRadius(",
                in: body
            )
        )
        #expect(args.contains("size: rect.size"))
        #expect(!body.contains("resolvedCornerRadius("))
        let box = try SourceScan.functionBody(
            of: "layoutFrontBox",
            in: "SpaceBarOverlay+FrontAppBox.swift",
            under: "Bar"
        )
        #expect(box.contains("let (rect, radius) = frontChipRect("))
        #expect(!box.contains("resolvedCornerRadius("))
    }

    @Test("the glass and the tint are both handed that radius")
    func bothTakeIt() throws {
        let body = try body()
        let glass = try #require(
            SourceScan.callArguments(of: "GlassPlate.update(", in: body)
        )
        let tint = try #require(
            SourceScan.callArguments(of: "GlassTint.apply(", in: body)
        )
        #expect(glass.contains("cornerRadius: radius"))
        #expect(tint.contains("cornerRadius: radius"))
    }
}
