import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

@Suite("Command execution — toggles & placement", .serialized)
@MainActor
struct CommandBehaviorTests {
    @Test("Toggles reach space animation and wake-restore")
    func toggles() {
        let core = makeCore()
        core.execute(
            "set_wake_restore_delay",
            args: [.number(2500)]
        )
        #expect(core.sleepWake.restoreDelayMS == 2500)
        // Duration: the namespaced command clamps to 50–1000.
        core.execute(
            "animations.set_duration",
            args: [.number(5000)]
        )
        #expect(core.tiler.animation.durationMS == 1000)
        core.execute(
            "animations.set_duration",
            args: [.number(300)]
        )
        #expect(core.tiler.animation.durationMS == 300)
        // Defaults: the Space cue (#2143), scrolling on (#11).
        #expect(core.tiler.settings.animations.spaceChange == .cue)
        #expect(core.tiler.settings.animations.onScrolling)
        // The style takes each case, and refuses another word.
        for style in SpaceChangeStyle.allCases {
            core.execute(
                "animations.set_space_change",
                args: [.string(style.rawValue)]
            )
            #expect(core.tiler.settings.animations.spaceChange == style)
        }
        #expect(
            !core.execute(
                "animations.set_space_change",
                args: [.string("fade")]
            ).isSuccess
        )
        // The 2.x toggle is retired, naming its replacement.
        let retired = core.execute(
            "animations.set_on_space_change",
            args: [.bool(true)]
        )
        #expect(retired.error?.contains("set_space_change") == true)
        core.execute(
            "animations.set_on_scrolling",
            args: [.bool(false)]
        )
        #expect(!core.tiler.settings.animations.onScrolling)
        core.execute(
            "animations.set_on_scrolling",
            args: [.bool(true)]
        )
        #expect(core.tiler.settings.animations.onScrolling)
        // Resize / swap toggles (default true) round-trip too.
        #expect(core.tiler.settings.animations.onWindowResize)
        #expect(core.tiler.settings.animations.onWindowSwap)
        core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        #expect(!core.tiler.settings.animations.onWindowResize)
        core.execute(
            "animations.set_on_window_swap",
            args: [.bool(false)]
        )
        #expect(!core.tiler.settings.animations.onWindowSwap)
        #expect(core.tiler.settings.animations.onRelayout)
        core.execute(
            "animations.set_on_relayout",
            args: [.bool(false)]
        )
        #expect(!core.tiler.settings.animations.onRelayout)
        #expect(core.tiler.settings.mouseResize == .layout)
        core.execute(
            "set_mouse_resize",
            args: [.string("snap_back")]
        )
        #expect(core.tiler.settings.mouseResize == .snapBack)
        #expect(
            !core.execute(
                "set_mouse_resize",
                args: [.string("bogus")]
            ).isSuccess
        )
    }

    @Test("Navigation uses layout slots, not live AX frames")
    func navigateBySlots() throws {
        // Needs a real screen for slot geometry.
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A")
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(2), pid: 1, appName: "B")
            )
        )
        if let space = core.state.workspaces.space(
            of: WindowID(1)
        ) {
            core.state.workspaces.focus(WindowID(1), in: space)
        }
        // Both windows still report frame .zero (no AX events
        // arrived): navigation must use the layout's slots.
        let response = core.execute(
            "focus",
            args: [.string("right")]
        )
        #expect(response.isSuccess)
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("stack.set_overflow_style updates and validates")
    func overflowStyle() {
        let core = makeCore()
        core.execute(
            "stack.set_overflow_style",
            args: [.string("cascade_all")]
        )
        #expect(
            core.tiler.settings.stack.overflowStyle
                == .cascadeAll
        )
        let bad = core.execute(
            "stack.set_overflow_style",
            args: [.string("sideways")]
        )
        #expect(!bad.isSuccess)
        #expect(
            core.tiler.settings.stack.overflowStyle
                == .cascadeAll
        )
    }

    @Test("set_new_window_placement updates and validates")
    func newWindowPlacement() {
        let core = makeCore()
        core.execute(
            "stack.set_new_window_placement",
            args: [.string("last")]
        )
        #expect(
            core.tiler.settings.stack.newWindowPlacement
                == .last
        )
        core.execute(
            "bsp.set_new_window_placement",
            args: [.string("before_focused")]
        )
        #expect(
            core.tiler.settings.bsp.newWindowPlacement
                == .beforeFocused
        )
        let bad = core.execute(
            "stack.set_new_window_placement",
            args: [.string("middle")]
        )
        #expect(!bad.isSuccess)
        #expect(
            core.tiler.settings.stack.newWindowPlacement
                == .last
        )
    }

    @Test("set_new_window_placement_override targets a space")
    func newWindowPlacementOverride() {
        let core = makeCore()
        core.execute(
            "set_new_window_placement_override",
            args: [.string("mail"), .string("first")]
        )
        #expect(
            core.tiler.settings.placementOverride[
                SpaceID("mail")
            ] == .first
        )
        let bad = core.execute(
            "set_new_window_placement_override",
            args: [.string("mail"), .string("middle")]
        )
        #expect(!bad.isSuccess)
    }
}
