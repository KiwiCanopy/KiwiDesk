import CoreGraphics
import Foundation

/// Identifier of a Space (space).
///
/// Spaces support arbitrary string identifiers ("mail", "α", "🎵").
/// Identifiers are case-sensitive, but numeric strings and plain
/// integers are equivalent: `SpaceID("1") == SpaceID(1)`.
public struct SpaceID: Hashable, Sendable, Codable,
    CustomStringConvertible, ExpressibleByStringLiteral,
    ExpressibleByIntegerLiteral
{
    public let raw: String

    public init(_ raw: String) {
        // Canonicalize integer-valued strings ("01" -> "1") so
        // numeric strings and integers compare as equal.
        if let n = Int(raw) {
            self.raw = String(n)
        } else {
            self.raw = raw
        }
    }

    public init(_ number: Int) {
        self.raw = String(number)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(integerLiteral value: Int) {
        self.init(value)
    }

    public var description: String { raw }

    // MARK: - Codable

    /// Encodes as its bare string ("1", "mail") — never as a
    /// keyed `{"raw": ...}` object — so ids read naturally in
    /// profile JSON. Decoding accepts strings and integers
    /// (hand-edited files may write `1` for `"1"`).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Int.self) {
            self.init(number)
        } else {
            self.init(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

// MARK: - Ordering helpers

extension SpaceID {
    /// Sorts space IDs: numeric ids ascending, then named ids
    /// alphabetically. Stable within equal-valued elements.
    ///
    /// Shared by `Profile.orderedSpaces` and
    /// `GuiConfig` sort helpers — the single canonical
    /// numeric-then-lexical comparator for space lists.
    public static func numericLexicalSorted(
        _ ids: [SpaceID]
    ) -> [SpaceID] {
        ids.sorted { a, b in
            switch (Int(a.raw), Int(b.raw)) {
            case (let l?, let r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.raw < b.raw
            }
        }
    }

    /// Order-preserving de-duplication: first occurrence wins.
    ///
    /// Shared by `Profile` and `GuiConfig` — the single
    /// canonical dedup helper for space ID arrays.
    public static func deduplicated(
        _ ids: [SpaceID]
    ) -> [SpaceID] {
        var seen: Set<SpaceID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}

/// Dictionaries keyed by SpaceID serialize as JSON objects
/// (`{"2": ...}`) instead of flattened key/value arrays.
extension SpaceID: CodingKeyRepresentable {
    struct RawKey: CodingKey {
        let stringValue: String
        var intValue: Int? { Int(stringValue) }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
        }
    }

    public var codingKey: CodingKey {
        RawKey(stringValue: raw)!
    }

    public init?(codingKey: some CodingKey) {
        self.init(codingKey.stringValue)
    }
}

/// The layout algorithm applied to a space.
public enum LayoutMode: String, Sendable, Codable, CaseIterable {
    case bsp
    case stack
    case scrolling
    case monocle
    case grid
    case track
    case floating

    /// Whether the layout's output depends on which window
    /// is focused, requiring a retile on focus changes.
    public var isFocusDriven: Bool {
        self == .scrolling || self == .monocle
    }

    /// Whether a focus move defers its AX raise until the
    /// focus retile's animations settle (#143). Scrolling
    /// only: raising first pops a top-pinned row over the
    /// screen before the pan starts. Monocle must stay
    /// raise-first — all its windows share one frame, so the
    /// raise IS the visible focus change. Must stay a subset
    /// of `isFocusDriven`: the deferred raise is armed on the
    /// focus retile that predicate gates.
    public var defersFocusRaise: Bool {
        self == .scrolling
    }
}

/// A Space holding its windows as a flat 1D array.
///
/// This is the core KiwiDesk idea: no trees, no containers. Layout
/// algorithms are pure functions over `windows`.
public struct Space: Sendable, Equatable {
    public let id: SpaceID
    public var mode: LayoutMode
    public var windows: [WindowID]
    public var focused: WindowID?
    /// Per-window vertical share of a stack column (#67):
    /// absent = 1.0 = an even share; `resize("y")` bumps the
    /// focused window's entry. A parallel map next to the flat
    /// array — never a tree. Ephemeral by design: WindowIDs
    /// are OS handles, unstable across relaunch, so there is
    /// nothing to persist the weights against (see
    /// docs/design-decisions.md); pruned when a window leaves
    /// the space.
    public var stackWeights: [WindowID: Double]
    /// The scrolling layout's last-computed viewport offset
    /// (#66): `nil` means "never scrolled yet" (fresh space or
    /// mode switch), so the layout falls back to centering on
    /// the anchor instead of scrolling minimally from a stale
    /// position. Ephemeral like `stackWeights` — never
    /// persisted, cleared only on an actual mode change
    /// (`setMode`). An emptied space keeps its last value;
    /// harmless, every consumer re-clamps it against the live
    /// row.
    public var scrollOffset: CGFloat?
    /// The track layout's boundaries (#128): a window in this
    /// set STARTS a new track; the partition of the tiled
    /// window list falls out of the flat array order plus these
    /// markers (`TrackLayout.counts`) — `masterCount`
    /// generalized, never a tree. Keyed by WindowID like
    /// `stackWeights` (not positional) so floating windows drop
    /// out of the partition with zero maintenance and removal
    /// prunes naturally; a dying head hands its break to its
    /// successor (`remove`), and `swap` keeps boundaries at the
    /// slot, not on the traveling window. Ephemeral: what
    /// persists is the *rule* (`layout.track.limit`/`axis`).
    /// Seeded to all windows on mode entry, cleared on leave.
    public var trackBreaks: Set<WindowID>
    /// Per-track size weight, keyed by the track's head window
    /// (#128): absent = 1.0 = an even share; `resize` across
    /// the axis bumps the focused window's track entry.
    /// Session-only like `stackWeights`; travels with the break
    /// marker.
    public var trackWeights: [WindowID: Double]
    /// Interactive-resize ratio layer (#458): the value a
    /// resize wrote for THIS space when no config override of
    /// the field exists — so resizing a no-override space no
    /// longer moves every other no-override space through the
    /// global. Session-only like `stackWeights` (never
    /// persisted); cleared on an actual mode change and on
    /// config reload. See `SessionRatios`.
    public var sessionRatios: SessionRatios

    public init(
        id: SpaceID,
        mode: LayoutMode = .bsp,
        windows: [WindowID] = [],
        focused: WindowID? = nil,
        stackWeights: [WindowID: Double] = [:],
        scrollOffset: CGFloat? = nil,
        trackBreaks: Set<WindowID> = [],
        trackWeights: [WindowID: Double] = [:],
        sessionRatios: SessionRatios = SessionRatios()
    ) {
        self.id = id
        self.mode = mode
        self.windows = windows
        self.focused = focused
        self.stackWeights = stackWeights
        self.scrollOffset = scrollOffset
        self.trackBreaks = trackBreaks
        self.trackWeights = trackWeights
        self.sessionRatios = sessionRatios
    }

    /// Appends a window if it is not already present.
    public mutating func append(_ window: WindowID) {
        guard !windows.contains(window) else { return }
        windows.append(window)
    }

    /// Inserts a window right after another one (BSP: a new
    /// window splits the FOCUSED window's region). Falls back
    /// to appending when the anchor is unknown.
    public mutating func insert(
        _ window: WindowID,
        after anchor: WindowID?
    ) {
        guard !windows.contains(window) else { return }
        if let anchor,
            let index = windows.firstIndex(of: anchor)
        {
            windows.insert(window, at: index + 1)
        } else {
            windows.append(window)
        }
    }

    /// Inserts a window per the layout's spawn placement rule
    /// (`new_window_placement`); the focused window anchors
    /// the relative placements, falling back to appending
    /// when there is none.
    public mutating func insert(
        _ window: WindowID,
        placement: SpawnPlacement
    ) {
        guard !windows.contains(window) else { return }
        switch placement {
        case .first:
            windows.insert(window, at: 0)
        case .last:
            windows.append(window)
        case .beforeFocused:
            if let focused,
                let index = windows.firstIndex(of: focused)
            {
                windows.insert(window, at: index)
            } else {
                windows.append(window)
            }
        case .afterFocused:
            insert(window, after: focused)
        }
    }

    /// Removes a window; hands focus to the spatial neighbor if
    /// it was focused, and prunes its stack weight (#67).
    public mutating func remove(_ window: WindowID) {
        let removedIndex = windows.firstIndex(of: window)
        // A departing track head hands its break (and the
        // track's weight) to its successor, so closing the
        // first window of a track does not merge that track
        // away (#128).
        handTrackBreakToSuccessor(of: window)
        trackWeights[window] = nil
        windows.removeAll { $0 == window }
        stackWeights[window] = nil
        if focused == window {
            // Fall back to the window that slid into the removed
            // slot (the neighbor further along the array), or the
            // new last window when the removed one was at the end.
            // Not `windows.last` unconditionally — that yanked
            // focus across the whole scrolling row when a middle
            // window closed, panning every window to the far end.
            focused =
                removedIndex.flatMap {
                    windows.indices.contains($0) ? windows[$0] : nil
                } ?? windows.last
        }
    }

    /// Swaps the positions of two windows in the flat array.
    /// Track boundaries are positional: a break marker (and the
    /// head weight riding it) stays at the slot, not on the
    /// traveling window, so swapping two windows never moves a
    /// track boundary (#128). Index 0 is an *implicit* head, so
    /// its weight must stay at the slot too even though it may
    /// carry no explicit marker.
    public mutating func swap(_ a: WindowID, _ b: WindowID) {
        guard let i = windows.firstIndex(of: a),
            let j = windows.firstIndex(of: b)
        else { return }
        windows.swapAt(i, j)
        let aBreak = trackBreaks.contains(a)
        let bBreak = trackBreaks.contains(b)
        if aBreak != bBreak {
            // Move the explicit marker to the window that now
            // holds the head slot.
            if aBreak {
                trackBreaks.remove(a)
                trackBreaks.insert(b)
            } else {
                trackBreaks.remove(b)
                trackBreaks.insert(a)
            }
        }
        // Swap the head weight whenever either slot is a head —
        // an explicit marker OR index 0 (the implicit first
        // head), so an index-0 head's weight can't travel with
        // the moved window.
        if aBreak || bBreak || i == 0 || j == 0 {
            let weight = trackWeights[a]
            trackWeights[a] = trackWeights[b]
            trackWeights[b] = weight
        }
    }

    /// Moves a window to a new index, clamped to valid bounds.
    public mutating func move(_ window: WindowID, to index: Int) {
        guard let from = windows.firstIndex(of: window) else {
            return
        }
        windows.remove(at: from)
        let clamped = min(max(index, 0), windows.count)
        windows.insert(window, at: clamped)
    }
}
