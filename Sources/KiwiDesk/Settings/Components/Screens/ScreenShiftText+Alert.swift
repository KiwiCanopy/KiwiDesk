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
            namesTheMove(offer),
            let shift = offer.shifts.first,
            let step = steps(shift.delta).first
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

    /// The moves, one line each wherever the title names none,
    /// then one line per shared edge whose crossing moves.
    static func alertMessage(
        _ offer: ScreenOffer,
        in state: ScreenShiftState
    ) -> String {
        var lines: [String] = []
        if !namesTheMove(offer) {
            for shift in offer.shifts {
                for step in steps(shift.delta) {
                    lines.append(move(step, state.name(of: shift.screen)))
                }
            }
        }
        for shift in offer.shifts {
            for crossing in shift.crossings {
                for step in steps(crossing.delta) {
                    lines.append(
                        cross(
                            step,
                            moved: state.name(of: shift.screen),
                            beside: state.name(of: crossing.screen)
                        )
                    )
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Whether the title states the one move, in one direction.
    static func namesTheMove(_ offer: ScreenOffer) -> Bool {
        offer.shifts.count == 1
            && steps(offer.shifts[0].delta).count == 1
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

    /// Where the pointer lands crossing a shifted edge, on each of
    /// its two screens: a screen moved up is entered further down
    /// on it, and the screen across the edge further up.
    private static func cross(
        _ step: Step,
        moved: String,
        beside: String
    ) -> String {
        switch step {
        case .up(let pt):
            return L(
                "screens.shift.alert.cross.up",
                "Between %1$@ and %2$@, the pointer will cross %3$d pt "
                    + "further down on %1$@ and further up on %2$@ than "
                    + "it does now.",
                moved,
                beside,
                pt
            )
        case .down(let pt):
            return L(
                "screens.shift.alert.cross.down",
                "Between %1$@ and %2$@, the pointer will cross %3$d pt "
                    + "further up on %1$@ and further down on %2$@ than "
                    + "it does now.",
                moved,
                beside,
                pt
            )
        case .left(let pt):
            return L(
                "screens.shift.alert.cross.left",
                "Between %1$@ and %2$@, the pointer will cross %3$d pt "
                    + "further right on %1$@ and further left on %2$@ "
                    + "than it does now.",
                moved,
                beside,
                pt
            )
        case .right(let pt):
            return L(
                "screens.shift.alert.cross.right",
                "Between %1$@ and %2$@, the pointer will cross %3$d pt "
                    + "further left on %1$@ and further right on %2$@ "
                    + "than it does now.",
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
