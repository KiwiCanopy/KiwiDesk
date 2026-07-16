import CoreGraphics
import Foundation

/// Pure matcher that turns a native-tab active-tab change into an
/// in-place re-key instead of a destroy + create.
///
/// macOS native tabs (Finder, Terminal, Ghostty) are separate
/// `NSWindow`s that share one on-screen frame, with only the active
/// tab visible to the Accessibility API at any moment and a fresh
/// `CGWindowID` per tab (empirically confirmed, issue #308). So a
/// tab **switch**, an **active-tab close** with a sibling left, and a
/// **new tab opening active** all look identical to a reconcile: one
/// `hasTabGroup` window disappears at the group's frame while another
/// appears at that same frame, same pid. This matcher pairs them so
/// the single layout slot adopts the new id — no spurious tile, no
/// lost focus. A **background** tab open or close mints no AX window,
/// so it never reaches here; a **whole-group close** leaves nothing
/// appearing at the frame, so it stays a normal destroy.
///
/// Biased to NOT merge: both sides must carry a tab group and share
/// the frame within tolerance. A false merge would hide a real
/// window; a false split is only today's extra tile.
public enum TabReconciler {
    /// Per-edge frame-match tolerance, in points — the group's
    /// on-screen frame is stable across a switch; the slack only
    /// absorbs AX-echo rounding.
    public static let frameTolerance: CGFloat = 2

    /// A native-tab re-key: the tracked slot moves from `from`
    /// (the tab that vanished) to `to` (the tab that appeared).
    public struct Rekey: Equatable, Sendable {
        public let from: WindowID
        public let to: WindowID

        public init(from: WindowID, to: WindowID) {
            self.from = from
            self.to = to
        }
    }

    /// Pair windows that vanished this reconcile with ones that
    /// appeared, when both carry a tab group and share a frame.
    /// Greedy and deterministic (lowest id first); each appeared
    /// window is claimed at most once, so N simultaneous switches in
    /// one app pair off by frame. `vanished` should exclude
    /// minimized windows — a minimize is not a tab close.
    public static func rekeys(
        vanished: [TabWindow],
        appeared: [TabWindow],
        tolerance: CGFloat = frameTolerance
    ) -> [Rekey] {
        let candidates = appeared.filter(\.hasTabGroup)
            .sorted { $0.id.raw < $1.id.raw }
        var claimed = Set<WindowID>()
        var rekeys: [Rekey] = []
        for gone in vanished.filter(\.hasTabGroup)
            .sorted(by: { $0.id.raw < $1.id.raw })
        {
            let match = candidates.first {
                !claimed.contains($0.id)
                    && framesMatch($0.frame, gone.frame, tolerance)
            }
            guard let match else { continue }
            claimed.insert(match.id)
            rekeys.append(Rekey(from: gone.id, to: match.id))
        }
        return rekeys
    }

    private static func framesMatch(
        _ a: CGRect,
        _ b: CGRect,
        _ tol: CGFloat
    ) -> Bool {
        abs(a.origin.x - b.origin.x) <= tol
            && abs(a.origin.y - b.origin.y) <= tol
            && abs(a.width - b.width) <= tol
            && abs(a.height - b.height) <= tol
    }
}
