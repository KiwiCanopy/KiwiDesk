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
    @Test("An explicit apply re-asks past a corroborated bound")
    func explicitApplyProbesPastTheBound() throws {
        // The production wiring of the owner-ruled heal
        // (2026-08-28): `scroll.set_slot_size` forces the
        // retile, the forced pass sets the pass-scoped flag,
        // and the layout ISSUES the new value — the ladder
        // records the real ask, not the bound. Without this
        // wiring the pure-layout probe test stays green while
        // the flag never connects.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-probe-wiring-\(UUID().uuidString)"
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
        for asked in [CGFloat(800), 900] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 715, height: 800),
                    settledRead: true
                )
            }
        }
        core.execute(
            "scroll.set_slot_size",
            args: [.number(1000)]
        )
        let asked = core.tiler.boundLearner
            .lastAsks[WindowID(1)]?.size.width
        #expect(asked == 1000)
    }

    @Test("A refused shrink never raises the shared slot")
    func refusedShrinkNeverRaisesTheSlot() throws {
        // The device shape (owner, 2026-08-28): the row was
        // shrunk to 300 BEFORE the focused window's floor
        // armed. A shrink press then hit
        // `max(requested, effectiveMin)` and snapped the
        // shared store UP to the floor — every neighbor popped
        // to the focused window's minimum on a SHRINK press,
        // and the row jump moved the frame the pill had just
        // anchored on. The floor is now capped at the current
        // size: refuse where the store stands, cue, move
        // nothing.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-never-raise-\(UUID().uuidString)"
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
        // Fixed span at 825, corroborated both ways (the lend).
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
            args: [.number(300)]
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(-50)]
        )
        let live = try #require(core.state.workspaces[space])
        let stored = core.tiler.settings
            .resolvedScrolling(for: live)
            .slotSize
            .editablePoints(along: 1200, horizontal: true)
        #expect(stored == 300)
        #expect(refusals == [.ownMinimum(WindowID(1))])
    }

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
        // Seeded ABOVE the span: the press shrinks INTO the
        // floor and clamps AT it. (A store already below the
        // span refuses where it stands instead — the
        // never-raise mirror, pinned by
        // `refusedShrinkNeverRaisesTheSlot`.)
        core.execute(
            "scroll.set_slot_size",
            args: [.number(850)]
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
