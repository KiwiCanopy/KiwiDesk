import Foundation

/// BSP's per-split ratios (#3672): split k of the dwindle divides
/// `windows[k]` from the rest, so the window at depth k owns it and
/// its ratio is keyed by that window, one map per axis. A split with
/// no entry takes the Space's shared ratio. Session-only, filed with
/// the other `SessionRatios` (#2921).
public struct BspSplitRatios: Sendable, Equatable {
    /// Side-by-side splits (`resize("x")`), by owning window.
    public var horizontal: [WindowID: Double] = [:]
    /// Stacked splits (`resize("y")`), by owning window.
    public var vertical: [WindowID: Double] = [:]

    public init() {}

    public var isEmpty: Bool { horizontal.isEmpty && vertical.isEmpty }

    /// The ratio `owner`'s split stores along the axis `sideBySide`
    /// names, if any.
    public func ratio(of owner: WindowID, sideBySide: Bool) -> Double? {
        sideBySide ? horizontal[owner] : vertical[owner]
    }

    /// Sets `owner`'s split along the axis `sideBySide` names.
    public mutating func set(
        _ ratio: Double?,
        of owner: WindowID,
        sideBySide: Bool
    ) {
        if sideBySide {
            horizontal[owner] = ratio
        } else {
            vertical[owner] = ratio
        }
    }

    /// The entries `old` owned, moved to `new` (a native-tab rekey).
    public mutating func rekey(_ old: WindowID, to new: WindowID) {
        if let value = horizontal.removeValue(forKey: old) {
            horizontal[new] = value
        }
        if let value = vertical.removeValue(forKey: old) {
            vertical[new] = value
        }
    }

    /// Drops every entry `window` owned.
    public mutating func forget(_ window: WindowID) {
        horizontal[window] = nil
        vertical[window] = nil
    }
}

/// The session snapshot's form (#930): window ids as their raw
/// numbers, since a JSON object takes string keys.
extension BspSplitRatios: Codable {
    private enum CodingKeys: String, CodingKey {
        case horizontal = "h"
        case vertical = "v"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func map(_ key: CodingKeys) throws -> [WindowID: Double] {
            let raw =
                try c.decodeIfPresent([String: Double].self, forKey: key)
                ?? [:]
            var out: [WindowID: Double] = [:]
            for (id, value) in raw {
                if let number = UInt32(id) { out[WindowID(number)] = value }
            }
            return out
        }
        horizontal = try map(.horizontal)
        vertical = try map(.vertical)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        func raw(_ map: [WindowID: Double]) -> [String: Double] {
            Dictionary(uniqueKeysWithValues: map.map { (String($0.raw), $1) })
        }
        if !horizontal.isEmpty {
            try c.encode(raw(horizontal), forKey: .horizontal)
        }
        if !vertical.isEmpty {
            try c.encode(raw(vertical), forKey: .vertical)
        }
    }
}

extension SessionRatios {
    /// Drops one axis's shared BSP ratio and every split's ratio on
    /// it: an explicit `ratio_h`/`ratio_v` write reaches every split.
    public mutating func clearBspAxis(sideBySide: Bool) {
        if sideBySide {
            splitRatioH = nil
            bspSplits?.horizontal = [:]
        } else {
            splitRatioV = nil
            bspSplits?.vertical = [:]
        }
        if bspSplits?.isEmpty == true { bspSplits = nil }
    }
}
