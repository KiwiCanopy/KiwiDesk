import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `KiwiCore.scrollingColumnCap(for:settings:)` (#1382): the
/// screen's size comes through the one bounds hook (#531) and
/// the strip reserved on it is the DRAFT's, not the live bar's.
/// A host with no screen answers nil, which the GUI reads as
/// the share's own floor — and the hook-vs-draft clauses are
/// vacuous there, so the suite is gated on a screen rather than
/// passing by absence.
@Suite(
    "Scrolling column cap door (#1382)",
    .enabled(if: !NSScreen.screens.isEmpty, "needs a screen")
)
@MainActor
struct ScrollingColumnCapDoorTests {
    private func draft() -> TilingSettings {
        var settings = TilingSettings()
        settings.minWindowSize = 300
        settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
            inner: Gaps.Inner(horizontal: 10, vertical: 10)
        )
        settings.scrolling.appBar.enabled = false
        settings.spaceBarStyle.enabled = false
        return settings
    }

    @Test("the size is the hook's, the strip the draft's")
    func hookAndDraft() {
        let core = makeTestCore()
        // A width no shipped screen has, so a read bypassing the
        // hook cannot answer the same count by coincidence.
        let pinned = CGRect(x: 0, y: 0, width: 3100, height: 1080)
        core.tiler.visibleBounds = { _ in pinned }
        // The live bar is wide and on the left; the draft has none.
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.spaceBarStyle.edge = .left
        core.tiler.settings.spaceBarStyle.thickness = 700
        // 3100 across at 300 + 10: ten — the live bar's 700 pt
        // strip would leave seven.
        #expect(core.scrollingColumnCap(for: nil, settings: draft()) == 10)
        // And the draft's own strip is reserved.
        var barred = draft()
        barred.spaceBarStyle.enabled = true
        barred.spaceBarStyle.edge = .left
        barred.spaceBarStyle.thickness = 700
        #expect(core.scrollingColumnCap(for: nil, settings: barred) == 7)
        // A space is answered on ITS resolution: an override gap
        // widens the pitch — (3100 + 100) / 400 = 8.
        var overridden = draft()
        overridden.gapsOverride[SpaceID("1")] = Gaps(
            outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
            inner: Gaps.Inner(horizontal: 100, vertical: 100)
        )
        #expect(
            core.scrollingColumnCap(for: SpaceID("1"), settings: overridden)
                == 8
        )
    }

    @Test("the widest screen wins, ties broken by position")
    func widest() {
        let narrow = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let wide = CGRect(x: 1440, y: 0, width: 2560, height: 1440)
        let twin = CGRect(x: -2560, y: 100, width: 2560, height: 1080)
        #expect(KiwiCore.widest(of: [narrow, wide]) == 1)
        #expect(KiwiCore.widest(of: [wide, narrow]) == 0)
        // Equal widths: the leftmost, whatever order they arrive in;
        // equal lefts: the lower.
        #expect(KiwiCore.widest(of: [narrow, wide, twin]) == 2)
        #expect(KiwiCore.widest(of: [twin, wide, narrow]) == 0)
        let above = CGRect(x: -2560, y: 1200, width: 2560, height: 1080)
        #expect(KiwiCore.widest(of: [above, twin]) == 1)
        #expect(KiwiCore.widest(of: [twin, above]) == 0)
        #expect(KiwiCore.widest(of: []) == nil)
    }
}
