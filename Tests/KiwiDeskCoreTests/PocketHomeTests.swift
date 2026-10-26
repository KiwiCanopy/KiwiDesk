import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Where the pocketed window lives (#2446): in no Space across a
/// profile switch, and waiting on the active Space's screen.
@Suite("Pocket home", .serialized)
@MainActor
struct PocketHomeTests {
    private let one = WindowID(1)
    private let two = WindowID(2)

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-home-\(UUID().uuidString)"
                )
        )
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [],
            spaces: ["1", "2"],
            spaceModes: ["1": .bsp, "2": .bsp],
            settings: TilingSettings()
        )
    }

    private func create(_ core: KiwiCore, _ id: WindowID) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 900_000 + pid_t(id.raw),
                    appName: "App\(id.raw)",
                    title: "Window \(id.raw)"
                )
            )
        )
    }

    /// B records the window in Space 2, so B's restore wants to
    /// file it there; the pocket keeps it out.
    @Test("a profile switch files no pocketed window")
    func profileSwitchFilesNoPocketedWindow() {
        let core = makeCore()
        let a = profile("A")
        let b = profile("B")
        core.apply(profile: a, cause: .event)
        create(core, two)
        create(core, one)
        core.state.workspaces.add(one, to: "1")
        core.apply(profile: b, cause: .event)
        core.state.workspaces.add(one, to: "2")
        core.apply(profile: a, cause: .event)

        core.state.apply(.windowFocused(one))
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketedWindow == one)

        core.apply(profile: b, cause: .event)
        #expect(core.state.workspaces.space(of: one) == nil)
        #expect(core.state.pocketedWindow == one)
    }

    /// The window was pocketed on the main screen; the home is
    /// the screen the user is on now, not the one it left.
    @Test("the pocket waits on the active Space's screen")
    func homeFollowsTheActiveSpace() {
        let main = DisplayID(1)
        let second = DisplayID(2)
        var state = StateCoordinator(defaultSpace: SpaceID("1"))
        state.workspaces.upsertDisplay(
            Display(
                id: main,
                name: "Main",
                frame: CGRect(x: 0, y: 0, width: 1728, height: 1117)
            )
        )
        state.workspaces.upsertDisplay(
            Display(
                id: second,
                name: "Second",
                frame: CGRect(
                    x: 1728,
                    y: -164,
                    width: 1920,
                    height: 1080
                )
            )
        )
        state.workspaces.ensureSpace(SpaceID("5"))
        state.workspaces.assign(SpaceID("1"), to: main)
        state.workspaces.assign(SpaceID("5"), to: second)
        state.workspaces.activate(SpaceID("1"))
        state.apply(
            .windowCreated(
                ManagedWindow(id: one, pid: 900_001, appName: "App1")
            )
        )
        state.workspaces.add(one, to: "1")
        state.pocketWindow(one)
        #expect(state.pocketHomeDisplay == main)

        state.workspaces.activate(SpaceID("5"))
        #expect(state.pocketHomeDisplay == second)
    }
}
