import Foundation

/// The Spaces visited, as a browser keeps pages (#1655): one trail
/// per screen and one across every screen, both recorded always so
/// switching `space_history` loses nothing. A visit pushes and
/// clears the forward half; Back and Forward move a cursor and
/// never push. Pure and actor-free; `KiwiCore+SpaceHistory` owns
/// the one instance and feeds it. Session-only by ruling: an
/// in-place restart starts it fresh (`SnapshotStoreCensusTests`).
public struct SpaceHistory: Sendable, Equatable {
    /// Which trail: a screen's own, or the one across all screens.
    public enum Key: Hashable, Sendable {
        case screen(DisplayID)
        case allScreens
    }

    /// One trail and where along it the user stands.
    struct Trail: Sendable, Equatable {
        var entries: [SpaceID] = []
        var cursor = 0
    }

    /// Entries kept per trail; the oldest goes first.
    public static let capacity = 50

    private(set) var trails: [Key: Trail] = [:]

    public init() {}

    /// `space` is now shown under `key`. The Space the cursor
    /// stands on is no visit — a Back or Forward landing, or a
    /// re-report of the same state.
    public mutating func visit(_ space: SpaceID, under key: Key) {
        var trail = trails[key] ?? Trail()
        if trail.entries.indices.contains(trail.cursor),
            trail.entries[trail.cursor] == space
        {
            return
        }
        if !trail.entries.isEmpty {
            trail.entries.removeSubrange((trail.cursor + 1)...)
        }
        trail.entries.append(space)
        if trail.entries.count > Self.capacity {
            trail.entries.removeFirst(
                trail.entries.count - Self.capacity
            )
        }
        trail.cursor = trail.entries.count - 1
        trails[key] = trail
    }

    /// The nearest entry `by` steps along (−1 back, +1 forward)
    /// that `reachable` accepts and that is not `shown`, with its
    /// index; nil at the end of the trail.
    public func step(
        under key: Key,
        by direction: Int,
        shown: SpaceID?,
        reachable: (SpaceID) -> Bool
    ) -> (index: Int, space: SpaceID)? {
        guard let trail = trails[key], direction != 0 else { return nil }
        var index = trail.cursor + direction.signum()
        while trail.entries.indices.contains(index) {
            let space = trail.entries[index]
            if space != shown, reachable(space) {
                return (index, space)
            }
            index += direction.signum()
        }
        return nil
    }

    /// Stands the cursor on `index`, which `step` returned.
    public mutating func move(under key: Key, to index: Int) {
        guard var trail = trails[key],
            trail.entries.indices.contains(index)
        else { return }
        trail.cursor = index
        trails[key] = trail
    }

    /// A held Space renumbered: its visits follow it.
    public mutating func rekey(_ old: SpaceID, to new: SpaceID) {
        trails = trails.mapValues { trail in
            var trail = trail
            trail.entries = trail.entries.map { $0 == old ? new : $0 }
            return trail
        }
    }

    /// A Space dropped: its visits go, the cursor staying on the
    /// entry it stood on, or the nearest one before it.
    public mutating func forget(_ space: SpaceID) {
        for (key, trail) in trails {
            var kept = Trail()
            for (index, entry) in trail.entries.enumerated()
            where entry != space {
                // Collapse a repeat the removal made adjacent.
                if kept.entries.last == entry {
                    if index <= trail.cursor {
                        kept.cursor = kept.entries.count - 1
                    }
                    continue
                }
                kept.entries.append(entry)
                if index <= trail.cursor {
                    kept.cursor = kept.entries.count - 1
                }
            }
            trails[key] = kept.entries.isEmpty ? nil : kept
        }
    }

    /// Drops the trails of screens no longer connected.
    public mutating func keepScreens(_ screens: Set<DisplayID>) {
        trails = trails.filter { key, _ in
            guard case .screen(let id) = key else { return true }
            return screens.contains(id)
        }
    }

    /// A trail's entries and cursor, for tests and diagnostics.
    public func entries(under key: Key) -> (list: [SpaceID], cursor: Int) {
        let trail = trails[key] ?? Trail()
        return (trail.entries, trail.cursor)
    }
}
