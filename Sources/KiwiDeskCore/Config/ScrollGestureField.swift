import Foundation

/// One scroll-gesture setting's value, as the "Applies to"
/// checklist compares it across profiles (#1656).
public enum ScrollGestureValue: Hashable, Sendable {
    case chord(ScrollChord)
    case flag(Bool)
    case points(Double)
}

/// The scroll-gesture settings one at a time (#1656): the keys of
/// the `RuleReachTable` a Settings row's checklist edits. One case
/// per `ScrollGestureBase` field (`ScrollGestureConfigParityTests`).
public enum ScrollGestureField: String, CaseIterable, Sendable {
    case pan
    case spaceStep = "space_step"
    case naturalTrackpad = "natural_trackpad"
    case naturalMouse = "natural_mouse"
    case longSwipes = "long_swipes"
    case stepDistance = "step_distance"

    /// This field's value in `base`.
    public func value(in base: ScrollGestureBase) -> ScrollGestureValue {
        switch self {
        case .pan: .chord(base.pan)
        case .spaceStep: .chord(base.spaceStep)
        case .naturalTrackpad: .flag(base.naturalTrackpad)
        case .naturalMouse: .flag(base.naturalMouse)
        case .longSwipes: .flag(base.longSwipes)
        case .stepDistance: .points(base.stepDistance)
        }
    }

    /// This field's value in `override`; nil where it follows.
    public func value(
        in override: ScrollGestureOverride
    ) -> ScrollGestureValue? {
        switch self {
        case .pan: override.pan.map { .chord($0) }
        case .spaceStep: override.spaceStep.map { .chord($0) }
        case .naturalTrackpad: override.naturalTrackpad.map { .flag($0) }
        case .naturalMouse: override.naturalMouse.map { .flag($0) }
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
        case (.pan, .chord(let chord)): base.pan = chord
        case (.spaceStep, .chord(let chord)): base.spaceStep = chord
        case (.naturalTrackpad, .flag(let on)): base.naturalTrackpad = on
        case (.naturalMouse, .flag(let on)): base.naturalMouse = on
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
