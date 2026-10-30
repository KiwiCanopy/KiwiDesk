import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// One refusal binds every sizing clamp (#2774): the BSP split
/// press, the scrolling slot press, the floating resize and the
/// master side of the split heal each stop at a window's least
/// refusal — one entry, never corroborated — rather than at
/// `min_window_size`. Display and the setting pinned (#531,
/// #660); `.enabled(if:)` because the presses resolve the
/// Space's screen.
@Suite(
    "A refusal binds every sizing clamp (#2774)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RefusalClampGuardTests {
    /// Two windows in `mode` on a pinned `width`×800 display,
    /// w1 focused.
    private func makeCore(
        mode: String,
        width: CGFloat = 1200
    ) -> (KiwiCore, SpaceID) {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-refusal-clamp-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: width, height: 800)
        }
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_200 + id),
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

    /// One width refusal: `answered` to an ask of `asked`.
    private func refuse(
        _ core: KiwiCore,
        _ window: WindowID,
        asked: CGFloat,
        answered: CGFloat
    ) {
        core.tiler.boundLearner.bounds[window] = .init(width: [
            .init(asked: asked, answered: answered)
        ])
    }

    private func width(_ core: KiwiCore, _ id: WindowID) -> CGFloat? {
        core.tiler.calculatedFrames(state: core.state)[id]?.width
    }

    @Test("A BSP split press stops at the refusal")
    func bspPressStopsAtTheRefusal() throws {
        let (core, space) = makeCore(mode: "bsp")
        refuse(core, WindowID(2), asked: 400, answered: 700)
        core.retile()
        let live = try #require(core.state.workspaces[space])
        core.writeCappedBspRatio(
            proposed: 0.9,
            axis: "x",
            span: core.layoutSpan(of: live, horizontal: true),
            space: live,
            focused: WindowID(1)
        )
        // Within the writer's raw-span slack of 700, never at the
        // 300 setting.
        #expect(try #require(width(core, WindowID(2))) >= 650)
    }

    @Test("The master side of the split heal counts a refusal")
    func masterSideHeals() throws {
        let (core, space) = makeCore(mode: "stack")
        core.retile()
        let ratio = {
            core.tiler.settings.resolvedStack(
                for: core.state.workspaces[space]!
            ).masterRatio
        }
        let before = ratio()
        let drawn = try #require(width(core, WindowID(1)))
        // 800 + 300 + gap fits the 1170 pt split.
        try #require(drawn < 800)
        refuse(core, WindowID(1), asked: 400, answered: 800)
        core.retile()
        #expect(ratio() > before)
        #expect(try #require(width(core, WindowID(1))) >= 799.5)
    }

    @Test("A scrolling slot shrink stops at the refusal")
    func scrollingSlotStopsAtTheRefusal() throws {
        let (core, space) = makeCore(mode: "scrolling")
        core.execute("set_min_window_size", args: [.number(60)])
        refuse(core, WindowID(1), asked: 100, answered: 400)
        core.execute("scroll.set_slot_size", args: [.number(450)])
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute("resize", args: [.string("x"), .number(-200)])
        let live = try #require(core.state.workspaces[space])
        let stored = core.tiler.settings
            .resolvedScrolling(for: live)
            .slotSize
            .editablePoints(along: 1200, gap: 0, horizontal: true)
        #expect(stored >= 399.5)
        #expect(
            refusals == [
                .ownMinimum(WindowID(1), axis: "x", appBound: true)
            ]
        )
    }

    @Test("A floating shrink stops at the refusal")
    func floatingShrinkStopsAtTheRefusal() {
        let (core, _) = makeCore(mode: "bsp", width: 1600)
        core.state.apply(
            .windowResized(
                WindowID(2),
                CGRect(x: 100, y: 100, width: 800, height: 500)
            )
        )
        core.state.apply(.windowFocused(WindowID(2)))
        core.state.setFloating(WindowID(2), true)
        core.tiler.animation.isEnabled = false
        var frames: [WindowID: CGRect] = [:]
        core.tiler.animation.apply = { id, frame, _ in
            frames[id] = frame
        }
        refuse(core, WindowID(2), asked: 400, answered: 700)
        _ = core.resizeFloating(WindowID(2), axis: "x", delta: -500)
        #expect((frames[WindowID(2)]?.width ?? 0) >= 699.5)
    }
}
