import Foundation

/// Which input a per-input scroll setting names (#1656).
public enum ScrollInput: String, CaseIterable, Sendable {
    case trackpad, mouse
}

/// The scroll gestures' stored settings (#1656): the global base
/// in `gui.json` every profile starts with; a profile diverges
/// through the sparse `ScrollGestureOverride`, and the two resolve
/// in one home, `KiwiCore.applyScrollGestures`. Which chords scroll
/// and what they do are gesture bindings (`GestureMap`, #3199).
public struct ScrollGestureBase: Equatable, Sendable {
    /// KiwiDesk's own Natural scrolling, per input (ruling
    /// 2026-09-29): macOS's choice followed live, or pinned (#3200).
    public var naturalTrackpad: NaturalScrolling
    public var naturalMouse: NaturalScrolling
    /// A trackpad swipe moves one window; with this on, one more
    /// every `stepLength` of further finger travel.
    public var longSwipes: Bool
    /// Finger travel on the pad per extra window, in mm (#1873 ▸
    /// Ruling 2026-11-16). Global only: no profile overrides it.
    public var stepLength: Double

    /// The bounds a `step_length` must fall within, in mm.
    public static let stepLengthRange = 3.0...60.0

    public static let defaults = ScrollGestureBase(
        naturalTrackpad: .system,
        naturalMouse: .system,
        longSwipes: true,
        stepLength: 10
    )

    public init(
        naturalTrackpad: NaturalScrolling,
        naturalMouse: NaturalScrolling,
        longSwipes: Bool,
        stepLength: Double
    ) {
        self.naturalTrackpad = naturalTrackpad
        self.naturalMouse = naturalMouse
        self.longSwipes = longSwipes
        self.stepLength = stepLength
    }

    /// What the tap is configured with: the routes the gesture
    /// bindings resolved to, and macOS's own Natural scrolling for
    /// a `.system` input.
    public func tapSettings(
        routes: [ScrollChord: ScrollRoute],
        hostNatural: Bool
    ) -> ScrollGestureSettings {
        ScrollGestureSettings(
            routes: routes,
            naturalTrackpad: naturalTrackpad.isNatural(host: hostNatural),
            naturalMouse: naturalMouse.isNatural(host: hostNatural)
        )
    }
}

extension ScrollGestureBase {
    /// The step length clamped, the one refusal a hand-edited
    /// file can still reach; the tap reads this verdict.
    public var sanitized: ScrollGestureBase {
        var result = self
        result.stepLength = min(
            max(stepLength, Self.stepLengthRange.lowerBound),
            Self.stepLengthRange.upperBound
        )
        return result
    }
}

/// A profile's sparse divergence from `ScrollGestureBase`
/// (#1656): a field it leaves nil follows the base. Written by the
/// Settings "Applies to" checklist, never by hand-merging; its
/// fields mirror the base's save the global-only `stepLength`
/// (`ScrollGestureConfigParityTests`).
public struct ScrollGestureOverride: Equatable, Sendable {
    public var naturalTrackpad: NaturalScrolling?
    public var naturalMouse: NaturalScrolling?
    public var longSwipes: Bool?

    public init(
        naturalTrackpad: NaturalScrolling? = nil,
        naturalMouse: NaturalScrolling? = nil,
        longSwipes: Bool? = nil
    ) {
        self.naturalTrackpad = naturalTrackpad
        self.naturalMouse = naturalMouse
        self.longSwipes = longSwipes
    }

    public var isEmpty: Bool { self == ScrollGestureOverride() }

    public func resolved(
        onto base: ScrollGestureBase
    ) -> ScrollGestureBase {
        ScrollGestureBase(
            naturalTrackpad: naturalTrackpad ?? base.naturalTrackpad,
            naturalMouse: naturalMouse ?? base.naturalMouse,
            longSwipes: longSwipes ?? base.longSwipes,
            stepLength: base.stepLength
        )
    }

    /// Inverse of `resolved(onto:)`: nil when nothing diverges.
    public static func diff(
        base: ScrollGestureBase,
        edited: ScrollGestureBase
    ) -> ScrollGestureOverride? {
        func kept<T: Equatable>(_ edited: T, _ base: T) -> T? {
            edited == base ? nil : edited
        }
        let over = ScrollGestureOverride(
            naturalTrackpad: kept(
                edited.naturalTrackpad,
                base.naturalTrackpad
            ),
            naturalMouse: kept(edited.naturalMouse, base.naturalMouse),
            longSwipes: kept(edited.longSwipes, base.longSwipes)
        )
        return over.isEmpty ? nil : over
    }
}
