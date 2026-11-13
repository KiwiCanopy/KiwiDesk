import CoreGraphics
import Foundation

/// The bound buttons' half of the router (#3281): a press a binding
/// takes is swallowed and fires, its drags and its release are
/// swallowed with it, and a press no binding takes passes untouched.
/// The release is the press's whatever the keys or the snapshot do
/// meanwhile, since the app never saw the press it would end.
extension PointerTapRouter {
    /// A button the router took, and what this event does to it;
    /// nil for an event of no held button.
    mutating func continuingButton(
        _ sample: PointerSample,
        now: CFAbsoluteTime
    ) -> Routed? {
        guard let (button, edge) = sample.kind.button,
            let pressed = heldButtons[button]
        else { return nil }
        switch edge {
        case .dragged:
            return Routed(swallow: true, grab: [])
        case .up:
            heldButtons[button] = nil
            var released = pressed
            released.phase = .released
            released.location = sample.location
            released.time = now
            return Routed(swallow: true, grab: [], buttons: [released])
        case .down:
            // A second press with no release between: the release
            // was lost, so the old press ends and this one decides
            // afresh.
            heldButtons[button] = nil
            return nil
        }
    }

    /// A press a binding takes: swallowed, fired and held.
    mutating func pressing(
        _ sample: PointerSample,
        _ settings: PointerButtonSettings,
        now: CFAbsoluteTime
    ) -> Routed {
        guard let (button, edge) = sample.kind.button, edge == .down,
            let gesture = button.gesture,
            settings.takes(button, chord: sample.chord)
        else { return .pass }
        let pressed = PointerButtonEvent(
            phase: .pressed,
            key: GestureKey(gesture.input, sample.chord),
            direction: gesture.direction,
            location: sample.location,
            time: now
        )
        heldButtons[button] = pressed
        return Routed(swallow: true, grab: [], buttons: [pressed])
    }

    /// Ends every held button with no event of its own — a
    /// re-enabled tap, whose releases went past it.
    mutating func releasingButtons(
        now: CFAbsoluteTime
    ) -> [PointerButtonEvent] {
        let held = heldButtons.values.sorted { $0.time < $1.time }
        heldButtons = [:]
        return held.map {
            var released = $0
            released.phase = .released
            released.location = nil
            released.time = now
            return released
        }
    }
}

extension PointerSample.Kind {
    enum ButtonEdge: Equatable { case down, dragged, up }

    /// The button this event is of, and which edge.
    var button: (PointerButton, ButtonEdge)? {
        switch self {
        case .leftDown: (.left, .down)
        case .leftDragged: (.left, .dragged)
        case .leftUp: (.left, .up)
        case .buttonDown(let button): (button, .down)
        case .buttonDragged(let button): (button, .dragged)
        case .buttonUp(let button): (button, .up)
        case .mouseMoved, .flagsChanged: nil
        }
    }
}
