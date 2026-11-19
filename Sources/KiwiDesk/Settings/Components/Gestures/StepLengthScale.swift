import Foundation
import KiwiDeskCore

/// The Step length slider's curve (#3505, owner 2026-11-19): a
/// track position 0…1 mapped onto mm on a log scale, so each
/// stretch of track changes the step by the same ratio. The low
/// edge is Core's clamp (`ScrollGestureBase.stepLengthRange`, gui.md
/// derived-edge rule); 20 mm is the GUI's curation, Lua open to 60.
enum StepLengthScale {
    /// The slider's span in mm.
    static let range: ClosedRange<Double> =
        ScrollGestureBase.stepLengthRange.lowerBound...20

    /// Where the default rests, which the tick marks.
    static var defaultPosition: Double {
        position(of: ScrollGestureBase.defaults.stepLength)
    }

    /// A drag this close to the default's position lands on it.
    static let snap = 0.03

    /// An arrow key's or a VoiceOver adjust's move along the track.
    static let notch = 0.05

    /// The track position of `mm`; a value outside the span pins
    /// to the nearer end.
    static func position(of mm: Double) -> Double {
        let clamped = min(max(mm, range.lowerBound), range.upperBound)
        return log(clamped / range.lowerBound)
            / log(range.upperBound / range.lowerBound)
    }

    /// Whether a move to `position` leaves `stored` as it is: a value
    /// Lua set past the span, pinned to its end, stays until the knob
    /// leaves that end, so a press toward it never shortens it.
    static func keeps(_ stored: Double, at position: Double) -> Bool {
        (stored > range.upperBound && position >= 1)
            || (stored < range.lowerBound && position <= 0)
    }

    /// The mm a track position stores: snapped onto the default
    /// when near it, else rounded to 0.1 mm.
    static func length(at position: Double) -> Double {
        let t = min(max(position, 0), 1)
        if abs(t - defaultPosition) < snap {
            return ScrollGestureBase.defaults.stepLength
        }
        let mm =
            range.lowerBound
            * pow(range.upperBound / range.lowerBound, t)
        return (mm * 10).rounded() / 10
    }
}
