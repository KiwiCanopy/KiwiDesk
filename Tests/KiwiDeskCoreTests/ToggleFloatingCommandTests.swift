import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The `toggle_floating` command (#221): one verb to flip the
/// focused window between floating and tiled — through the float
/// verbs, so a toggle back to tiled hands the window to detection
/// again (#1810, `TileReturnsToRulesTests`).
@Suite("toggle_floating command", .serialized)
@MainActor
struct ToggleFloatingCommandTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
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

    /// A toggle back to tiled leaves no manual tile behind: a
    /// detection float applies at once (#1810).
    @Test("a toggle back to tiled yields to detection")
    func toggleBackYieldsToDetection() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(core.execute("toggle_floating").isSuccess)
        core.state.apply(
            .windowFloatChanged(WindowID(1), isFloating: true)
        )
        #expect(isFloating(core) == true)
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
