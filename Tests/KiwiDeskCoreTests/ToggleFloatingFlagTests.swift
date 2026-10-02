import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `toggle_floating` flips the window's own float FLAG (#1697,
/// the `EffectiveFloat` roster): in a floating-mode Space every
/// member floats and none can tile, so an effective-state toggle
/// would write the same no-op each press. The flag is the window's
/// intent, and it decides what the window does once the Space
/// leaves floating mode.
@Suite("toggle_floating flips the flag (#1697)", .serialized)
@MainActor
struct ToggleFloatingFlagTests {
    private let window = WindowID(1)

    /// One window alone on Space 1, which is in floating mode.
    private func setup() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 1, appName: "A", title: "W")
            )
        )
        core.state.apply(.windowFocused(window))
        core.execute("set_mode", args: [.string("1"), .string("floating")])
        return core
    }

    @Test("each press flips the flag in a floating-mode Space")
    func pressesFlipTheFlag() {
        let core = setup()
        #expect(core.state.windows[window]?.isFloating == false)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(core.state.windows[window]?.isFloating == true)
        #expect(core.state.userFloated == [window])
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(core.state.windows[window]?.isFloating == false)
        #expect(core.state.userFloated.isEmpty)
    }

    /// The flag set there is what the window keeps once the Space
    /// tiles: floated by the toggle, it stays out of the layout.
    @Test("the flag decides the window once the Space tiles")
    func flagOutlivesTheFloatingMode() {
        let core = setup()
        #expect(core.execute("toggle_floating").isSuccess)
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        #expect(core.state.windows[window]?.isFloating == true)
        #expect(
            core.tiler.calculatedFrames(state: core.state)[window] == nil
        )
    }
}
