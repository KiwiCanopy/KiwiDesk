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
/// Conservative, but not maximally so: a pair merges only when it
/// shares the frame within tolerance AND carries a tab group on at
/// least one side (the 1↔2 boundary needs the either-side rule, since
/// an app exposes the group only at 2+ tabs). A pair with no tab
/// group on either side never merges. A false merge would hide a real
/// window; a false split is only today's extra tile. The residual
/// exposure is same-app windows deliberately stacked at one frame (an
/// `OverlapStack` pile): a carrier closing in the same pass a new
/// same-app window appears there could merge — accepted, as it needs
/// both to land in one reconcile.
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
    /// appeared, when they share a frame and a tab group is present
    /// on **either** side. The either-side rule handles the 1↔2 tab
    /// boundary: an app like Ghostty exposes an `AXTabGroup` only
    /// once a second tab exists, so opening the first extra tab
    /// vanishes a *non*-carrier single-tab window as a carrier 2-tab
    /// window appears, and closing back to one tab does the reverse.
    /// Requiring the group on both sides would miss both. A pair with
    /// no tab group on either side never merges (ordinary windows are
    /// untouched). Greedy and deterministic (lowest id first); each
    /// appeared window is claimed at most once, so N simultaneous
    /// switches in one app pair off by frame. `vanished` should
    /// exclude minimized windows — a minimize is not a tab close.
    public static func rekeys(
        vanished: [TabWindow],
        appeared: [TabWindow],
        tolerance: CGFloat = frameTolerance
    ) -> [Rekey] {
        let candidates = appeared.sorted { $0.id.raw < $1.id.raw }
        var claimed = Set<WindowID>()
        var rekeys: [Rekey] = []
        for gone in vanished.sorted(by: { $0.id.raw < $1.id.raw }) {
            let match = candidates.first {
                !claimed.contains($0.id)
                    && (gone.hasTabGroup || $0.hasTabGroup)
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
