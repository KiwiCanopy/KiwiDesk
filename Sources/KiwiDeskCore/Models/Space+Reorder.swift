import Foundation

/// The in-array reorders and the scrolling-rest release they
/// share (#1353). `swap` stays in `SpaceModel.swift` for the
/// track-boundary bookkeeping it carries; it calls the same
/// release.
extension Space {
    /// Forgets which slot the scrolling rest was measured
    /// against, so the next pass holds the viewport and pans only
    /// as far as visibility asks (#1353). A reorder is the user's
    /// act on a static row — the pair must visibly trade places
    /// — where `follow` otherwise holds the focused window's
    /// place on screen (#966). The census of callers is this
    /// file plus `swap`; `ScrollSlotReleaseSeamTests` holds that
    /// no order write lives outside the model.
    public mutating func releaseScrollSlot() {
        scrollRest?.slot = nil
    }

    /// Moves window to clamped target index. A reorder, so it
    /// releases; an ARRIVAL seats through `insert` and keeps the
    /// slot (#1353).
    public mutating func move(_ window: WindowID, to index: Int) {
        guard let from = windows.firstIndex(of: window) else {
            return
        }
        windows.remove(at: from)
        let clamped = min(max(index, 0), windows.count)
        windows.insert(window, at: clamped)
        releaseScrollSlot()
    }

    /// Rewrites the order of the `tiled` members to `stream`,
    /// leaving every other id in its slot — the App Bar drop's
    /// reorder. `stream` carries exactly the tiled members, or
    /// nothing is written.
    public mutating func reorder(
        tiled stream: [WindowID],
        among tiled: Set<WindowID>
    ) {
        guard stream.count == windows.filter(tiled.contains).count
        else {
            assertionFailure("reorder stream does not match slots")
            return
        }
        var reordered = stream.makeIterator()
        windows = windows.map { id in
            tiled.contains(id) ? (reordered.next() ?? id) : id
        }
        releaseScrollSlot()
    }
}
