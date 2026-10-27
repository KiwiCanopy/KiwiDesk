import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2676: a window changing state — floating and back, maximizing
/// and back, pocketing and out — moves under `on_state_change`,
/// apart from the toggles its neighbours follow. A counted
/// `animation.apply` is the animated path; the instant `setFrame`
/// path is uncounted (the #11 suites' probe).
@Suite("State change animation (#2676)", .serialized)
@MainActor
struct StateChangeAnimationTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-state-change-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        return core
    }

    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 900_001,
                    appName: "App\(raw)",
                    // A window with no size reads as already parked.
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                )
            )
        )
    }

    /// Counts animated applies per window from here on.
    private func countApplies(
        _ core: KiwiCore
    ) -> () -> [WindowID: Int] {
        core.tiler.animation.isEnabled = false
        var applies: [WindowID: Int] = [:]
        core.tiler.animation.apply = { id, _, _ in
            applies[id, default: 0] += 1
        }
        return { applies }
    }

    @Test("decodes absent as on and reads its key")
    func storedShape() throws {
        let absent = try JSONDecoder().decode(
            AnimationSettings.self,
            from: Data("{}".utf8)
        )
        #expect(absent.onStateChange)
        let off = try JSONDecoder().decode(
            AnimationSettings.self,
            from: Data(#"{"on_state_change":false}"#.utf8)
        )
        #expect(!off.onStateChange)
        let encoded =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(AnimationSettings())
            ) as? [String: Any]
        #expect(encoded?["on_state_change"] as? Bool == true)
    }

    @Test("the Lua verb sets it")
    func verbSetsIt() {
        let core = makeCore()
        #expect(
            core.execute(
                "animations.set_on_state_change",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.animations.onStateChange)
    }

    @Test("a held pass keeps the newest state change")
    func owedMergeKeepsTheWindow() {
        let older = MotionGate.Owed(
            animated: nil,
            pass: .event,
            sizing: .mayInstantSize,
            stateChange: WindowID(1)
        )
        let bare = MotionGate.Owed(
            animated: nil,
            pass: .event,
            sizing: .mayInstantSize
        )
        #expect(older.merged(with: bare).stateChange == WindowID(1))
        let newer = MotionGate.Owed(
            animated: nil,
            pass: .event,
            sizing: .mayInstantSize,
            stateChange: WindowID(2)
        )
        #expect(older.merged(with: newer).stateChange == WindowID(2))
    }

    @Test("floating follows on_state_change, not on_relayout")
    func floatOnFollowsItsToggle() {
        guard NSScreen.main != nil else { return }
        for on in [true, false] {
            let core = makeCore()
            addWindow(core, 1)
            addWindow(core, 2)
            core.focusWindow(WindowID(1), warp: false)
            core.tiler.settings.animations.onRelayout = !on
            core.tiler.settings.animations.onStateChange = on
            let applies = countApplies(core)
            #expect(core.execute("make_floating").isSuccess)
            let moved = applies()[WindowID(1)] ?? 0
            #expect(on ? moved >= 1 : moved == 0)
        }
    }

    @Test("tiling back animates the window, not its neighbour")
    func floatOffSplitsTheToggles() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        addWindow(core, 1)
        addWindow(core, 2)
        core.focusWindow(WindowID(1), warp: false)
        #expect(core.execute("make_floating").isSuccess)
        core.tiler.settings.animations.onRelayout = false
        core.tiler.settings.animations.onStateChange = true
        let applies = countApplies(core)
        #expect(core.execute("make_tiled").isSuccess)
        #expect((applies()[WindowID(1)] ?? 0) >= 1)
        #expect((applies()[WindowID(2)] ?? 0) == 0)
    }

    @Test("maximizing follows on_state_change")
    func maximizeFollowsItsToggle() {
        guard NSScreen.main != nil else { return }
        for on in [true, false] {
            let core = makeCore()
            core.execute(
                "set_mode",
                args: [.string("1"), .string("bsp")]
            )
            addWindow(core, 1)
            addWindow(core, 2)
            core.focusWindow(WindowID(1), warp: false)
            core.tiler.settings.animations.onWindowResize = !on
            core.tiler.settings.animations.onStateChange = on
            let applies = countApplies(core)
            #expect(core.execute("toggle_maximized").isSuccess)
            let moved = applies()[WindowID(1)] ?? 0
            #expect(on ? moved >= 1 : moved == 0)
        }
    }

    @Test("pocketing slides only under on_state_change")
    func pocketFollowsItsToggle() {
        guard NSScreen.main != nil else { return }
        for on in [true, false] {
            let core = makeCore()
            addWindow(core, 1)
            addWindow(core, 2)
            core.focusWindow(WindowID(1), warp: false)
            core.tiler.settings.animations.onStateChange = on
            let applies = countApplies(core)
            #expect(core.execute("pocket").isSuccess)
            #expect(core.state.pocketedWindow == WindowID(1))
            let moved = applies()[WindowID(1)] ?? 0
            #expect(on ? moved >= 1 : moved == 0)
        }
    }

    @Test("taking a window out of the pocket slides it in")
    func pocketOutFollowsItsToggle() {
        guard NSScreen.main != nil else { return }
        for on in [true, false] {
            let core = makeCore()
            addWindow(core, 1)
            addWindow(core, 2)
            core.focusWindow(WindowID(1), warp: false)
            #expect(core.execute("pocket").isSuccess)
            core.tiler.settings.animations.onStateChange = on
            let applies = countApplies(core)
            #expect(core.execute("pocket").isSuccess)
            #expect(core.state.pocketedWindow == nil)
            let moved = applies()[WindowID(1)] ?? 0
            #expect(on ? moved >= 1 : moved == 0)
        }
    }

    @Test("a detected float keeps on_relayout")
    func detectedFloatKeepsRelayout() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.tiler.settings.animations.onStateChange = false
        core.tiler.settings.animations.onRelayout = true
        let applies = countApplies(core)
        core.state.apply(
            .windowFloatChanged(WindowID(1), isFloating: true)
        )
        core.placeFloating(WindowID(1))
        #expect((applies()[WindowID(1)] ?? 0) >= 1)
    }

    @Test("a focus that ends a maximize follows on_state_change")
    func focusEndedMaximizeFollowsItsToggle() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        addWindow(core, 1)
        addWindow(core, 2)
        core.focusWindow(WindowID(1), warp: false)
        #expect(core.execute("toggle_maximized").isSuccess)
        core.tiler.settings.animations.onStateChange = false
        core.tiler.settings.animations.onRelayout = true
        core.tiler.settings.animations.onWindowResize = true
        let applies = countApplies(core)
        core.focusWindow(WindowID(2), warp: false)
        #expect((applies()[WindowID(1)] ?? 0) == 0)
        // The control: with the toggle on, the same end animates.
        core.focusWindow(WindowID(1), warp: false)
        #expect(core.execute("toggle_maximized").isSuccess)
        core.tiler.settings.animations.onStateChange = true
        let more = countApplies(core)
        core.focusWindow(WindowID(2), warp: false)
        #expect((more()[WindowID(1)] ?? 0) >= 1)
    }

    @Test("a newcomer's pass promises no state-change spring")
    func newcomerKeepsTheInvariant() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.tiler.retile(
            state: core.state,
            newlyCreatedWindow: WindowID(2),
            stateChange: WindowID(1)
        )
        #expect(!core.tiler.stateChangeSprings)
        core.tiler.retile(state: core.state, stateChange: WindowID(1))
        #expect(core.tiler.stateChangeSprings)
    }

    /// The newcomer is never the state change: it follows the
    /// pass's toggle, never `on_state_change`.
    @Test("a newcomer named as the state change follows the pass")
    func newcomerIsNoStateChange() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        core.tiler.settings.animations.onStateChange = false
        let applies = countApplies(core)
        core.tiler.retile(
            state: core.state,
            animated: true,
            newlyCreatedWindow: WindowID(1),
            stateChange: WindowID(1)
        )
        #expect((applies()[WindowID(1)] ?? 0) >= 1)
    }

    @Test("a held pass replays its state change")
    func heldPassKeepsTheWindow() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        addWindow(core, 1)
        addWindow(core, 2)
        core.focusWindow(WindowID(1), warp: false)
        #expect(core.execute("make_floating").isSuccess)
        core.state.setFloating(WindowID(1), false)
        core.tiler.settings.animations.onRelayout = false
        core.tiler.settings.animations.onStateChange = true
        let applies = countApplies(core)
        core.tiler.motionGate.release(
            MotionGate.Owed(
                animated: nil,
                pass: .event,
                sizing: .mayInstantSize,
                stateChange: WindowID(1)
            )
        )
        #expect((applies()[WindowID(1)] ?? 0) >= 1)
        #expect((applies()[WindowID(2)] ?? 0) == 0)
    }

    @Test("a newcomer's spring promises nothing for the state change")
    func newcomerSpringIsInstantSized() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        addWindow(core, 1)
        addWindow(core, 2)
        core.tiler.animation.isEnabled = true
        defer { core.tiler.animation.cancelAll(snapToTargets: false) }
        core.tiler.settings.animations.onStateChange = true
        core.tiler.retile(
            state: core.state,
            newlyCreatedWindow: WindowID(2),
            stateChange: WindowID(1)
        )
        let spring = try #require(
            core.tiler.animation.removeAnimation(for: WindowID(1))
        )
        #expect(spring.sizing == .mayInstantSize)
    }

    /// The OS focus report path (a click, ⌘-Tab), beside the
    /// commanded focus `focusEndedMaximizeFollowsItsToggle` drives.
    @Test("a focus report that ends a maximize follows its toggle")
    func reportEndedMaximizeFollowsItsToggle() {
        guard NSScreen.main != nil else { return }
        for on in [true, false] {
            let core = makeCore()
            core.execute(
                "set_mode",
                args: [.string("1"), .string("bsp")]
            )
            addWindow(core, 1)
            addWindow(core, 2)
            core.focusWindow(WindowID(1), warp: false)
            #expect(core.execute("toggle_maximized").isSuccess)
            core.tiler.settings.animations.onStateChange = on
            core.tiler.settings.animations.onRelayout = !on
            core.tiler.settings.animations.onWindowResize = !on
            let applies = countApplies(core)
            core.handle(.windowFocused(WindowID(2)))
            let moved = applies()[WindowID(1)] ?? 0
            #expect(on ? moved >= 1 : moved == 0)
        }
    }
}
