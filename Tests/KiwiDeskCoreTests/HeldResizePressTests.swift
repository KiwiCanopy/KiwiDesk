import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A held resize, press by press, on BSP and across Track's tracks
/// (#2969): every press moves the focused window the way it asks or
/// cues, so a hold ends where nothing more can move — never a bounce
/// between two widths, never a silent press. The display, gaps and
/// floor are pinned (#531, #660). `.enabled(if:)` because the
/// writers resolve the Space's screen.
@Suite(
    "Held resize: every press moves or cues (#2969)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct HeldResizePressTests {
    private func makeSpace(
        _ mode: String,
        windows count: UInt32,
        focus: UInt32,
        width: CGFloat,
        height: CGFloat,
        setup: (KiwiCore) -> Void = { _ in }
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-held-resize-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: width, height: height)
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
        return core
    }

    /// Holds `resize axis step` for `presses` presses: each one must
    /// move the focused window the way it asks or cue, and the hold
    /// must reach a cue — the point it ends.
    private func hold(
        _ core: KiwiCore,
        focus: UInt32,
        axis: String,
        step: Double,
        presses: Int = 400,
        _ label: String
    ) {
        var cues = 0
        core.borders.onResizeRefusal = { _ in cues += 1 }
        let window = WindowID(focus)
        func length() -> CGFloat {
            let frame = core.tiler.calculatedFrames(state: core.state)[window]
            return (axis == "x" ? frame?.width : frame?.height) ?? 0
        }
        // A window spanning the axis is on no split of it: its press
        // sizes its mates (#1259), so a neighbour must move instead.
        let extent = core.tiler.calculatedFrames(state: core.state)
            .values.reduce(CGRect.null) { $0.union($1) }
        let spans =
            length() >= (axis == "x" ? extent.width : extent.height) - 1
        for press in 0..<presses {
            let before = length()
            let frames = core.tiler.calculatedFrames(state: core.state)
            let cued = cues
            core.execute("resize", args: [.string(axis), .number(step)])
            core.retile(animated: false)
            let note = Comment(rawValue: "\(label) press \(press)")
            if spans {
                let after = core.tiler.calculatedFrames(state: core.state)
                let mateMoved = frames.contains { id, frame in
                    guard let now = after[id] else { return true }
                    return abs(now.width - frame.width) > 0.5
                        || abs(now.height - frame.height) > 0.5
                }
                #expect(mateMoved || cues > cued, note)
            } else {
                let moved = (length() - before) * (step < 0 ? -1 : 1)
                #expect(moved > 0.5 || cues > cued, note)
            }
            if cues > cued { return }
        }
        Issue.record(Comment(rawValue: "\(label): the hold never ends"))
    }

    @Test("BSP: a window on the shared ratio's peak cues, never bounces")
    func bspBounce() {
        for (width, height) in [(1220.0, 820.0), (2560.0, 1440.0)] {
            for focus in UInt32(1)...4 {
                for step in [5.0, -5.0] {
                    for axis in ["x", "y"] {
                        let core = makeSpace(
                            "bsp",
                            windows: 4,
                            focus: focus,
                            width: width,
                            height: height
                        )
                        hold(
                            core,
                            focus: focus,
                            axis: axis,
                            step: step,
                            "\(Int(width)) w\(focus) \(axis)\(step)"
                        )
                    }
                }
            }
        }
    }

    @Test("BSP: a ratio at the store's bound cues on a wide screen")
    func bspRatioBound() {
        for focus in UInt32(1)...6 {
            for step in [5.0, -5.0] {
                let core = makeSpace(
                    "bsp",
                    windows: 6,
                    focus: focus,
                    width: 4000,
                    height: 4000
                )
                hold(
                    core,
                    focus: focus,
                    axis: "x",
                    step: step,
                    presses: 1000,
                    "w\(focus) x\(step)"
                )
            }
        }
    }

    @Test("Track: a track weight at its limit cues across the tracks")
    func trackWeightLimit() {
        for width in [4000.0, 5120.0] {
            for focus in UInt32(1)...2 {
                for step in [5.0, -5.0] {
                    let core = makeSpace(
                        "track",
                        windows: 2,
                        focus: focus,
                        width: width,
                        height: 1440
                    ) {
                        $0.execute(
                            "track.set_new_window",
                            args: [.string("own_track")]
                        )
                    }
                    hold(
                        core,
                        focus: focus,
                        axis: "x",
                        step: step,
                        presses: 1000,
                        "\(Int(width)) w\(focus) x\(step)"
                    )
                }
            }
        }
    }
}
