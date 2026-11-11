import Foundation

/// One scroll-gesture setting's value, as the "Applies to"
/// checklist compares it across profiles (#1656).
public enum ScrollGestureValue: Hashable, Sendable {
    case flag(Bool)
    case natural(NaturalScrolling)
    case points(Double)
}

/// The scroll-gesture settings one at a time (#1656): the keys of
/// the `RuleReachTable` a Settings row's checklist edits. One case
/// per `ScrollGestureBase` field (`ScrollGestureConfigParityTests`).
public enum ScrollGestureField: String, CaseIterable, Sendable {
    case naturalTrackpad = "natural_trackpad"
    case naturalMouse = "natural_mouse"
    case longSwipes = "long_swipes"
    case stepDistance = "step_distance"

    /// This field's value in `base`.
    public func value(in base: ScrollGestureBase) -> ScrollGestureValue {
        switch self {
        case .naturalTrackpad: .natural(base.naturalTrackpad)
        case .naturalMouse: .natural(base.naturalMouse)
        case .longSwipes: .flag(base.longSwipes)
        case .stepDistance: .points(base.stepDistance)
        }
    }

    /// This field's value in `override`; nil where it follows.
    public func value(
        in override: ScrollGestureOverride
    ) -> ScrollGestureValue? {
        switch self {
        case .naturalTrackpad:
            override.naturalTrackpad.map { .natural($0) }
        case .naturalMouse: override.naturalMouse.map { .natural($0) }
        case .longSwipes: override.longSwipes.map { .flag($0) }
        case .stepDistance: override.stepDistance.map { .points($0) }
        }
    }

    /// Writes `value` into `base`; a value of the wrong kind is
    /// ignored.
    public func write(
        _ value: ScrollGestureValue,
        into base: inout ScrollGestureBase
    ) {
        switch (self, value) {
        case (.naturalTrackpad, .natural(let value)):
            base.naturalTrackpad = value
        case (.naturalMouse, .natural(let value)):
            base.naturalMouse = value
        case (.longSwipes, .flag(let on)): base.longSwipes = on
        case (.stepDistance, .points(let points)):
            base.stepDistance = points
        default: break
        }
    }
}

extension ScrollGestureBase {
    /// Every field, keyed by `ScrollGestureField.rawValue`.
    public var fields: [String: ScrollGestureValue] {
        Dictionary(
            uniqueKeysWithValues: ScrollGestureField.allCases.map {
                ($0.rawValue, $0.value(in: self))
            }
        )
    }

    /// `self` with every field `fields` names written over it.
    public func writing(
        _ fields: [String: ScrollGestureValue]
    ) -> ScrollGestureBase {
        var result = self
        for field in ScrollGestureField.allCases {
            if let value = fields[field.rawValue] {
                field.write(value, into: &result)
            }
        }
        return result
    }
}

extension ScrollGestureOverride {
    /// The fields this override sets, keyed like the base's.
    public var fields: [String: ScrollGestureValue] {
        var result: [String: ScrollGestureValue] = [:]
        for field in ScrollGestureField.allCases {
            result[field.rawValue] = field.value(in: self)
        }
        return result
    }
}
