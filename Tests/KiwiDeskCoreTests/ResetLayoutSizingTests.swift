import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `reset_layout_sizing` (#764) clears every Space's SIZING —
/// the session layer, the size fields of the authored overrides
/// and the stack/track weights — and keeps structure and the
/// globals. Display pinned (#531); a headless host reads as a
/// SKIP, the `ScrollingResizeAnchorEndToEndTests` shape, since
/// the retile the verb rides needs a screen.
@Suite(
    "reset_layout_sizing (#764)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ResetLayoutSizingTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    /// Two windows on a pinned 1200×800 display in the bsp
    /// Space "1", whose global side-by-side ratio is the USER's
    /// 0.4 — the reset must land there, never on the shipped
    /// 0.5. Spaces 2–5 exist to carry the other stores.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-reset-sizing-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        for id in 2...7 {
            core.state.workspaces.ensureSpace(SpaceID(id))
        }
        #expect(
            core.execute("bsp.set_ratio_h", args: [.number(0.4)])
                .isSuccess
        )
        return core
    }

    /// Seeds one size AND one structure value in every store.
    private func seed(_ core: KiwiCore) {
        core.execute(
            "bsp.set_strategy_override",
            args: [.string("1"), .string("longest_side")]
        )
        core.execute(
            "bsp.set_ratio_v_override",
            args: [.string("1"), .number(0.3)]
        )
        core.execute(
            "stack.set_master_count_override",
            args: [.string("2"), .number(2)]
        )
        core.execute(
            "stack.set_master_ratio_override",
            args: [.string("2"), .number(0.7)]
        )
        core.execute(
            "scroll.set_anchor_override",
            args: [.string("3"), .string("start")]
        )
        core.execute(
            "scroll.set_slot_size_override",
            args: [.string("3"), .number(400)]
        )
        core.execute(
            "track.set_limit_override",
            args: [.string("4"), .number(3)]
        )
        // Size-only override entries, one per store, to be
        // pruned whole.
        core.execute(
            "bsp.set_ratio_h_override",
            args: [.string("5"), .number(0.2)]
        )
        core.execute(
            "stack.set_master_ratio_override",
            args: [.string("6"), .number(0.8)]
        )
        core.execute(
            "scroll.set_slot_size_override",
            args: [.string("7"), .number(300)]
        )
        core.state.workspaces.withSpace(SpaceID("2")) {
            $0.stackWeights[w1] = 2
            $0.sessionRatios.masterRatio = 0.6
        }
        core.state.workspaces.withSpace(SpaceID("4")) {
            $0.trackWeights[w1] = 2
            $0.trackBreaks = [w1]
            $0.sessionRatios.slotSize = .points(500)
        }
    }

    @Test("Every size store is cleared and every structure kept")
    func clearsSizesKeepsStructure() throws {
        let core = makeCore()
        seed(core)
        // An interactive resize lands in Space 1's session layer.
        core.execute("resize", args: [.string("x"), .number(200)])
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.splitRatioH != nil
        )
        #expect(core.execute("reset_layout_sizing").isSuccess)
        for space in core.state.workspaces.allSpaces {
            #expect(space.sessionRatios == SessionRatios())
            #expect(space.stackWeights.isEmpty)
            #expect(space.trackWeights.isEmpty)
        }
        let settings = core.tiler.settings
        let bsp = try #require(settings.bsp.override[SpaceID("1")])
        #expect(bsp.strategy == .longestSide)
        #expect(bsp.splitRatioH == nil)
        #expect(bsp.splitRatioV == nil)
        let stack = try #require(
            settings.stack.override[SpaceID("2")]
        )
        #expect(stack.masterCount == 2)
        #expect(stack.masterRatio == nil)
        let scrolling = try #require(
            settings.scrolling.override[SpaceID("3")]
        )
        #expect(scrolling.anchor == .start)
        #expect(scrolling.slotSize == nil)
        #expect(settings.track.override[SpaceID("4")]?.limit == 3)
        #expect(
            core.state.workspaces[SpaceID("4")]?.trackBreaks == [w1]
        )
        #expect(settings.bsp.override[SpaceID("5")] == nil)
        #expect(settings.stack.override[SpaceID("6")] == nil)
        #expect(settings.scrolling.override[SpaceID("7")] == nil)
    }

    @Test("The reset lands on the global and retiles")
    func returnsToTheConfiguredFrames() throws {
        let core = makeCore()
        core.retile()
        let configured = core.tiler.calculatedFrames(
            state: core.state
        )
        core.execute("resize", args: [.string("x"), .number(200)])
        let resized = core.tiler.calculatedFrames(state: core.state)
        #expect(resized[w1]?.width != configured[w1]?.width)
        #expect(core.execute("reset_layout_sizing").isSuccess)
        // Never the shipped 0.5: the user's global is the floor.
        #expect(core.tiler.settings.bsp.splitRatioH == 0.4)
        let reset = core.tiler.calculatedFrames(state: core.state)
        #expect(reset[w1] == configured[w1])
        #expect(reset[w2] == configured[w2])
        // The trailing retile issued the configured frames —
        // `onRelayout` animates, so the target is the frame.
        #expect(
            core.tiler.animation.targetFrame(window: w1)
                == configured[w1]
        )
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
