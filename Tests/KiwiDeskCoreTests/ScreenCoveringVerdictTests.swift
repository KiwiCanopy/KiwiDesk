import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The screen-covering verdict's algebra (#1787). Its consumers
/// — the float fit and the shelf stand-down — hold the
/// process-global `isUser` override, so they live in
/// `FullscreenStandDownTests+Presentation.swift`.
@Suite("Screen-covering verdict (#1787)")
struct ScreenCoveringVerdictTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    @Test("Covering is the whole screen, within the tolerance")
    func coveringVerdict() {
        #expect(KiwiCore.covers(screen, screen))
        // PowerPoint's own ask, 1 pt past every edge.
        #expect(KiwiCore.covers(screen.insetBy(dx: -1, dy: -1), screen))
        #expect(KiwiCore.covers(screen.insetBy(dx: 1, dy: 1), screen))
        #expect(!KiwiCore.covers(screen.insetBy(dx: 3, dy: 3), screen))
        // Larger than the screen is an oversized float, not a show.
        #expect(!KiwiCore.covers(screen.insetBy(dx: -400, dy: -400), screen))
        // A maximised titled window stops at the menu bar.
        var belowMenuBar = screen
        belowMenuBar.origin.y = 32
        belowMenuBar.size.height -= 32
        #expect(!KiwiCore.covers(belowMenuBar, screen))
        // Where the fit had put the show: pushed under the shelf.
        #expect(
            !KiwiCore.covers(
                CGRect(x: 0, y: 77, width: 1728, height: 1117),
                screen
            )
        )
        #expect(!KiwiCore.covers(screen, .zero), "no screen, no cover")
    }
}

/// The two live reads the verdict takes are pinned by
/// `makeTestCore` (#1787). Asked through the factory rather than
/// read off its source: a host always has windows and a screen,
/// so a pin dropped from BOTH twins — which the twins-identical
/// clause cannot see — answers non-empty here.
@Suite("Screen-covering seams are pinned (#1787)")
@MainActor
struct ScreenCoveringPinTests {
    @Test("makeTestCore hands the verdict no host screen or window")
    func factoryPinsBothReads() {
        let core = makeTestCore()
        #expect(core.shelves.frontWindowFrames().isEmpty)
        #expect(core.shelves.screenFrames().isEmpty)
    }
}
