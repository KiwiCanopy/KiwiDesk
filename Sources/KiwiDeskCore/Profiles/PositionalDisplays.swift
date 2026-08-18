import CoreGraphics
import Foundation

/// Hardware-agnostic monitor ordering for the built-in default
/// layouts (#53).
///
/// User profiles pin spaces to fingerprints; the built-ins can't
/// (they must work on any hardware), so they address monitors
/// *positionally*: "main display", "second display", … resolved
/// against the live setup. Main is whatever macOS says is main
/// (`CGMainDisplayID`), secondaries follow in physical order
/// (left to right), which is unambiguous by construction.
public enum PositionalDisplays {
    #if DEBUG
        /// Pins the main display for tests: the live read is
        /// the host's, and a fixture's fake `DisplayID` can
        /// collide with it (#523's crime, one API over).
        public static nonisolated(unsafe) var liveMainIDOverride: DisplayID?
    #endif

    /// The current main display's id (the screen with the menu
    /// bar). Pure CoreGraphics — safe off the AX path.
    public static var liveMainID: DisplayID {
        #if DEBUG
            if let override = liveMainIDOverride {
                return override
            }
        #endif
        return DisplayID(CGMainDisplayID())
    }

    /// Orders displays positionally: the main display first,
    /// then secondaries left-to-right (`frame.minX`), ties
    /// broken top-to-bottom and finally by fingerprint so the
    /// order is deterministic for identical coordinates.
    ///
    /// When `mainID` is nil or not present, the leftmost display
    /// takes the main slot — every position still resolves.
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
