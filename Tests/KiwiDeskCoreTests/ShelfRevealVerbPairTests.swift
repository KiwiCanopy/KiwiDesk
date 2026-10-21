import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The two reveal verbs on one shared edge, through `execute` — the
/// door the shortcut, Lua and the CLI all take (#761): each pins its
/// own bar and leaves the other's reveal alone, in either order and
/// for every pair of hiding values.
@Suite("Shelf reveal verb pairs (#761)", .serialized)
@MainActor
struct ShelfRevealVerbPairTests {
    private static let window = WindowID(900_762)

    /// A core on the primary screen with one window in a monocle
    /// Space, both bars on the top edge at the given values. Nil
    /// where the host has no screen to paint on.
    private func makeCore(
        space: ShelfVisibility,
        app: ShelfVisibility
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
                    pid: 900_762,
                    appName: "VerbPairApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        if let id = core.state.workspaces.space(of: Self.window) {
            core.state.workspaces.setMode(id, .monocle)
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = space
        settings.monocle.appBar.visibility = app
        settings.kiwishelf.revealDuration = 0
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display.id)
    }

    @Test(
        "Each verb pins its own bar and keeps the other's",
        .enabled(if: NSScreen.main != nil),
        arguments: [
            (ShelfVisibility.auto, ShelfVisibility.auto),
            (.auto, .hidden),
            (.hidden, .auto),
            (.hidden, .hidden),
        ]
    )
    func bothStayPinned(
        values: (ShelfVisibility, ShelfVisibility)
    ) throws {
        for order in [["app_bar", "space_bar"], ["space_bar", "app_bar"]] {
            let (core, display) = try #require(
                makeCore(space: values.0, app: values.1)
            )
            defer { NativeSpaces.currentSpaceIsUserOverride = nil }
            var lines: [String] = []
            core.onLog = { lines.append($0) }
            for bar in order {
                #expect(
                    core.execute("\(bar).toggle_reveal", args: []).isSuccess
                )
            }
            let shelf = ShelfManager.Key(display: display, edge: .top)
            for bar in [ShelfBar.space, .app] {
                #expect(
                    core.shelves.reveal.reveal(
                        of: .init(shelf: shelf, bar: bar)
                    ) == .pinned(until: nil),
                    "\(bar) after \(order)"
                )
            }
            #expect(!core.spaceBars.shownStrips.isEmpty)
            #expect(!core.appBars.shownStrips.isEmpty)
            // Each toggle leaves one line naming its bar.
            let reveals = lines.filter { $0.hasPrefix("shelf reveal: ") }
            #expect(reveals.count == 2)
        }
    }
}
