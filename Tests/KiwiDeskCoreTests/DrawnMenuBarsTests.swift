import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The #1386 correction over the owner's measured topology: the
/// built-in (1728×1117, notch) at the origin and a DELL U2720Q
/// (2560×1440) to its right at y −164, the WindowServer drawing a
/// 33 pt bar on the built-in and a 30 pt one on the DELL.
@Suite("Drawn menu bars (#1386)")
@MainActor
struct DrawnMenuBarsTests {
    private let builtIn = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let dell = CGRect(
        x: 1728,
        y: -164,
        width: 2560,
        height: 1440
    )
    /// The two bars as `CGWindowListCopyWindowInfo` lists them.
    private let bars = [
        CGRect(x: 1728, y: -159, width: 2560, height: 30),
        CGRect(x: 0, y: 0, width: 1728, height: 33),
    ]

    @Test("each drawn bar is filed under its own screen")
    func barsFileUnderTheirScreen() {
        let bottoms = DrawnMenuBars.bottoms(
            of: bars,
            screens: [(1, builtIn), (3, dell)],
            primaryHeight: 1117
        )
        #expect(bottoms == [1: 1084, 3: 1246])
    }

    @Test("a screen drawing no bar gets no entry")
    func screenWithoutBarHasNoEntry() {
        let bottoms = DrawnMenuBars.bottoms(
            of: [bars[1]],
            screens: [(1, builtIn), (3, dell)],
            primaryHeight: 1117
        )
        #expect(bottoms[3] == nil)
    }

    @Test("only a bar on a screen's top edge, and short, is filed")
    func onlyTopEdgeBarsFile() {
        let lowered = CGRect(x: 1728, y: 400, width: 2560, height: 30)
        let tall = CGRect(x: 1728, y: -159, width: 2560, height: 400)
        let bottoms = DrawnMenuBars.bottoms(
            of: [lowered, tall],
            screens: [(1, builtIn), (3, dell)],
            primaryHeight: 1117
        )
        #expect(bottoms.isEmpty)
    }

    @Test("the deepest of two bars on one screen wins")
    func deepestBarWins() {
        let deeper = CGRect(x: 1728, y: -159, width: 2560, height: 40)
        // Both orders: a last-listed-wins filing passes one.
        for listed in [[bars[0], deeper], [deeper, bars[0]]] {
            let bottoms = DrawnMenuBars.bottoms(
                of: listed,
                screens: [(1, builtIn), (3, dell)],
                primaryHeight: 1117
            )
            #expect(bottoms[3] == 1236)
        }
    }

    @Test("a stale hidden-bar top is lowered under the drawn bar")
    func staleTopIsLowered() {
        // The cache after the missed notification: no band.
        let stale = CGRect(x: 1728, y: -164, width: 2560, height: 1440)
        let cleared = GeometryUtils.clearingMenuBar(
            stale,
            barBottom: 1246
        )
        #expect(cleared.maxY == 1246)
        #expect(cleared.minY == stale.minY)
    }

    @Test("a correct top is never raised or moved")
    func correctTopIsKept() {
        // What AppKit reports once it has caught up: 31 pt band.
        let fresh = CGRect(x: 1728, y: -164, width: 2560, height: 1409)
        #expect(
            GeometryUtils.clearingMenuBar(fresh, barBottom: 1246)
                == fresh
        )
        #expect(
            GeometryUtils.clearingMenuBar(fresh, barBottom: nil)
                == fresh
        )
    }
}
