import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Two pocketable windows on the real main screen, the Space Bar at the
/// top, so the pocket's own edge draws nothing; One window by default.
/// The pocket's real panels order in, so its suites need a main screen.
@MainActor
struct PocketListFixture {
    let one = WindowID(1)
    let two = WindowID(2)
    let core: KiwiCore
    let display: DisplayID

    init() throws {
        core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-list-\(UUID().uuidString)")
        )
        for id in [one, two] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: 900_000 + pid_t(id.raw),
                        appName: "App\(id.raw)",
                        title: "Window \(id.raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        let screen = try #require(NSScreen.main)
        display = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: display, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: display)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        core.tiler.settings.spaceBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.tiler.settings.kiwishelf.pocketEdge = .bottom
        core.pocketPlate.ordersPanel = true
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
    }

    func tearDown() {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        core.pocketPlate.sync([])
        NativeSpaces.currentSpaceIsUserOverride = nil
    }

    /// Pockets `ids`, Several windows holding them.
    func pocket(_ ids: [WindowID]) {
        core.execute("pocket.set_capacity", args: [.string("several")])
        for id in ids {
            core.handle(.windowFocused(id))
            core.execute("toggle_pocket_window")
            core.execute("pocket")
            #expect(core.state.isPocketed(id))
        }
        core.updatePocketPlate(slots: [:])
    }
}
