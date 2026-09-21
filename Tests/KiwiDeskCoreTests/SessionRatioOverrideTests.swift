import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The session layer against an AUTHORED override (#458, #764):
/// a resize never writes the override — the layer outranks it —
/// so the override stays the number the profile wrote and
/// `reset_layout_sizing` can return to it; the price is that an
/// explicit per-space `_override` write must drop its shadow.
@Suite("Session resize layer — authored overrides (#764)", .serialized)
@MainActor
struct SessionRatioOverrideTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-session-override-\(UUID().uuidString)"
                )
        )
    }

    /// The session layer outranks the override, so the explicit
    /// per-space write must drop the shadow or it visibly does
    /// nothing (#383's trap, one layer down).
    @Test("An explicit per-space override drops that Space's shadow")
    func overrideSetterClearsShadow() {
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
        let space = core.state.workspaces[SpaceID("1")]
        #expect(space?.sessionRatios.splitRatioH == nil)
        if let space {
            #expect(
                core.tiler.settings.resolvedBsp(for: space)
                    .splitRatioH == 0.3
            )
        }
    }

    /// The #764 shape: a resize on an authored Space lands in the
    /// session layer, the override keeps the authored number, and
    /// the session value is what the layout resolves — so the
    /// reset can return to the override by dropping the layer.
    @Test("A resize on an authored Space never writes the override")
    func resizeLeavesTheOverrideAuthored() {
        let core = makeCore()
        core.execute(
            "bsp.set_ratio_h_override",
            args: [.string("1"), .number(0.3)]
        )
        core.execute("resize", args: [.string("x"), .number(500)])
        #expect(
            core.tiler.settings.bsp.override[SpaceID("1")]?
                .splitRatioH == 0.3
        )
        let space = core.state.workspaces[SpaceID("1")]
        let session = space?.sessionRatios.splitRatioH
        #expect(session != nil && session != 0.3)
        if let space, let session {
            #expect(
                core.tiler.settings.resolvedBsp(for: space)
                    .splitRatioH == session
            )
        }
    }

    /// The other three overlay lines, each pinned on its own
    /// field: a resolver that flips one back to override-first
    /// stays green on the H clause above.
    @Test("Every overlay line reads the session layer first")
    func everyOverlayLineReadsSessionFirst() {
        var over = TilingSettings()
        var bsp = BspOverride()
        bsp.splitRatioH = 0.3
        bsp.splitRatioV = 0.3
        over.bsp.override[SpaceID("1")] = bsp
        var stack = StackOverride()
        stack.masterRatio = 0.3
        over.stack.override[SpaceID("1")] = stack
        var scrolling = ScrollingOverride()
        scrolling.slotSize = .points(300)
        over.scrolling.override[SpaceID("1")] = scrolling
        var session = SessionRatios()
        session.splitRatioH = 0.8
        session.splitRatioV = 0.7
        session.masterRatio = 0.6
        session.slotSize = .points(500)
        let space = Space(id: SpaceID("1"), sessionRatios: session)
        #expect(over.resolvedBsp(for: space).splitRatioH == 0.8)
        #expect(over.resolvedBsp(for: space).splitRatioV == 0.7)
        #expect(over.resolvedStack(for: space).masterRatio == 0.6)
        #expect(
            over.resolvedScrolling(for: space).slotSize
                == .points(500)
        )
    }

    @Test("Every per-space override setter drops its own shadow")
    func allOverrideSettersClearTheirField() {
        let core = makeCore()
        core.execute("resize", args: [.string("y"), .number(500)])
        #expect(
            core.execute(
                "bsp.set_ratio_v_override",
                args: [.string("1"), .number(0.4)]
            ).isSuccess
        )
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.splitRatioV == nil
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        core.execute("resize", args: [.string("x"), .number(500)])
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.masterRatio != nil
        )
        #expect(
            core.execute(
                "stack.set_master_ratio_override",
                args: [.string("1"), .number(0.55)]
            ).isSuccess
        )
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.masterRatio == nil
        )
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
            core.execute(
                "scroll.set_slot_size_override",
                args: [.string("1"), .number(700)]
            ).isSuccess
        )
        #expect(
            core.state.workspaces[SpaceID("1")]?
                .sessionRatios.slotSize == nil
        )
    }
}
