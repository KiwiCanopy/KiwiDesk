import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Settings with both bars on one edge, the Space Bar Always and the
/// App Bar in Monocle Auto beside it, the pocket on that edge,
/// Monocle's "Maximize windows" as `maximize` says.
private func settings(maximize: Bool) -> TilingSettings {
    var settings = TilingSettings()
    settings.spaceBarStyle.visibility = .always
    settings.spaceBarStyle.setEdge(.top)
    settings.appBarStyle.setEdge(.top)
    settings.monocle.appBar.visibility = .auto
    settings.kiwishelf.pocketVisibility = .auto
    settings.kiwishelf.pocketEdge = .top
    settings.monocle.maximizeWindows = maximize
    return settings
}

/// Monocle's "Maximize windows" reads both bars as Hidden in Monocle
/// through the one `barVisibilities(in:)`, never as a stand-down, and
/// rests the pocket nowhere there (#2976 ▸ 3, 4).
@Suite("Monocle maximize windows: bars and pocket (#2976)")
struct MonocleMaximizeBarTests {
    @Test("Both bars read Hidden in Monocle alone")
    func barsReadHidden() {
        let on = settings(maximize: true)
        #expect(on.barVisibilities(in: .monocle).space == .hidden)
        #expect(on.barVisibilities(in: .monocle).app == .hidden)
        #expect(on.barVisibilities(in: .bsp).space == .always)
        #expect(on.barVisibilities(in: .scrolling).space == .always)
        let off = settings(maximize: false)
        #expect(off.barVisibilities(in: .monocle).space == .always)
        #expect(off.barVisibilities(in: .monocle).app == .auto)
    }

    @Test("A layout with no App Bar stays without one")
    func absentAppBarStaysAbsent() {
        let on = settings(maximize: true)
        #expect(on.barVisibilities(in: .bsp).app == nil)
    }

    @Test("Nothing draws at rest; the menu-bar item names the Space")
    func nothingDrawsAtRest() {
        let on = settings(maximize: true)
        #expect(!on.drawsAtRest(.space, in: .monocle, on: nil))
        #expect(!on.drawsAtRest(.app, in: .monocle, on: nil))
        let off = settings(maximize: false)
        #expect(off.drawsAtRest(.space, in: .monocle, on: nil))
    }

    @Test("A bar's shortcut stays live, Hidden beating Always")
    func shortcutStaysLive() {
        let on = settings(maximize: true)
        #expect(on.revealActionLive(.space, in: .monocle))
        #expect(!on.autoReadsAlways(.app, in: .monocle, on: nil))
        let off = settings(maximize: false)
        #expect(!off.revealActionLive(.space, in: .monocle))
        #expect(off.autoReadsAlways(.app, in: .monocle, on: nil))
    }

    @Test("Some bar hides, so the Reveal row stays live")
    func someBarHides() {
        var on = settings(maximize: true)
        on.monocle.appBar.visibility = .always
        on.scrolling.appBar.visibility = .always
        #expect(on.someBarHides)
        on.monocle.maximizeWindows = false
        #expect(!on.someBarHides)
    }

    @Test("Monocle reserves nothing: no strip, no pocket")
    func reservesNothing() {
        let visible = CGRect(x: 0, y: 25, width: 1600, height: 1000)
        let on = settings(maximize: true)
        #expect(on.shelfEdges(in: .monocle, on: nil).isEmpty)
        #expect(on.pocketReservation(in: .monocle, on: nil) == nil)
        #expect(
            on.layoutBounds(
                from: visible,
                mode: .monocle,
                on: nil,
                pocketAtRest: on.pocketRests
            ) == visible
        )
        #expect(!on.shelfEdges(in: .bsp, on: nil).isEmpty)
    }

    @Test("The pocket rests nowhere on a maximizing Monocle")
    func pocketRestsNowhere() {
        let on = settings(maximize: true)
        #expect(on.pocketRests)
        #expect(!on.pocketRests(in: .monocle))
        #expect(on.pocketRests(in: .bsp))
        #expect(settings(maximize: false).pocketRests(in: .monocle))
    }

    @Test("Monocle's gaps are zero only while it maximizes")
    func gapsZero() {
        var on = settings(maximize: true)
        on.gapsGlobal = Gaps(
            outer: .init(top: 10, bottom: 10, left: 10, right: 10),
            inner: .init(horizontal: 6, vertical: 6)
        )
        var space = Space(id: "1", mode: .monocle)
        let gaps = on.layoutGaps(for: space)
        #expect(gaps.outer.top == 0 && gaps.inner.horizontal == 0)
        space.mode = .grid
        #expect(on.layoutGaps(for: space) == on.gapsGlobal)
    }
}
