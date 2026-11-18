import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The minimum-size fit readout (#3461): the count is the engine's
/// carve and pitch over the layout's region with the global gaps,
/// and the door reads the main screen once, its size through the
/// one bounds hook, reserving the DRAFT's strip. The door clauses
/// need a screen, so they skip on a host with none rather than
/// pass by absence.
@Suite("Minimum size fit readout")
@MainActor
struct MinSizeFitTests {
    private let noOuter = Gaps(
        outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
        inner: Gaps.Inner(horizontal: 10, vertical: 10)
    )

    private func region(_ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }

    @Test("a count is the region plus one gap over the pitch")
    func counts() {
        // The #3461 report: 3200 × 900 at 400 with 8 pt gaps.
        let eight = Gaps(
            outer: Gaps.Outer(top: 8, bottom: 8, left: 8, right: 8),
            inner: Gaps.Inner(horizontal: 8, vertical: 8)
        )
        let report = MinSizeFit.counts(
            of: .square(400),
            in: region(3200, 900),
            gaps: eight
        )
        #expect(report.across == 7)
        #expect(report.down == 2)
        // Exactly three of 300 with two 10 pt gaps between them.
        let exact = MinSizeFit.counts(
            of: MinSize(width: 300, height: 500),
            in: region(920, 999),
            gaps: noOuter
        )
        #expect(exact.across == 3)
        #expect(exact.down == 1)
        // The outer gaps are carved first: 1216 less 16 fits two of
        // 400, where the whole 1216 would fit three.
        #expect(
            MinSizeFit.counts(
                of: .square(400),
                in: region(1216, 500),
                gaps: eight
            ).across == 2
        )
        // One point short of the third drops it.
        #expect(
            MinSizeFit.counts(
                of: .square(300),
                in: region(919, 300),
                gaps: noOuter
            ).across == 2
        )
        // Larger than the region fits none, never a negative.
        let none = MinSizeFit.counts(
            of: .square(1700),
            in: region(1512, 982),
            gaps: eight
        )
        #expect(none.across == 0)
        #expect(none.down == 0)
        // A region well inside its own outer gaps: the carve goes
        // past one pitch below zero, which would truncate to -1,
        // and still counts nothing.
        let wide = Gaps(
            outer: Gaps.Outer(top: 20, bottom: 20, left: 20, right: 20),
            inner: Gaps.Inner(horizontal: 8, vertical: 8)
        )
        let starved = MinSizeFit.counts(
            of: .square(10),
            in: region(4, 4),
            gaps: wide
        )
        #expect(starved.across == 0)
        #expect(starved.down == 0)
    }

    @Test(
        "the door takes the hook's size and the draft's strip",
        .enabled(if: !NSScreen.screens.isEmpty, "needs a screen")
    )
    func doorReadsTheHookAndDraft() throws {
        let core = makeTestCore()
        // A size no shipped screen has, so a read bypassing the
        // hook cannot answer the same counts by coincidence.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 3110, height: 1270)
        }
        // The live bar is wide; the draft has none.
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.barEdge = .left
        core.tiler.settings.kiwishelf.thickness = 700
        var draft = TilingSettings()
        draft.gapsGlobal = noOuter
        draft.spaceBarStyle.visibility = .hidden
        draft.kiwishelf.pocketVisibility = .hidden
        let fits = core.minSizeFits(
            [.bsp: .square(300), .grid: .square(400)],
            settings: draft
        )
        let fit = try #require(fits[.bsp])
        // (3110 + 10) / 310 = 10 across, (1270 + 10) / 310 = 4 down.
        #expect(fit.across == 10)
        #expect(fit.down == 4)
        #expect(!fit.screen.name.isEmpty)
        // Each layout counts its own size on the one screen.
        let grid = try #require(fits[.grid])
        #expect(grid.across == 7)
        #expect(grid.screen == fit.screen)
        // The draft's own strip is reserved: 700 off the width.
        var barred = draft
        barred.spaceBarStyle.visibility = .always
        barred.barEdge = .left
        barred.kiwishelf.thickness = 700
        let narrowed = try #require(
            core.minSizeFits([.bsp: .square(300)], settings: barred)[.bsp]
        )
        #expect(narrowed.across == 7)
    }

    @Test(
        "the door counts on the seed's main screen, not the first",
        .enabled(if: NSScreen.screens.count > 1, "needs two screens")
    )
    func doorTakesTheMainScreen() throws {
        let core = makeTestCore()
        let screens = NSScreen.screens
        let second = try #require(screens[1].kiwiDisplayID)
        PositionalDisplays.mainIDOverride = { second }
        defer { PositionalDisplays.mainIDOverride = nil }
        core.tiler.visibleBounds = { screen in
            screen.kiwiDisplayID == second
                ? CGRect(x: 0, y: 0, width: 3110, height: 1270)
                : CGRect(x: 0, y: 0, width: 1000, height: 1000)
        }
        var draft = TilingSettings()
        draft.gapsGlobal = noOuter
        draft.spaceBarStyle.visibility = .hidden
        draft.kiwishelf.pocketVisibility = .hidden
        let fit = try #require(
            core.minSizeFits([.bsp: .square(300)], settings: draft)[.bsp]
        )
        #expect(fit.across == 10)
    }
}
