import CoreGraphics
import Foundation

/// Positional monitor ordering for hardware-agnostic space layout defaults
/// (#53).
public enum PositionalDisplays {
    /// ID of current main display (menu bar display); a test core
    /// memoizes it, the read being a WindowServer round trip
    /// (#1894, `ScreenListSeamTests`).
    @MainActor public static var liveMainID: DisplayID {
        #if DEBUG
            if let mainIDOverride { return mainIDOverride() }
        #endif
        return DisplayID(CGMainDisplayID())
    }

    #if DEBUG
        /// Test seam over `liveMainID`; nil reads the machine.
        @MainActor static var mainIDOverride: (() -> DisplayID)?
    #endif

    /// Orders displays with main first, then secondaries
    /// left-to-right, remaining ties broken deterministically
    /// (`minY`, then fingerprint). A nil or absent `mainID` hands
    /// the main slot to the leftmost — every position resolves.
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
