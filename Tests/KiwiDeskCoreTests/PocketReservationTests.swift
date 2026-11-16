import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pocket's strip (#2784, #2978, #3361): a pocket resting as its
/// handle floats like a bar's handle and reserves nothing; the whole
/// mark reserves the shelf's own strip where the pocket reads Always
/// on an edge that draws no bar at rest.
@Suite("Pocket reservation (#2784)")
struct PocketReservationTests {
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)

    /// The Space Bar alone on top: `.bsp` hosts no App Bar.
    private func settings(
        space: ShelfVisibility,
        pocket: AppBarEdge,
        show: ShelfVisibility = .auto
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.pocketVisibility = show
        settings.spaceBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = space
        settings.kiwishelf.pocketEdge = pocket
        settings.kiwishelf.outerMargin = 3
        settings.kiwishelf.innerMargin = 5
        return settings
    }

    private func reserved(
        _ settings: TilingSettings,
        at edge: AppBarEdge,
        resting: Bool = true
    ) -> CGFloat {
        settings.shelfReservation(
            in: .bsp,
            on: nil,
            pocketAtRest: resting
        ).depth(of: edge)
    }

    @Test("a hidden bar's edge reserves nothing for the handle")
    func hiddenEdgeReservesNoHandle() {
        let hidden = settings(space: .hidden, pocket: .top)
        #expect(hidden.pocketRest(in: .bsp, on: nil) == .handle)
        #expect(reserved(hidden, at: .top) == 0)
        #expect(reserved(hidden, at: .top, resting: false) == 0)
        // Always on that edge stands the whole mark (#2978).
        let whole = settings(space: .hidden, pocket: .top, show: .always)
        #expect(whole.pocketRest(in: .bsp, on: nil) == .mark)
        #expect(reserved(whole, at: .top) == whole.kiwishelf.reservation)
        // Hidden reserves nothing, resting or not.
        let gone = settings(space: .hidden, pocket: .top, show: .hidden)
        #expect(reserved(gone, at: .top) == 0)
    }

    /// Nothing reserves on an Auto edge, the pocket's handle
    /// included (#3349, #3361 ruling 4).
    @Test("an Auto edge reserves nothing, the pocket included")
    func autoEdgeReservesNothing() {
        let auto = settings(space: .auto, pocket: .top)
        #expect(auto.pocketRest(in: .bsp, on: nil) == .handle)
        #expect(reserved(auto, at: .top) == 0)
    }

    @Test("a shown bar's edge holds the pocket as a section")
    func shownEdgeIsASection() {
        let shown = settings(space: .always, pocket: .top)
        #expect(shown.pocketRest(in: .bsp, on: nil) == .section)
        #expect(reserved(shown, at: .top) == shown.kiwishelf.reservation)
    }

    @Test("an edge no bar shows follows the pocket's own Show")
    func emptyEdgeFollowsThePocket() {
        let always = settings(
            space: .auto,
            pocket: .bottom,
            show: .always
        )
        #expect(always.pocketRest(in: .bsp, on: nil) == .mark)
        #expect(
            reserved(always, at: .bottom) == always.kiwishelf.reservation
        )
        let auto = settings(space: .always, pocket: .bottom)
        #expect(auto.pocketRest(in: .bsp, on: nil) == .handle)
        #expect(reserved(auto, at: .bottom) == 0)
        // The Space Bar's reserve off frees it, an App Bar this
        // layout does not host holding nothing.
        let both = settings(
            space: .always,
            pocket: .bottom,
            show: .always
        )
        var free = both
        free.spaceBarStyle.reserve = false
        #expect(reserved(free, at: .bottom) == 0)
        // The layout bounds take exactly what the strips reserve.
        let bounds = both.layoutBounds(
            from: visible,
            mode: .bsp,
            on: nil,
            pocketAtRest: true
        )
        #expect(
            visible.height - bounds.height
                == 2 * both.kiwishelf.reservation
        )
    }

    /// Settings' Pocket row notes a bar that keeps an Auto pocket
    /// shown (#2978).
    @Test("an Auto pocket on a shown bar's edge is noted")
    func autoPocketBesideAShownBar() {
        let shown = settings(space: .always, pocket: .top)
        #expect(shown.barKeepsAutoPocket(in: .bsp, on: nil))
        let hiding = settings(space: .auto, pocket: .top)
        #expect(!hiding.barKeepsAutoPocket(in: .bsp, on: nil))
        let apart = settings(space: .always, pocket: .bottom)
        #expect(!apart.barKeepsAutoPocket(in: .bsp, on: nil))
        let always = settings(space: .always, pocket: .top, show: .always)
        #expect(!always.barKeepsAutoPocket(in: .bsp, on: nil))
    }
}
