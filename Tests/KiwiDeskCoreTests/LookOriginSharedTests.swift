import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shared look carries its origin to every follower (#1740): a
/// write that changes only the origin still re-stamps a follower's
/// file copy, which a paint-only comparison would skip.
@Suite("Look origin in the shared look", .serialized)
@MainActor
struct LookOriginSharedTests {
    private func profile(_ name: String, look: LookReference?) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings(),
            look: look
        )
    }

    private func crossedCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-origin-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        try core.profiles.save(profile("Work", look: .own))
        core.prepareSharedLook()
        #expect(
            core.execute("load_profile", args: [.string("Work")])
                .isSuccess
        )
        #expect(core.sharedLook != nil)
        return core
    }

    @Test("an origin-only write re-stamps a follower")
    func originRestampsFollowers() throws {
        let core = try crossedCore()
        #expect(try core.profiles.read(name: "Work").look == nil)
        var home = profile("Home", look: nil)
        home.settings = core.tiler.settings
        try core.profiles.save(home)
        let origin = ShelfLook(
            name: "Dusk",
            style: [:],
            colors: [:],
            author: "Anna"
        )
        core.tiler.settings.lookOrigin = origin
        try core.persistProfile(named: "Work", modes: nil)
        #expect(core.sharedLook?.origin == origin)
        let stored = try core.profiles.read(name: "Home")
        #expect(stored.settings.lookOrigin == origin)
    }
}
