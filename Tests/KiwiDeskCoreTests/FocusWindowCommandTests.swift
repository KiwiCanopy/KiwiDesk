import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `focus_window <window>` (#2492): focuses a window by id, on its
/// own Space — switching there where another Space holds it — and
/// refuses an id no tracked window carries and a missing one,
/// rather than falling back to the focus.
@Suite("focus_window", .serialized)
@MainActor
struct FocusWindowCommandTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-focus-window-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        return core
    }

    /// Space 1 (active) holds 1 and 2, Space 2 holds 3; 1 focused.
    private func seed(_ core: KiwiCore) {
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        for (id, space) in [(1, "1"), (2, "1"), (3, "2")] {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: Int32(920_000 + id),
                    appName: "App\(id)",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
            core.state.workspaces.add(
                WindowID(UInt32(id)),
                to: SpaceID(space)
            )
        }
        core.state.workspaces.focus(WindowID(3), in: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
    }

    @Test("A window on the active Space takes the focus")
    func sameSpace() {
        let core = makeCore()
        seed(core)
        let response = core.execute("focus_window", args: [.number(2)])
        #expect(response.isSuccess)
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("A window on another Space switches there")
    func otherSpace() {
        let core = makeCore()
        seed(core)
        let response = core.execute("focus_window", args: [.number(3)])
        #expect(response.isSuccess)
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("An unknown or missing id is refused, never the focus")
    func refusals() {
        let core = makeCore()
        seed(core)
        #expect(
            !core.execute("focus_window", args: [.number(99)]).isSuccess
        )
        #expect(!core.execute("focus_window").isSuccess)
        #expect(core.activeSpace?.focused == WindowID(1))
    }
}
