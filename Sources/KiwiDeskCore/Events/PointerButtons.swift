import CoreGraphics
import Foundation

/// A mouse button as the pointer tap reads it (#3281): the left
/// and right buttons by their event type, every other one by its
/// `mouseEventButtonNumber` — 2 the wheel's press, 3 Back, 4
/// Forward (measured on a Logitech MX Ergo, 2026-11-13).
enum PointerButton: Hashable, Sendable {
    case left, right
    case other(Int)

    /// The input a press of this button is, and the direction it
    /// names; nil for a button no input takes.
    var gesture: (input: GestureInput, direction: GestureDirection?)? {
        switch self {
        case .left: (.click, nil)
        case .right: (.rightClick, nil)
        case .other(2): (.wheelClick, nil)
        case .other(3): (.sideButtons, .back)
        case .other(4): (.sideButtons, .forward)
        case .other: nil
        }
    }
}

/// One bound press the tap may take: the input, the keys held
/// with it and, for the side buttons, which one.
struct PointerButtonPress: Hashable, Sendable {
    var input: GestureInput
    var chord: ScrollChord
    var direction: GestureDirection?
}

/// The button presses a binding takes, as the tap reads them per
/// event (#3281), built from the resolved list alone. A press not
/// here passes to the app untouched.
public struct PointerButtonSettings: Equatable, Sendable {
    var presses: Set<PointerButtonPress>

    /// Every click and side-button row of a resolved list: a side
    /// button takes both buttons on a family, and only the arms a
    /// split binds.
    public init(resolved: [GestureKey: GestureAction]) {
        var presses: Set<PointerButtonPress> = []
        for (key, action) in resolved {
            guard key.input.isButton else { continue }
            let directions: [GestureDirection?]
            switch action {
            case .run: directions = key.input.directions.isEmpty ? [nil] : []
            case .family: directions = key.input.directions
            case .split(let arms):
                directions = key.input.directions.filter { arms[$0] != nil }
            case .grab: directions = []
            }
            for direction in directions {
                presses.insert(
                    PointerButtonPress(
                        input: key.input,
                        chord: key.chord,
                        direction: direction
                    )
                )
            }
        }
        self.presses = presses
    }

    public var isOn: Bool { !presses.isEmpty }

    /// Whether a press of `button` with `chord` held is a binding's.
    func takes(_ button: PointerButton, chord: ScrollChord) -> Bool {
        guard let gesture = button.gesture else { return false }
        return presses.contains(
            PointerButtonPress(
                input: gesture.input,
                chord: chord,
                direction: gesture.direction
            )
        )
    }
}

/// A bound button's press or release, as the router decided it.
public struct PointerButtonEvent: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case pressed, released }

    public var phase: Phase
    /// The binding the press fired.
    public var key: GestureKey
    /// Back or Forward for a side button; nil otherwise.
    public var direction: GestureDirection?
    /// The event's own location, AX space; nil for a release the
    /// router ended with no event of its own.
    public var location: CGPoint?
    /// The tap's clock (`CFAbsoluteTimeGetCurrent`) at the event.
    public var time: CFAbsoluteTime
}
