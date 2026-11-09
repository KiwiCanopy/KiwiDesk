import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space move refuses a window in native full screen, which macOS
/// holds on its own Space (#3119): the verb in both forms, named or
/// focused, the bar menu's Move row, and the move's own net.
@MainActor
@Suite("A Space move refuses a full-screen window", .serialized)
struct MoveToSpaceFullScreenTests {
    private static let reason =
        WindowActionRefusal
        .cannotChangeSpaceFullScreen(window: "").logReason

    /// Three windows in Space 1, the first focused, Space 2 empty.
    private func makeCore() -> (KiwiCore, () -> [String]) {
        LocalizationManager.shared.select("en")
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
                    pid: 910_000 + pid_t(id),
                    appName: "App\(id)",
                    title: "Doc \(id)"
                )
            )
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.workspaces.focus(WindowID(1), in: "1")
        return (core, { logs })
    }

    private func fullScreen(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowFullscreenChanged(WindowID(raw), isFullscreen: true)
        )
    }

    @Test(
        "the focused window refuses in both forms",
        arguments: ["move_to_space", "move_to_space_and_follow"]
    )
    func focusedRefuses(command: String) {
        let (core, logs) = makeCore()
        fullScreen(core, 1)
        let response = core.execute(command, args: [.string("2")])
        #expect(response.error == Self.reason)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(logs().contains("\(Self.reason): w1"))
    }

    @Test(
        "a named window refuses in both forms",
        arguments: ["move_to_space", "move_to_space_and_follow"]
    )
    func namedRefuses(command: String) {
        let (core, logs) = makeCore()
        fullScreen(core, 3)
        let response = core.execute(
            command,
            args: [.string("2"), .number(3)]
        )
        #expect(response.error == Self.reason)
        #expect(core.state.workspaces.space(of: WindowID(3)) == "1")
        #expect(logs().contains("\(Self.reason): w3"))

        // The control: a window not in full screen moves.
        #expect(
            core.execute(command, args: [.string("2"), .number(2)])
                .isSuccess
        )
        #expect(core.state.workspaces.space(of: WindowID(2)) == "2")
    }

    @Test("the bar menu's Move row is greyed for a full-screen window")
    func barRowGreyed() {
        let (core, _) = makeCore()
        core.execute("move_to_space", args: [.string("2"), .number(2)])
        let move = { () -> BarMenuRow? in
            core.barMenuRows(.glyph([WindowID(2)])).first {
                $0.title == "Move to Current Space"
            }
        }
        #expect(move()?.enabled == true)
        fullScreen(core, 2)
        #expect(move()?.enabled == false)
    }

    @Test("the move itself files no full-screen window")
    func moveWindowNet() {
        let (core, logs) = makeCore()
        fullScreen(core, 2)
        core.moveWindow(WindowID(2), to: "2", follow: false)
        #expect(core.state.workspaces.space(of: WindowID(2)) == "1")
        #expect(logs().contains("move: w2 refused — full screen"))

        // The control: the same move of a tiled window files it.
        core.moveWindow(WindowID(3), to: "2", follow: false)
        #expect(core.state.workspaces.space(of: WindowID(3)) == "2")
    }
}
