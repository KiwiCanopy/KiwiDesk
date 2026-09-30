import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A tiled window detection starts floating — a float rule saved
/// over it — is placed as the float verbs place one (#1820): it
/// leaves its layout slot for the centred placement, `keep` leaves
/// it, and a window already an effective float is never placed.
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
        core.handle(.windowFloatChanged(window, isFloating: true))
        #expect(core.state.windows[window]?.isFloating == true)
        #expect(isCentred(frames[window], in: core))
    }

    @Test("keep leaves the window where it was")
    func keepLeavesIt() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.tiler.settings.floatPlacement = .keep
        core.handle(.windowFloatChanged(window, isFloating: true))
        #expect(!isCentred(frames[window], in: core))
    }

    /// Already an effective float: its frame is the user's.
    @Test("a window the user floated is not placed again")
    func userFloatNotPlaced() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        #expect(core.execute("make_floating").isSuccess)
        frames = [:]
        core.handle(.windowFloatChanged(window, isFloating: true))
        #expect(frames[window] == nil)
    }

    @Test("a floating-mode member is not placed")
    func floatingModeMemberNotPlaced() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "floating") { frames[$0] = $1 }
        frames = [:]
        core.handle(.windowFloatChanged(window, isFloating: true))
        #expect(!isCentred(frames[window], in: core))
    }

    @Test("a flip back to tiled places nothing")
    func tileFlipNotPlaced() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.handle(.windowFloatChanged(window, isFloating: true))
        frames = [:]
        core.handle(.windowFloatChanged(window, isFloating: false))
        #expect(!isCentred(frames[window], in: core))
    }
}
