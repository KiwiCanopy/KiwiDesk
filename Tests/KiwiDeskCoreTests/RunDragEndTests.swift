import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A mouse drag of a run's outer edge from the drop itself (#2970):
/// `handleDragEnd`'s filter runs ahead of `handleResizeEnd`, where
/// the other run drag suites start. A lone window's shrink pulls the
/// next one back, a shrink beside a shown mate widens it, and a grow
/// snaps back without a cue. Stack and Track here,
/// `RunDragEndChainTests` the BSP chain and the Grid.
/// The display, gaps and floor are pinned (#531, #660);
/// `.enabled(if:)` because the writers resolve the Space's screen.
@Suite(
    "Run drag end (#2970)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunDragEndTests {
    /// `count` windows in one `mode` Space on a 1220 × 820 display
    /// with 10-pt gaps and every bar off, `focus` focused; `height`
    /// under two floors leaves a lone window nothing that fits.
    private func makeSpace(
        _ mode: String,
        windows count: UInt32,
        focus: UInt32,
        height: CGFloat = 820,
        setup: (KiwiCore) -> Void = { _ in }
    ) -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-drag-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1220, height: height)
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

    /// A Track Space with the tracks [1] [2, 3].
    private func trackSpace() -> (KiwiCore, SpaceID) {
        let (core, id) = makeSpace("track", windows: 3, focus: 2) {
            $0.execute("track.set_new_window", args: [.string("own_track")])
        }
        core.state.workspaces.withSpace(id) {
            $0.trackBreaks = [w(1), w(2)]
        }
        core.retile(animated: false)
        return (core, id)
    }

    private func w(_ raw: UInt32) -> WindowID { WindowID(raw) }

    private func frame(_ core: KiwiCore, _ id: WindowID) throws -> CGRect {
        try #require(core.tiler.calculatedFrames(state: core.state)[id])
    }

    private func hidden(_ core: KiwiCore, _ id: SpaceID) -> Set<WindowID> {
        Set(core.tiler.runCovers[id]?.behind.keys.map { $0 } ?? [])
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

    private func press(_ core: KiwiCore, _ axis: String, _ points: Double) {
        core.execute("resize", args: [.string(axis), .number(points)])
        core.retile(animated: false)
    }

    @Test(
        "Stack: a lone window's outer shrink pulls the next one back",
        arguments: [true, false]
    )
    func stackLonePulls(leading: Bool) throws {
        let (core, id) = makeSpace("stack", windows: 3, focus: 2)
        press(core, "y", 300)
        #expect(hidden(core, id) == [w(3)])
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        try drop(core, w(2), vertical: true, leading: leading, by: 20)
        #expect(hidden(core, id).isEmpty)
        #expect(abs(try frame(core, w(3)).height - 300) < 1)
        #expect(refusals.isEmpty)
    }

    @Test("Stack: a next window that cannot fit refuses, as the key does")
    func stackUnfitNextRefuses() throws {
        // Two 300-pt floors and a gap overflow the 600-pt zone, so w2
        // shows alone with w3 waiting.
        let (core, id) = makeSpace("stack", windows: 3, focus: 2, height: 620)
        #expect(hidden(core, id) == [w(3)])
        let slot = try frame(core, w(2))
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        try drop(core, w(2), vertical: true, leading: false, by: 20)
        #expect(hidden(core, id) == [w(3)])
        #expect(try frame(core, w(2)) == slot)
        #expect(refusals.count == 1)
    }

    @Test("Stack: a zone of one with none waiting snaps back and cues nothing")
    func stackZoneOfOneSnapsBack() throws {
        // A master zone lying along y, so y is the zone's own line.
        let (core, id) = makeSpace("stack", windows: 3, focus: 1) {
            $0.execute(
                "stack.set_master_orientation",
                args: [.string("vertical")]
            )
        }
        let first = try #require(core.state.workspaces[id]?.windows.first)
        let slot = try frame(core, first)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        try drop(core, first, vertical: true, leading: true, by: 60)
        #expect(try frame(core, first) == slot)
        #expect(refusals.isEmpty)
    }

    @Test("Stack: the drop lands what the keyboard's shrink lands")
    func stackDropMatchesTheKeyboard() throws {
        let (dragged, id) = makeSpace("stack", windows: 3, focus: 2)
        let (pressed, _) = makeSpace("stack", windows: 3, focus: 2)
        for core in [dragged, pressed] { press(core, "y", 300) }
        try drop(dragged, w(2), vertical: true, leading: false, by: 20)
        press(pressed, "y", -20)
        #expect(hidden(dragged, id).isEmpty)
        for raw in UInt32(1)...3 {
            #expect(
                try frame(dragged, w(raw)) == frame(pressed, w(raw))
            )
        }
    }

    @Test("Stack: an outer shrink beside a shown mate widens the mate")
    func stackMateWidens() throws {
        let (core, id) = makeSpace("stack", windows: 3, focus: 2)
        #expect(hidden(core, id).isEmpty)
        let window = try frame(core, w(2))
        let mate = try frame(core, w(3))
        try drop(core, w(2), vertical: true, leading: true, by: 60)
        #expect(try frame(core, w(2)).height < window.height - 30)
        #expect(try frame(core, w(3)).height > mate.height + 30)
        #expect(abs(try frame(core, w(2)).minY - window.minY) < 1)
    }

    @Test("Stack: an outer grow snaps back and cues nothing")
    func stackGrowSnapsBack() throws {
        let (core, id) = makeSpace("stack", windows: 3, focus: 2)
        press(core, "y", 300)
        let before = core.state.workspaces[id]?.runSizes
        let slot = try frame(core, w(2))
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        try drop(core, w(2), vertical: true, leading: false, by: -60)
        #expect(try frame(core, w(2)) == slot)
        #expect(hidden(core, id) == [w(3)])
        #expect(core.state.workspaces[id]?.runSizes == before)
        #expect(refusals.isEmpty)
    }

    @Test("Stack: a master zone along the split keeps its snap back")
    func stackZoneAlongTheSplitSnapsBack() throws {
        let (core, id) = makeSpace("stack", windows: 3, focus: 1) {
            $0.execute("stack.set_master_count", args: [.number(2)])
            $0.execute(
                "stack.set_master_orientation",
                args: [.string("horizontal")]
            )
        }
        let space = try #require(core.state.workspaces[id])
        let ratio = core.tiler.settings.resolvedStack(
            for: space,
            session: core.sessionRatios(of: id),
            flip: core.stackFlip(of: id)
        ).masterRatio
        let first = try #require(space.windows.first)
        let slot = try frame(core, first)
        try drop(core, first, vertical: false, leading: true, by: 60)
        #expect(try frame(core, first) == slot)
        #expect(
            core.tiler.settings.resolvedStack(
                for: try #require(core.state.workspaces[id]),
                session: core.sessionRatios(of: id),
                flip: core.stackFlip(of: id)
            ).masterRatio == ratio
        )
    }

    @Test("Track: a lone window's outer shrink pulls the next one back")
    func trackLonePulls() throws {
        let (core, id) = trackSpace()
        let vertical =
            core.tiler.settings.resolvedTrack(for: id).axis == .vertical
        press(core, vertical ? "y" : "x", 400)
        #expect(hidden(core, id) == [w(3)])
        try drop(core, w(2), vertical: vertical, leading: false, by: 20)
        #expect(hidden(core, id).isEmpty)
    }

    @Test("Track: an outer shrink beside a shown mate widens the mate")
    func trackMateWidens() throws {
        let (core, id) = trackSpace()
        let vertical =
            core.tiler.settings.resolvedTrack(for: id).axis == .vertical
        let mate = try frame(core, w(3))
        try drop(core, w(2), vertical: vertical, leading: true, by: 60)
        let after = try frame(core, w(3))
        #expect(
            (vertical ? after.height - mate.height : after.width - mate.width)
                > 50
        )
        #expect(hidden(core, id).isEmpty)
    }

    @Test("Track: across the tracks an outer shrink still snaps back")
    func trackAcrossSnapsBack() throws {
        let (core, id) = trackSpace()
        let vertical =
            core.tiler.settings.resolvedTrack(for: id).axis == .vertical
        let slot = try frame(core, w(1))
        try drop(core, w(1), vertical: !vertical, leading: true, by: 60)
        #expect(try frame(core, w(1)) == slot)
        #expect(core.state.workspaces[id]?.trackWeights.isEmpty == true)
    }
}
