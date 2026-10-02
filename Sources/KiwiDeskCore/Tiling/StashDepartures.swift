import Foundation

/// Which Spaces' parks a re-issuing pass forces (#1508). A Space
/// that leaves view may hold windows whose state frame still
/// reads an echo-lagged corner from before they were shown, so
/// its park is forced; a Space parked longer than that takes the
/// "already parked" check, or every switch re-parks every hidden
/// window.
///
/// A departure is recorded on whichever pass first sees it —
/// an event pass included, which forces nothing — and is owed
/// the next `forcedPasses` forcing passes, whichever they are:
/// usually the switch's own and its settle's, which re-sends a
/// park a slow app dropped. A second switch or an apply inside
/// the settle spends the second, and the stash's commanded-frame
/// check is then the net. A Space shown again owes nothing.
struct StashDepartures {
    /// Usually the switch pass and its settle.
    static let forcedPasses = 2

    /// The Spaces shown on some display at the last stash pass.
    private(set) var shown: Set<SpaceID> = []
    /// Departed Spaces → forcing passes still owed.
    private(set) var owed: [SpaceID: Int] = [:]

    /// Records the Spaces shown now and returns the Spaces whose
    /// parks this pass forces — none unless `forcing`.
    mutating func pass(
        shown now: Set<SpaceID>,
        forcing: Bool
    ) -> Set<SpaceID> {
        for left in shown.subtracting(now) {
            owed[left] = Self.forcedPasses
        }
        for back in now { owed[back] = nil }
        shown = now
        guard forcing else { return [] }
        let forced = Set(owed.keys)
        owed = owed.compactMapValues { $0 > 1 ? $0 - 1 : nil }
        return forced
    }
}
