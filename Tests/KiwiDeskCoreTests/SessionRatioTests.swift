import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The session resize layer (#458): interactive resizes on a
/// space with no authored override live in per-space runtime
/// state — config layers untouched, other spaces unmoved —
/// with authored override > session > global precedence, and
/// reseeding on mode change and explicit global writes.
@Suite("Session resize layer (#458)", .serialized)
@MainActor
struct SessionRatioTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-session-\(UUID().uuidString)"
                )
        )
    }

    @Test("BSP resize moves only the resized space")
    func bspIsolation() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("2")
        core.execute("resize", args: [.string("x"), .number(500)])
        // The resized space resolves its session value…
        let one = core.state.workspaces[SpaceID("1")]
        #expect(one?.sessionRatios.splitRatioH != nil)
        if let one {
            #expect(
                core.tiler.settings.resolvedBsp(for: one)
                    .splitRatioH != 0.5
            )
        }
        // …while the other no-override space still resolves
        // the untouched global.
        let two = core.state.workspaces[SpaceID("2")]
        if let two {
            #expect(
                core.tiler.settings.resolvedBsp(for: two)
                    .splitRatioH == 0.5
            )
        }
        #expect(core.tiler.settings.bsp.splitRatioH == 0.5)
    }

    @Test("An authored override wins over a stale session value")
    func overrideBeatsSession() {
        let core = makeCore()
        core.execute("resize", args: [.string("x"), .number(500)])
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.splitRatioH != nil
        )
        core.execute(
            "bsp.set_ratio_h_override",
            args: [.string("1"), .number(0.3)]
        )
        if let space = core.state.workspaces[SpaceID("1")] {
            #expect(
                core.tiler.settings.resolvedBsp(for: space)
                    .splitRatioH == 0.3
            )
        }
    }

    @Test("A real mode change reseeds; a same-mode set keeps")
    func modeChangeReseeds() {
        let core = makeCore()
        core.execute("resize", args: [.string("x"), .number(500)])
        // Dense same-mode applies (profile/GUI) must not wipe.
        core.state.workspaces.setMode(SpaceID("1"), .bsp)
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.splitRatioH != nil
        )
        core.state.workspaces.setMode(SpaceID("1"), .stack)
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios == SessionRatios()
        )
    }

    @Test("An explicit global setter drops the session shadow")
    func explicitGlobalClearsShadow() {
        let core = makeCore()
        core.execute("resize", args: [.string("x"), .number(500)])
        core.execute("resize", args: [.string("y"), .number(500)])
        #expect(
            core.execute(
                "bsp.set_ratio_h",
                args: [.number(0.4)]
            ).isSuccess
        )
        let session =
            core.state.workspaces[SpaceID("1")]?.sessionRatios
        // Only the written field is cleared; the V value is a
        // different knob and survives.
        #expect(session?.splitRatioH == nil)
        #expect(session?.splitRatioV != nil)
        if let space = core.state.workspaces[SpaceID("1")] {
            #expect(
                core.tiler.settings.resolvedBsp(for: space)
                    .splitRatioH == 0.4
            )
        }
    }

    @Test("Scrolling slot resize stays per-space too")
    func scrollingSlotSession() {
        let core = makeCore()
        let globalBefore = core.tiler.settings.scrolling.slotSize
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.execute("resize", args: [.string("x"), .number(50)])
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.slotSize != nil
        )
        #expect(
            core.tiler.settings.scrolling.slotSize == globalBefore
        )
    }

    @Test("The mouse drop path writes the same session layer")
    func mouseAdjustmentSession() {
        let core = makeCore()
        guard let space = core.state.workspaces[SpaceID("1")]
        else {
            Issue.record("active space missing")
            return
        }
        core.applyResizeAdjustment(
            .bspRatioH(0.1),
            in: space,
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        let session =
            core.state.workspaces[SpaceID("1")]?.sessionRatios
        #expect(session?.splitRatioH != nil)
        #expect(core.tiler.settings.bsp.splitRatioH == 0.5)
    }
}
