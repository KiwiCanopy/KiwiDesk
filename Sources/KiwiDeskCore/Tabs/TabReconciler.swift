import CoreGraphics
import Foundation

/// Pairs native-tab window transitions for in-place re-keying (#308).
///
/// Native tabs share frames across window IDs (`AXTabGroup`, `hasTabGroup`).
public enum TabReconciler {
    /// Per-edge frame-match tolerance in points.
    public static let frameTolerance: CGFloat = 2

    /// Native tab re-key from vanished window ID to appeared window ID.
    public struct Rekey: Equatable, Sendable {
        public let from: WindowID
        public let to: WindowID

        public init(from: WindowID, to: WindowID) {
            self.from = from
            self.to = to
        }
    }

    /// Matches vanished and appeared tab windows sharing a frame,
    /// with a tab group on EITHER side (#308): apps expose
    /// `AXTabGroup` only at 2+ tabs, so the 1↔2 boundary vanishes
    /// a non-carrier as a carrier appears — requiring both sides
    /// would miss both. A false merge hides a real window; a false
    /// split is only today's extra tile. `vanished` should exclude
    /// minimized windows — a minimize is not a tab close
    /// (`hasTabGroup`).
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
