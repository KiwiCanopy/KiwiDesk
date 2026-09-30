import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A tiled window detection starts floating — a float rule saved
/// over it — is placed as the float verbs place one (#1820): it
/// leaves its layout slot for the centred placement, `keep` leaves
/// it, and a window already an effective float is never placed.
/// A detection tile files the float frame as `make_tiled` does,
/// so the rule coming back returns the window there (#1675).
@Suite("Float placement on a detection flip", .serialized)
@MainActor
struct DetectedFloatPlacementTests {
    private let slot = CGRect(x: 40, y: 60, width: 300, height: 900)
    private let window = WindowID(2)

    /// Two windows on space 1 in `mode`, w2 at `slot`. The
    /// animation engine is disabled so the placement lands
    /// synchronously on the observable `apply` hook.
    private func setup(
        mode: String = "bsp",
        applied: @escaping @MainActor (WindowID, CGRect) -> Void
    ) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        // Pin the display (#531): the region is read through it.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.tiler.settings.floatPlacement = .center
        // The screen the remembered frame is judged on (#1675).
        core.tiler.allScreenBounds = {
            [CGRect(x: 0, y: 0, width: 1600, height: 1000)]
        }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
        for index in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        core.state.apply(.windowResized(window, slot))
        core.state.apply(.windowFocused(window))
        core.tiler.settings.animations.onRelayout = true
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        return core
    }

    private func flip(_ core: KiwiCore, _ floating: Bool) {
        core.handle(.windowFloatChanged(window, isFloating: floating))
    }

    private func isCentred(_ frame: CGRect?, in core: KiwiCore) -> Bool {
        guard let frame,
            let region = core.floatGrowBounds(of: window)
        else { return false }
        return abs(frame.midX - region.midX) < 0.001
            && abs(frame.midY - region.midY) < 0.001
            && frame.width == FloatPlacement.longFloor
    }

    @Test("a rule floating a tiled window centres it")
    func ruleFlipCentres() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        flip(core, true)
        #expect(core.state.windows[window]?.isFloating == true)
        #expect(isCentred(frames[window], in: core))
    }

    @Test("keep leaves the window where it was")
    func keepLeavesIt() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.tiler.settings.floatPlacement = .keep
        frames = [:]
        flip(core, true)
        #expect(frames[window] == nil)
    }

    /// Already an effective float: its frame is the user's.
    @Test("a window the user floated is not placed again")
    func userFloatNotPlaced() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        #expect(core.execute("make_floating").isSuccess)
        frames = [:]
        flip(core, true)
        #expect(frames[window] == nil)
    }

    @Test("a floating-mode member is not placed")
    func floatingModeMemberNotPlaced() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "floating") { frames[$0] = $1 }
        frames = [:]
        flip(core, true)
        #expect(frames[window] == nil)
    }

    @Test("a window a drag holds is left under the pointer")
    func dragHeldNotPlaced() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.tiler.dragExemptWindow = window
        frames = [:]
        flip(core, true)
        #expect(frames[window] == nil)
    }

    @Test("a native-fullscreen window is not placed")
    func fullscreenNotPlaced() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.state.windows.setFullscreen(window, true)
        frames = [:]
        flip(core, true)
        #expect(frames[window] == nil)
    }

    /// Boot and a sweep chunk: the frame is the app's, no slot.
    @Test("nothing is placed while event retiles are deferred")
    func deferredRetilesStandDown() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.defersEventRetiles = true
        frames = [:]
        flip(core, true)
        #expect(frames[window] == nil)
    }

    /// The rule coming back returns the window to the frame it
    /// floated at, as `make_tiled` then `make_floating` does.
    @Test("a detection tile remembers where the window floated")
    func tileRemembersTheFloatFrame() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        let moved = CGRect(x: 300, y: 200, width: 700, height: 500)
        flip(core, true)
        // Moved by hand while floating, then tiled by detection.
        core.state.apply(.windowMoved(window, moved))
        flip(core, false)
        #expect(core.state.floatFrames[window]?.frame == moved)
        frames = [:]
        flip(core, true)
        #expect(frames[window] == moved)
    }

    @Test("a window on an unshown Space is seeded, not placed")
    func unshownSpaceSeeds() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.execute(
            "move_to_space",
            args: [.string("2"), .number(Double(window.raw))]
        )
        frames = [:]
        flip(core, true)
        #expect(frames[window] == nil)
        let seed = try #require(core.tiler.stashedFrames[window])
        #expect(seed.width == FloatPlacement.longFloor)
    }

    /// One Save floats several windows, one event each: the later
    /// steps off the earlier rather than landing on it.
    @Test("several flips cascade")
    func flipsCascade() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.handle(.windowFloatChanged(WindowID(1), isFloating: true))
        // The first placement's echo, as the app reports it.
        let placed = try #require(frames[WindowID(1)])
        core.state.apply(.windowMoved(WindowID(1), placed))
        flip(core, true)
        let first = try #require(frames[WindowID(1)])
        let second = try #require(frames[window])
        #expect(second.minX > first.minX)
        #expect(second.minY > first.minY)
    }

    @Test("a flip back to tiled returns the window to its slot")
    func tileFlipTiles() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        flip(core, true)
        frames = [:]
        flip(core, false)
        let slot = core.tiler.calculatedFrames(state: core.state)[window]
        #expect(slot != nil)
        #expect(frames[window] == slot)
    }
}
