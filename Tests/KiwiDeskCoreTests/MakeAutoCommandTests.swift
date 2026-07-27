import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The `make_auto` command (#164): the escape hatch back to
/// detection-controlled float state.
@Suite("make_auto command", .serialized)
@MainActor
struct MakeAutoCommandTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-auto-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: "App\(raw)"
                )
            )
        )
    }

    @Test("make_auto clears a manual float override")
    func clearsOverride() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_floating").isSuccess)
        #expect(
            core.state.windows[WindowID(1)]?.isFloating == true
        )
        #expect(core.execute("make_auto").isSuccess)
        // No cached detection verdict in tests (no AX): the
        // current state stands, but detection applies again.
        core.state.apply(
            .windowFloatChanged(WindowID(1), isFloating: false)
        )
        #expect(
            core.state.windows[WindowID(1)]?.isFloating == false
        )
    }

    @Test("make_auto forgets the close/reopen intent")
    func forgetsReopenIntent() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.execute("make_auto").isSuccess)
        core.state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        addWindow(core, 2)
        #expect(
            core.state.windows[WindowID(2)]?.isFloating == false
        )
    }

    @Test("make_auto re-applies the cached detection verdict")
    func reappliesCachedVerdict() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_floating").isSuccess)
        // Seed what the event loop would have cached at track
        // time: detection said "tiled".
        core.eventLoop.detectedFloating[WindowID(1)] = false
        #expect(core.execute("make_auto").isSuccess)
        #expect(
            core.state.windows[WindowID(1)]?.isFloating == false
        )
    }

    @Test("make_auto without a focused window fails")
    func failsWithoutFocus() {
        let core = makeCore()
        #expect(!core.execute("make_auto").isSuccess)
    }

    @Test("make_auto is listed in the API reference")
    func listedInReference() {
        #expect(
            APIReference.commands.contains {
                $0.command == "make_auto"
            }
        )
    }
}
