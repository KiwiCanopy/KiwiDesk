import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// A scrolling fraction is a share of the PITCH — window plus one
/// inner gap (#1382): `slot = f·(along + gap) − gap`, so n slots of
/// 1/n tile the axis exactly at any gap on any screen, and "50%"
/// is two windows side by side, gaps included. The press base
/// (`editablePoints`) is the same drawn slot.
@Suite("Scrolling pitch fraction (#1382)")
struct ScrollingPitchTests {
    /// The WRITER's press base at its call site (the type is
    /// pinned below; this is the wiring): a grow from a `%`
    /// store lands the drawn slot plus the delta. At a 37 pt gap
    /// a bare-axis base sits 18.5 pt above the drawn slot, so a
    /// `gap: 0` in `writeCappedScrollSlot` — or a base read off
    /// the region while the layout draws the pitch — lands the
    /// wrong number by a margin no tolerance hides. Requires a
    /// screen like every writer suite (`ScrollingSlotCeilingTests`).
    @Test(
        "the writer's grow lands the drawn slot plus the delta",
        .enabled(if: NSScreen.main != nil)
    )
    @MainActor func writerGrowLandsTheDrawnSlot() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-pitch-writer-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        // Outer gaps at zero so the region the writer seeds from
        // IS the carve the layout draws into — the #537 residue is
        // not this guard's subject, the inner-gap term is.
        let gaps = Gaps(
            outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
            inner: Gaps.Inner(horizontal: 37, vertical: 37)
        )
        // And no bar strip on the x axis (#660): both bars off,
        // so the carve is the region on the axis measured.
        core.tiler.settings.scrolling.appBar.enabled = false
        core.tiler.settings.spaceBarStyle.enabled = false
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
        // The gap is the SPACE's, set as an override over a
        // different global, so a writer reading the global gap
        // lands wrong too.
        core.tiler.settings.gapsGlobal = Gaps(
            outer: gaps.outer,
            inner: Gaps.Inner(horizontal: 10, vertical: 10)
        )
        core.tiler.settings.gapsOverride[space] = gaps
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.execute("scroll.set_slot_size", args: [.string("50%")])
        core.state.workspaces.focus(WindowID(1), in: space)
        let input = try #require(core.tiler.layoutInput(state: core.state))
        let drawn = try #require(
            ScrollingLayout().calculateGeometry(
                for: input.tiled,
                in: input.context
            )[WindowID(1)]
        ).width
        core.execute("resize", args: [.string("x"), .number(60)])
        let live = try #require(core.state.workspaces[space])
        guard
            case .points(let written) = core.tiler.settings
                .resolvedScrolling(for: live).slotSize
        else {
            Issue.record("the grow did not write points")
            return
        }
        #expect(abs(written - (drawn + 60)) < 0.5)
    }

    private func context(
        fraction: Double,
        gap: CGFloat,
        focused: WindowID = w1
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(gap),
            focused: focused
        )
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .fraction(fraction)
        return context
    }

    @Test("1/n tiles n columns exactly, gaps included")
    func nthTilesExactly() throws {
        for (n, windows) in [(2, [w1, w2]), (3, [w1, w2, w3])] {
            for gap: CGFloat in [0, 10, 37] {
                let context = context(fraction: 1 / Double(n), gap: gap)
                let frames = ScrollingLayout().calculateGeometry(
                    for: windows,
                    in: context
                )
                let first = try #require(frames[windows.first!])
                let last = try #require(frames[windows.last!])
                #expect(abs(first.minX - context.usable.minX) < 0.01)
                #expect(abs(last.maxX - context.usable.maxX) < 0.01)
                // Each slot is the pitch share less the gap.
                let along = context.usable.width
                let expected = (along + gap) / CGFloat(n) - gap
                #expect(abs(first.width - expected) < 0.01)
            }
        }
    }

    @Test("100% is still the whole axis, and points ignore the gap")
    func edges() {
        #expect(
            ScrollSize.fraction(1)
                .resolved(along: 1000, gap: 40, horizontal: true)
                == 1000
        )
        #expect(
            ScrollSize.points(640)
                .resolved(along: 1000, gap: 40, horizontal: true)
                == 640
        )
    }

    @Test("The press base is the drawn slot")
    func pressBaseIsDrawn() throws {
        let context = context(fraction: 0.5, gap: 10)
        let drawn = try #require(
            ScrollingLayout().calculateGeometry(
                for: [w1, w2],
                in: context
            )[w1]
        )
        let base = context.scrolling.slotSize.editablePoints(
            along: context.usable.width,
            gap: 10,
            horizontal: true
        )
        #expect(abs(base - drawn.width) < 0.01)
    }
}
