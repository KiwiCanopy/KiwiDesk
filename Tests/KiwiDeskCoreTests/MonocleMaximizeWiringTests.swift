import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A maximizing Monocle through the real bar pass (#2976 ▸ 3, 4):
/// the shelf's plan reads the screen's layout, so an Always Space Bar
/// reads Hidden and its shortcut shows it, and the pocket rests nowhere
/// there, standing only for a drag. Each case beside the setting off.
@Suite(
    "Monocle maximize windows: wiring (#2976)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct MonocleMaximizeWiringTests {
    private let one = WindowID(1)

    /// One window on a Monocle Space on the main screen, the Space Bar
    /// Always and an Auto pocket on the bottom edge.
    private func makeCore(maximize: Bool) throws -> (KiwiCore, DisplayID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-monomax-\(UUID().uuidString)")
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: one,
                    pid: 900_001,
                    appName: "App1",
                    title: "Window 1",
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                )
            )
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.state.workspaces.setMode(space, .monocle)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        core.tiler.settings.spaceBarStyle.edge = .bottom
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.tiler.settings.kiwishelf.pocketEdge = .bottom
        core.tiler.settings.kiwishelf.pocketVisibility = .auto
        core.tiler.settings.monocle.maximizeWindows = maximize
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, id)
    }

    @Test("The pocket rests as its handle on the screen (#3523)")
    func pocketRestsAsHandle() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (on, display) = try makeCore(maximize: true)
        #expect(on.pocketRests(on: display))
        #expect(on.pocketPlace(on: display) == .handle)
        #expect(on.pocketPlate.slots[display] == nil)
        #expect(!on.pocketPlateSpecs().isEmpty)
        // Control: unmaximized, the Always Space Bar holds a section.
        let (off, offDisplay) = try makeCore(maximize: false)
        #expect(off.pocketPlace(on: offDisplay).isSection)
    }

    @Test("With the maximized reveal off a drag stands no handle")
    func dragStandsThePocket() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try makeCore(maximize: true)
        core.execute(
            "kiwishelf.set_maximized_visibility",
            args: [.string("hidden")]
        )
        core.updateBars()
        #expect(!core.pocketRests(on: display))
        #expect(core.pocketPlateSpecs().isEmpty)
        core.pocketPlate.dragging = one
        core.updateBars()
        let place = core.pocketPlace(on: display)
        #expect(place != .handle)
        #expect(!place.isSection)
        #expect(!core.pocketPlateSpecs().isEmpty)
    }

    @Test("The Always Space Bar's shortcut shows it there")
    func shortcutShowsTheBar() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (on, _) = try makeCore(maximize: true)
        #expect(on.execute("space_bar.toggle_reveal").isSuccess)
        let (off, _) = try makeCore(maximize: false)
        #expect(!off.execute("space_bar.toggle_reveal").isSuccess)
    }
}
