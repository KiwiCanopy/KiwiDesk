import CoreGraphics
import Foundation

/// The pure order math behind the z-order restores: which raise
/// sequence a pile needs, and whether a layout piles at all.
/// Actor-free and unit-tested, with no AX or AppKit anywhere near
/// it — the restores in `KiwiCore+ZOrder` are what turn these
/// answers into raises.
extension KiwiCore {
    /// The floor a raise sequence must land above: the plane it
    /// is being lifted over, minus the window that legitimately
    /// sits on top of it. Two callers, one rule — the float raise
    /// passes the active space's tiled members (#418), and the
    /// monocle restore passes the space's OTHER windows.
    ///
    /// Both halves are load-bearing. Without a floor the sequence
    /// diffs itself down to nothing — floats keep their order
    /// among themselves, so a layer buried under the tile
    /// `focusWindow` just raised reads as "already correct" and
    /// nothing is re-raised (#418). And without the exclusion the
    /// floor is a condition no raise can satisfy: a quiet raise
    /// never gets a window above the frontmost app's key window
    /// (measured on device 2026-08-02, macOS 26.6 — 7 windows,
    /// none displaced, over 600 ms), and
    /// after `focusWindow` the key window is exactly this one, so
    /// every poll would fail and the drain would burn its whole
    /// budget on every focus change. Above every OTHER tiled
    /// window is what #418 promises and what a raise can deliver.
    ///
    /// Monocle needs it for a second reason, and that one is not
    /// about the key window at all: it raises exactly ONE window,
    /// and a lone target is trivially "already in order" among a
    /// target set of one, so with no floor the plan comes back
    /// empty and the restore does nothing whatever. Every window
    /// in monocle sits at the same full-screen frame, so the
    /// windows it must clear are the only thing that makes its
    /// raise meaningful.
    ///
    /// Pure so the rule is testable: its call sites reach AX and
    /// no unit test covers them (`guard-prover`, 2026-08-02).
    nonisolated static func raiseFloor(
        tiled: [WindowID],
        excluding raised: WindowID?
    ) -> [WindowID] {
        tiled.filter { $0 != raised }
    }

    /// Raise order for a cascading region: ascending `minY` —
    /// piles always cascade downward, so the most-buried
    /// (topmost) frame raises first and each later raise lands
    /// on top of it. Frame order, not array order: the render
    /// can reorder a pile (`OverlapStack.stickyExempt`, #414
    /// v2), and raising in array order would bury the displaced
    /// window's title bar under the promoted sticky's full
    /// slot. Non-overlapping members sort in too (harmless —
    /// nothing they cover). Ties keep the input order. Pure
    /// math, unit-tested.
    nonisolated static func cascadeRaiseOrder(
        _ ids: [WindowID],
        frames: [WindowID: CGRect]
    ) -> [WindowID] {
        // A frameless id raises LAST (on top): unreachable
        // today (both callers derive ids and frames from the
        // same layout), but if a derivation ever drifts, a
        // window floating above the cascade is visible —
        // buried under it would be a silent loss.
        let unknown = CGFloat.greatestFiniteMagnitude
        return
            ids.enumerated()
            .sorted { a, b in
                let ya = frames[a.element]?.minY ?? unknown
                let yb = frames[b.element]?.minY ?? unknown
                if ya != yb { return ya < yb }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    /// Whether any two laid-out frames overlap — the signature
    /// of an overflow cascade. Tiled tracks never overlap (the
    /// inner gaps separate them), so this is false whenever the
    /// space fits without piling. Pure math, unit-tested.
    nonisolated static func framesCascade(
        _ frames: [WindowID: CGRect]
    ) -> Bool {
        let rects = Array(frames.values)
        for i in rects.indices {
            for j in (i + 1)..<rects.count
            where !rects[i].intersection(rects[j]).isEmpty {
                return true
            }
        }
        return false
    }

    /// The raise sequence for the scrolling piles: both sides
    /// run farthest-from-focus first, so every raise lands on
    /// top of the previous one — the left pile ascending, the
    /// right pile descending. The focused window itself is
    /// left out; the closing focus re-assert puts it on top.
    /// Pure math, unit-tested.
    nonisolated static func scrollingRaiseOrder(
        _ windows: [WindowID],
        focusIndex: Int
    ) -> [WindowID] {
        guard windows.indices.contains(focusIndex) else {
            return windows
        }
        return Array(windows[..<focusIndex])
            + windows[(focusIndex + 1)...].reversed()
    }
}
