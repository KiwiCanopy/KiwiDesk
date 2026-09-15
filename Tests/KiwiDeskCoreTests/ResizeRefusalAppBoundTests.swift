import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Which term of a window's effective minimum a refusal names
/// (#1261): the configured `min_window_size`, or the learned
/// app floor above it. The verdict is derived once in
/// `KiwiCore.minimumIsAppBound` and read at the seam through
/// the case's `appBound`, so these tests build the fixture
/// where the two terms DISAGREE and assert the flag — the
/// config-floor twins live in `ResizeNeighborLimitTests`,
/// `ResizeRefusalTargetingTests` and `SplitFloorCueTests`,
/// which stamp the flag their fixtures earn.
///
/// Display and `min_window_size` pinned (#531, #660).
@Suite("Resize refusal names the app's floor (#1261)", .serialized)
@MainActor
struct ResizeRefusalAppBoundTests {
    private func makeCore(mode: String) -> (KiwiCore, SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-app-bound-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    /// A corroborated `minWidth` floor (#677): two distinct asks,
    /// each refused twice with the same answer.
    private func seed(
        _ core: KiwiCore,
        window: WindowID,
        minWidth: CGFloat
    ) {
        for asked in [minWidth - 60, minWidth - 110] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    window,
                    size: CGSize(width: asked, height: 385)
                )
                core.tiler.boundLearner.observe(
                    window,
                    currentSize: CGSize(width: minWidth, height: 385),
                    settledRead: true
                )
            }
        }
    }

    @Test("A shrink stopped by the window's OWN app floor says so")
    func ownAppFloorIsNamed() {
        // The master carries a 500 pt learned floor above the
        // 300 pt setting; a shrink past it stops at the APP's
        // limit, and lowering `min_window_size` would not help.
        let (core, _) = makeCore(mode: "stack")
        seed(core, window: WindowID(1), minWidth: 500)
        #expect(
            core.minimumIsAppBound(of: WindowID(1), axis: "x")
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(-400)]
        )
        #expect(
            refusals == [
                .ownMinimum(WindowID(1), axis: "x", appBound: true)
            ]
        )
    }

    @Test("A learned floor at or under the setting is the setting's")
    func floorUnderTheSettingIsNotTheApps() {
        // The learner knows a 250 pt floor, but `max(300, 250)`
        // resolves to the setting — so the setting is what the
        // press met, and naming the app would send the user
        // after a limit that never bound.
        let (core, _) = makeCore(mode: "stack")
        seed(core, window: WindowID(1), minWidth: 250)
        #expect(
            core.tiler.sizeBound(for: WindowID(1))?.minWidth == 250
        )
        #expect(
            !core.minimumIsAppBound(of: WindowID(1), axis: "x")
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(-500)]
        )
        #expect(
            refusals == [
                .ownMinimum(WindowID(1), axis: "x", appBound: false)
            ]
        )
    }

    @Test("A clamp's own floor above the app's is not the app's")
    func scrollingFloorAboveTheAppFloorIsNotTheApps() throws {
        // The scrolling slot floors at `ScrollSize.minPoints`
        // (100) on top of `min_window_size`. With the setting at
        // 60 and a learned 80 pt floor, the 100 pt slot floor is
        // what the shrink met — above the setting, so a verdict
        // read against the setting alone would name an app that
        // goes to 80 (architect review, 2026-09-14).
        let (core, space) = makeCore(mode: "scrolling")
        core.execute("set_min_window_size", args: [.number(60)])
        #expect(core.tiler.settings.minWindowSize == 60)
        for asked in [CGFloat(60), 40] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 780)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 80, height: 780),
                    settledRead: true
                )
            }
        }
        #expect(
            core.tiler.sizeBound(for: WindowID(1))?.minWidth == 80
        )
        // Above the setting, under the slot floor: the setting
        // alone says "app", the slot floor says otherwise.
        #expect(core.minimumIsAppBound(of: WindowID(1), axis: "x"))
        #expect(
            !core.minimumIsAppBound(
                of: WindowID(1),
                axis: "x",
                raisedBy: Double(ScrollSize.minPoints)
            )
        )
        core.execute("scroll.set_slot_size", args: [.number(120)])
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute("resize", args: [.string("x"), .number(-40)])
        let live = try #require(core.state.workspaces[space])
        let stored = core.tiler.settings
            .resolvedScrolling(for: live)
            .slotSize
            // A points store: the pitch gap is inert (#1382).
            .editablePoints(along: 1200, gap: 0, horizontal: true)
        #expect(stored == 100)
        #expect(
            refusals == [
                .ownMinimum(WindowID(1), axis: "x", appBound: false)
            ]
        )
    }

    @Test("The retile pair reads the ANCHOR's floor, not the trier's")
    func retilePairReadsTheAnchor() {
        // Only w1 carries a learned floor — 900 pt, which the
        // 1170 pt split cannot hold beside w2's 300 pt setting.
        // w1 overhangs and w2 binds at the CONFIGURED floor, so
        // the pair must not name an app: the trier's learned
        // bound is real and is not what bound.
        guard NSScreen.main != nil else { return }
        let (core, _) = makeCore(mode: "bsp")
        seed(core, window: WindowID(1), minWidth: 900)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.retile()
        #expect(
            refusals == [
                .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(1),
                    axis: "x",
                    appBound: false
                )
            ]
        )
    }
}
