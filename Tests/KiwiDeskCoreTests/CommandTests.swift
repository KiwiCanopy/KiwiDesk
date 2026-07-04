import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

@Suite("Command execution", .serialized)
@MainActor
struct CommandTests {
    @Test("set_mode changes the space layout and emits")
    func setMode() {
        let core = makeCore()
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        let response = core.execute(
            "set_mode",
            args: [.string("2"), .string("stack")]
        )
        #expect(response.isSuccess)
        #expect(
            core.state.workspaces[SpaceID(2)]?.mode == .stack
        )
        #expect(events.contains { $0.0 == .layoutChange })
    }

    @Test("set_gap_global updates tiling settings")
    func gaps() {
        let core = makeCore()
        #expect(
            core.execute(
                "set_gap_global",
                args: [.number(24)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.gapsGlobal
                == .uniform(24)
        )
        #expect(
            core.execute(
                "set_gap_override",
                args: [.string("3"), .number(0)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.gaps(for: SpaceID(3))
                == .uniform(0)
        )
    }

    @Test("Layout sub-APIs adjust parameters")
    func subAPIs() {
        let core = makeCore()
        #expect(
            core.execute(
                "stack.set_master_count",
                args: [.number(2)]
            ).isSuccess
        )
        #expect(core.tiler.settings.stack.masterCount == 2)

        #expect(
            core.execute(
                "bsp.set_strategy",
                args: [.string("alternating")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.bsp.strategy == .alternating
        )

        #expect(
            core.execute(
                "grid.set_dimensions",
                args: [.number(4), .number(2)]
            ).isSuccess
        )
        #expect(core.tiler.settings.grid.columns == 4)
        #expect(core.tiler.settings.grid.rows == 2)
    }

    @Test("Unknown commands return an error with a hint")
    func unknownCommand() {
        let core = makeCore()
        let response = core.execute("frobnicate")
        #expect(!response.isSuccess)
        #expect(response.error?.contains("unknown") == true)
        #expect(response.error?.contains("help") == true)
    }

    @Test("Typos get a did-you-mean suggestion")
    func didYouMean() {
        let core = makeCore()
        let response = core.execute("set_mdoe")
        #expect(
            response.error?.contains("set_mode") == true
        )
    }

    @Test("help lists every command")
    func helpCommand() {
        let core = makeCore()
        let response = core.execute("help")
        guard case .array(let names)? = response.data else {
            Issue.record("expected command list")
            return
        }
        #expect(names.contains(.string("focus")))
        #expect(
            names.contains(.string("stack.set_master_count"))
        )
        #expect(names.contains(.string("subscribe")))
    }

    @Test("get_state reports spaces and windows")
    func getState() {
        var events = makeCore()
        events.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(7),
                    pid: 1,
                    appName: "Editor"
                )
            )
        )
        let response = events.execute("get_state")
        guard case .object(let data)? = response.data else {
            Issue.record("expected object data")
            return
        }
        #expect(data["active_space"] == .string("1"))
        guard case .array(let windows)? = data["windows"]
        else {
            Issue.record("expected windows array")
            return
        }
        #expect(windows.count == 1)
    }

    @Test("Toggles reach animation and wake-restore")
    func toggles() {
        let core = makeCore()
        core.execute(
            "enable_animations",
            args: [.bool(false)]
        )
        #expect(!core.tiler.animation.isEnabled)
        core.execute(
            "set_wake_restore_delay",
            args: [.number(2500)]
        )
        #expect(core.sleepWake.restoreDelayMS == 2500)
        #expect(!core.tiler.animateSpaceSwitch)
        core.execute(
            "set_space_animation",
            args: [.bool(true)]
        )
        #expect(core.tiler.animateSpaceSwitch)
        #expect(core.tiler.mouseResize == .layout)
        core.execute(
            "set_mouse_resize",
            args: [.string("snap_back")]
        )
        #expect(core.tiler.mouseResize == .snapBack)
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

@Suite("Config loading", .serialized)
@MainActor
struct ConfigTests {
    @Test("init.lua drives settings, rules, and events")
    func endToEnd() throws {
        let core = makeCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let config = """
            KiwiDesk.set_gap_global(16)
            stack.set_master_count(3)
            float_rules = { "Calculator" }
            app_rules = { ["Spotify"] = "music" }
            KiwiDesk.on("layout_change", function(id, mode)
                last_mode = mode
            end)
            """
        try config.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()

        #expect(
            core.tiler.settings.gapsGlobal == .uniform(16)
        )
        #expect(core.tiler.settings.stack.masterCount == 3)
        #expect(
            core.state.appRules["Spotify"]
                == SpaceID("music")
        )

        // Trigger a layout change; the Lua callback runs.
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        #expect(
            core.lua?.global("last_mode")
                == .string("monocle")
        )
    }

    @Test("Missing config is created with defaults")
    func defaultConfig() {
        let core = makeCore()
        core.loadConfig()
        #expect(
            FileManager.default.fileExists(
                atPath: core.configURL.path
            )
        )
    }

    @Test("Lua typos log a hint instead of erroring")
    func typoGuard() throws {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.loadConfig()
        let result = core.lua?.run(
            "KiwiDesk.focsu('left')"
        )
        #expect(result?.succeeded == true)
        #expect(
            logs.contains {
                $0.contains("focsu")
                    && $0.contains("KiwiDesk.help()")
            }
        )
    }
}

@Suite("API reference")
struct APIReferenceTests {
    @Test("Suggestions catch close typos only")
    func suggestions() {
        #expect(
            APIReference.suggestion(for: "set_mdoe")
                == "set_mode"
        )
        #expect(
            APIReference.suggestion(for: "focsu") == "focus"
        )
        #expect(
            APIReference.suggestion(
                for: "completely_unrelated_xyz"
            ) == nil
        )
    }

    @Test("Edit distance is symmetric and exact")
    func editDistance() {
        #expect(APIReference.editDistance("", "abc") == 3)
        #expect(
            APIReference.editDistance("focus", "focus") == 0
        )
        #expect(
            APIReference.editDistance("focus", "focsu") == 2
        )
    }
}

@Suite("Navigation")
struct NavigationTests {
    private func frame(
        _ x: CGFloat,
        _ y: CGFloat
    ) -> CGRect {
        CGRect(x: x, y: y, width: 100, height: 100)
    }

    @Test("No cross-column jump without cross-axis overlap")
    func requiresOverlap() {
        // Full-height master, two stack windows to the right.
        let master = CGRect(x: 0, y: 0, width: 500, height: 1000)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(2), CGRect(x: 510, y: 0, width: 300, height: 490)),
            (WindowID(3), CGRect(x: 510, y: 510, width: 300, height: 490)),
        ]
        // Up/down from the master must fail, not jump into
        // the stack column diagonally.
        #expect(
            Navigation.neighbor(
                from: master,
                in: .up,
                candidates: candidates
            ) == nil
        )
        #expect(
            Navigation.neighbor(
                from: master,
                in: .down,
                candidates: candidates
            ) == nil
        )
        // Right still finds the stack (rows overlap).
        #expect(
            Navigation.neighbor(
                from: master,
                in: .right,
                candidates: candidates
            ) != nil
        )
    }

    @Test("Finds the straight neighbor in each direction")
    func straightNeighbors() {
        let origin = frame(500, 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), frame(300, 500)),
            (WindowID(2), frame(700, 500)),
            (WindowID(3), frame(500, 300)),
            (WindowID(4), frame(500, 700)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .left,
                candidates: candidates
            ) == WindowID(1)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: candidates
            ) == WindowID(2)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .up,
                candidates: candidates
            ) == WindowID(3)
        )
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .down,
                candidates: candidates
            ) == WindowID(4)
        )
    }

    @Test("Straight neighbors beat closer diagonal ones")
    func lateralPenalty() {
        let origin = frame(500, 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), frame(650, 350)),
            (WindowID(2), frame(800, 500)),
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .right,
                candidates: candidates
            ) == WindowID(2)
        )
    }

    @Test("No neighbor in an empty direction")
    func emptyDirection() {
        let origin = frame(500, 500)
        let candidates: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), frame(700, 500))
        ]
        #expect(
            Navigation.neighbor(
                from: origin,
                in: .left,
                candidates: candidates
            ) == nil
        )
    }
}

extension Result {
    fileprivate var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}
