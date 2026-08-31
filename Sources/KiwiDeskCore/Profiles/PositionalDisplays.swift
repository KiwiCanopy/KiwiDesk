import CoreGraphics
import Foundation

/// Positional monitor ordering for hardware-agnostic space layout defaults
/// (#53).
public enum PositionalDisplays {
    /// ID of current main display (menu bar display).
    public static var liveMainID: DisplayID {
        DisplayID(CGMainDisplayID())
    }

    /// Orders displays with main display first, then secondaries
    /// left-to-right.
    public static func ordered(
        _ displays: [Display],
        mainID: DisplayID?
    ) -> [Display] {
        guard !displays.isEmpty else { return [] }
        let sorted = displays.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }
            if lhs.frame.minY != rhs.frame.minY {
                return lhs.frame.minY < rhs.frame.minY
            }
            return lhs.fingerprint < rhs.fingerprint
        }
        guard
            let main = sorted.first(where: { $0.id == mainID })
        else { return sorted }
        return [main] + sorted.filter { $0.id != main.id }
    }
}
