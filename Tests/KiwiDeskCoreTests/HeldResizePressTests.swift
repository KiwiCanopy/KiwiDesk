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
/// writers resolve the Space's screen. Main-actor spend: about 9000
/// `resize` presses, each a command with its own retile and one
/// frame read, some 8 s serialized on a dev Mac.
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
    /// must reach a cue — the point it ends. Answers how many presses
    /// moved, so a hold that cues at once is told from one that ends.
    @discardableResult
    private func hold(
        _ core: KiwiCore,
        focus: UInt32,
        axis: String,
        step: Double,
        presses: Int = 400,
        _ label: String
    ) -> Int {
        var cues = 0
        var moves = 0
        core.borders.onResizeRefusal = { _ in cues += 1 }
        let window = WindowID(focus)
        func length(_ frames: [WindowID: CGRect]) -> CGFloat {
            let frame = frames[window]
            return (axis == "x" ? frame?.width : frame?.height) ?? 0
        }
        // Each press's after-frames are the next press's
        // before-frames: one frame read per press (#3654).
        var frames = core.tiler.calculatedFrames(state: core.state)
        // A window spanning the axis is on no split of it: its press
        // sizes its mates (#1259), so a neighbour must move instead.
        let extent = frames.values.reduce(CGRect.null) { $0.union($1) }
        let spans =
            length(frames)
            >= (axis == "x" ? extent.width : extent.height) - 1
        for press in 0..<presses {
            let cued = cues
            core.execute("resize", args: [.string(axis), .number(step)])
            let after = core.tiler.calculatedFrames(state: core.state)
            let note = Comment(rawValue: "\(label) press \(press)")
            if spans {
                let mateMoved = frames.contains { id, frame in
                    guard let now = after[id] else { return true }
                    return abs(now.width - frame.width) > 0.01
                        || abs(now.height - frame.height) > 0.01
                }
                #expect(mateMoved || cues > cued, note)
            } else {
                let moved =
                    (length(after) - length(frames)) * (step < 0 ? -1 : 1)
                #expect(moved > 0.01 || cues > cued, note)
            }
            if cues > cued { return moves }
            moves += 1
            frames = after
        }
        Issue.record(Comment(rawValue: "\(label): the hold never ends"))
        return moves
    }

    @Test("BSP: a window on the shared ratio's peak cues, never bounces")
    func bspBounce() {
        var moves = 0
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
                        moves += hold(
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
        // The holds move before they end: a press that cued at once
        // would pass every per-press clause.
        #expect(moves >= 1200, "\(moves) moving presses")
    }

    @Test("BSP: a ratio at the store's bound cues on a wide screen")
    func bspRatioBound() {
        var moves = 0
        for focus in UInt32(1)...6 {
            for step in [5.0, -5.0] {
                let core = makeSpace(
                    "bsp",
                    windows: 6,
                    focus: focus,
                    width: 4000,
                    height: 4000
                )
                moves += hold(
                    core,
                    focus: focus,
                    axis: "x",
                    step: step,
                    presses: 600,
                    "w\(focus) x\(step)"
                )
            }
        }
        #expect(moves >= 1300, "\(moves) moving presses")
    }

    @Test("Track: a track weight at its limit cues across the tracks")
    func trackWeightLimit() {
        var moves = 0
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
                    moves += hold(
                        core,
                        focus: focus,
                        axis: "x",
                        step: step,
                        presses: 600,
                        "\(Int(width)) w\(focus) x\(step)"
                    )
                }
            }
        }
        #expect(moves >= 1300, "\(moves) moving presses")
    }

    @Test("BSP: a full-span window's hold ends on the stuck neighbour")
    func fullSpanHoldBlamesTheNeighbour() throws {
        // w1 holds the whole height; its height press moves w2/w3's
        // split until w2 stops at its floor, and every press after
        // that names w2, never w1 (#1259).
        let core = makeSpace(
            "bsp",
            windows: 3,
            focus: 1,
            width: 2560,
            height: 1440
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        for _ in 0..<300 {
            core.execute("resize", args: [.string("y"), .number(-5)])
        }
        let last = try #require(refusals.last)
        #expect(refusals.count > 1)
        #expect(
            last
                == .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(1),
                    axis: "y",
                    appBound: false,
                    anchorApp: "App2"
                )
        )
    }

    /// The refusals a hold ends on where no mate sits at its floor:
    /// the window itself, the ratio moving it the other way or the
    /// ratio's stored bound by the press's sign (#2969, #3643).
    @Test("BSP: the inner window and the store bound refuse on the window")
    func refusalsNameTheWindow() {
        func lastRefusal(
            width: CGFloat,
            windows: UInt32,
            focus: UInt32,
            step: Double
        ) -> ResizeRefusal? {
            let core = makeSpace(
                "bsp",
                windows: windows,
                focus: focus,
                width: width,
                height: width == 4000 ? 4000 : 820
            )
            var refusals: [ResizeRefusal] = []
            core.borders.onResizeRefusal = { refusals.append($0) }
            for _ in 0..<600 where refusals.isEmpty {
                core.execute("resize", args: [.string("x"), .number(step)])
            }
            return refusals.first
        }
        // A grow held to the inner window's peak, where the one
        // shared ratio gives it no larger share either way.
        #expect(
            lastRefusal(width: 1220, windows: 4, focus: 3, step: 5)
                == .ratioLimit(WindowID(3), axis: "x", grows: true)
        )
        // The store's bound on a desk where every floor is far off.
        #expect(
            lastRefusal(width: 4000, windows: 6, focus: 1, step: 5)
                == .ratioLimit(WindowID(1), axis: "x", grows: true)
        )
        #expect(
            lastRefusal(width: 4000, windows: 6, focus: 1, step: -5)
                == .ratioLimit(WindowID(1), axis: "x", grows: false)
        )
    }
}
