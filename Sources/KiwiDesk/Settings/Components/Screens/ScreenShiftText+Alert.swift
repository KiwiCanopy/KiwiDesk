import CoreGraphics
import Foundation
import KiwiDeskCore

/// The offer's alert (#2756 ▸ the preview questions): the moves
/// and the crossings they change, nothing else.
@MainActor
extension ScreenShiftText {
    /// One direction a move takes, with its distance in points.
    enum Step: Equatable {
        case up(Int)
        case down(Int)
        case left(Int)
        case right(Int)
    }

    /// A move's steps; a move along both axes takes two.
    static func steps(_ delta: CGVector) -> [Step] {
        var steps: [Step] = []
        let dy = Int(delta.dy.rounded())
        let dx = Int(delta.dx.rounded())
        if dy < 0 { steps.append(.up(-dy)) }
        if dy > 0 { steps.append(.down(dy)) }
        if dx < 0 { steps.append(.left(-dx)) }
        if dx > 0 { steps.append(.right(dx)) }
        return steps
    }

    static func alertTitle(
        _ offer: ScreenOffer,
        in state: ScreenShiftState
    ) -> String {
        guard
            offer.shifts.count == 1,
            let shift = offer.shifts.first,
            let step = steps(shift.delta).first,
            steps(shift.delta).count == 1
        else {
            return L(
                "screens.shift.alert.title.many",
                "Shift these screens in your macOS screen arrangement?"
            )
        }
        let name = state.name(of: shift.screen)
        switch step {
        case .up(let pt):
            return L(
                "screens.shift.alert.title.up",
                "Shift %1$@ up %2$d pt in your macOS screen "
                    + "arrangement?",
                name,
                pt
            )
        case .down(let pt):
            return L(
                "screens.shift.alert.title.down",
                "Shift %1$@ down %2$d pt in your macOS screen "
                    + "arrangement?",
                name,
                pt
            )
        case .left(let pt):
            return L(
                "screens.shift.alert.title.left",
                "Shift %1$@ left %2$d pt in your macOS screen "
                    + "arrangement?",
                name,
                pt
            )
        case .right(let pt):
            return L(
                "screens.shift.alert.title.right",
                "Shift %1$@ right %2$d pt in your macOS screen "
                    + "arrangement?",
                name,
                pt
            )
        }
    }

    /// The moves, one line each where several screens move, then
    /// one line per crossing that changes.
    static func alertMessage(
        _ offer: ScreenOffer,
        in state: ScreenShiftState
    ) -> String {
        var lines: [String] = []
        if offer.shifts.count > 1 {
            for shift in offer.shifts {
                for step in steps(shift.delta) {
                    lines.append(move(step, state.name(of: shift.screen)))
                }
            }
        }
        for shift in offer.shifts {
            for neighbour in shift.crossings {
                for step in steps(shift.delta) {
                    lines.append(
                        crossing(
                            step,
                            moved: state.name(of: shift.screen),
                            beside: state.name(of: neighbour)
                        )
                    )
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func move(_ step: Step, _ name: String) -> String {
        switch step {
        case .up(let pt):
            return L(
                "screens.shift.alert.move.up",
                "%1$@: up %2$d pt",
                name,
                pt
            )
        case .down(let pt):
            return L(
                "screens.shift.alert.move.down",
                "%1$@: down %2$d pt",
                name,
                pt
            )
        case .left(let pt):
            return L(
                "screens.shift.alert.move.left",
                "%1$@: left %2$d pt",
                name,
                pt
            )
        case .right(let pt):
            return L(
                "screens.shift.alert.move.right",
                "%1$@: right %2$d pt",
                name,
                pt
            )
        }
    }

    /// Where the pointer lands crossing the changed edge: a screen
    /// moved up is entered lower on it, and the screen beside it
    /// higher, by the move's distance.
    private static func crossing(
        _ step: Step,
        moved: String,
        beside: String
    ) -> String {
        switch step {
        case .up(let pt):
            return L(
                "screens.shift.alert.crossing.up",
                "The pointer will then enter %1$@ %3$d pt lower than "
                    + "now, and %2$@ %3$d pt higher.",
                moved,
                beside,
                pt
            )
        case .down(let pt):
            return L(
                "screens.shift.alert.crossing.down",
                "The pointer will then enter %1$@ %3$d pt higher than "
                    + "now, and %2$@ %3$d pt lower.",
                moved,
                beside,
                pt
            )
        case .left(let pt):
            return L(
                "screens.shift.alert.crossing.left",
                "The pointer will then enter %1$@ %3$d pt further "
                    + "right than now, and %2$@ %3$d pt further left.",
                moved,
                beside,
                pt
            )
        case .right(let pt):
            return L(
                "screens.shift.alert.crossing.right",
                "The pointer will then enter %1$@ %3$d pt further "
                    + "left than now, and %2$@ %3$d pt further right.",
                moved,
                beside,
                pt
            )
        }
    }

    static var shiftAction: String {
        L("screens.shift.alert.shift", "Shift")
    }

    static var keepAction: String {
        L("screens.shift.alert.keep", "Keep as Is")
    }
}
