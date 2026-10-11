import Foundation

/// The layouts `cycle_mode` walks (#453, `mode_cycle`): the user's
/// own ordered list, at least two, each at most once. The ring
/// wraps — a layout ring has no geometry to stop at, unlike the
/// Space order's step (#1655).
public enum ModeCycle {
    public static let defaultList: [LayoutMode] = [
        .bsp, .scrolling, .floating,
    ]
    public static let minimumCount = 2

    /// Whether `modes` is a list the cycle can walk.
    public static func isValid(_ modes: [LayoutMode]) -> Bool {
        modes.count >= minimumCount && Set(modes).count == modes.count
    }

    /// The stored list under `key`, the default where absent; a
    /// list the cycle cannot walk fails the file, as every strict
    /// decoder does.
    static func decoded<Key: CodingKey>(
        _ container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> [LayoutMode] {
        try decodedIfPresent(container, forKey: key) ?? defaultList
    }

    /// The stored list under `key`, nil where absent — a profile's
    /// sparse override; a present list is held to the same bar.
    static func decodedIfPresent<Key: CodingKey>(
        _ container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> [LayoutMode]? {
        guard
            let modes = try container.decodeIfPresent(
                [LayoutMode].self,
                forKey: key
            )
        else { return nil }
        guard isValid(modes) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription:
                    "needs \(minimumCount) different layouts or more"
            )
        }
        return modes
    }

    /// A profile's sparse override for `value` over `base`: nil
    /// where it follows the base.
    public static func sparse(
        _ value: [LayoutMode],
        over base: [LayoutMode]
    ) -> [LayoutMode]? {
        value == base ? nil : value
    }

    /// The layout after `current` in `list`, or before it going
    /// back. A layout outside the list sits at the ring's seam:
    /// Next goes to the first entry, Previous to the last.
    public static func step(
        from current: LayoutMode,
        in list: [LayoutMode],
        direction: ModeCycleDirection
    ) -> LayoutMode? {
        guard let first = list.first, let last = list.last else {
            return nil
        }
        guard let index = list.firstIndex(of: current) else {
            return direction == .next ? first : last
        }
        let offset = direction == .next ? 1 : list.count - 1
        return list[(index + offset) % list.count]
    }
}

/// Which way `cycle_mode` steps (#453).
public enum ModeCycleDirection: String, CaseIterable, Sendable {
    case next
    case previous
}
