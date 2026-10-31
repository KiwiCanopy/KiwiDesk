import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A move into the window's own Space refuses with a pill rather
/// than re-filing the window at the row's end.
@MainActor
@Suite("A move into the window's own Space refuses", .serialized)
struct MoveToOwnSpaceTests {
    /// Three windows in Space 1, the first focused, Space 2 empty.
    private func makeCore() -> (KiwiCore, () -> [String]) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        for space: SpaceID in ["1", "2"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...3 {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 900_000 + pid_t(id),
                    appName: "App\(id)"
                )
            )
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.workspaces.focus(WindowID(1), in: "1")
        return (core, { logs })
    }

    private func row(_ core: KiwiCore, _ space: SpaceID) -> [WindowID] {
        core.state.workspaces[space]?.windows ?? []
    }

    @Test(
        "the own Space refuses and keeps the row",
        arguments: ["move_to_space", "move_to_space_and_follow"]
    )
    func ownSpaceRefuses(command: String) {
        let (core, logs) = makeCore()
        let before = row(core, "1")
        let response = core.execute(
            command,
            args: [.string("1"), .number(1)]
        )
        #expect(!response.isSuccess)
        #expect(row(core, "1") == before)
        let reason = WindowActionRefusal.alreadyIn(space: "1").logReason
        #expect(logs().contains("\(reason): w1"))
    }

    @Test("another Space still takes the window")
    func otherSpaceMoves() {
        let (core, logs) = makeCore()
        let response = core.execute(
            "move_to_space",
            args: [.string("2"), .number(1)]
        )
        #expect(response.isSuccess)
        #expect(row(core, "2") == [WindowID(1)])
        let reason = WindowActionRefusal.alreadyIn(space: "2").logReason
        #expect(!logs().contains { $0.hasPrefix(reason) })
    }
}
