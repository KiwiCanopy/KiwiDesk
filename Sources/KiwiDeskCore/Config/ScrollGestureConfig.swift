import Foundation

/// Which input a per-input scroll setting names (#1656).
public enum ScrollInput: String, CaseIterable, Sendable {
    case trackpad, mouse
}

/// Why a scroll gesture's chord is refused (#1656 ruling): one
/// modifier alone belongs to macOS and apps, and the two gestures
/// never share a chord. Core names it; the CLI and the Settings
/// recorder each word it.
public enum ScrollChordRefusal: Equatable, Sendable {
    case singleModifier
    /// The other gesture, named, already holds these keys.
    case otherGesture(ScrollGestures.Consumer)

    /// The refusal for `chord` beside `other`, the chord the
    /// gesture `heldBy` holds; empty (off) is always accepted.
    public static func of(
        _ chord: ScrollChord,
        other: ScrollChord,
        heldBy: ScrollGestures.Consumer
    ) -> ScrollChordRefusal? {
        guard !chord.isEmpty else { return nil }
        if chord.rawValue.nonzeroBitCount < 2 { return .singleModifier }
        if chord == other { return .otherGesture(heldBy) }
        return nil
    }
}

/// The scroll gestures' stored settings (#1656): the global base
/// in `gui.json` every profile starts with. A profile diverges
/// through the sparse `ScrollGestureOverride`; the two resolve in
/// one home, `KiwiCore.applyScrollGestures`.
public struct ScrollGestureBase: Equatable, Sendable {
    /// ⌃⌥ + scroll moves focus window by window; empty is off.
    public var pan: ScrollChord
    /// ⌃⌥⌘ + scroll steps between Spaces (#1519); empty is off.
    public var spaceStep: ScrollChord
    /// KiwiDesk's own Natural scrolling, per input and whatever
    /// macOS says (ruling 2026-09-29).
    public var naturalTrackpad: Bool
    public var naturalMouse: Bool
    /// A trackpad swipe moves one window; with this on, one more
    /// every `stepDistance` of further travel.
    public var longSwipes: Bool
    /// Further finger travel per extra window, in points.
    public var stepDistance: Double

    /// The bounds a `step_distance` must fall within.
    public static let stepDistanceRange = 10.0...1000.0

    public static let defaults = ScrollGestureBase(
        pan: [.control, .option],
        spaceStep: [.control, .option, .command],
        naturalTrackpad: true,
        naturalMouse: true,
        longSwipes: false,
        stepDistance: 60
    )

    public init(
        pan: ScrollChord,
        spaceStep: ScrollChord,
        naturalTrackpad: Bool,
        naturalMouse: Bool,
        longSwipes: Bool,
        stepDistance: Double
    ) {
        self.pan = pan
        self.spaceStep = spaceStep
        self.naturalTrackpad = naturalTrackpad
        self.naturalMouse = naturalMouse
        self.longSwipes = longSwipes
        self.stepDistance = stepDistance
    }

    /// What the tap is configured with.
    public var tapSettings: ScrollGestureSettings {
        ScrollGestureSettings(
            chords: [.pan: pan, .step: spaceStep],
            naturalTrackpad: naturalTrackpad,
            naturalMouse: naturalMouse
        )
    }
}

extension ScrollGestureBase {
    /// The refusals the recorder and the verbs make at entry,
    /// applied once more to a value a hand-edited file can still
    /// reach: a lone modifier turns that gesture off, a shared
    /// chord stays the pan's (the `Consumer` order), and the step
    /// distance is clamped. The tap and the Settings entry both
    /// read this one verdict.
    public var sanitized: ScrollGestureBase {
        var result = self
        if ScrollChordRefusal.of(pan, other: [], heldBy: .step) != nil {
            result.pan = []
        }
        if ScrollChordRefusal.of(
            spaceStep,
            other: result.pan,
            heldBy: .pan
        ) != nil {
            result.spaceStep = []
        }
        result.stepDistance = min(
            max(stepDistance, Self.stepDistanceRange.lowerBound),
            Self.stepDistanceRange.upperBound
        )
        return result
    }
}

/// A profile's sparse divergence from `ScrollGestureBase`
/// (#1656): a field it leaves nil follows the base. Written by the
/// Settings "Applies to" checklist, never by hand-merging; its
/// fields mirror the base's (`ScrollGestureConfigParityTests`).
public struct ScrollGestureOverride: Equatable, Sendable {
    public var pan: ScrollChord?
    public var spaceStep: ScrollChord?
    public var naturalTrackpad: Bool?
    public var naturalMouse: Bool?
    public var longSwipes: Bool?
    public var stepDistance: Double?

    public init(
        pan: ScrollChord? = nil,
        spaceStep: ScrollChord? = nil,
        naturalTrackpad: Bool? = nil,
        naturalMouse: Bool? = nil,
        longSwipes: Bool? = nil,
        stepDistance: Double? = nil
    ) {
        self.pan = pan
        self.spaceStep = spaceStep
        self.naturalTrackpad = naturalTrackpad
        self.naturalMouse = naturalMouse
        self.longSwipes = longSwipes
        self.stepDistance = stepDistance
    }

    public var isEmpty: Bool { self == ScrollGestureOverride() }

    public func resolved(
        onto base: ScrollGestureBase
    ) -> ScrollGestureBase {
        ScrollGestureBase(
            pan: pan ?? base.pan,
            spaceStep: spaceStep ?? base.spaceStep,
            naturalTrackpad: naturalTrackpad ?? base.naturalTrackpad,
            naturalMouse: naturalMouse ?? base.naturalMouse,
            longSwipes: longSwipes ?? base.longSwipes,
            stepDistance: stepDistance ?? base.stepDistance
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
            pan: kept(edited.pan, base.pan),
            spaceStep: kept(edited.spaceStep, base.spaceStep),
            naturalTrackpad: kept(
                edited.naturalTrackpad,
                base.naturalTrackpad
            ),
            naturalMouse: kept(edited.naturalMouse, base.naturalMouse),
            longSwipes: kept(edited.longSwipes, base.longSwipes),
            stepDistance: kept(edited.stepDistance, base.stepDistance)
        )
        return over.isEmpty ? nil : over
    }
}
