import Foundation

/// What the pointer tap's gesture consumer takes (#1873): the keys
/// bound to each gesture-event slot, and the swipe axes the Dock
/// streams it may claim. Built from the touch front's bindings, the
/// one copy `TouchGestures.onGestureEventChords` hands over.
struct GestureEventSettings: Equatable, Sendable {
    /// The keys of each gesture-event slot this consumer fires.
    var chords: [GestureInput: Set<ScrollChord>]
    /// Per swipe finger count, the Dock axes each chord claims
    /// (`GestureEventSample.horizontal`, `.vertical`).
    var swipeAxes: [Int: [ScrollChord: Set<Int>]]

    /// An empty chord never reaches the consumer, whatever a file
    /// holds: a plain macOS gesture is never taken (owner,
    /// 2026-11-14).
    init(
        _ chords: [GestureInput: Set<ScrollChord>] = [:],
        swipeAxes: [Int: [ScrollChord: Set<Int>]] = [:]
    ) {
        self.chords = chords.compactMapValues { keys in
            let held = keys.filter { !$0.isEmpty }
            return held.isEmpty ? nil : held
        }.filter { $0.key.isGestureEvent && $0.key.isFired }
        self.swipeAxes = swipeAxes.compactMapValues { axes in
            let held = axes.filter { !$0.key.isEmpty && !$0.value.isEmpty }
            return held.isEmpty ? nil : held
        }
    }

    /// The consumer's share of the touch front's bindings: the
    /// fired gesture events, and with `swipes` the touch reader's
    /// swipes.
    init(
        bindings: [GestureKey: GestureAction],
        swipes: Bool
    ) {
        var chords: [GestureInput: Set<ScrollChord>] = [:]
        var axes: [Int: [ScrollChord: Set<Int>]] = [:]
        for (key, action) in bindings where key.input.isFired {
            if key.input.isGestureEvent {
                chords[key.input, default: []].insert(key.chord)
            } else if swipes, let fingers = key.input.fingers,
                TrackpadGestureRouter.fingerRange.contains(fingers),
                !key.input.directions.isEmpty
            {
                axes[fingers, default: [:]][key.chord, default: []]
                    .formUnion(Self.axes(of: action))
            }
        }
        self.init(chords, swipeAxes: axes)
    }

    var isOn: Bool { !chords.isEmpty || !swipeAxes.isEmpty }

    func binds(_ input: GestureInput, _ chord: ScrollChord) -> Bool {
        chords[input]?.contains(chord) == true
    }

    /// Whether a stream of `subtype` begun with `chord` is the
    /// tap's: a magnification serves spread and pinch together.
    func claims(_ subtype: Int, _ chord: ScrollChord) -> Bool {
        switch subtype {
        case GestureEventSample.magnify:
            binds(.spread, chord) || binds(.pinchTogether, chord)
        case GestureEventSample.rotation: binds(.rotate, chord)
        default: false
        }
    }

    /// Whether a Dock stream on `axis`, begun with `chord` while
    /// the touch reader saw `fingers`, is the tap's. With no reading
    /// (0) a swipe of any bound finger count claims the axis, so a
    /// ⌃⌥ four-finger swipe may be swallowed for a three-finger
    /// slot (owner, 2026-11-14).
    func claimsDock(
        _ axis: Int,
        _ chord: ScrollChord,
        fingers: Int
    ) -> Bool {
        guard axis != GestureEventSample.dockPinch else {
            guard fingers == 0 || fingers == 4 else { return false }
            return binds(.spread4, chord) || binds(.pinchTogether4, chord)
        }
        if fingers != 0 {
            return swipeAxes[fingers]?[chord]?.contains(axis) == true
        }
        return swipeAxes.values.contains {
            $0[chord]?.contains(axis) == true
        }
    }

    /// The axes a swipe binding names: a family both, a table its
    /// arms'.
    static func axes(of action: GestureAction) -> Set<Int> {
        let directions: [GestureDirection]
        switch action {
        case .family:
            return [
                GestureEventSample.horizontal,
                GestureEventSample.vertical,
            ]
        case .split(let arms): directions = Array(arms.keys)
        case .run, .grab: return []
        }
        return Set(
            directions.map {
                $0.isHorizontal
                    ? GestureEventSample.horizontal
                    : GestureEventSample.vertical
            }
        )
    }
}
