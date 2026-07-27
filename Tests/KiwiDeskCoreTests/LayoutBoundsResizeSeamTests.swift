import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A resize span is the LAYOUT REGION, not the display (#537).
/// With the Space Bar on — the default — the region is the visible
/// frame minus its strip (#293), and every one of these assertions
/// is off by exactly the strip if a path reads
/// `tiler.visibleBounds` raw instead of `tiler.layoutBounds(on:)`.
///
/// The sibling `VisibleBoundsResizeSeamTests` keeps the Space Bar
/// OFF so the injected rect *is* the span, which is what pins the
/// #531 hook; this suite is the other half — bar ON, and the strip
/// deliberately enormous so the two spans can never be confused
/// for rounding.
@Suite("Resize spans read the layout region (#537)", .serialized)
@MainActor
struct LayoutBoundsResizeSeamTests {
    /// A 2000×1000 display with a 400pt Space Bar on `edge`, so
    /// the layout region is 1600 wide (or tall) against a 2000pt
    /// display: every ratio below differs by a fifth between the
    /// two, far outside any tolerance.
    private func makeCore(
        bounds: CGRect,
        edge: String
    ) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-layoutbounds-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in bounds }
        core.execute("set_gap_global", args: [.number(0)])
        core.execute("space_bar.set_enabled", args: [.bool(true)])
        core.execute("space_bar.set_edge", args: [.string(edge)])
        core.execute(
            "space_bar.set_thickness",
            args: [.number(400)]
        )
        // Pin every default these fixtures reason from (§5). The
        // min size is LOWERED from its 300 default on purpose: the
        // #383 write cap is `minSize / span`, and at 300 it would
        // clip the ratios below and mask the very difference this
        // suite measures.
        core.execute("set_min_window_size", args: [.number(200)])
        #expect(core.tiler.settings.minWindowSize == 200)
        #expect(core.tiler.settings.mouseResize == .layout)
        #expect(core.tiler.settings.spaceBarStyle.enabled)
        #expect(core.tiler.settings.spaceBarStyle.thickness == 400)
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        core.execute(
            "bsp.set_strategy",
            args: [.string("alternating")]
        )
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
        return core
    }

    private func ratioH(_ core: KiwiCore) -> Double {
        core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[SpaceID("1")]!
        ).splitRatioH
    }

    @Test("The keyboard span excludes the Space Bar's strip")
    func keyboardSpanExcludesStrip() {
        // 160pt of the 1600pt region is 0.1 of the ratio; of the
        // 2000pt display it would be 0.08.
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 2000, height: 1000),
            edge: "left"
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let before = ratioH(core)
        core.execute("resize", args: [.string("x"), .number(160)])
        #expect(abs((ratioH(core) - before) - 0.1) < 1e-9)
    }

    @Test("The BSP sign classifies against the region's midpoint")
    func bspSignUsesRegionMidpoint() {
        // The one case where the strip changes the *direction*,
        // not only the magnitude. Bar on the RIGHT, so the region
        // is 0…1600 (midX 800) inside a 0…2000 display (midX
        // 1000). At ratio 0.2 the right window's slot spans
        // 320…1600 — midX 960, which is past the region's
        // midpoint (second region, sign −1) but short of the
        // display's (first region, sign +1). Growing the right
        // window must LOWER the shared ratio (#122), so a raw-span
        // read is wrong twice over: 0.2 − 40/1600 = 0.175 against
        // 0.2 + 40/2000 = 0.22.
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 2000, height: 1000),
            edge: "right"
        )
        core.execute("bsp.set_ratio_h", args: [.number(0.2)])
        core.state.apply(.windowFocused(WindowID(2)))
        #expect(abs(ratioH(core) - 0.2) < 1e-9)
        core.execute("resize", args: [.string("x"), .number(40)])
        #expect(abs(ratioH(core) - 0.175) < 1e-9)
    }

    @Test("The scrolling slot seeds from the region's length")
    func scrollingSlotSeedsFromRegion() {
        // The one resize whose span becomes a STORED value: a 50%
        // slot seeds from the along-axis length, so +10pt stores
        // 0.5 × 1600 + 10 = 810 — against 1010 for the raw
        // display, a value that then outlives the nudge.
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 2000, height: 1000),
            edge: "left"
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.execute(
            "scroll.set_slot_size",
            args: [.string("50%")]
        )
        core.execute("resize", args: [.string("x"), .number(10)])
        guard let space = core.state.workspaces[SpaceID("1")]
        else {
            Issue.record("no space 1")
            return
        }
        let scrolling = core.tiler.settings
            .resolvedScrolling(for: space)
        // Pin the default this arithmetic reasons from: a
        // vertical axis would measure the (bar-unaffected)
        // height and red this test for an unrelated reason.
        #expect(scrolling.axisIsHorizontal)
        #expect(scrolling.slotSize == .points(810))
    }

    @Test("A finished mouse resize divides by the region")
    func mouseResizeEndDividesByRegion() {
        // `handleResizeEnd` translates the dragged frame into a
        // ratio delta over the same span: dragging the left
        // window 160pt wider is +0.1 of a 1600pt region, +0.08 of
        // the display. Called directly because that IS the drop
        // entry point (`KiwiCore+Drag` calls this signature).
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 2000, height: 1000),
            edge: "left"
        )
        guard let space = core.state.workspaces[SpaceID("1")],
            let slot = core.tiler.calculatedFrames(
                state: core.state
            )[WindowID(1)]
        else {
            Issue.record("no slot for the left window")
            return
        }
        // The slot itself already lives inside the region — proof
        // the layout side was never the bug, only the span the
        // resize compared it against.
        #expect(abs(slot.width - 800) < 1e-9)
        let before = ratioH(core)
        var dragged = slot
        dragged.size.width += 160
        core.handleResizeEnd(
            WindowID(1),
            slot: slot,
            frame: dragged,
            in: space
        )
        #expect(abs((ratioH(core) - before) - 0.1) < 1e-9)
    }
}
