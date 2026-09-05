import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The bsp half of #1258's arms — split from
/// `NothingToDivideCueTests` at the file ceiling, which is where
/// tests.md says to split. The stack and track arms live there;
/// what is here is the ratio writer's own reading, including the
/// pile, which answers to neither ratio.
///
/// The assertions read the `ResizeRefusal` STRUCTURE rather than
/// rendered text, so no locale is pinned (#96); one swapped to
/// the sentence would owe it (#740).
@Suite("Nothing to divide — bsp (#1258)")
@MainActor
struct NothingToDivideBspTests {
    /// Pinned display (#531), gaps (#660) and the minimum every
    /// clamp below is measured against.
    private func makeCore(
        width: CGFloat = 1200,
        height: CGFloat = 800
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-nothing-divide-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: width, height: height)
        }
        core.tiler.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(
                top: 10,
                bottom: 10,
                left: 10,
                right: 10
            ),
            inner: Gaps.Inner(horizontal: 16, vertical: 16)
        )
        #expect(core.tiler.settings.minWindowSize == 300)
        return core
    }

    private func space(
        _ core: KiwiCore,
        windows: UInt32,
        mode: String
    ) -> Space {
        for id in 1...windows {
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
        let id = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(id.raw), .string(mode)]
        )
        core.state.workspaces.focus(WindowID(1), in: id)
        return core.state.workspaces[id]!
    }

    private func refusals(
        _ core: KiwiCore,
        _ body: () -> Void
    ) -> [ResizeRefusal] {
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        body()
        return seen
    }

    @Test("A bsp space that divides neither axis says so")
    func bspSingleWindow() {
        // #1259 left this wordless on purpose — naming an axis
        // would have been false about both. This is the string
        // that fills it.
        let core = makeCore()
        _ = space(core, windows: 1, mode: "bsp")
        // BOTH axes: gating the cue on one of them left this
        // suite green while half the wiring was dead
        // (guard-prover, 2026-09-05).
        let seen = refusals(core) {
            for axis in ["x", "y"] {
                core.execute(
                    "resize",
                    args: [.string(axis), .number(-200)]
                )
            }
        }
        #expect(
            seen == [
                .nothingToDivide(
                    WindowID(1),
                    otherAxisDivides: false
                ),
                .nothingToDivide(
                    WindowID(1),
                    otherAxisDivides: false
                ),
            ]
        )
    }

    @Test("An overflow pile answers to no ratio")
    func bspOverflowPileDividesNothing() {
        // A display too narrow for two minimum-size windows
        // makes the layout give up and pile them, and a pile
        // answers to neither ratio. The extent test cannot see
        // that — the cascade offsets each copy, so the union
        // outgrows every slot and the pile reads as
        // participants — which is why the drop exists.
        //
        // The pile is the WHOLE space on purpose. A pile at a
        // leaf leaves its ancestors dividing normally, so no
        // refusal is emitted at all and an assertion there
        // watches nothing (guard-prover, 2026-09-05: the first
        // version of this test could not red, and deleting the
        // drop left the whole suite green).
        let core = makeCore(width: 500, height: 800)
        _ = space(core, windows: 2, mode: "bsp")
        let frames = core.tiler.calculatedFrames(state: core.state)
        let piled = frames[WindowID(1)]!
            .intersects(frames[WindowID(2)]!)
        #expect(piled, "fixture no longer piles — retune it")
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("x"), .number(-300)]
            )
        }
        // Equality, not absence: without the drop this is
        // `.noAxisHere`, the false sentence — and only the
        // verdict tells the two apart.
        #expect(
            seen == [
                .nothingToDivide(
                    WindowID(1),
                    otherAxisDivides: false
                )
            ]
        )
    }

    @Test("A divided axis is untouched by the new cue")
    func aRealSplitStillReportsItsLimit() {
        // The regression pin: three bsp windows, focus one that
        // IS in the vertical split, shrink to its floor. The
        // group has something to divide, so the limit cue is
        // the one that fires.
        let core = makeCore()
        let sp = space(core, windows: 3, mode: "bsp")
        core.state.workspaces.focus(WindowID(2), in: sp.id)
        let seen = refusals(core) {
            core.execute(
                "resize",
                args: [.string("y"), .number(-200)]
            )
        }
        #expect(seen == [.ownMinimum(WindowID(2), axis: "y")])
    }
}
