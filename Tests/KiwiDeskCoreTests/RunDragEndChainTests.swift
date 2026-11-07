import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A mouse drag of an outer edge along a BSP chain or a Grid's last
/// track, from the drop itself (#2970): `RunDragEndTests`' answers
/// on the two layouts whose run a press reaches by its own door. The
/// display, gaps and floor are pinned (#531, #660); `.enabled(if:)`
/// because the writers resolve the Space's screen.
@Suite(
    "Run drag end, chain and grid (#2970)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunDragEndChainTests {
    /// `count` windows in one `mode` Space on a 1220 × 820 display
    /// with 10-pt gaps and every bar off, `focus` focused.
    private func makeSpace(
        _ mode: String,
        windows count: UInt32,
        focus: UInt32,
        setup: (KiwiCore) -> Void = { _ in }
    ) -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-chain-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1220, height: 820)
        }
        core.tiler.settings.gapsGlobal = Gaps.uniform(10)
        for verb in [
            "space_bar.set_visibility",
            "monocle.set_app_bar_visibility",
            "scroll.set_app_bar_visibility",
        ] {
            core.execute(verb, args: [.string("hidden")])
        }
        #expect(!core.tiler.settings.anyAppBarCanShow)
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.tiler.animation.isEnabled = false
        core.tiler.settings.mouseResize = .layout
        // Over no slot, so the drop reads no swap target (#492).
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(CGPoint(x: -9000, y: -9000))
        }
        setup(core)
        for id in UInt32(1)...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(900_000 + Int32(id)),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute("set_mode", args: [.string(space.raw), .string(mode)])
        core.state.workspaces.focus(WindowID(focus), in: space)
        core.retile(animated: false)
        return (core, space)
    }

    /// A rigid 3 × 2 Grid of nine windows, its last row running.
    private func gridSpace(autoSize: Bool) -> (KiwiCore, SpaceID) {
        makeSpace("grid", windows: 9, focus: 5) {
            $0.execute("grid.set_type", args: [.string("rigid")])
            $0.execute(
                "grid.set_dimensions",
                args: [.number(3), .number(2)]
            )
            $0.execute("grid.set_auto_size", args: [.bool(autoSize)])
        }
    }

    private func w(_ raw: UInt32) -> WindowID { WindowID(raw) }

    private func frame(_ core: KiwiCore, _ id: WindowID) throws -> CGRect {
        try #require(core.tiler.calculatedFrames(state: core.state)[id])
    }

    private func run(
        _ core: KiwiCore,
        _ id: SpaceID
    ) throws -> RunCover.Run {
        try #require(core.tiler.runCovers[id]?.runs.first)
    }

    /// `slot` with its `edge` moved `points` inward along the axis;
    /// a negative `points` moves it outward.
    private func inward(
        _ slot: CGRect,
        vertical: Bool,
        leading: Bool,
        by points: CGFloat
    ) -> CGRect {
        var result = slot
        if vertical {
            if leading { result.origin.y += points }
            result.size.height -= points
        } else {
            if leading { result.origin.x += points }
            result.size.width -= points
        }
        return result
    }

    /// Drops `id` at `slot`'s `edge` moved `points` inward.
    private func drop(
        _ core: KiwiCore,
        _ id: WindowID,
        vertical: Bool,
        leading: Bool,
        by points: CGFloat
    ) throws {
        let slot = try frame(core, id)
        core.handleDragEnd(
            id,
            start: slot,
            frame: inward(
                slot,
                vertical: vertical,
                leading: leading,
                by: points
            )
        )
        core.retile(animated: false)
    }

    /// Pushes along `axis` until the run shows one window, `focus`.
    private func pushToLone(
        _ core: KiwiCore,
        _ id: SpaceID,
        axis: String,
        focus: WindowID
    ) throws {
        core.state.workspaces.focus(focus, in: id)
        core.retile(animated: false)
        for _ in 0..<6 where try run(core, id).shown.count > 1 {
            _ = core.resizeInRunForTest(focus, axis: axis, in: id)
            core.retile(animated: false)
        }
        #expect(try run(core, id).shown == [focus])
    }

    /// A BSP Space whose chain runs along y, its first shown window
    /// focused.
    private func bspSpace() throws -> (KiwiCore, SpaceID, WindowID) {
        let (core, id) = makeSpace("bsp", windows: 4, focus: 2) {
            $0.execute("bsp.set_strategy", args: [.string("alternating")])
        }
        let chain = try run(core, id)
        #expect(chain.zone.vertical)
        #expect(chain.shown.count >= 2)
        return (core, id, try #require(chain.shown.first))
    }

    @Test("BSP: a lone chain window's outer shrink pulls the next one back")
    func bspLonePulls() throws {
        let (core, id, focus) = try bspSpace()
        try pushToLone(core, id, axis: "y", focus: focus)
        try drop(core, focus, vertical: true, leading: false, by: 20)
        #expect(try run(core, id).shown.count == 2)
    }

    @Test("BSP: an outer shrink beside a shown mate widens the mate")
    func bspMateWidens() throws {
        let (core, id, focus) = try bspSpace()
        let chain = try run(core, id)
        let mate = try #require(chain.shown.dropFirst().first)
        let before = try frame(core, mate).height
        try drop(core, focus, vertical: true, leading: true, by: 60)
        #expect(try frame(core, mate).height > before + 30)
    }

    @Test("Auto-sized Grid: a lone window's outer shrink pulls one back")
    func gridLonePulls() throws {
        let (core, id) = gridSpace(autoSize: true)
        try pushToLone(core, id, axis: "x", focus: w(5))
        try drop(core, w(5), vertical: false, leading: false, by: 20)
        #expect(try run(core, id).shown.count == 2)
    }

    @Test("Auto-sized Grid: an outer shrink widens a shown mate")
    func gridMateWidens() throws {
        let (core, id) = gridSpace(autoSize: true)
        let shown = try run(core, id).shown
        let first = try #require(shown.first)
        let mate = try #require(shown.dropFirst().first)
        let before = try frame(core, mate).width
        try drop(core, first, vertical: false, leading: true, by: 60)
        #expect(try frame(core, mate).width > before + 20)
    }

    @Test("Fixed Grid: a last row's outer shrink keeps its snap back")
    func fixedGridSnapsBack() throws {
        let (core, id) = gridSpace(autoSize: false)
        let first = try #require(try run(core, id).shown.first)
        let slot = try frame(core, first)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        try drop(core, first, vertical: false, leading: true, by: 60)
        #expect(try frame(core, first) == slot)
        expectEqual(core.state.workspaces[id]?.runSizes.isEmpty, true)
        #expect(refusals.isEmpty)
    }
}

extension KiwiCore {
    /// One large grow of `window` through the run writer the mouse
    /// reaches, with no hold in flight.
    fileprivate func resizeInRunForTest(
        _ window: WindowID,
        axis: String,
        in id: SpaceID
    ) -> CommandResponse? {
        guard let space = state.workspaces[id] else { return nil }
        return resizeInRun(
            window,
            axis: axis,
            delta: 400,
            toward: .both,
            space: space,
            otherAxisDivides: true
        )
    }
}
