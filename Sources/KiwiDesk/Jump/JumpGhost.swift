import Foundation
import KiwiDeskCore
import SwiftUI

/// What the field shows in place of the typing (owner,
/// 2026-10-12): the selected row's name — the typed letters drawn
/// at full ink where they matched, the rest grey — then what ↩
/// does with it. Never typed text: → and Tab never accept it, and
/// where nothing is selected the field shows the typing itself.
@MainActor
enum JumpGhost {
    struct Field: Equatable {
        let name: AttributedString
        let action: String
    }

    static func field(
        selected: JumpSearch.Match?,
        moveHere: Bool
    ) -> Field? {
        guard let selected else { return nil }
        var name = JumpTitle.attributed(selected)
        for run in name.runs {
            let typed = run.inlinePresentationIntent == .stronglyEmphasized
            name[run.range].foregroundColor =
                typed ? Color.primary : Color.secondary
            // Ink alone marks the typed letters; the weight stays.
            name[run.range].inlinePresentationIntent = nil
        }
        let action =
            moveHere
            ? L("jump.ghost.move_here", "— Move here")
            : L("jump.ghost.jump", "— Jump")
        return Field(name: name, action: action)
    }
}
