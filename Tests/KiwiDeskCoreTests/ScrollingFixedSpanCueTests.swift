import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #1055 repro C, closed by Lane B: a fixed-width app (System
/// Settings, 825 pt) refuses shrinks below its span, and the
/// shrink cue used to stay silent for a ~10-press walk —
/// shrink asks from ABOVE the span produce ceiling entries,
/// so the floor never corroborated until the slot had silently
/// descended below the span and refused twice more. The
/// fixed-span lend (`EffectiveSizeBound.floor(of:)`) closes
/// it: a corroborated ceiling corroborates the single floor
/// entry at the same span, `effectiveMinSize` rises, and the
/// write-site clamp cues the first truncated shrink.
///
/// Screen trait for the sibling suites' reason:
/// `resizeScrollingSlot` falls back to a 1920x1080 rect when
/// no screen resolves — a SKIP says that; a green would not.
@Suite(
    "Scrolling fixed-span shrink cue (#1055)",
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ScrollingFixedSpanCueTests {
    @Test("The shrink below a fixed span clamps and cues")
    func shrinkBelowTheFixedSpanCues() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-fixed-span-\(UUID().uuidString)"
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
        #expect(core.tiler.settings.minWindowSize == 300)

        // The device shape: grow-side asks (above the span)
        // teach the corroborated ceiling; ONE shrink-side ask
        // below the span answers the same 825 — the fixed-span
        // signature.
        for asked in [CGFloat(900), 1000, 800] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 825, height: 800),
                    settledRead: true
                )
            }
        }
        core.execute(
            "scroll.set_slot_size",
            args: [.number(780)]
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(-50)]
        )
        // The lent floor binds: the slot clamps AT the span
        // and the refusal says so — the first press, not the
        // tenth.
        #expect(refusals == [.ownMinimum(WindowID(1))])
        let live = try #require(core.state.workspaces[space])
        let stored = core.tiler.settings
            .resolvedScrolling(for: live)
            .slotSize
            .editablePoints(along: 1200, horizontal: true)
        #expect(stored == 825)
    }
}
