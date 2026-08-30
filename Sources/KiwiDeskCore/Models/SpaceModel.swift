import CoreGraphics
import Foundation

/// Identifier of a Space (case-sensitive strings, integer-canonicalized).
public struct SpaceID: Hashable, Sendable, Codable,
    CustomStringConvertible, ExpressibleByStringLiteral,
    ExpressibleByIntegerLiteral
{
    public let raw: String

    public init(_ raw: String) {
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

extension SpaceID {
    /// Sorts space IDs: numeric IDs ascending, then named IDs alphabetically.
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
    public static func deduplicated(
        _ ids: [SpaceID]
    ) -> [SpaceID] {
        var seen: Set<SpaceID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}

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

    /// True if layout output depends on focused window.
    public var isFocusDriven: Bool {
        self == .scrolling || self == .monocle
    }

    /// True if focus move defers AX raise until animations settle (#143).
    public var defersFocusRaise: Bool {
        self == .scrolling
    }
}

/// Space holding windows as a flat 1D array.
public struct Space: Sendable, Equatable {
    public let id: SpaceID
    public var mode: LayoutMode
    public var windows: [WindowID]
    public var focused: WindowID?
    /// Per-window vertical share in stack column (#67).
    public var stackWeights: [WindowID: Double]
    /// Scrolling layout last-computed viewport rest
    /// (#66, #966, `ScrollRest`).
    public var scrollRest: ScrollRest?
    /// Track layout track boundary markers (#128, `TrackLayout.counts`).
    public var trackBreaks: Set<WindowID>
    /// Per-track weight keyed by head window (#128).
    public var trackWeights: [WindowID: Double]
    /// Session-only interactive resize ratio overrides
    /// (#458, `SessionRatios`).
    public var sessionRatios: SessionRatios

    public init(
        id: SpaceID,
        mode: LayoutMode = .bsp,
        windows: [WindowID] = [],
        focused: WindowID? = nil,
        stackWeights: [WindowID: Double] = [:],
        scrollRest: ScrollRest? = nil,
        trackBreaks: Set<WindowID> = [],
        trackWeights: [WindowID: Double] = [:],
        sessionRatios: SessionRatios = SessionRatios()
    ) {
        self.id = id
        self.mode = mode
        self.windows = windows
        self.focused = focused
        self.stackWeights = stackWeights
        self.scrollRest = scrollRest
        self.trackBreaks = trackBreaks
        self.trackWeights = trackWeights
        self.sessionRatios = sessionRatios
    }

    /// Appends window if not already present.
    public mutating func append(_ window: WindowID) {
        guard !windows.contains(window) else { return }
        windows.append(window)
    }

    /// Inserts window immediately after anchor or appends if anchor missing.
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

    /// Inserts window per layout spawn placement rule.
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

    /// Removes window, updating track heads (#128) and neighbor focus (#67).
    public mutating func remove(_ window: WindowID) {
        let removedIndex = windows.firstIndex(of: window)
        handTrackBreakToSuccessor(of: window)
        trackWeights[window] = nil
        windows.removeAll { $0 == window }
        stackWeights[window] = nil
        if focused == window {
            focused =
                removedIndex.flatMap {
                    windows.indices.contains($0) ? windows[$0] : nil
                } ?? windows.last
        }
    }

    /// Swaps positions of two windows preserving track boundary slots (#128).
    public mutating func swap(_ a: WindowID, _ b: WindowID) {
        guard let i = windows.firstIndex(of: a),
            let j = windows.firstIndex(of: b)
        else { return }
        windows.swapAt(i, j)
        let aBreak = trackBreaks.contains(a)
        let bBreak = trackBreaks.contains(b)
        if aBreak != bBreak {
            if aBreak {
                trackBreaks.remove(a)
                trackBreaks.insert(b)
            } else {
                trackBreaks.remove(b)
                trackBreaks.insert(a)
            }
        }
        if aBreak || bBreak || i == 0 || j == 0 {
            let weight = trackWeights[a]
            trackWeights[a] = trackWeights[b]
            trackWeights[b] = weight
        }
    }

    /// Moves window to clamped target index.
    public mutating func move(_ window: WindowID, to index: Int) {
        guard let from = windows.firstIndex(of: window) else {
            return
        }
        windows.remove(at: from)
        let clamped = min(max(index, 0), windows.count)
        windows.insert(window, at: clamped)
    }
}
