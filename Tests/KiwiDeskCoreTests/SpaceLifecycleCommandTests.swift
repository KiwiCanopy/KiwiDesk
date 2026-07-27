import Foundation
import Testing

@testable import KiwiDeskCore

/// `create_space` / `delete_space` (space lifecycle Lua/CLI API).
@Suite("Space lifecycle commands", .serialized)
@MainActor
struct SpaceLifecycleCommandTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-core-\(UUID().uuidString)"
                )
        )
    }

    @Test("create_space brings a space into existence with a mode")
    func createWithMode() {
        let core = makeCore()
        let r = core.execute(
            "create_space",
            args: [.string("scratch"), .string("monocle")]
        )
        #expect(r.isSuccess)
        #expect(core.state.workspaces[SpaceID("scratch")] != nil)
        #expect(
            core.state.workspaces[SpaceID("scratch")]?.mode
                == .monocle
        )
    }

    @Test("create_space rejects an unknown mode")
    func createBadMode() {
        let core = makeCore()
        let r = core.execute(
            "create_space",
            args: [.string("x"), .string("bogus")]
        )
        #expect(!r.isSuccess)
    }

    @Test("delete_space rehomes windows to the first survivor")
    func deleteRehomes() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.add(WindowID(7), to: SpaceID("2"))
        let r = core.execute("delete_space", args: [.string("2")])
        #expect(r.isSuccess)
        #expect(core.state.workspaces[SpaceID("2")] == nil)
        // Window 7 moved to the first surviving space (1).
        #expect(
            core.state.workspaces.space(of: WindowID(7))
                == SpaceID("1")
        )
    }

    @Test("delete_space honors the fallback space as the target")
    func deleteUsesFallback() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("home"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.fallbackSpace = SpaceID("home")
        core.state.workspaces.add(WindowID(7), to: SpaceID("2"))
        _ = core.execute("delete_space", args: [.string("2")])
        #expect(
            core.state.workspaces.space(of: WindowID(7))
                == SpaceID("home")
        )
    }

    @Test("delete_space refuses to delete the only space")
    func deleteLastRefused() {
        let core = makeCore()
        // A fresh core has exactly one default space.
        let only = core.state.workspaces.allSpaces.first!.id
        let r = core.execute(
            "delete_space",
            args: [.string(only.raw)]
        )
        #expect(!r.isSuccess)
        #expect(core.state.workspaces[only] != nil)
    }

    @Test("delete_space rejects an unknown space")
    func deleteUnknown() {
        let core = makeCore()
        let r = core.execute(
            "delete_space",
            args: [.string("nope")]
        )
        #expect(!r.isSuccess)
    }
}
