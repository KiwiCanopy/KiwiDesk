import AppKit
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.handle_thickness` reaching the drawn handles through
/// the real `updateBars()` (#3451): an Auto bar's handle frame and
/// the Pocket handle's resting frame both take the shelf's depth.
@Suite(
    "Handle thickness wiring (#3451)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct HandleThicknessWiringTests {
    private func core(thickness: CGFloat) throws -> (KiwiCore, Display) {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.bottom)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .auto
        settings.kiwishelf.pocketEdge = .left
        settings.kiwishelf.pocketVisibility = .auto
        settings.kiwishelf.handleThickness = thickness
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        pinRevealLength()
        core.updateBars()
        return (core, display)
    }

    @Test("an Auto bar's handle is the shelf's depth", arguments: [2, 5])
    func barHandle(thickness: Int) throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try core(thickness: CGFloat(thickness))
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display.id, edge: .bottom),
            bar: .space
        )
        let spec = try #require(
            core.shelves.handles.handleForTesting(key)?.view.spec
        )
        #expect(spec.frame.height == CGFloat(thickness))
    }

    @Test("the Pocket handle rests on the shelf's depth")
    func pocketHandle() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (thin, a) = try core(thickness: 2)
        let (thick, b) = try core(thickness: 6)
        let rest = { (core: KiwiCore, display: Display) in
            core.pocketHandleFrame(on: display.id, risen: false)?.width
        }
        let low = try #require(rest(thin, a))
        let high = try #require(rest(thick, b))
        #expect(abs((high - low) - 4) < 0.001)
    }

    /// A put-in or take-out lands on the risen pocket past the
    /// shelf's tab, as the overlay draws it: 4 pt further in at
    /// 6 pt than at 2.
    @Test("a landing on the risen pocket clears the shelf's tab")
    func landingClearsTheTab() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (thin, a) = try core(thickness: 2)
        let (thick, b) = try core(thickness: 6)
        let low = try #require(thin.pocketLanding(on: a.id))
        let high = try #require(thick.pocketLanding(on: b.id))
        #expect(abs(abs(high.minX - low.minX) - 4) < 0.001)
        #expect(high.size == low.size)
    }

    /// The overlay hands the risen pocket its screen's tab depth:
    /// at 6 pt it stands `lift` past a 6 pt tab, not the default's.
    @Test("the risen pocket stands past the shelf's tab")
    func risenPocketClearsTheTab() throws {
        let rig = try PocketApproachTests().rig()
        defer { BarMotion.reducedOverride = nil }
        rig.core.tiler.settings.kiwishelf.handleThickness = 6
        rig.pass()
        rig.move(
            to: try PocketApproachTests().nearTab(try #require(rig.target))
        )
        let spec = try #require(rig.spec)
        let edge = try #require(spec.handle)
        let view = try #require(rig.core.pocketPlate.view(on: rig.display))
        let room = PocketPlateView.room(
            in: view.bounds,
            edge: edge,
            outer: spec.outer
        )
        let want = PocketPlateView.risenFrame(
            in: room,
            edge: edge,
            side: spec.risenSide,
            tabDepth: 6
        )
        #expect(view.pocket.frame == want)
    }
}
