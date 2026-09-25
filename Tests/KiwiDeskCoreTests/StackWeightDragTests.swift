import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The stack cross-axis mouse drag (#941): a `.stackWeight`
/// adjustment reaches the dragged window's zone share through
/// the one `resizeStackMember` the keyboard `resize` verb also
/// takes — the same #67 step, the same #933 clamps — so the
/// drag no longer snaps back. The zone verdicts stay the
/// writer's: a master zone lined up along the split refuses, a
/// window that is no member of the Space is never written.
@Suite("Stack cross-axis mouse drag (#941)", .serialized)
@MainActor
struct StackWeightDragTests {
    private static let display = CGRect(
        x: 0,
        y: 0,
        width: 1920,
        height: 1080
    )

    private let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in Self.display }
        // Every bar off: the shelf reserves in every layout while
        // any can show (#1517), App Bars included.
        core.tiler.settings.spaceBarStyle.enabled = false
        core.tiler.settings.monocle.appBar.enabled = false
        core.tiler.settings.scrolling.appBar.enabled = false
        #expect(core.tiler.settings.minWindowSize == 300)
        return core
    }

    /// Stack Space "1" with three windows. `.first` placement
    /// makes the LAST created window the master, so the array
    /// is [3, 2, 1]: w3 master, w2/w1 the stack column.
    private func stackSpace(_ core: KiwiCore) -> Space {
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        for index in 1...3 {
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
        let space = core.state.workspaces[SpaceID("1")]!
        #expect(space.windows == [WindowID(3), WindowID(2), WindowID(1)])
        return space
    }

    private func weight(_ core: KiwiCore, _ id: UInt32) -> Double? {
        core.state.workspaces[SpaceID("1")]?.stackWeights[WindowID(id)]
    }

    @Test("A height drag grows the dragged window's share")
    func heightDragGrowsTheShare() {
        let core = makeCore()
        let space = stackSpace(core)
        // The stack column is [2, 1]; drag w2 taller by 100 pt.
        // The drop hands the DRAGGED window, not the focus —
        // w3 is the focus here.
        #expect(space.focused == WindowID(3))
        core.applyResizeAdjustment(
            .stackWeight(100),
            for: WindowID(2),
            in: space,
            bounds: bounds
        )
        #expect((weight(core, 2) ?? 1) > 1)
        #expect(weight(core, 1) == nil)
        #expect(weight(core, 3) == nil)
    }

    @Test("A shrink drag lowers the share")
    func shrinkDragLowersTheShare() {
        let core = makeCore()
        let space = stackSpace(core)
        core.applyResizeAdjustment(
            .stackWeight(-100),
            for: WindowID(2),
            in: space,
            bounds: bounds
        )
        #expect((weight(core, 2) ?? 1) < 1)
    }

    /// The drop's write is the keyboard verb's write: the same
    /// delta through `resize("y")` on the same window lands the
    /// same weight.
    @Test("The drag and the keyboard verb write the same weight")
    func dragMatchesTheKeyboardVerb() {
        let dragged = makeCore()
        let space = stackSpace(dragged)
        dragged.applyResizeAdjustment(
            .stackWeight(150),
            for: WindowID(2),
            in: space,
            bounds: bounds
        )
        let typed = makeCore()
        _ = stackSpace(typed)
        typed.state.apply(.windowFocused(WindowID(2)))
        let response = typed.execute(
            "resize",
            args: [.string("y"), .number(150)]
        )
        #expect(response.isSuccess)
        let fromDrag = weight(dragged, 2)
        let fromKey = weight(typed, 2)
        #expect(fromDrag != nil)
        #expect(fromDrag == fromKey)
    }

    /// A vertical split (stack on top or bottom) divides its
    /// zones on x, so the cross-axis drag is a width drag and
    /// the span is the bounds' width.
    @Test("A vertical split takes the width drag")
    func verticalSplitTakesWidth() {
        let core = makeCore()
        _ = stackSpace(core)
        core.execute(
            "stack.set_position",
            args: [.string("bottom")]
        )
        let space = core.state.workspaces[SpaceID("1")]!
        core.applyResizeAdjustment(
            .stackWeight(100),
            for: WindowID(2),
            in: space,
            bounds: bounds
        )
        #expect((weight(core, 2) ?? 1) > 1)
    }

    /// A master zone lined up ALONG the split — side-by-side
    /// masters beside a right stack — has no cross-axis
    /// parameter: the writer refuses, and nothing is written
    /// (the accepted-limitations row on masters' shares).
    @Test("A master along the split refuses the cross-axis drag")
    func masterAlongTheSplitRefuses() {
        let core = makeCore()
        _ = stackSpace(core)
        core.execute(
            "stack.set_master_count",
            args: [.number(2)]
        )
        core.execute(
            "stack.set_master_orientation",
            args: [.string("horizontal")]
        )
        let space = core.state.workspaces[SpaceID("1")]!
        // Windows are [3, 2, 1]: w3+w2 master side by side.
        let response = core.resizeStackMember(
            WindowID(3),
            axis: "y",
            delta: 100,
            span: Double(bounds.height),
            space: space
        )
        #expect(!response.isSuccess)
        #expect(weight(core, 3) == nil)
        core.applyResizeAdjustment(
            .stackWeight(100),
            for: WindowID(3),
            in: space,
            bounds: bounds
        )
        #expect(weight(core, 3) == nil)
    }

    /// The share write keys per-window state by id, so a
    /// tiled-sticky traveler (#414 v2) — in the tiled list the
    /// drop reads, not in `space.windows` — is refused rather
    /// than orphaning an entry (#308). The drop can hand one;
    /// the keyboard's `space.focused` cannot.
    @Test("A traveler is refused, not written")
    func travelerIsNotWritten() {
        let core = makeCore()
        let space = stackSpace(core)
        core.state.workspaces.ensureSpace(SpaceID("2"))
        // Two home-mates ahead of the traveler, so it is injected
        // past the master slot: at index 0 it would be the lone
        // master and the AXIS clause would refuse it first
        // (guard-prover, 2026-09-22).
        for id: UInt32 in 60...61 {
            core.state.windows.upsert(
                ManagedWindow(id: WindowID(id), pid: 3, appName: "H")
            )
            core.state.workspaces.add(WindowID(id), to: SpaceID("2"))
        }
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(50),
                pid: 2,
                appName: "Traveler",
                stickyScope: .global
            )
        )
        core.state.workspaces.add(WindowID(50), to: SpaceID("2"))
        // The traveler shape: injected into "1"'s tiled list in
        // the stack column, absent from its members — the column
        // lookup finds it and only the membership guard refuses.
        let tiled = core.state.effectiveTiledMembers(of: space)
        #expect((tiled.firstIndex(of: WindowID(50)) ?? 0) >= 1)
        #expect(!space.windows.contains(WindowID(50)))
        let response = core.resizeStackMember(
            WindowID(50),
            axis: "y",
            delta: 100,
            span: Double(bounds.height),
            space: space
        )
        #expect(
            response.error
                == "the focused window is visiting from another Space"
        )
        #expect(weight(core, 50) == nil)
        let home = core.state.workspaces[SpaceID("2")]?.stackWeights
        #expect(home?[WindowID(50)] == nil)
    }

    /// The drop end to end: `handleResizeEnd` classifies the
    /// gesture against the Space's own split and hands the
    /// dragged window through — the join this change wires.
    /// Needs a screen for the layout bounds, as the track twin
    /// does.
    @Test("A height drag on the drop end lands the share")
    func dropEndLandsTheShare() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        let space = stackSpace(core)
        let slot = CGRect(x: 1000, y: 25, width: 900, height: 500)
        let dragged = CGRect(x: 1000, y: 25, width: 900, height: 620)
        core.handleResizeEnd(
            WindowID(2),
            slot: slot,
            frame: dragged,
            in: space
        )
        #expect((weight(core, 2) ?? 1) > 1)
        #expect(weight(core, 3) == nil)
    }

    /// The drop without a window identity writes nothing — nil
    /// is the explicit "no window at this site" answer.
    @Test("No window identity writes nothing")
    func noIdentityWritesNothing() {
        let core = makeCore()
        let space = stackSpace(core)
        core.applyResizeAdjustment(
            .stackWeight(100),
            for: nil,
            in: space,
            bounds: bounds
        )
        let weights = core.state.workspaces[SpaceID("1")]?.stackWeights
        #expect(weights?.isEmpty == true)
    }
}
