/// Resolves opening layout modes per screen for saved profile preview
/// cards (#789, #959).
/// Precedence follows `SpacePlacement` (pin -> Main role -> fallback).
/// Tested via `ProfileOpeningModesTests`.
extension Profile {
    /// Opening layout mode for each screen in monitor order
    /// (nil if unassigned).
    public func openingModes() -> [LayoutMode?] {
        let screens = monitorCount
        guard screens > 0 else { return [] }
        guard screens > 1 else {
            return [orderedSpaces.first.flatMap { spaceModes[$0] }]
        }
        guard let set = monitorSets.first else {
            return Array(repeating: nil, count: screens)
        }
        var firsts = set.monitors.prefix(screens).map {
            firstSpace(pinnedTo: $0, in: set)
        }
        if let main = soleUnpinnedScreen(in: firsts),
            let space = firstMainSpace(in: set)
        {
            firsts[main] = space
        }
        return firsts.map { $0.flatMap { spaceModes[$0] } }
    }

    /// Index of sole unpinned screen in set (nil if 0 or >1, #959).
    private func soleUnpinnedScreen(
        in firsts: [SpaceID?]
    ) -> Int? {
        let blank = firsts.indices.filter { firsts[$0] == nil }
        return blank.count == 1 ? blank.first : nil
    }

    /// First ordered space assigned to Main role without display pin.
    private func firstMainSpace(in set: MonitorSet) -> SpaceID? {
        let main = Set(mainSpaces)
        return orderedSpaces.first {
            main.contains($0) && set.spaceMonitorMap[$0] == nil
        }
    }

    /// First ordered space pinned to monitor fingerprint.
    private func firstSpace(
        pinnedTo fingerprint: String,
        in set: MonitorSet
    ) -> SpaceID? {
        orderedSpaces.first {
            set.spaceMonitorMap[$0] == fingerprint
        }
    }
}
