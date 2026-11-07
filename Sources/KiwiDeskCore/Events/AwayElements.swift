import ApplicationServices

/// The AX element of each window that left for a Space nobody shows
/// (#2939, #3048). AX lists no such window, so the element its
/// departure released is the one way to raise it on its full-screen
/// Space or write its frame on a hidden Desktop. Bookkeeping beside
/// the away ledger, never a member of it: pruned to the ledger's ids
/// at each keep and read, so it takes no ender or re-key of its own,
/// and a use re-checks the id the element names. A window away since
/// before KiwiDesk adopted it has none.
struct AwayElements {
    /// The registration released last, which the gone handler of
    /// the same removal claims synchronously.
    private var released: (id: WindowID, element: AXUIElement)?
    private var kept: [WindowID: AXUIElement] = [:]

    /// Called by `releaseWindowRegistration`, ahead of the release.
    mutating func noteRelease(_ id: WindowID, _ element: AXUIElement?) {
        released = element.map { (id, $0) }
    }

    /// Keeps the element `id` released last, and drops every entry
    /// whose window `away` no longer lists.
    mutating func keep(_ id: WindowID, away: Set<WindowID>) {
        if let released, released.id == id {
            kept[id] = released.element
            self.released = nil
        }
        kept = kept.filter { away.contains($0.key) }
    }

    /// The kept element of `id` while `away` still lists it.
    mutating func element(
        of id: WindowID,
        away: Set<WindowID>
    ) -> AXUIElement? {
        kept = kept.filter { away.contains($0.key) }
        return kept[id]
    }

    mutating func forgetAll() {
        released = nil
        kept = [:]
    }
}
