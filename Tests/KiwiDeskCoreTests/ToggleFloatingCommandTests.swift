import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The `toggle_floating` command (#221): one verb to flip the
/// focused window between floating and tiled, reading its
/// effective state and writing the explicit opposite — never
/// `auto` (that stays `make_auto`'s job, #164).
@Suite("toggle_floating command", .serialized)
@MainActor
struct ToggleFloatingCommandTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-toggle-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
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

    private func isFloating(_ core: KiwiCore) -> Bool? {
        core.state.windows[WindowID(1)]?.isFloating
    }

    @Test("a tiled window toggles to floating")
    func tiledToFloating() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(isFloating(core) == false)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(isFloating(core) == true)
    }

    @Test("a floating window toggles to tiled")
    func floatingToTiled() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("make_floating").isSuccess)
        #expect(isFloating(core) == true)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(isFloating(core) == false)
    }

    @Test("two toggles return to the original state")
    func roundTrip() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(isFloating(core) == false)
    }

    /// A fresh window is detection-controlled (auto). Toggling it
    /// must write an *explicit* override, not leave it auto —
    /// proven here because `make_auto` + a re-detection verdict is
    /// then required to move it back, exactly as after a
    /// `make_floating`.
    @Test("toggle writes an explicit override, not auto")
    func writesExplicitOverride() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(isFloating(core) == true)
        // Detection alone can't move an explicitly-overridden
        // window; only make_auto returns it to detection control.
        core.eventLoop.detectedFloating[WindowID(1)] = false
        #expect(core.execute("make_auto").isSuccess)
        #expect(isFloating(core) == false)
    }

    @Test("toggle without a focused window fails")
    func failsWithoutFocus() {
        let core = makeCore()
        #expect(!core.execute("toggle_floating").isSuccess)
    }

    @Test("toggle_floating is listed in the API reference")
    func listedInReference() {
        #expect(
            APIReference.commands.contains {
                $0.command == "toggle_floating"
            }
        )
    }
}
