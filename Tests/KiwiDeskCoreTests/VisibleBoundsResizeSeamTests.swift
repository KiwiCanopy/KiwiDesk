import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The resize half of the `visibleBounds` seam (#531): a resize
/// span is delta-over-display-width, so every one of these
/// arithmetic results is a function of the injected rect. Split
/// from `VisibleBoundsSeamTests`, which pins the layout half —
/// per-file helpers are the convention (§5), and the small
/// duplication of `makeCore` between the two is the cheaper side
/// of that trade.
@Suite("Injected visible bounds — resize (#531)", .serialized)
@MainActor
struct VisibleBoundsResizeSeamTests {
    private func makeCore(bounds: CGRect) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-bounds-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in bounds }
        // Zero gaps and no Space Bar, so the injected rect IS the
        // span: both reservations are real defaults with their
        // own coverage, and leaving them on would only blur what
        // these assertions are about. `LayoutBoundsResizeSeamTests`
        // is the bar-ON half — that the span excludes the strip
        // (#537); this suite pins that it follows the hook at all.
        core.execute("set_gap_global", args: [.number(0)])
        core.execute(
            "space_bar.set_enabled",
            args: [.bool(false)]
        )
        // Pin the defaults these fixtures reason from, the rule
        // this change set wrote into §5: a finished mouse resize
        // only reaches the layout in `.layout` mode, and the caps
        // every span feeds derive from the minimum.
        #expect(core.tiler.settings.minWindowSize == 300)
        #expect(core.tiler.settings.mouseResize == .layout)
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

    @Test("The keyboard span is the injected width")
    func resizeSpanFollowsInjectedWidth() {
        // A 1000pt-wide display makes the delta-over-span
        // arithmetic exact: 100pt of a 1000pt span is 0.1 of the
        // ratio, whatever the host measures.
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 900)
        )
        core.state.apply(.windowFocused(WindowID(1)))
        let before = ratioH(core)
        core.execute("resize", args: [.string("x"), .number(100)])
        #expect(abs((ratioH(core) - before) - 0.1) < 1e-9)
    }

    @Test("The BSP resize sign reads the injected bounds")
    func bspFocusSignFollowsInjectedBounds() {
        // `bspFocusSign` classifies the focused slot as the first
        // or second region via `BspSplit.side`, which is
        // `slot.midX <= bounds.midX ? 1 : -1`. Growing the right
        // window must lower the shared ratio (#122).
        //
        // The rect sits at a NEGATIVE origin on purpose. A revert
        // to the host's screen leaves the slot where the injected
        // rect put it and only changes the `bounds` it is compared
        // against — so with a rect at x: 0 the classification
        // survives on any host narrower than ~1500pt, including
        // the ~1066pt runner of #523: the guard would have been
        // green on CI and red only on a wide dev Mac, reproducing
        // the very anti-pattern it exists to catch (review). Here
        // the right slot's midX is −4250 against the injected
        // −4500 (second region), while EVERY real display has
        // midX ≥ 0 (first region), so a revert goes red anywhere.
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(
                x: -5000,
                y: 0,
                width: 1000,
                height: 900
            )
        )
        core.state.apply(.windowFocused(WindowID(2)))
        let before = ratioH(core)
        core.execute("resize", args: [.string("x"), .number(100)])
        #expect(abs((before - ratioH(core)) - 0.1) < 1e-9)
    }

    @Test("A finished mouse resize reads the injected bounds")
    func mouseResizeEndFollowsInjectedBounds() {
        // `handleResizeEnd` translates the dragged frame into a
        // ratio delta against the display bounds, so the stored
        // ratio is delta-over-span for the INJECTED span: dragging
        // the left window's right edge 100pt wider on a 1000pt
        // display is +0.1, whatever the host measures.
        //
        // Called directly because that IS the drop entry point
        // (`KiwiCore+Drag` calls this signature); the pipeline
        // ahead of it is not what this pins.
        guard NSScreen.main != nil else { return }
        let core = makeCore(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 900)
        )
        guard let space = core.state.workspaces[SpaceID("1")],
            let slot = core.tiler.calculatedFrames(
                state: core.state
            )[WindowID(1)]
        else {
            Issue.record("no slot for the left window")
            return
        }
        let before = ratioH(core)
        var dragged = slot
        dragged.size.width += 100
        core.handleResizeEnd(
            WindowID(1),
            slot: slot,
            frame: dragged,
            in: space
        )
        #expect(abs((ratioH(core) - before) - 0.1) < 1e-9)
    }
}
