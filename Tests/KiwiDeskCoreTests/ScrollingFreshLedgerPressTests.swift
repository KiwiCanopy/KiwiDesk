import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The scrolling press measures from the drawn span even on a
/// FRESH ledger (#1063). Split from `ScrollingAppCeilingTests`
/// at the file ceiling, under the same screen trait for the
/// same reason: `resizeScrollingSlot` falls back to a 1920x1080
/// rect when no screen resolves, so headless this would assert
/// against a viewport the fixture never pinned — a SKIP says
/// that; a green would not.
///
/// The shape this suite pins: a relaunch loses the size-bound
/// ledger, the boot dance re-confirms ONE per-ask entry at the
/// LAYOUT's own ask span, and nothing is corroborated yet. The
/// writer's first #1057 shape reconstructed the drawn span from
/// the store's consume, which asked the ladder at the raw-axis
/// auto seed — a span no layout ever issued — so the base fell
/// back to the ~full-axis store and one shrink ballooned the
/// slot the whole row shares around a window that never moved.
@Suite(
    "Scrolling fresh-ledger press base (#1063)",
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ScrollingFreshLedgerPressTests {
    /// A scrolling space on a pinned 1200pt-wide display
    /// (#531), focused on the first of two windows — the
    /// sibling suites' fixture.
    private func makeCore() -> (core: KiwiCore, space: SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-fresh-ledger-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        // Pin the default the exact expectations reason from
        // (#660): the `== 665` assertion holds only while the
        // global floor sits below it.
        #expect(core.tiler.settings.minWindowSize == 300)
        return (core, space)
    }

    private func slotPoints(
        _ core: KiwiCore,
        _ space: SpaceID
    ) throws -> CGFloat {
        let live = try #require(core.state.workspaces[space])
        return core.tiler.settings.resolvedScrolling(for: live)
            .slotSize
            .editablePoints(along: 1200, horizontal: true)
    }

    @Test(
        "A fresh uncorroborated ledger measures from the drawn span"
    )
    func freshLedgerMeasuresFromTheDrawnSpan() throws {
        let (core, space) = makeCore()
        // The layout's own ask for the default auto store,
        // derived exactly as `ScrollingLayout.metrics` derives
        // it, so the taught entry sits where the boot dance
        // would put it.
        let input = try #require(
            core.tiler.layoutInput(state: core.state)
        )
        let context = input.context
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let ask = min(
            area.width,
            max(
                context.scrolling.slotSize.resolved(
                    along: area.width,
                    horizontal: true
                ),
                context.minWindowSize
            )
        )
        // The premise the regression rests on, derived rather
        // than assumed: the raw-axis seed the old
        // reconstruction consulted the ladder at is NOT the
        // layout's ask, past the match tolerance — the two
        // resolutions diverge by the outer-gap carve.
        let seed = context.scrolling.slotSize.editablePoints(
            along: 1200,
            horizontal: true
        )
        #expect(
            abs(seed - ask) > EffectiveSizeBound.matchTolerance
        )
        // ONE ask span, observed twice: confirmed, and
        // deliberately NOT corroborated — corroboration needs
        // two distinct spans, and a fresh boot issues one.
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(
                WindowID(1),
                size: CGSize(width: ask, height: 800)
            )
            core.tiler.boundLearner.observe(
                WindowID(1),
                currentSize: CGSize(width: 715, height: 800),
                settledRead: true
            )
        }
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(-50)]
        )
        // Measured from the 715pt the window renders — never
        // from the auto seed, which is the balloon. Silent:
        // nothing corroborated pins a minimum yet.
        #expect(try slotPoints(core, space) == 665)
        #expect(refusals.isEmpty)
    }
}
