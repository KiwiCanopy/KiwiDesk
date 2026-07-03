import Foundation

/// Identifier of a virtual workspace (space).
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
}

/// The layout algorithm applied to a space.
public enum LayoutMode: String, Sendable, Codable, CaseIterable {
    case bsp
    case stack
    case scrolling
    case monocle
    case grid
    case floating

    /// Whether the layout's output depends on which window
    /// is focused, requiring a retile on focus changes.
    public var isFocusDriven: Bool {
        self == .scrolling || self == .monocle
    }
}

/// A virtual workspace holding its windows as a flat 1D array.
///
/// This is the core KiwiDesk idea: no trees, no containers. Layout
/// algorithms are pure functions over `windows`.
public struct Space: Sendable, Equatable {
    public let id: SpaceID
    public var mode: LayoutMode
    public var windows: [WindowID]
    public var focused: WindowID?

    public init(
        id: SpaceID,
        mode: LayoutMode = .bsp,
        windows: [WindowID] = [],
        focused: WindowID? = nil
    ) {
        self.id = id
        self.mode = mode
        self.windows = windows
        self.focused = focused
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

    /// Removes a window; clears focus if it was focused.
    public mutating func remove(_ window: WindowID) {
        windows.removeAll { $0 == window }
        if focused == window {
            focused = windows.last
        }
    }

    /// Swaps the positions of two windows in the flat array.
    public mutating func swap(_ a: WindowID, _ b: WindowID) {
        guard let i = windows.firstIndex(of: a),
            let j = windows.firstIndex(of: b)
        else { return }
        windows.swapAt(i, j)
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
