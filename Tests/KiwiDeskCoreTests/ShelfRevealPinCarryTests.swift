import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar its shortcut showed stays shown until the next call or its
/// `reveal_timeout`, across a pass whose layout draws no such bar
/// (#3481): the App Bar's target leaves the revealer on a bar-less
/// Space, and its pin must come back with it.
@Suite("Shelf reveal pin across a bar-less pass (#3481)", .serialized)
@MainActor
struct ShelfRevealPinCarryTests {
    private static let window = WindowID(903_481)

    /// A core on the primary screen with one window in a Monocle
    /// Space whose App Bar is Auto on the top edge. Nil where the
    /// host has no screen to paint on.
    private func makeCore() -> (KiwiCore, DisplayID, SpaceID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 903_481,
                    appName: "PinApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.barEdge = .top
        settings.spaceBarStyle.visibility = .hidden
        settings.monocle.appBar.visibility = .auto
        core.tiler.settings = settings
        guard let space = core.state.workspaces.space(of: Self.window)
        else { return nil }
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display.id, space)
    }

    private func appKey(_ display: DisplayID) -> ShelfRevealer.Key {
        .init(
            shelf: ShelfManager.Key(display: display, edge: .top),
            bar: .app
        )
    }

    private func setMode(_ core: KiwiCore, _ space: SpaceID, _ mode: String) {
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        core.updateBars()
    }

    @Test(
        "a shown App Bar comes back shown after a bar-less layout",
        .enabled(if: NSScreen.main != nil)
    )
    func pinSurvivesABarlessPass() throws {
        let (core, display, space) = try #require(makeCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let key = appKey(display)
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        #expect(core.shelves.reveal.reveal(of: key) == .pinned(until: nil))
        // BSP carries no App Bar: its target leaves the revealer.
        setMode(core, space, "bsp")
        #expect(core.shelves.reveal.targets[key] == nil)
        #expect(core.appBars.shownStrips.isEmpty)
        setMode(core, space, "monocle")
        #expect(core.shelves.reveal.reveal(of: key) == .pinned(until: nil))
        #expect(!core.appBars.shownStrips.isEmpty)
        // The next call still hides it.
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        #expect(core.shelves.reveal.reveal(of: key) == .hidden)
    }

    @Test("a kept pin leaves no sibling standing aside")
    func keptPinYieldsNothing() {
        let shelf = ShelfManager.Key(display: DisplayID(1), edge: .top)
        let app = ShelfRevealer.Key(shelf: shelf, bar: .app)
        let space = ShelfRevealer.Key(shelf: shelf, bar: .space)
        let target = ShelfRevealer.Target.hidden(
            edge: .top,
            strip: CGRect(x: 0, y: 760, width: 1000, height: 40),
            screen: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        let revealer = ShelfRevealer()
        revealer.macEdges = { .none }
        revealer.makeMonitor = { _ in nil }
        revealer.schedule = { _, _ in ShelfRevealTimer() }
        revealer.sync([app: target, space: target])
        revealer.start()
        defer { revealer.stop() }
        #expect(revealer.toggle(app, duration: 0))
        #expect(revealer.yields(space))
        revealer.sync([space: target])
        #expect(revealer.reveal(of: app) == .pinned(until: nil))
        #expect(!revealer.yields(space))
    }

    @Test("a timed pin kept off screen ends at its timeout")
    func keptTimedPinEnds() {
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
            bar: .app
        )
        let target = ShelfRevealer.Target.hidden(
            edge: .top,
            strip: CGRect(x: 0, y: 760, width: 1000, height: 40),
            screen: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        var due: [() -> Void] = []
        let revealer = ShelfRevealer()
        revealer.macEdges = { .none }
        revealer.makeMonitor = { _ in nil }
        revealer.now = { Date(timeIntervalSince1970: 1_000) }
        revealer.schedule = { _, body in
            due.append(body)
            return ShelfRevealTimer()
        }
        revealer.sync([key: target])
        revealer.start()
        defer { revealer.stop() }
        #expect(revealer.toggle(key, duration: 5))
        revealer.sync([:])
        #expect(revealer.reveal(of: key).isShown)
        due.forEach { $0() }
        revealer.sync([key: target])
        #expect(revealer.reveal(of: key) == .hidden)
    }

    /// A bar moved to another edge of its screen leaves no pin at
    /// the edge it left.
    @Test("a kept pin goes when its bar moves edge")
    func movedBarDropsThePin() {
        let display = DisplayID(1)
        let top = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display, edge: .top),
            bar: .app
        )
        let bottom = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display, edge: .bottom),
            bar: .app
        )
        let target = ShelfRevealer.Target.hidden(
            edge: .top,
            strip: CGRect(x: 0, y: 760, width: 1000, height: 40),
            screen: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        let revealer = ShelfRevealer()
        revealer.macEdges = { .none }
        revealer.makeMonitor = { _ in nil }
        revealer.schedule = { _, _ in ShelfRevealTimer() }
        revealer.sync([top: target])
        revealer.start()
        defer { revealer.stop() }
        #expect(revealer.toggle(top, duration: 0))
        revealer.sync([:])
        #expect(revealer.reveal(of: top).isShown)
        revealer.sync([bottom: target])
        revealer.sync([top: target])
        #expect(revealer.reveal(of: top) == .hidden)
    }
}
