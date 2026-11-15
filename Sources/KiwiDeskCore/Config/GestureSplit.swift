import Foundation

/// One axis of a swipe: its two directions (#1873 ▸ Ruling
/// 2026-11-15, a per-axis family arm). Named after the direction
/// pair, since `horizontal` / `vertical` already name a layout's
/// orientation in Lua.
public enum GestureAxis: String, CaseIterable, Codable, Sendable {
    case leftRight = "left_right"
    case upDown = "up_down"

    public var directions: [GestureDirection] {
        switch self {
        case .leftRight: [.left, .right]
        case .upDown: [.up, .down]
        }
    }

    /// The axis a motion's direction lies on; nil for a side
    /// button, which is a press.
    public init?(of direction: GestureDirection) {
        switch direction {
        case .left, .right: self = .leftRight
        case .up, .down: self = .upDown
        case .back, .forward: return nil
        }
    }
}

/// A directional binding below its whole family (#1873 ▸ Ruling
/// 2026-11-15): an axis may take a family, which follows Natural
/// scrolling like a whole one, and a direction a fixed action,
/// which never flips. Mixed forms (2 + 1 + 1) are one value.
/// `GestureAction.split(normalizing:)` is its one fold, so each
/// behaviour has one stored spelling.
public struct GestureSplit: Hashable, Sendable {
    public var axes: [GestureAxis: GestureFamily]
    public var arms: [GestureDirection: LuaAction]

    public init(
        axes: [GestureAxis: GestureFamily] = [:],
        arms: [GestureDirection: LuaAction] = [:]
    ) {
        self.axes = axes
        self.arms = arms
    }

    /// The directions this split binds: an axis family's both, and
    /// each arm's own.
    public var directions: Set<GestureDirection> {
        Set(axes.keys.flatMap(\.directions)).union(arms.keys)
    }
}

extension GestureSplit: ExpressibleByDictionaryLiteral {
    /// Direction arms alone: the per-direction table every split
    /// was before an axis could take a family.
    public init(
        dictionaryLiteral elements: (GestureDirection, LuaAction)...
    ) {
        self.init(arms: Dictionary(uniqueKeysWithValues: elements))
    }
}

/// What one motion of a binding runs: a family's step, or a Lua
/// action. The one resolver every consumer reads a direction
/// through — the runners, the Natural flip and the axis claim —
/// so none re-derives which axis holds a family.
public enum GestureStep: Hashable, Sendable {
    case family(GestureFamily)
    case lua(LuaAction)
}

extension GestureAction {
    /// What a motion toward `direction` runs, nil where it runs
    /// nothing. A tap or a press names no direction.
    public func step(toward direction: GestureDirection?) -> GestureStep? {
        switch self {
        case .run(let action): return .lua(action)
        case .family(let family):
            return direction == nil ? nil : .family(family)
        case .split(let split):
            guard let direction else { return nil }
            if let axis = GestureAxis(of: direction),
                let family = split.axes[axis]
            {
                return .family(family)
            }
            return split.arms[direction].map(GestureStep.lua)
        case .grab: return nil
        }
    }

    /// A split, folded to its one spelling: an arm on an axis that
    /// has a family is dropped, both axes on one family with no arm
    /// is that whole family, and an empty split is nil, which binds
    /// nothing. The one home of the fold every writer takes; the
    /// decoder refuses a body it would change.
    public static func split(normalizing split: GestureSplit) -> GestureAction?
    {
        var split = split
        split.arms = split.arms.filter { direction, _ in
            GestureAxis(of: direction).map { split.axes[$0] == nil } ?? true
        }
        if split.arms.isEmpty, split.axes.count == GestureAxis.allCases.count,
            let family = split.axes.values.first,
            split.axes.values.allSatisfy({ $0 == family })
        {
            return .family(family)
        }
        if split.axes.isEmpty, split.arms.isEmpty { return nil }
        return .split(split)
    }
}
