import Foundation

/// The Space prune an apply and a Settings Save share (#77).
extension KiwiCore {
    /// Explicit-load reconcile: drop live spaces whose name isn't
    /// in the new profile, forwarding any windows they hold to
    /// the rehome target so none are orphaned. A space whose
    /// name also exists in the new profile is kept untouched —
    /// its windows stay put regardless of the layout difference.
    ///
    /// `preferring` is the profile's explicit fallback space
    /// (#68): when it names a survivor, windows rehome there.
    /// Otherwise `orderedBy` — the profile's `orderedSpaces`
    /// list (#75) — decides: the rehome target is the first
    /// element that is also a survivor, so windows land in the
    /// first space of the new profile's displayed list. When
    /// both lists are empty (degenerate call) the guard skips
    /// pruning entirely.
    ///
    /// `internal` (not `private`): the GUI save path
    /// (`applyProfileScopedState`) reuses this same reconcile so a
    /// Spaces-tab deletion drops the space from live too (#77),
    /// not just profile loads.
    func pruneSpaces(
        keeping survivors: Set<SpaceID>,
        orderedBy storedOrder: [SpaceID],
        preferring explicit: SpaceID? = nil
    ) {
        // `orderedSpaces ⊆ declaredSpaces == survivors` so a
        // non-empty storedOrder always has a match — nil only
        // when storedOrder itself is empty (empty profile).
        let fallback =
            explicit.flatMap {
                survivors.contains($0) ? $0 : nil
            }
            ?? storedOrder.first {
                survivors.contains($0)
            }
        guard let fallback else { return }
        for space in state.workspaces.allSpaces
        where !survivors.contains(space.id) {
            forwardWindows(of: space.id, to: fallback)
        }
    }
}
