import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A window is tiled or floating (#1810): a Float records the
/// user's choice, a Tile clears it and hands the window back to
/// detection, and a Tile refuses where detection floats it.
@Suite("Tile returns a window to its rules (#1810)", .serialized)
@MainActor
struct TileReturnsToRulesTests {
    private let id = WindowID(1)

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-tile-rules-\(UUID().uuidString)"
                )
        )
    }

    /// Tracks window 1 the way the event loop would: the state
    /// flag and the cached verdict agree.
    private func track(
        _ core: KiwiCore,
        _ verdict: FloatVerdict = .tiles,
        title: String = "Doc"
    ) {
        var window = ManagedWindow(
            id: id,
            pid: 1,
            appName: "App",
            title: title
        )
        window.isFloating = verdict.floats
        core.eventLoop.detectedFloating[id] = verdict
        core.state.apply(.windowCreated(window))
    }

    private func floats(_ core: KiwiCore) -> Bool? {
        core.state.windows[id]?.isFloating
    }

    @Test("a Tile hands the window back to detection")
    func tileFollowsDetectionAgain() {
        let core = makeCore()
        track(core)
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.execute("make_tiled").isSuccess)
        #expect(core.state.userFloated.isEmpty)
        // A rule added later floats it: no manual tile holds it.
        core.eventLoop.detectedFloating[id] = .floats(.rule)
        core.state.apply(.windowFloatChanged(id, isFloating: true))
        #expect(floats(core) == true)
    }

    @Test("a user float outranks detection until tiled")
    func floatOutranksDetection() {
        let core = makeCore()
        track(core)
        #expect(core.execute("make_floating").isSuccess)
        core.state.apply(.windowFloatChanged(id, isFloating: false))
        #expect(floats(core) == true)
        #expect(core.state.userFloated == [id])
    }

    @Test(
        "a Tile refuses where detection floats the window",
        arguments: [
            AutoFloatReason.rule, .panel, .accessoryApp,
        ]
    )
    func tileRefuses(_ reason: AutoFloatReason) {
        let core = makeCore()
        track(core, .floats(reason))
        let response = core.execute("make_tiled")
        #expect(response == .fail(reason.failure))
        #expect(floats(core) == true)
        #expect(core.tileRefusal(of: id) == reason)
    }

    @Test("a toggle towards tiled refuses the same way")
    func toggleRefuses() {
        let core = makeCore()
        track(core, .floats(.panel))
        #expect(
            core.execute("toggle_floating")
                == .fail(AutoFloatReason.panel.failure)
        )
        #expect(floats(core) == true)
    }

    @Test("a Float records nothing where detection floats it")
    func floatRecordsNothing() {
        let core = makeCore()
        track(core, .floats(.rule))
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.state.userFloated.isEmpty)
        // So a rule removed later tiles the window.
        core.eventLoop.detectedFloating[id] = .tiles
        core.state.apply(.windowFloatChanged(id, isFloating: false))
        #expect(floats(core) == false)
    }

    @Test("a Tile forgets the close/reopen memory")
    func tileForgetsReopen() {
        let core = makeCore()
        track(core)
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.execute("make_tiled").isSuccess)
        core.state.apply(.windowDestroyed(id, wasMinimized: false))
        #expect(core.state.rememberedFloating.isEmpty)
    }

    @Test("make_auto is retired in favour of make_tiled")
    func makeAutoRetired() {
        let core = makeCore()
        track(core)
        #expect(
            core.execute("make_auto")
                == .fail("make_auto was retired — use make_tiled")
        )
        #expect(
            !APIReference.commands.contains {
                $0.command == "make_auto"
            }
        )
    }
}
