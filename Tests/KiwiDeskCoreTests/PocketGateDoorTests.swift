import Foundation
import Testing

@testable import KiwiDeskCore

/// Each door into the pocket refuses what `pocketBlock` refuses, in
/// its sentence and with nothing marked (#3037). `RefusalWordingTests`
/// holds the named `pocket` call.
@Suite("The pocket's gate at every door (#3037)", .serialized)
@MainActor
struct PocketGateDoorTests {
    private let id = WindowID(1)

    private func makeCore(
        _ change: (inout ManagedWindow) -> Void
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-gate-\(UUID().uuidString)"
                )
        )
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        var window = ManagedWindow(
            id: id,
            pid: 900_001,
            appName: "App",
            title: "W1"
        )
        change(&window)
        core.state.apply(.windowCreated(window))
        // A panel's arrival takes no focus of its own (#671).
        core.state.apply(.windowFocused(id))
        return core
    }

    private let cases: [(String, (inout ManagedWindow) -> Void)] = [
        (
            "a full-screen window cannot be pocketed",
            { $0.isFullscreen = true }
        ),
        (
            "a panel or popup cannot be pocketed",
            { $0.isTransientOverlay = true }
        ),
    ]

    @Test("the bare press refuses a focused window it may not take")
    func barePress() {
        for (sentence, change) in cases {
            let core = makeCore(change)
            expectEqual(core.focusedWindowID, id)
            expectEqual(core.execute("pocket").error, sentence)
            #expect(core.state.pocketPhase(of: id) == nil)
        }
    }

    @Test("toggle_pocket_window refuses a window it may not mark")
    func toggle() {
        for (sentence, change) in cases {
            let core = makeCore(change)
            let response = core.execute(
                "toggle_pocket_window",
                args: [.number(Double(id.raw))]
            )
            expectEqual(response.error, sentence)
            #expect(core.state.pocketPhase(of: id) == nil)
        }
    }
}
