import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A hiding shelf through the real drivers (#761): `updateBars()`
/// draws its indicator and no bar until the shelf is revealed,
/// the show/hide action reveals it without touching the layout,
/// and setting the mode is the one change that moves the bounds.
@Suite("Shelf auto-hide through the drivers (#761)", .serialized)
@MainActor
struct ShelfAutoHideCoreTests {
    private static let window = WindowID(1)

    /// A core on the primary screen with one window, the Space
    /// Bar alone on the top edge in `visibility`. Nil where the
    /// host has no screen to paint on.
    private func makeCore(
        _ visibility: ShelfVisibility
    ) -> (KiwiCore, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "HideApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        settings.barEdge = .top
        settings.spaceBarStyle.visibility = visibility
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display.id)
    }

    @Test(
        "A hidden shelf draws its Space dots and no bar",
        .enabled(if: NSScreen.main != nil)
    )
    func hiddenDrawsTheIndicator() throws {
        let (core, display) = try #require(makeCore(.auto))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let key = ShelfManager.Key(display: display, edge: .top)
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(core.shelves.reveal.covers(key))
        let indicator = try #require(
            core.shelves.indicators.indicatorForTesting(key)
        )
        let spec = try #require(indicator.view.spec)
        guard case .dots(let dots) = spec.mark else {
            Issue.record("a Space Bar shelf draws Space dots")
            return
        }
        #expect(dots.filter(\.current).count == 1)
        #expect(dots.contains { $0.current && $0.occupied })
        #expect(!spec.shown)
    }

    @Test(
        "The action reveals the shelf and moves no window",
        .enabled(if: NSScreen.main != nil)
    )
    func actionRevealsWithoutARetile() throws {
        let (core, display) = try #require(makeCore(.auto))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let key = ShelfManager.Key(display: display, edge: .top)
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        let response = core.execute("space_bar.toggle_reveal", args: [])
        #expect(response.isSuccess)
        #expect(
            core.shelves.reveal.reveal(of: .init(shelf: key, bar: .space))
                == .pinned(until: nil)
        )
        #expect(!core.spaceBars.shownStrips.isEmpty)
        // The reveal redraws the bars and runs no layout pass.
        let counts = meter.snapshot(reset: false).counts
        #expect(counts.retiles + counts.passesHeld == 0)
        #expect(counts.barRenders > 0)
        let spec = try #require(
            core.shelves.indicators.indicatorForTesting(key)?.view.spec
        )
        #expect(spec.shown)
        #expect(
            core.execute("space_bar.toggle_reveal", args: []).isSuccess
        )
        #expect(core.spaceBars.shownStrips.isEmpty)
    }

    @Test(
        "The action refuses a bar that never hides",
        .enabled(if: NSScreen.main != nil)
    )
    func actionRefusesAlways() throws {
        let (core, _) = try #require(makeCore(.always))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let response = core.execute("space_bar.toggle_reveal", args: [])
        #expect(!response.isSuccess)
        #expect(!core.spaceBars.shownStrips.isEmpty)
        #expect(!core.execute("app_bar.toggle_reveal", args: []).isSuccess)
    }

    @Test(
        "Setting the mode is the one change that moves the bounds",
        .enabled(if: NSScreen.main != nil)
    )
    func modeMovesTheBounds() throws {
        let (core, _) = try #require(makeCore(.always))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let shown = core.shelfReservations
        #expect(
            core.execute(
                "space_bar.set_visibility",
                args: [.string("auto")]
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.visibility == .auto)
        #expect(core.shelfReservations != shown)
        #expect(
            !core.execute(
                "space_bar.set_visibility",
                args: [.string("never")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "space_bar.set_visibility",
                args: [.string("hidden")]
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.visibility == .hidden)
    }

    @Test(
        "The reveal duration is the shelf's, clamped",
        .enabled(if: NSScreen.main != nil)
    )
    func revealDurationVerb() throws {
        let (core, _) = try #require(makeCore(.auto))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(
            core.execute(
                "kiwishelf.set_reveal_duration",
                args: [.number(90)]
            ).isSuccess
        )
        #expect(core.tiler.settings.kiwishelf.revealDuration == 60)
        #expect(
            !core.execute(
                "monocle.set_app_bar_visibility",
                args: [.bool(true)]
            ).isSuccess
        )
    }

    @Test(
        "A shelf write runs a pass only where the reservation moved",
        .enabled(if: NSScreen.main != nil)
    )
    func shelfWriteSkipsAnIdlePass() throws {
        let (core, _) = try #require(makeCore(.always))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        let passes = { () -> Int in
            let counts = meter.snapshot(reset: true).counts
            return counts.retiles + counts.passesHeld
        }
        #expect(
            core.execute("kiwishelf.set_glyph_size", args: [.number(12)])
                .isSuccess
        )
        #expect(passes() == 0)
        let depth = core.tiler.settings.kiwishelf.thickness
        #expect(
            core.execute(
                "kiwishelf.set_thickness",
                args: [.number(Double(depth) + 6)]
            ).isSuccess
        )
        #expect(passes() > 0)
    }

    @Test(
        "The App Bar's action refuses where the layout carries none",
        .enabled(if: NSScreen.main != nil)
    )
    func actionNamesItsBar() throws {
        let (core, _) = try #require(makeCore(.auto))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // The active Space lays out in BSP, which carries no App
        // Bar, so its action refuses while the Space Bar's acts.
        #expect(!core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        #expect(core.execute("space_bar.toggle_reveal", args: []).isSuccess)
    }

    @Test(
        "The indicator lets the mouse through",
        .enabled(if: NSScreen.main != nil)
    )
    func indicatorIgnoresTheMouse() throws {
        let (core, display) = try #require(makeCore(.auto))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let key = ShelfManager.Key(display: display, edge: .top)
        let panel = try #require(
            core.shelves.indicators.indicatorForTesting(key)?.panel
        )
        #expect(panel.ignoresMouseEvents)
    }
}
